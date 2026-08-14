import UIKit

/// Single source of truth for resolving a `layer.src` to a `UIImage`.
///
/// Compiled into both the `Runner` and `DriveStudioWidgetExtension`
/// targets via the `DriveStudioWidget/` file-system-synchronized
/// group. The Runner side uses it for the in-app editor preview
/// (`WidgetCanvas`) and the widget side uses it for the live
/// TimelineProvider. Keeping one body — instead of two narrower
/// loaders — ensures the editor preview shows exactly what the
/// home-screen widget will eventually render.
///
/// Checked locations, in order:
///
///   1. `data:image/...;base64,…` payload — embedded inline sources
///   2. Bundle / Asset Catalog (`UIImage(named:)`) — covers bundled
///      stock assets like `template_car`
///   3. `<AppGroup>/SharedImages/generation_<gen>/<src>` — the
///      archived per-generation copy the stager writes
///   4. `<AppGroup>/SharedImages/<src>` — the immediate-write
///      location used by `addVehicleLayer` / `addDrawnImageLayer`
///   5. `<AppGroup>/<src>` — App Group root, the third immediate
///      write path (rare, but kept for symmetry)
///   6. `Documents/<src>` — the host sandbox; the widget extension
///      cannot read this, but `Runner` can
///   7. Absolute path — escape hatch for callers that already
///      resolved a full URL
///
/// Generation-aware cache: the cache key is `(namespace, src)`,
/// where `namespace` is one of `g:<generation>`, `legacy:v1` (when
/// no generation is known), or `bundle` (which is shared across
/// generations so a bundled asset isn't decoded once per slot).
struct DriveStudioImageLoader {
    private static let imageCache = NSCache<NSString, UIImage>()

    /// Resolve `src` to a loadable image. Pass `generation` when
    /// the caller already knows which snapshot generation it is
    /// rendering (the widget's `TimelineProvider` does). When
    /// `generation` is nil, the loader falls back to
    /// `AppGroupState.currentGeneration` and ultimately to the
    /// legacy namespace.
    static func load(from src: String, generation: String? = nil) -> UIImage? {
        if src.hasPrefix("data:image") {
            guard let c = src.firstIndex(of: ","),
                  let d = Data(base64Encoded: String(src[src.index(after: c)...])) else { return nil }
            return UIImage(data: d)
        }

        let namespace = cacheNamespace(for: generation)
        let cacheKey = "\(namespace)|\(src)" as NSString
        if let cached = imageCache.object(forKey: cacheKey) { return cached }

        // 1. Asset Catalog / Bundle.main — generation-independent.
        if let assetImg = UIImage(named: src) {
            let bundleKey = "bundle|\(src)" as NSString
            imageCache.setObject(assetImg, forKey: bundleKey)
            imageCache.setObject(assetImg, forKey: cacheKey)
            return assetImg
        }

        // 2. App Group paths — the production cross-process location.
        if let shared = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroupContract.suiteName) {
            let gen = generation ?? AppGroupState.currentGeneration
            if let g = gen {
                let genURL = shared
                    .appendingPathComponent("SharedImages")
                    .appendingPathComponent("generation_\(g)")
                    .appendingPathComponent(src)
                if let img = UIImage(contentsOfFile: genURL.path) {
                    imageCache.setObject(img, forKey: cacheKey)
                    return img
                }
            }
            let sharedImagesURL = shared
                .appendingPathComponent("SharedImages")
                .appendingPathComponent(src)
            if let img = UIImage(contentsOfFile: sharedImagesURL.path) {
                imageCache.setObject(img, forKey: cacheKey)
                return img
            }
            let appGroupRootURL = shared.appendingPathComponent(src)
            if let img = UIImage(contentsOfFile: appGroupRootURL.path) {
                imageCache.setObject(img, forKey: cacheKey)
                return img
            }
        }

        // 3. Host sandbox Documents — only reachable from `Runner`.
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let docsURL = docs.appendingPathComponent(src)
            if let img = UIImage(contentsOfFile: docsURL.path) {
                imageCache.setObject(img, forKey: cacheKey)
                return img
            }
        }

        // 4. Absolute path — last resort.
        if let img = UIImage(contentsOfFile: src) {
            imageCache.setObject(img, forKey: cacheKey)
            return img
        }

        return nil
    }

    /// Map an optional generation to its cache namespace. Bundled
    /// assets share a single namespace so the same bundled image
    /// isn't decoded once per generation.
    static func cacheNamespace(for generation: String?) -> String {
        if let g = generation { return "g:\(g)" }
        return "legacy:v1"
    }

    /// Test seam: compute the cache key the loader would use for
    /// `(generation, src)`. Tests assert directly on this string
    /// to prove the namespace rule: two different generations
    /// produce different keys, and the legacy nil-generation
    /// namespace is clearly separated.
    static func _cacheKey(for src: String, generation: String?) -> String {
        return "\(cacheNamespace(for: generation))|\(src)"
    }

    /// Test seam: clear the in-memory cache so tests start from
    /// a deterministic baseline.
    static func _clearCacheForTest() {
        imageCache.removeAllObjects()
    }

    /// Production cache invalidation — call this whenever a new image
    /// is written to disk (e.g. after `saveVehicleImage` or after
    /// `installState` publishes a new generation). Clears all cached
    /// entries so the very next `load(from:)` call re-reads from disk
    /// and picks up the new bytes.
    static func invalidateCache() {
        imageCache.removeAllObjects()
    }
}
