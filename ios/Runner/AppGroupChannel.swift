import Flutter
import UIKit
import WidgetKit
import CryptoKit

/// App Group bridge — register from AppDelegate in Wave 2.
/// Channel: `drive_studio/app_group`
/// Methods: syncState({json: String}), reloadWidgets()
enum AppGroupChannel {
    static let name = "drive_studio/app_group"

    struct Metadata: Codable {
        let schemaVersion: Int
        let generation: String
        let stateFile: String
        let checksum: String
        let updatedAt: String
    }

    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: name, binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "syncState":
                guard
                    let args = call.arguments as? [String: Any],
                    let json = args["json"] as? String
                else {
                    result(FlutterError(code: "bad_args", message: "json required", details: nil))
                    return
                }
                
                // 10MB limit on JSON size
                guard json.utf8.count < 10_000_000 else {
                    result(FlutterError(code: "oversized_state", message: "JSON exceeds 10MB limit", details: nil))
                    return
                }
                
                guard let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroupContract.suiteName),
                      let defaults = UserDefaults(suiteName: AppGroupContract.suiteName) else {
                    result(FlutterError(code: "no_suite", message: "App Group unavailable", details: nil))
                    return
                }
                
                migrateV1ifNeeded(sharedURL: sharedURL, defaults: defaults)
                
                let generationId = UUID().uuidString
                let generationDir = sharedURL.appendingPathComponent("SharedImages/generation_\(generationId)", isDirectory: true)
                
                do {
                    try FileManager.default.createDirectory(at: generationDir, withIntermediateDirectories: true)
                    
                    var finalJson = json
                    if let data = json.data(using: .utf8),
                       let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        
                        let processedDict = try processAndCopyImages(in: dict, to: generationDir)
                        
                        let finalData = try JSONSerialization.data(withJSONObject: processedDict)
                        guard let finalString = String(data: finalData, encoding: .utf8) else {
                            throw NSError(domain: "StateError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to stringify JSON"])
                        }
                        finalJson = finalString
                    }
                    
                    guard let finalDataToWrite = finalJson.data(using: .utf8) else {
                        throw NSError(domain: "StateError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to get data for JSON"])
                    }
                    
                    let stateFileURL = generationDir.appendingPathComponent("state.json")
                    try finalDataToWrite.write(to: stateFileURL, options: .atomic)
                    
                    let checksum = SHA256.hash(data: finalDataToWrite).compactMap { String(format: "%02x", $0) }.joined()
                    
                    let metadata = Metadata(
                        schemaVersion: 2,
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
                    
                    result(nil)
                } catch {
                    result(FlutterError(code: "persistence_error", message: error.localizedDescription, details: nil))
                }
                
            case "reloadWidgets":
                if #available(iOS 14.0, *) {
                    WidgetCenter.shared.reloadAllTimelines()
                }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    static func migrateV1ifNeeded(sharedURL: URL, defaults: UserDefaults) {
        if defaults.data(forKey: "widget_state_v2_metadata") != nil {
            return
        }
        guard let v1json = defaults.string(forKey: AppGroupContract.stateKey) else {
            return
        }
        
        let generationId = "migration_v1"
        let generationDir = sharedURL.appendingPathComponent("SharedImages/generation_\(generationId)", isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(at: generationDir, withIntermediateDirectories: true)
            
            // We won't re-parse old images strictly here, just try to move them or keep them relative
            // Old V1 images were flat in SharedImages/. We'll just leave them flat for V1 migration since WidgetKit falls back.
            
            let finalData = v1json.data(using: .utf8)!
            let stateFileURL = generationDir.appendingPathComponent("state.json")
            try finalData.write(to: stateFileURL, options: .atomic)
            
            let checksum = SHA256.hash(data: finalData).compactMap { String(format: "%02x", $0) }.joined()
            
            let metadata = Metadata(
                schemaVersion: 2,
                generation: generationId,
                stateFile: "SharedImages/generation_\(generationId)/state.json",
                checksum: checksum,
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
            
            let metadataData = try JSONEncoder().encode(metadata)
            defaults.set(metadataData, forKey: "widget_state_v2_metadata")
            defaults.set(generationId, forKey: "widget_state_v2_current_generation")
            
            // Delete old multi-megabyte string
            defaults.removeObject(forKey: AppGroupContract.stateKey)
            defaults.synchronize()
        } catch {
            print("V1 Migration failed: \(error)")
        }
    }
    
    /// Retains exactly:
    ///   - current active generation
    ///   - immediately previous generation (for recovery)
    ///   - "migration_v1" legacy folder (never purged)
    /// All other generation_ folders are deleted atomically.
    static func cleanupOrphanGenerations(sharedURL: URL, defaults: UserDefaults) {
        let currentGen  = defaults.string(forKey: "widget_state_v2_current_generation")
        let prevGen     = defaults.string(forKey: "widget_state_v2_previous_generation")
        let protected   = Set([currentGen, prevGen, "migration_v1"].compactMap { $0 })

        let sharedImagesDir = sharedURL.appendingPathComponent("SharedImages", isDirectory: true)
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: sharedImagesDir,
            includingPropertiesForKeys: nil
        ) else { return }

        for url in contents where url.lastPathComponent.hasPrefix("generation_") {
            let genId = url.lastPathComponent.replacingOccurrences(of: "generation_", with: "")
            if !protected.contains(genId) {
                do {
                    try FileManager.default.removeItem(at: url)
                    print("[AppGroupChannel] 🗑 Deleted orphan generation: \(genId)")
                } catch {
                    print("[AppGroupChannel] ⚠️ Failed to delete generation \(genId): \(error)")
                }
            }
        }
    }

    static func processAndCopyImages(in dict: [String: Any], to generationDir: URL) throws -> [String: Any] {
        var mutableDict = dict

        func saveToGeneration(src: String, filenamePrefix: String) throws -> String {
            var rawData: Data? = nil
            
            if src.hasPrefix("data:image") {
                guard let commaIdx = src.firstIndex(of: ",") else {
                    throw NSError(domain: "ImageError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid data URI"])
                }
                rawData = Data(base64Encoded: String(src[src.index(after: commaIdx)...]))
            } else if FileManager.default.fileExists(atPath: src) {
                rawData = try? Data(contentsOf: URL(fileURLWithPath: src))
            } else {
                let originalFilename = URL(fileURLWithPath: src).lastPathComponent
                if let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    let possibleURL = docDir.appendingPathComponent("drive_studio_images").appendingPathComponent(originalFilename)
                    if FileManager.default.fileExists(atPath: possibleURL.path) {
                        rawData = try? Data(contentsOf: possibleURL)
                    }
                }
            }
            
            // If it's already a bundled asset
            guard let dataToValidate = rawData else {
                return src
            }
            
            // Image Validation
            guard let uiImg = UIImage(data: dataToValidate) else {
                throw NSError(domain: "ImageError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid or unsupported image format. Only raster images (PNG, JPEG, HEIC) are supported."])
            }
            
            // Size limit: Scale down if > 2000px
            var finalImage = uiImg
            if uiImg.size.width > 2000 || uiImg.size.height > 2000 {
                let scale = 2000 / max(uiImg.size.width, uiImg.size.height)
                let newSize = CGSize(width: uiImg.size.width * scale, height: uiImg.size.height * scale)
                UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
                uiImg.draw(in: CGRect(origin: .zero, size: newSize))
                if let scaled = UIGraphicsGetImageFromCurrentImageContext() {
                    finalImage = scaled
                }
                UIGraphicsEndImageContext()
            }
            
            // Convert everything strictly to PNG
            guard let pngData = finalImage.pngData() else {
                throw NSError(domain: "ImageError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to PNG."])
            }
            
            let filename = "\(filenamePrefix)_\(abs(src.hashValue)).png"
            let fileURL = generationDir.appendingPathComponent(filename)
            try pngData.write(to: fileURL, options: .atomic)
            return filename
        }

        // 1. Process vehicle.customImage
        if var vehicle = mutableDict["vehicle"] as? [String: Any],
           let customImg = vehicle["customImage"] as? String, !customImg.isEmpty {
            let relativeName = try saveToGeneration(src: customImg, filenamePrefix: "vehicle_hero")
            vehicle["customImage"] = relativeName
            mutableDict["vehicle"] = vehicle
        }

        // 2. Process layers and background in slots
        if var slots = mutableDict["slots"] as? [[String: Any]] {
            for i in 0..<slots.count {
                var slot = slots[i]
                
                // Clear old slot swift keys (we don't use swift_slot_X anymore, but cleanup legacy)
                if let index = slot["index"] as? Int,
                   let draftId = slot["draftId"] as? String,
                   draftId.isEmpty {
                   UserDefaults(suiteName: AppGroupContract.suiteName)?.removeObject(forKey: "swift_slot_\(index)")
                }

                if var spec = slot["spec"] as? [String: Any] {
                    // background
                    if var background = spec["background"] as? [String: Any],
                       let imageSrc = background["imageSrc"] as? String, !imageSrc.isEmpty {
                        let relativeName = try saveToGeneration(src: imageSrc, filenamePrefix: "bg_\(i)")
                        background["imageSrc"] = relativeName
                        spec["background"] = background
                    }

                    // layers
                    if var layers = spec["layers"] as? [[String: Any]] {
                        for j in 0..<layers.count {
                            var layer = layers[j]
                            if let src = layer["src"] as? String, !src.isEmpty {
                                let relativeName = try saveToGeneration(src: src, filenamePrefix: "layer_\(i)_\(j)")
                                layer["src"] = relativeName
                                layers[j] = layer
                            }
                        }
                        spec["layers"] = layers
                    }
                    
                    slot["spec"] = spec
                    slots[i] = slot
                }
            }
            mutableDict["slots"] = slots
        }

        return mutableDict
    }
}
