import UIKit
import ImageIO

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
/// **Memory-safe decoding.** `UIImage(contentsOfFile:)` would
/// materialise the entire backing bitmap (potentially 48 MP × 4
/// bytes ≈ 192 MB) before any subsequent thumbnail work. We use
/// `CGImageSourceCreateThumbnailAtIndex` with
/// `kCGImageSourceThumbnailMaxPixelSize` so the kernel hands us a
/// pre-downsampled `CGImage` directly. A 48 MP JPEG becomes a
/// 1024 px JPEG decode (≈4 MB) regardless of source resolution.
/// EXIF orientation is applied during the same pass via
/// `kCGImageSourceCreateThumbnailWithTransform`.
///
/// Checked locations, in order:
///
///   1. `data:image/...;base64,…` payload — embedded inline sources
///   2. Bundle / Asset Catalog (`UIImage(named:)`) — covers bundled
///      stock assets like `template_car`
///   3. `<AppGroup>/SharedImages/generation_<gen>/<src>` — the
///      archived per-generation copy the stager writes
///   4. `<AppGroup>/SharedImages/<src>` — the immediate-write
///      location used by `addVehicleLayer`
///   5. `<AppGroup>/<src>` — App Group root, the third immediate
///      write path (rare, but kept for symmetry)
///   6. `Documents/<src>` — the host sandbox; the widget extension
///      cannot read this, but `Runner` can
///   7. Absolute path — escape hatch for callers that already
///      resolved a full URL
///
/// **Generation-aware cache.** The cache key is `(namespace, src)`,
/// where `namespace` is one of `g:<generation>`, `legacy:v1` (when
/// no generation is known), or `bundle` (which is shared across
/// generations so a bundled asset isn't decoded once per slot).
///
/// **Cache cost.** NSCache entries are billed by their decoded
/// pixel memory (width × height × 4) so the widget can hold ~24
/// medium-sized photos before evicting instead of an unbounded
/// count of arbitrary bytes. `totalCostLimit` caps the aggregate
/// footprint at ~96 MB.
struct DriveStudioImageLoader {

    /// Maximum long edge (backing pixels) for decoded images.
    /// Matches `ImageDerivativeService.maxLongEdgePixels` so
    /// the widget renders the same pixel resolution the stager
    /// produced — anything larger would be downsampled by the
    /// kernel anyway and just costs memory.
    static let maxLongEdgePixels: Int = 1024

    /// Bytes per pixel used for cost accounting. RGBA premultiplied
    /// last — matches what UIImage allocates when decoded into a
    /// CGContext-backed bitmap.
    static let bytesPerPixel: Int = 4

    /// Total NSCache cost budget. 24 megapixels' worth of decoded
    /// RGBA pixels = ~96 MB. WidgetKit timelines routinely swap
    /// caches under memory pressure, so we leave room for the
    /// rest of the process.
    static let totalCacheCostLimit: Int = 96 * 1024 * 1024

    /// Total NSCache count limit. Sanity bound in case some asset
    /// has an absurd pixel-size cost entry (we have not seen one,
    /// but defensive).
    static let totalCacheCountLimit: Int = 256

