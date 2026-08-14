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
    
    static func newCar(src: String) -> WidgetLayer {
        WidgetLayer(id: UUID().uuidString, kind: "image", src: src, x: 0, y: 0, w: 150, h: 100)
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
