import Foundation
import ImageIO
import CoreGraphics
import MobileCoreServices
import UniformTypeIdentifiers

/// Build a widget-safe image derivative directly from a source URL or
/// in-memory bytes using ImageIO. The pipeline never materialises a
/// full-resolution `UIImage`: CGImageSource + kCGImageSourceCreate*
/// options downsample to the configured long-edge cap during decode,
/// apply EXIF orientation, and hand back a downsampled `CGImage` that
/// is small enough to encode without buffering the original.
///
/// Compiled into both the `Runner` and `DriveStudioWidgetExtension`
/// targets via the file-system-synchronized `DriveStudioWidget/`
/// folder. The host uses it when the user picks a photo from the
/// PhotosPicker; the widget never needs to invoke it (the widget
/// reads pre-built derivatives the stager writes).
///
/// The output is small enough for the widget sandbox but still
/// preserves the original aspect ratio and (when present) alpha
/// channel. Animated formats collapse to their first frame because
/// WidgetKit does not animate image layers.
enum ImageDerivativeService {

    /// Maximum long-edge in pixels for the derivative. The widget
    /// canvas is ~340 logical points and a 3× scale = 1020 backing
    /// pixels, so 1024 leaves headroom for the largest supported
    /// size class without bloating the App Group container with
    /// assets the widget will never fully read.
    static let maxLongEdgePixels: Int = 1024

    /// JPEG quality used for opaque photographs. Alpha-friendly
    /// results are encoded as lossless PNG instead, regardless of
    /// quality setting.
    static let opaqueJPEGQuality: Double = 0.85

    /// The successful derivative and the metadata the editor needs
    /// to size the layer's frame to match the photo.
    struct Derivative: Equatable {
        /// On-disk bytes ready to write to the App Group container.
        let data: Data
        /// File extension: "png" for alpha-bearing derivatives,
        /// "jpg" for opaque. Matches what the loader decodes.
        let ext: String
        /// Backing pixel width after EXIF orientation + downsample.
        let pixelWidth: Int
        /// Backing pixel height after EXIF orientation + downsample.
        let pixelHeight: Int
        /// `width / height`. Used to size the layer's frame so the
        /// dashed yellow border hugs the photo's edges.
        let aspectRatio: CGFloat
        /// `true` iff the encoded derivative carries alpha.
        let hasAlpha: Bool
    }

    /// Errors raised when the source cannot be decoded into a
    /// derivative. The editor surfaces the message verbatim so the
    /// user gets a useful retryable error instead of a silent no-op.
    enum DerivativeError: Error, LocalizedError, Equatable {
        case unreadableSource(String)
        case noImageData(String)
        case unsupportedFormat(String)
        case encodeFailed(String)

        var errorDescription: String? {
            switch self {
            case .unreadableSource(let msg):
                return "Couldn't read the source image (\(msg))."
            case .noImageData(let msg):
                return "The picked image has no decodable data (\(msg))."
            case .unsupportedFormat(let msg):
                return "This image format isn't supported (\(msg))."
            case .encodeFailed(let msg):
                return "Failed to encode the optimized image (\(msg))."
            }
        }
    }

