import UIKit
import WidgetKit
import CryptoKit

/// Native App Group bridge (V2) — writes widget state to the shared suite.
/// Replaces the old Flutter MethodChannel version. Now called directly from SwiftUI views.
enum AppGroupChannel {
    static let name = "drive_studio/app_group"

    struct Metadata: Codable {
        let schemaVersion: Int
        let generation: String
        let stateFile: String
        let checksum: String
        let updatedAt: String
    }

    private static let processQueue = DispatchQueue(
        label: "com.drivestudio.app_group.process",
        qos: .userInitiated
    )

    /// Sync a JSON state string to the App Group and reload widgets.
    static func syncState(json: String, completion: ((Error?) -> Void)? = nil) {
        guard let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroupContract.suiteName),
              let defaults = UserDefaults(suiteName: AppGroupContract.suiteName) else {
            completion?(NSError(domain: "AppGroupChannel", code: 1, userInfo: [NSLocalizedDescriptionKey: "App Group unavailable"]))
            return
        }

        migrateV1ifNeeded(sharedURL: sharedURL, defaults: defaults)

        let generationId = UUID().uuidString
        let generationDir = sharedURL.appendingPathComponent("SharedImages/generation_\(generationId)", isDirectory: true)

        processQueue.async {
            var caughtError: Error?
            do {
                try FileManager.default.createDirectory(at: generationDir, withIntermediateDirectories: true)

                var finalJson = json
                if let data = json.data(using: .utf8),
                   let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let processedDict = try processAndCopyImages(in: dict, to: generationDir)
                    let finalData = try JSONSerialization.data(withJSONObject: processedDict)
                    if let finalString = String(data: finalData, encoding: .utf8) {
                        finalJson = finalString
                    }
                }

                guard let finalDataToWrite = finalJson.data(using: .utf8) else {
                    throw NSError(domain: "StateError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to encode JSON"])
                }

                let stateFileURL = generationDir.appendingPathComponent("state.json")
                try finalDataToWrite.write(to: stateFileURL, options: .atomic)

                let checksum = SHA256.hash(data: finalDataToWrite).compactMap { String(format: "%02x", $0) }.joined()
                let metadata = Metadata(
                    schemaVersion: AppGroupContract.schemaVersionV2,
                    generation: generationId,
                    stateFile: "SharedImages/generation_\(generationId)/state.json",
                    checksum: checksum,
                    updatedAt: ISO8601DateFormatter().string(from: Date())
                )

                let metadataData = try JSONEncoder().encode(metadata)
                let previousGeneration = defaults.string(forKey: "widget_state_v2_current_generation")
                defaults.set(metadataData, forKey: "widget_state_v2_metadata")
                defaults.set(generationId, forKey: "widget_state_v2_current_generation")
                if let prev = previousGeneration, prev != generationId {
                    defaults.set(prev, forKey: "widget_state_v2_previous_generation")
                }
                defaults.synchronize()