    private static let imageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = totalCacheCostLimit
        cache.countLimit = totalCacheCountLimit
        return cache
    }()

    /// Resolve `src` to a loadable image. Pass `generation` when
    /// the caller already knows which snapshot generation it is
    /// rendering (the widget's `TimelineProvider` does). When
    /// `generation` is nil, the loader falls back to
    /// `AppGroupState.currentGeneration` and ultimately to the
    /// legacy namespace.
    static func load(from src: String, generation: String? = nil) -> UIImage? {
        if src.hasPrefix("data:image") {
            guard let c = src.firstIndex(of: ","),
                  let d = Data(base64Encoded: String(src[src.index(after: c)...])) else {
                return nil
            }
            return decode(downsampledFrom: d, maxPixelSize: maxLongEdgePixels)
        }

        let namespace = cacheNamespace(for: generation)
        let cacheKey = "\(namespace)|\(src)" as NSString
        if let cached = imageCache.object(forKey: cacheKey) {
            return cached
        }

        // 1. Asset Catalog / Bundle.main — generation-independent.
        //    Asset catalog entries are already in the form we need,
        //    so we don't run them through the ImageIO downsampler.
        if let assetImg = UIImage(named: src) {
            let bundleKey = "bundle|\(src)" as NSString
            imageCache.setObject(assetImg, forKey: bundleKey, cost: pixelCost(of: assetImg))
            imageCache.setObject(assetImg, forKey: cacheKey, cost: pixelCost(of: assetImg))
            return assetImg
        }

        // 2. App Group paths — the production cross-process location.
        if let shared = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroupContract.suiteName
        ) {
            let gen = generation ?? AppGroupState.currentGeneration
            if let g = gen {
                let genURL = shared
                    .appendingPathComponent("SharedImages")
                    .appendingPathComponent("generation_\(g)")
                    .appendingPathComponent(src)
                if let img = decode(downsampledFileAt: genURL, maxPixelSize: maxLongEdgePixels) {
                    cacheImage(img, key: cacheKey)
                    return img
                }
            }
            let sharedImagesURL = shared
                .appendingPathComponent("SharedImages")
                .appendingPathComponent(src)
            if let img = decode(downsampledFileAt: sharedImagesURL, maxPixelSize: maxLongEdgePixels) {
                cacheImage(img, key: cacheKey)
                return img
            }
            let appGroupRootURL = shared.appendingPathComponent(src)
            if let img = decode(downsampledFileAt: appGroupRootURL, maxPixelSize: maxLongEdgePixels) {
                cacheImage(img, key: cacheKey)
                return img
            }
        }

        // 3. Host sandbox Documents — only reachable from `Runner`.
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let docsURL = docs.appendingPathComponent(src)
            if let img = decode(downsampledFileAt: docsURL, maxPixelSize: maxLongEdgePixels) {
                cacheImage(img, key: cacheKey)
                return img
            }
        }

        // 4. Absolute path — last resort.
        if let img = decode(downsampledFileAt: URL(fileURLWithPath: src), maxPixelSize: maxLongEdgePixels) {
            cacheImage(img, key: cacheKey)
            return img
        }

        return nil
    }

    /// Insert `img` into the per-generation cache (and the shared
    /// bundle cache when the asset is bundled). Cost is the
    /// decoded bitmap's pixel memory so NSCache can enforce the
    /// 96 MB ceiling correctly across heterogeneous asset sizes.
    private static func cacheImage(_ img: UIImage, key: NSString) {
        let cost = pixelCost(of: img)
        imageCache.setObject(img, forKey: key, cost: cost)
        let bundleKey = "bundle|\(key as String)" as NSString
        imageCache.setObject(img, forKey: bundleKey, cost: cost)
    }

    /// Decoded pixel memory in bytes. UIImage reports its backing
    /// pixel size via `cgImage`; if the decode already produced a
    /// bitmap context (the ImageIO thumbnail path), this is the
    /// size of that context.
    private static func pixelCost(of img: UIImage) -> Int {
        let w = img.cgImage?.width ?? Int(img.size.width * img.scale)
        let h = img.cgImage?.height ?? Int(img.size.height * img.scale)
        guard w > 0, h > 0 else { return bytesPerPixel }
        return w * h * bytesPerPixel
    }

    // MARK: - ImageIO decode helpers

    /// Decode a file URL with `CGImageSourceCreateThumbnailAtIndex`.
    /// Returns `nil` on any failure so callers can fall through to
    /// the next candidate location. `maxPixelSize` is the long-edge
    /// cap applied during decode.
    static func decode(downsampledFileAt url: URL, maxPixelSize: Int) -> UIImage? {
        let opts: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, opts as CFDictionary) else {
            return nil
        }
        return decode(source: source, maxPixelSize: maxPixelSize)
    }

    /// Decode in-memory bytes with the same thumbnail path. Used
    /// for the base64 inline-source branch.
    static func decode(downsampledFrom data: Data, maxPixelSize: Int) -> UIImage? {
        let opts: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, opts as CFDictionary) else {
            return nil
        }
        return decode(source: source, maxPixelSize: maxPixelSize)
    }

    private static func decode(source: CGImageSource, maxPixelSize: Int) -> UIImage? {
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, opts as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cg, scale: 1.0, orientation: .up)
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
    /// is written to disk (e.g. after `installState` publishes a new
    /// generation). Clears all cached entries so the very next
    /// `load(from:)` call re-reads from disk and picks up the new
    /// bytes.
    static func invalidateCache() {
        imageCache.removeAllObjects()
    }
}