    /// Build a derivative from a file URL. The URL is read via
    /// `CGImageSourceCreateWithURL`, so the kernel pages the file
    /// directly without buffering the entire image in our address
    /// space.
    static func makeDerivative(from url: URL) throws -> Derivative {
        let opts: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, opts as CFDictionary) else {
            throw DerivativeError.unreadableSource(url.lastPathComponent)
        }
        return try makeDerivative(from: source, fallbackLabel: url.lastPathComponent)
    }

    /// Build a derivative from in-memory bytes (e.g. PhotosPicker
    /// `loadTransferable`). CGImageSource reads from a
    /// `CGDataProvider`, so the original data is never copied into
    /// a full-resolution UIImage.
    static func makeDerivative(from data: Data, suggestedFilename: String) throws -> Derivative {
        let opts: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, opts as CFDictionary) else {
            throw DerivativeError.noImageData(suggestedFilename)
        }
        return try makeDerivative(from: source, fallbackLabel: suggestedFilename)
    }

    // MARK: - Core decode pipeline

    /// Downsample + EXIF-correct + alpha-detect + encode in one pass.
    /// The returned `CGImage` is bounded by `maxLongEdgePixels` on
    /// its long edge and is oriented to display-up.
    private static func makeDerivative(
        from source: CGImageSource,
        fallbackLabel: String
    ) throws -> Derivative {
        let thumbOpts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxLongEdgePixels
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(
            source, 0, thumbOpts as CFDictionary
        ) else {
            throw DerivativeError.unsupportedFormat(fallbackLabel)
        }

        let width = cg.width
        let height = cg.height
        guard width > 0 && height > 0 else {
            throw DerivativeError.unsupportedFormat(fallbackLabel)
        }

        let alphaInfo = cg.alphaInfo
        let hasAlpha = Self.derivativeHasAlpha(alphaInfo)

        let (data, ext) = try Self.encode(cg: cg, hasAlpha: hasAlpha)

        let aspect: CGFloat = CGFloat(width) / CGFloat(height)
        return Derivative(
            data: data,
            ext: ext,
            pixelWidth: width,
            pixelHeight: height,
            aspectRatio: aspect,
            hasAlpha: hasAlpha
        )
    }

    /// Decide whether the encoded derivative should carry alpha.
    /// Premultiplied-first/last variants indicate the source had an
    /// alpha channel; non-premultiplied are equivalent for our
    /// purposes. RGB-only formats (no alpha) collapse to JPEG.
    private static func derivativeHasAlpha(_ info: CGImageAlphaInfo) -> Bool {
        switch info {
        case .premultipliedFirst, .premultipliedLast,
             .first, .last, .alphaOnly:
            return true
        case .none, .noneSkipFirst, .noneSkipLast:
            return false
        @unknown default:
            return false
        }
    }

    /// Encode the downsampled CGImage as PNG (alpha) or JPEG
    /// (opaque). Uses CGImageDestination so the encode path stays
    /// inside ImageIO and never falls back to a UIImage re-encode.
    private static func encode(cg: CGImage, hasAlpha: Bool) throws -> (Data, String) {
        if hasAlpha {
            return try encodePNG(cg: cg)
        } else {
            return try encodeJPEG(cg: cg, quality: opaqueJPEGQuality)
        }
    }

    private static func encodePNG(cg: CGImage) throws -> (Data, String) {
        let outData = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            outData as CFMutableData,
            UTType.png.identifier as CFString,
            1, nil
        ) else {
            throw DerivativeError.encodeFailed("PNG destination init")
        }
        let props: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 1.0
        ]
        CGImageDestinationAddImage(dest, cg, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            throw DerivativeError.encodeFailed("PNG finalize")
        }
        return (outData as Data, "png")
    }

    private static func encodeJPEG(cg: CGImage, quality: Double) throws -> (Data, String) {
        let outData = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            outData as CFMutableData,
            UTType.jpeg.identifier as CFString,
            1, nil
        ) else {
            throw DerivativeError.encodeFailed("JPEG destination init")
        }
        let props: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(dest, cg, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            throw DerivativeError.encodeFailed("JPEG finalize")
        }
        return (outData as Data, "jpg")
    }

    // MARK: - Filename helpers

    /// Compose a derivative filename. We never use the source's
    /// extension because the derivative's extension is determined
    /// by alpha (`png` vs `jpg`), not by the source's container
    /// format. The leading `vehicle_` keeps the asset searchable in
    /// the App Group folder by purpose.
    static func derivativeFilename(hasAlpha: Bool) -> String {
        let ext = hasAlpha ? "png" : "jpg"
        return "vehicle_\(UUID().uuidString).\(ext)"
    }

    /// Compose a filename for the original, preserving its original
    /// extension so the user can keep editing in the future without
    /// us having to re-derive the format from a binary blob. The
    /// original NEVER lives in the App Group container — it is a
    /// host-private asset used only for re-edits inside the host
    /// app.
    static func originalFilename(suggested: String, typeIdentifier: String?) -> String {
        let ext = Self.inferOriginalExtension(suggested: suggested, typeIdentifier: typeIdentifier)
        return "original_\(UUID().uuidString).\(ext)"
    }

    private static func inferOriginalExtension(
        suggested: String,
        typeIdentifier: String?
    ) -> String {
        // Prefer the source's actual file extension when available.
        let srcExt = (suggested as NSString).pathExtension.lowercased()
        if !srcExt.isEmpty, srcExt.allSatisfy({ $0.isLetter || $0.isNumber }) {
            return srcExt
        }
        if let ti = typeIdentifier, let ut = UTType(ti), let preferred = ut.preferredFilenameExtension {
            return preferred.lowercased()
        }
        if let ti = typeIdentifier, let ut = UTType(ti) {
            if ut.conforms(to: .heic) || ut.conforms(to: .heif) { return "heic" }
            if ut.conforms(to: .png) { return "png" }
            if ut.conforms(to: .jpeg) { return "jpg" }
            if ut.conforms(to: .tiff) { return "tiff" }
            if ut.conforms(to: .gif)  { return "gif"  }
            if ut.conforms(to: .webP) { return "webp" }
        }
        // Last resort — preserve bytes verbatim under a generic name.
        return "bin"
    }
}

