import Foundation

// MARK: - ImageSource
//
// Typed classification of a `layer.src` (or background `imageSrc`)
// string. Replaces the silent "search the filesystem, then give up
// and render `photo.badge.exclamationmark`" behaviour with an explicit
// contract:
//
//   - `.symbolicVehicleGuide` — `template_car`. This is NOT a real
//     image filename; it is an intentional editor guide that tells the
//     renderer to draw a neutral "CAR PHOTO" placeholder box. The
//     asset stager MUST skip these names entirely (it would never
//     find a file by that name on disk, and creating one would be a
//     fake stock image — we never invent car artwork).
//
//   - `.generationFile` — a real file written by the asset stager
//     inside `<AppGroup>/SharedImages/generation_<gen>/<filename>`.
//     The widget reads it through `DriveStudioImageLoader`'s
//     generation-aware path.
//
//   - `.stableSharedFile` — a real file at the App Group root or
//     `<AppGroup>/SharedImages/<filename>` that survives cleanup of
//     older generations (e.g. `home_vehicle.png`).
//
//   - `.verifiedWidgetResource` — a bundled asset (verified via
//     `Bundle.main`) or another widget-loadable resource the
//     `ImageResourceResolver` confirms. The widget can load it
//     without any per-generation copy.
//
//   - `.missing` — no source found. A real missing user image raises
//     `AssetStageError.missing(...)` from `copyReferencedImages`; the
//     stager never silently swallows it.
//
//   - `.unsafe` — absolute path, traversal, empty, or otherwise not
//     safe to append to a destination folder. Stager throws
//     `AssetStageError.unsafeFilename(...)`.
//
// The classifier is pure and DI-friendly: callers pass the App Group
// suite name and the resolver closures they want to use. Tests can
// inject deterministic answers without touching Bundle.main or
// FileManager's container API.
enum ImageSource: Equatable {
    case symbolicVehicleGuide
    case generationFile(generation: String?)
    case stableSharedFile
    case verifiedWidgetResource
    case missing
    case unsafe(reason: String)

    /// Filenames that mean "this layer is a symbolic editor guide,
    /// not a real image." The renderer draws a neutral placeholder
    /// (a dashed box with `CAR PHOTO` text); the asset stager MUST
    /// NOT search for these names on disk.
    static let symbolicVehicleGuideNames: Set<String> = ["template_car"]

    /// True for the one case that must never be staged or copied.
    var isSymbolicGuide: Bool {
        if case .symbolicVehicleGuide = self { return true }
        return false
    }

    /// True for any case where the renderer should display the neutral
    /// "CAR PHOTO" guide instead of attempting to load a UIImage.
    /// Currently identical to `isSymbolicGuide`, but kept as a
    /// separate seam so future symbolic names don't silently change
    /// the renderer's behaviour.
    var shouldRenderGuide: Bool { isSymbolicGuide }

    /// Pure classification of a single `src` string. Callers pass
    /// the App Group container URL and the resolver so the
    /// classifier can decide between `.generationFile`,
    /// `.stableSharedFile`, and `.verifiedWidgetResource` without
    /// touching globals.
    ///
    /// - Parameters:
    ///   - src: the raw `imageSrc` / `layer.src` value (may be empty
    ///     or nil — callers can pass `""` or `"template_car"`).
    ///   - appGroupContainer: `<AppGroup>/` URL, when available.
    ///   - currentGeneration: the generation UUID the stager is
    ///     targeting, or `nil` for the legacy shared-root namespace.
    ///   - resolver: the shared resolver hooks. Production callers
    ///     pass `.production`; tests pass their own.
    static func classify(
        src: String?,
        appGroupContainer: URL?,
        currentGeneration: String?,
        resolver: ImageResourceResolverLite
    ) -> ImageSource {
        guard let src = src, !src.isEmpty else {
            return .unsafe(reason: "empty src")
        }
        if src.hasPrefix("/") || src.hasPrefix("~") {
            return .unsafe(reason: "absolute path")
        }
        if src.contains("..") || src.contains("\0") {
            return .unsafe(reason: "path traversal")
        }
        if symbolicVehicleGuideNames.contains(src) {
            return .symbolicVehicleGuide
        }

        let fm = FileManager.default
        if let container = appGroupContainer {
            // Generation-scoped location: the canonical stager output.
            if let gen = currentGeneration, !gen.isEmpty {
                let genURL = container
                    .appendingPathComponent("SharedImages")
                    .appendingPathComponent("generation_\(gen)")
                    .appendingPathComponent(src)
                if fm.fileExists(atPath: genURL.path) {
                    return .generationFile(generation: gen)
                }
            }
            // Stable App Group locations: `SharedImages/<filename>`
            // (the immediate-write / vehicle-image path) or
            // `<AppGroup>/<filename>` (the third immediate-write path).
            let sharedImagesURL = container
                .appendingPathComponent("SharedImages")
                .appendingPathComponent(src)
            if fm.fileExists(atPath: sharedImagesURL.path) {
                return .stableSharedFile
            }
            let rootURL = container.appendingPathComponent(src)
            if fm.fileExists(atPath: rootURL.path) {
                return .stableSharedFile
            }
        }

        // No on-disk hit — fall through to the resolver. The resolver
        // MUST prove the resource exists (bundle lookup, legacy
        // SharedImages root, etc.). It is never assumed.
        if resolver.verify(name: src) {
            return .verifiedWidgetResource
        }

        return .missing
    }
}

// MARK: - ImageResourceResolverLite
//
// Lightweight, target-agnostic resolver hooks. `ImageResourceResolver`
// in `AppStore.swift` is the production wiring, but the widget
// extension can't import Runner. This slim variant lets both targets
// share the classification logic via `ImageSource.classify`. The
// `ImageResourceResolver` in AppStore keeps doing the staging
// decisions — `ImageSource` is the renderer-facing classification
// only.
struct ImageResourceResolverLite {
    var verifyBundle: (String) -> Bool
    var verifyLegacySharedImagesRoot: (String) -> Bool

    init(
        verifyBundle: @escaping (String) -> Bool,
        verifyLegacySharedImagesRoot: @escaping (String) -> Bool = { _ in false }
    ) {
        self.verifyBundle = verifyBundle
        self.verifyLegacySharedImagesRoot = verifyLegacySharedImagesRoot
    }

    func verify(name: String) -> Bool {
        return verifyBundle(name) || verifyLegacySharedImagesRoot(name)
    }
}