import Flutter
import UIKit
import WidgetKit
import CryptoKit

/// App Group bridge (V2) — registered from AppDelegate.
/// Channel: `drive_studio/app_group`
/// Methods: syncState({json: String}), reloadWidgets()
///
/// Writes a V2 envelope: a `widget_state_v2_metadata` blob in the App Group
/// UserDefaults plus a generation-scoped state file + copied images at
/// `SharedImages/generation_<gen>/state.json`. The widget extension reads
/// V2 by default and falls back to V1 (`widget_state_v1`) when no V2 metadata
/// is present.
enum AppGroupChannel {
    static let name = "drive_studio/app_group"

    struct Metadata: Codable {
        let schemaVersion: Int
        let generation: String
        let stateFile: String
        let checksum: String
        let updatedAt: String
    }

    /// iOS-12 fix: dedicated background queue for the heavy
    /// decode-scale-encode-write pipeline. The work runs serially off the
    /// Flutter platform thread so the host UI never blocks on
    /// `processAndCopyImages` (which can take seconds when there are
    /// many large asset images).
    private static let processQueue = DispatchQueue(
        label: "com.drivestudio.app_group.process",
        qos: .userInitiated
    )

    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: name, binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "syncState":
                // Validate arguments on the platform thread (fast) so we
                // can fail fast without dispatching. The expensive
                // process-and-copy work happens on `processQueue` below.
                guard
                    let args = call.arguments as? [String: Any],
                    let json = args["json"] as? String
                else {
                    result(FlutterError(code: "bad_args", message: "json required", details: nil))
                    return
                }

                // 10MB limit on JSON size — soft cap matches the Dart-side guard.
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

                // iOS-12: hop to background queue for the decode-scale-
                // encode-write work; then back to main to deliver the
                // FlutterMethodChannel result. We capture everything by
                // value so the closure is independent of the caller's
                // state. `result` (FlutterResult) is itself thread-safe
                // and can be invoked from any queue.
                processQueue.async {
                    var caughtError: Error?
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

                    // Always call `result` exactly once. Deliver on the
                    // main queue so Flutter's framework-side handler
                    // observes the response on the platform thread.
                    DispatchQueue.main.async {
                        if let err = caughtError {
                            result(FlutterError(
                                code: "persistence_error",
                                message: err.localizedDescription,
                                details: nil
                            ))
                        } else {
                            result(nil)
                        }
                    }
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

    /// First-time V2 migration: copies the legacy `widget_state_v1` blob into
    /// a `migration_v1` generation folder with V2 metadata, then removes the
    /// old V1 string. No-op when V2 metadata already exists.
    static func migrateV1ifNeeded(sharedURL: URL, defaults: UserDefaults) {
        if defaults.data(forKey: "widget_state_v2_metadata") != nil {
            return
        }
        guard let v1json = defaults.string(forKey: AppGroupContract.stateKey) else {
            return
        }

        let generationId = "migration_v1"
        let generationDir = sharedURL.appendingPathComponent("SharedImages/generation_\(generationId)", isDirectory: true)
        let flatImagesDir = sharedURL.appendingPathComponent("SharedImages", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: generationDir, withIntermediateDirectories: true)

            // Old V1 images lived flat under SharedImages/. The widget's
            // V2 ImageLoader always prepends `generation_<current>/`, so
            // copy each loose image into the migration_v1 generation dir
            // so the lookup paths line up. iOS-8 fix.
            if let entries = try? FileManager.default.contentsOfDirectory(
                at: flatImagesDir,
                includingPropertiesForKeys: nil
            ) {
                for url in entries where url.hasDirectoryPath == false {
                    let dest = generationDir.appendingPathComponent(url.lastPathComponent)
                    if FileManager.default.fileExists(atPath: url.path) {
                        // Don't overwrite the freshly-written state.json.
                        if url.lastPathComponent == "state.json" { continue }
                        try? FileManager.default.copyItem(at: url, to: dest)
                    }
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
    /// All other `generation_*` folders are deleted atomically.
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
                } catch {
                    print("[AppGroupChannel] Failed to delete orphan generation \(genId): \(error)")
                }
            }
        }
    }