// MARK: - Memory-safe working image for background removal
//
// `removeBackground` historically allocated `width * height * 4` for
// the full-resolution image. That allocation can exceed available
// memory on a 48 MP photo. Downsample first to a memory-safe working
// CGImage, then perform background removal on the working buffer.
extension ImageDerivativeService {

    /// A downsampled working CGImage + the context the caller
    /// needs to read raw RGBA bytes. The buffer is exactly
    /// `workingWidth * workingHeight * 4` bytes — bounded by
    /// `maxLongEdgePixels`, never by the source resolution.
    struct WorkingImage {
        let cgImage: CGImage
        let pixelWidth: Int
        let pixelHeight: Int
        let bytesPerRow: Int
        /// 32-bit RGBA premultiplied-last buffer the caller can
        /// safely read from / write to.
        let rgbaBuffer: UnsafeMutableBufferPointer<UInt8>
    }

    /// Decode the source into a memory-safe working image for
    /// background removal. The returned buffer is allocated exactly
    /// `workingWidth * workingHeight * 4` bytes; the caller is
    /// responsible for releasing it after the cutout work completes.
    static func makeWorkingImage(from url: URL) throws -> WorkingImage {
        let derivative = try makeDerivative(from: url)
        return try makeWorkingImage(from: derivative)
    }

    static func makeWorkingImage(from data: Data, suggestedFilename: String) throws -> WorkingImage {
        let derivative = try makeDerivative(from: data, suggestedFilename: suggestedFilename)
        return try makeWorkingImage(from: derivative)
    }

    private static func makeWorkingImage(from derivative: Derivative) throws -> WorkingImage {
        // Round-trip the derivative bytes through CGImageSource so
        // we get a CGImage without knowing whether the encoder
        // produced JPEG or PNG. CGImageSource dispatches to the
        // right decoder based on the bytes' magic numbers.
        let opts: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let src = CGImageSourceCreateWithData(
            derivative.data as CFData, opts as CFDictionary),
              let cg = CGImageSourceCreateImageAtIndex(
                src, 0, opts as CFDictionary
              )
        else {
            throw DerivativeError.noImageData("decode-back for cutout")
        }
        return try allocateWorkingBuffer(for: cg)
    }

    private static func allocateWorkingBuffer(for cg: CGImage) throws -> WorkingImage {
        let width = cg.width
        let height = cg.height
        guard width > 0 && height > 0 else {
            throw DerivativeError.unsupportedFormat("zero-dim working image")
        }
        let bytesPerRow = width * 4
        let totalBytes = bytesPerRow * height
        let buffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: totalBytes)
        buffer.initialize(repeating: 0)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue
        guard let ctx = CGContext(
            data: buffer.baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            buffer.deallocate()
            throw DerivativeError.encodeFailed("working context init")
        }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        return WorkingImage(
            cgImage: cg,
            pixelWidth: width,
            pixelHeight: height,
            bytesPerRow: bytesPerRow,
            rgbaBuffer: buffer
        )
    }
}
