import Foundation
import CryptoKit

/// Shared App Group identifier, V2 metadata key, and V2 JSON schema
/// version. Use these constants instead of hardcoding the suite name or
/// metadata key at call sites — they must match what `AppStore.saveState`
/// writes.
enum AppGroupContract {
    static let suiteName = "group.com.drivestudio.shared"
    static let stateKey = "widget_state_v1"

    /// Schema version of the V2 envelope (metadata blob + generation folder).
    /// Used by `AppStore.Metadata(...)` when writing, and matched here
    /// when reading.
    static let schemaVersionV2 = 2

    /// UserDefaults key holding the V2 metadata blob (`Metadata` struct).
    static let v2MetadataKey = "widget_state_v2_metadata"
}

/// Single source of truth for reading the V2 `WidgetState` blob written by
/// `AppStore.saveState` from any process in the App Group
/// (Runner app, widget extension, App Intents extension, future
/// CarPlay scene).
///
/// The original 4 duplicate readers were all migrated here in two passes:
///   * Phase 3: `DriveStudioIntentsReader`, `CarPlayAppGroupReader`,
///     `AppStore.loadState()` rewritten to delegate here.
///   * Simplify: `AppGroupHelper` (the 70-line duplicate that lived in
///     `DriveStudioWidget.swift`) deleted; all 7 widget callers
///     (`DriveStudioWidget.swift`, `DriveStudioMixedWidgets.swift`,
///     `NativeSpecialWidgets.swift`) now read from this enum.
///
/// This file lives in the `DriveStudioWidget/` synchronized folder so it is
/// automatically compiled into both the Runner app and the
/// DriveStudioWidgetExtension target.
enum AppGroupState {

    /// V2 metadata envelope. Written by `AppStore` as a JSON object in
    /// `UserDefaults` under `AppGroupContract.v2MetadataKey`. Pointed at
    /// the actual state file in the shared container by `stateFile`.
    struct Metadata: Codable {
        let schemaVersion: Int
        let generation: String
        let stateFile: String
        let checksum: String
        let updatedAt: String
    }

    /// The most recent generation we successfully read. Useful for
    /// per-generation cache lookups (e.g. `SharedImages/generation_<id>/`).
    static var currentGeneration: String?

    /// iOS performance fix: cache the parsed `WidgetState` plus the
    /// generation it came from. Each `getTimeline` call otherwise re-reads
    /// up to ~10 MB from disk, hashes it with SHA-256, and re-decodes the
    /// JSON — all on the timeline thread. Subsequent calls for the same
    /// generation return the cached decode instantly. The cache is
    /// invalidated automatically when the generation changes (via the
    /// host process calling `AppStore.saveState` which bumps the UUID).
    private static var cachedState: (generation: String, state: WidgetState?)?

    /// Load the current `WidgetState`. Tries V2 first, then falls back to
    /// the legacy V1 single-key JSON blob. Returns `nil` if no state is
    /// present, the metadata is unreadable, the state file is missing,
    /// or the SHA-256 checksum does not match.
    static func loadState() -> WidgetState? {
        let defaults = UserDefaults(suiteName: AppGroupContract.suiteName)

        // V2 metadata envelope. Inlined here so the only call sites share
        // one read of the metadata blob.
        func readMetadata() -> Metadata? {
            guard let metadataData = defaults?.data(forKey: AppGroupContract.v2MetadataKey) else {
                return nil
            }
            return try? JSONDecoder().decode(Metadata.self, from: metadataData)
        }

        // Fast path: same generation as cached → return immediately.
        if let cached = cachedState,
           let metadata = readMetadata(),
           metadata.generation == cached.generation {
            currentGeneration = metadata.generation
            return cached.state
        }

        // V2 path: metadata blob → state file on disk → SHA-256 verify.
        if let metadata = readMetadata(),
           let sharedURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: AppGroupContract.suiteName) {
            let fileURL = sharedURL.appendingPathComponent(metadata.stateFile)
            if let data = try? Data(contentsOf: fileURL) {
                let actual = SHA256.hash(data: data)
                    .compactMap { String(format: "%02x", $0) }
                    .joined()
                if actual == metadata.checksum {
                    currentGeneration = metadata.generation
                    let decoded = try? JSONDecoder().decode(WidgetState.self, from: data)
                    cachedState = (generation: metadata.generation, state: decoded)
                    return decoded
                }
            }
            // V2 metadata present but payload unreadable — record the
            // generation so we don't keep re-hashing, but return nil.
            cachedState = (generation: metadata.generation, state: nil)
            currentGeneration = metadata.generation
            return nil
        }

        // V1 fallback: single JSON string in defaults.
        if let json = defaults?.string(forKey: AppGroupContract.stateKey),
           let data = json.data(using: .utf8),
           let state = try? JSONDecoder().decode(WidgetState.self, from: data) {
            cachedState = (generation: "v1", state: state)
            return state
        }

        cachedState = (generation: "", state: nil)
        return nil
    }

    /// Drop the in-memory cache. The host process (`AppStore.saveState`)
    /// calls this every time it writes a fresh generation so the next
    /// read in any process — Runner, widget extension, App Intents — is
    /// forced to re-fetch and re-hash instead of returning the stale
    /// cached `WidgetState`. Safe to call repeatedly; `currentGeneration`
    /// is reset on the next `loadState` call.
    static func invalidateCache() {
        cachedState = nil
        currentGeneration = nil
    }
}