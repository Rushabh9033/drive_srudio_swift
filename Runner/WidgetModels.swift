import Foundation
import CoreGraphics

struct VehicleData: Codable, Equatable {
    var brandId: String?
    var modelId: String?
    var artwork: String?
    var displayName: String?
    var hasCustomImage: Bool?
    var customImage: String?
}

struct TelemetrySnapshot: Codable, Equatable {
    var carConnected: Bool
    var batteryPercent: Int?
    var isCharging: Bool
    var speed: Double?
    var timestamp: Date?
    
    var isStale: Bool {
        guard let ts = timestamp else { return true }
        return Date().timeIntervalSince(ts) > 300 // 5 minutes
    }
}

struct WidgetLayer: Codable, Identifiable, Equatable {
    var id: String
    var kind: String
    var label: String?
    var text: String?
    var src: String?
    var x: Double?
    var y: Double?
    var w: Double?
    var h: Double?
    var fontSize: Double?
    var weight: Int?
    var align: String?
    var color: String?
    var opacity: Double?
    var radius: Double?
    var hidden: Bool?
    var strokes: String?
    var format: String?
    /// Optional group identifier — when set, this layer moves/resizes together
    /// with every other layer that shares the same `groupId`. Library items
    /// that contain multiple layers assign a shared `groupId` so the whole
    /// composite asset behaves as a single unit on the canvas.
    var groupId: String?

    // Default initializers for editor creation
    static func newText() -> WidgetLayer {
        WidgetLayer(
            id: UUID().uuidString,
            kind: "text",
            text: "New Text",
            x: 25.0,
            y: 15.0,
            w: 50.0,
            h: 15.0,
            fontSize: 22.0,
            weight: 600,
            align: "center",
            color: "FFFFFF"
        )
    }

    static func newCar(src: String, aspectRatio: CGFloat? = nil) -> WidgetLayer {
        // Default small initial footprint so the user sees their
        // freshly-uploaded image at a manageable size and can drag
        // the corners to make it bigger. The *longer* dimension is
        // anchored at 30% of the design canvas and the shorter is
        // derived from `aspectRatio` (width / height) so the frame
        // matches the image's natural shape exactly — the dashed
        // border lines up with the photo's edges instead of
        // floating around it with empty space.
        let initialLongSide: CGFloat = 30
        let width: CGFloat
        let height: CGFloat
        if let ar = aspectRatio, ar > 0 {
            if ar >= 1 {
                width = initialLongSide
                height = initialLongSide / ar
            } else {
                height = initialLongSide
                width = initialLongSide * ar
            }
        } else {
            width = initialLongSide
            height = initialLongSide
        }
        return WidgetLayer(
            id: UUID().uuidString,
            kind: "image",
            src: src,
            x: 35,
            y: 35,
            w: width,
            h: height
        )
    }

    // MARK: - Image-add merge
    //
    // Pure, testable decision: when the user picks a new image to add
    // to a draft, where does it land? Rules (in order):
    //
    //   1. If the currently-selected layer is a symbolic vehicle
    //      guide (`template_car`), replace it in place — keep its
    //      `id`, `x`, `y`, `w`, `h`, `opacity`, `hidden`, `groupId`.
    //      The selection stays on the (now-real) layer.
    //   2. Else if exactly one visible symbolic vehicle guide
    //      exists in the layer list, replace that one in place. The
    //      selection moves to its index. (Multiple visible guides:
    //      ambiguous — append a new layer; the user can move or
    //      delete one of the guides manually.)
    //   3. Else append a new layer with default placement.
    //
    // Returns the new layer array and the index the editor should
    // select after the merge. Callers update `selectedLayerIndex`
    // themselves so the helper stays pure.
    static func mergedLayersAfterAddingImage(
        current: [WidgetLayer],
        selectedIndex: Int?,
        newImageSrc: String,
        newImageAspect: CGFloat? = nil
    ) -> (layers: [WidgetLayer], selectedIndex: Int?) {
        // Rule 1: selected symbolic guide → replace in place.
        if let sel = selectedIndex,
           sel >= 0, sel < current.count,
           current[sel].kind == "image",
           let src = current[sel].src,
           ImageSource.symbolicVehicleGuideNames.contains(src) {
            var updated = current
            updated[sel] = current[sel].withReplacedImageSrc(newImageSrc, aspectRatio: newImageAspect)
            return (updated, sel)
        }
        // Rule 2: exactly one visible symbolic guide → replace that.
        let visibleGuideIndices = current.enumerated().compactMap { idx, layer -> Int? in
            guard layer.kind == "image",
                  let src = layer.src,
                  ImageSource.symbolicVehicleGuideNames.contains(src),
                  layer.hidden != true else { return nil }
            return idx
        }
        if visibleGuideIndices.count == 1 {
            let target = visibleGuideIndices[0]
            var updated = current
            updated[target] = current[target].withReplacedImageSrc(newImageSrc, aspectRatio: newImageAspect)
            return (updated, target)
        }
        // Rule 3: append a new layer.
        var updated = current
        let newLayer = WidgetLayer.newCar(src: newImageSrc, aspectRatio: newImageAspect)
        updated.append(newLayer)
        return (updated, updated.count - 1)
    }

    /// Return a copy with `src` replaced. Preserves `id`, `x`, `y`,
    /// `opacity`, `hidden`, and `groupId` so the new image stays
    /// anchored where the guide was. `w` / `h` are recomputed from
    /// `aspectRatio` (width / height) when available — using a
    /// **small** default footprint (the guide's old `w` is ignored;
    /// it could be 76% of the canvas which would swamp the user)
    /// and deriving the other dimension from the image's aspect
    /// keeps the dashed border exactly hugging the photo's edges.
    private func withReplacedImageSrc(
        _ newSrc: String,
        aspectRatio: CGFloat?
    ) -> WidgetLayer {
        var copy = self
        copy.src = newSrc
        if let ar = aspectRatio, ar > 0 {
            // Anchor the *longer* dimension at a small initial size
            // (30% of the design canvas) and derive the shorter
            // dimension from the image's aspect ratio. This means
            // the frame matches the image's natural shape AND starts
            // small enough for the user to drag-resize.
            let initialLongSide: CGFloat = 30
            if ar >= 1 {
                // Landscape (or square) — width is the long side.
                copy.w = initialLongSide
                copy.h = initialLongSide / ar
            } else {
                // Portrait — height is the long side.
                copy.h = initialLongSide
                copy.w = initialLongSide * ar
            }
        }
        return copy
    }
}

struct WidgetBackground: Codable, Equatable {
    var type: String? // "solid", "gradient", "image"
    var from: String? // hex color
    var to: String?
    var imageSrc: String?
    
    static var defaultBg: WidgetBackground {
        WidgetBackground(type: "solid", from: "18181A", to: nil, imageSrc: nil)
    }
}

struct WidgetSpec: Codable, Equatable {
    var background: WidgetBackground?
    var layers: [WidgetLayer]?

    static var empty: WidgetSpec {
        WidgetSpec(background: WidgetBackground.defaultBg, layers: [])
    }
}

struct Slot: Codable, Equatable {
    let index: Int
    let draftId: String?
    let spec: WidgetSpec?
}

struct WidgetState: Codable, Equatable {
    var schemaVersion: Int?
    var vehicle: VehicleData?
    var slots: [Slot]?
    var telemetry: TelemetrySnapshot?
    var widgetImagePath: String?
}

// Full Draft representation
struct Draft: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var spec: WidgetSpec
    var updatedAt: Double
}