                if #available(iOS 14.0, *) {
                    WidgetCenter.shared.reloadAllTimelines()
                }

                cleanupOrphanGenerations(sharedURL: sharedURL, defaults: defaults)
            } catch {
                caughtError = error
            }

            DispatchQueue.main.async {
                completion?(caughtError)
            }
        }
    }

    static func reloadWidgets() {
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: - Migration

    static func migrateV1ifNeeded(sharedURL: URL, defaults: UserDefaults) {
        if defaults.data(forKey: "widget_state_v2_metadata") != nil { return }
        guard let v1json = defaults.string(forKey: AppGroupContract.stateKey) else { return }

        let generationId = "migration_v1"
        let generationDir = sharedURL.appendingPathComponent("SharedImages/generation_\(generationId)", isDirectory: true)
        let flatImagesDir = sharedURL.appendingPathComponent("SharedImages", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: generationDir, withIntermediateDirectories: true)
            if let entries = try? FileManager.default.contentsOfDirectory(at: flatImagesDir, includingPropertiesForKeys: nil) {
                for url in entries where !url.hasDirectoryPath {
                    let dest = generationDir.appendingPathComponent(url.lastPathComponent)
                    if url.lastPathComponent == "state.json" { continue }
                    try? FileManager.default.copyItem(at: url, to: dest)
                }
            }
            let finalData = v1json.data(using: .utf8)!
            let stateFileURL = generationDir.appendingPathComponent("state.json")
            try finalData.write(to: stateFileURL, options: .atomic)
            let checksum = SHA256.hash(data: finalData).compactMap { String(format: "%02x", $0) }.joined()
            let metadata = Metadata(
                schemaVersion: AppGroupContract.schemaVersionV2,
                generation: generationId,
                stateFile: "SharedImages/generation_\(generationId)/state.json",
                checksum: checksum,
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
            let metadataData = try JSONEncoder().encode(metadata)
            defaults.set(metadataData, forKey: "widget_state_v2_metadata")
            defaults.set(generationId, forKey: "widget_state_v2_current_generation")
            defaults.removeObject(forKey: AppGroupContract.stateKey)
            defaults.synchronize()
        } catch {
            print("V1 Migration failed: \(error)")
        }
    }

    static func cleanupOrphanGenerations(sharedURL: URL, defaults: UserDefaults) {
        let currentGen = defaults.string(forKey: "widget_state_v2_current_generation")
        let prevGen = defaults.string(forKey: "widget_state_v2_previous_generation")
        let protected = Set([currentGen, prevGen, "migration_v1"].compactMap { $0 })
        let sharedImagesDir = sharedURL.appendingPathComponent("SharedImages", isDirectory: true)
        guard let contents = try? FileManager.default.contentsOfDirectory(at: sharedImagesDir, includingPropertiesForKeys: nil) else { return }
        for url in contents where url.lastPathComponent.hasPrefix("generation_") {
            let genId = url.lastPathComponent.replacingOccurrences(of: "generation_", with: "")
            if !protected.contains(genId) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    // MARK: - Image Processing

    static func processAndCopyImages(in dict: [String: Any], to generationDir: URL) throws -> [String: Any] {
        func saveToGeneration(src: String, filenamePrefix: String) throws -> String {
            var rawData: Data?
            if src.hasPrefix("data:image") {
                guard let commaIdx = src.firstIndex(of: ",") else { return src }
                rawData = Data(base64Encoded: String(src[src.index(after: commaIdx)...]))
            } else if FileManager.default.fileExists(atPath: src) {
                rawData = try? Data(contentsOf: URL(fileURLWithPath: src))
            } else {
                let filename = URL(fileURLWithPath: src).lastPathComponent
                if let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    let candidate = docDir.appendingPathComponent("drive_studio_images/\(filename)")
                    if FileManager.default.fileExists(atPath: candidate.path) {
                        rawData = try? Data(contentsOf: candidate)
                    }
                }
            }

            guard let dataToValidate = rawData else { return src }
            guard let uiImg = UIImage(data: dataToValidate) else { return src }

            var finalImage = uiImg
            if uiImg.size.width > 2000 || uiImg.size.height > 2000 {
                let scale = 2000 / max(uiImg.size.width, uiImg.size.height)
                let newSize = CGSize(width: uiImg.size.width * scale, height: uiImg.size.height * scale)
                UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
                uiImg.draw(in: CGRect(origin: .zero, size: newSize))
                if let scaled = UIGraphicsGetImageFromCurrentImageContext() { finalImage = scaled }
                UIGraphicsEndImageContext()
            }

            guard let pngData = finalImage.pngData() else { return src }
            let nameHash = SHA256.hash(data: Data(src.utf8)).compactMap { String(format: "%02x", $0) }.prefix(16).joined()
            let filename = "\(filenamePrefix)_\(nameHash).png"
            let fileURL = generationDir.appendingPathComponent(filename)
            try pngData.write(to: fileURL, options: .atomic)
            return filename
        }

        func looksLikeImageSrc(_ s: String) -> Bool {
            if s.isEmpty || s.hasPrefix("monogram:") { return false }
            if s.hasPrefix("data:image") || s.hasPrefix("assets/") { return true }
            if s.hasPrefix("/") && FileManager.default.fileExists(atPath: s) { return true }
            if let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let candidate = docDir.appendingPathComponent("drive_studio_images/\(URL(fileURLWithPath: s).lastPathComponent)")
                if FileManager.default.fileExists(atPath: candidate.path) { return true }
            }
            return false
        }

        func deepProcess(_ value: Any, prefix: String) throws -> Any {
            if let str = value as? String {
                return looksLikeImageSrc(str) ? (try? saveToGeneration(src: str, filenamePrefix: prefix)) ?? str : str
            } else if let arr = value as? [Any] {
                return try arr.enumerated().map { (i, v) in try deepProcess(v, prefix: "\(prefix)_\(i)") }
            } else if let d = value as? [String: Any] {
                var out = d
                for (k, v) in d { out[k] = try deepProcess(v, prefix: "\(prefix)_\(k)") }
                return out
            }
            return value
        }

        return (try deepProcess(dict, prefix: "asset") as? [String: Any]) ?? dict
    }
}