    /// Resolves a Flutter asset path (`assets/...`) to its raw bytes on disk.
///
/// Flutter ships assets at
/// `<Runner.app>/Frameworks/App.framework/flutter_assets/assets/...`.
/// `Bundle.main.url(forResource:withExtension:subdirectory:)` does NOT find
/// them because Flutter doesn't register the `flutter_assets` directory as
/// a bundle resource. Iterating `Bundle.allBundles / .allFrameworks` is
/// also unreliable because `App.framework` is a dynamic framework and may
/// not be enumerated at the moment this runs. The most robust approach is
/// to compute the filesystem path directly from `Bundle.main.bundlePath`.
///
/// Returns `nil` for non-`assets/` paths or when the asset isn't bundled.
    static func loadFlutterAssetData(_ src: String) -> Data? {
        guard src.hasPrefix("assets/") else { return nil }

        // Strip the "assets/" prefix to get the relative path inside
        // `flutter_assets/`.
        let relative = String(src.dropFirst("assets/".count))

        // Flutter iOS apps put the asset tree under
        // `<Bundle.main.bundlePath>/Frameworks/App.framework/flutter_assets/<relative>`.
        let appFramework = Bundle.main.bundleURL
            .appendingPathComponent("Frameworks", isDirectory: true)
            .appendingPathComponent("App.framework", isDirectory: true)
        let assetURL = appFramework
            .appendingPathComponent("flutter_assets", isDirectory: true)
            .appendingPathComponent(relative)

        if let data = try? Data(contentsOf: assetURL) {
            return data
        }

        // Fallback 1: some Flutter packaging modes put assets directly in
        // the main bundle's `flutter_assets/` directory (no App.framework).
        let flatAssetURL = Bundle.main.bundleURL
            .appendingPathComponent("flutter_assets", isDirectory: true)
            .appendingPathComponent(relative)
        if let data = try? Data(contentsOf: flatAssetURL) {
            return data
        }

        // Fallback 2: try the bundle resource API on every loaded bundle
        // (handles edge cases like embedded XCFrameworks or legacy
        // packaging where assets ended up flattened).
        let url = URL(fileURLWithPath: relative)
        let dir = url.deletingLastPathComponent().path
        let filenameNoExt = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension.isEmpty ? nil : url.pathExtension
        let subdir = dir.isEmpty ? "flutter_assets" : "flutter_assets/\(dir)"
        for bundle in Bundle.allBundles + Bundle.allFrameworks {
            if let u = bundle.url(forResource: filenameNoExt, withExtension: ext, subdirectory: subdir) {
                return try? Data(contentsOf: u)
            }
            if let u = bundle.url(forResource: filenameNoExt, withExtension: ext) {
                return try? Data(contentsOf: u)
            }
        }
        return nil
    }

    /// Copies each referenced image (vehicle.customImage, background.imageSrc,
    /// layer.src) into the new generation folder, re-encodes as PNG, scales to
    /// ≤2000 px on the long edge, and rewrites the dict so the JSON references
    /// the new relative filename.
    ///
    /// Asset resolution priority (so the widget picker matches the studio):
    ///   1. `data:image` base64
    ///   2. Absolute file path on disk
    ///   3. File inside `documents/drive_studio_images/`
    ///   4. **Flutter asset under `assets/...` resolved via the main app
    ///      bundle** — this is the critical one. Without it, body-style
    ///      heroes (`assets/vehicles/coupe.png`), model heroes
    ///      (`assets/vehicles/models/aurelio-gt.png`), and stock car photos
    ///      would not appear in the widget since the widget extension's
    ///      `Assets.xcassets/` only carries the textures the editor embeds
    ///      directly. By copying through, every asset the studio can show
    ///      ends up in the App Group container where the widget reads from.
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
            } else if let bundleData = loadFlutterAssetData(src) {
                rawData = bundleData
            } else {
                let originalFilename = URL(fileURLWithPath: src).lastPathComponent
                if let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    let possibleURL = docDir.appendingPathComponent("drive_studio_images").appendingPathComponent(originalFilename)
                    if FileManager.default.fileExists(atPath: possibleURL.path) {
                        rawData = try? Data(contentsOf: possibleURL)
                    }
                }
            }

            // If we can't load the bytes (e.g. a remote URL), leave the source
            // string untouched so the widget's ImageLoader can resolve it from
            // its own bundle, or skip it (the widget's http fetch was removed
            // for timeline-thread safety).
            guard let dataToValidate = rawData else {
                return src
            }

            // Image validation
            guard let uiImg = UIImage(data: dataToValidate) else {
                throw NSError(domain: "ImageError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid or unsupported image format. Only raster images (PNG, JPEG, HEIC) are supported."])
            }

            // Scale down if > 2000px
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

            // SHA-256 the original src bytes so the same asset in different
            // generation folders maps to the same filename — keeps the V2
            // metadata checksum stable across re-saves of unchanged layers.
            let nameHash = SHA256.hash(data: Data(src.utf8))
                .compactMap { String(format: "%02x", $0) }
                .prefix(16)
                .joined()
            let filename = "\(filenamePrefix)_\(nameHash).png"
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

                // Clear legacy `swift_slot_<index>` keys when the slot has no
                // assigned draft (the in-app designer is no longer the source
                // of truth).
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