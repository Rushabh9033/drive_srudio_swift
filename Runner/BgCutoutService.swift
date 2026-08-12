import UIKit
import Vision

@available(iOS 17.0, *)
class BgCutoutService {
    
    static func removeBackground(from image: UIImage) async throws -> UIImage {
        guard let cgImage = image.cgImage else {
            throw NSError(domain: "BgCutout", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid CGImage"])
        }
        
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        try handler.perform([request])
        
        guard let result = request.results?.first else {
            throw NSError(domain: "BgCutout", code: 1, userInfo: [NSLocalizedDescriptionKey: "No foreground instance found"])
        }
        
        let mask = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
        
        guard let maskedImage = applyMask(mask: mask, to: cgImage) else {
            throw NSError(domain: "BgCutout", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to apply mask"])
        }
        
        return UIImage(cgImage: maskedImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    private static func applyMask(mask: CVPixelBuffer, to image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height
        
        guard let colorSpace = image.colorSpace,
              let context = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }
        
        // We use CIContext to render the pixel buffer mask to a CGImage
        let ciContext = CIContext()
        let ciMask = CIImage(cvPixelBuffer: mask)
        guard let cgMask = ciContext.createCGImage(ciMask, from: CGRect(x: 0, y: 0, width: width, height: height)) else { return nil }
        
        // Setup drawing
        context.clip(to: CGRect(x: 0, y: 0, width: width, height: height), mask: cgMask)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return context.makeImage()
    }
}
