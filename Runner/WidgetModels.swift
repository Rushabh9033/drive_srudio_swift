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
    
    // MARK: - Template Generators
        static func template(named name: String, accentHex: String = "FFB84D") -> WidgetSpec {
        var spec = WidgetSpec.empty
        
        // Define base variables
        let uid = { UUID().uuidString }
        
        switch name {
        // MARK: - Night Drive (General)
        case "Neon Grid":
            spec.background = WidgetBackground(type: "solid", from: "07070F", to: nil, imageSrc: nil)
            spec.layers = [
                // Top header
                WidgetLayer(id: uid(), kind: "text", text: "CYBER", x: 20, y: 20, w: 100, h: 20, fontSize: 14, weight: 800, align: "left", color: accentHex, opacity: 0.8),
                WidgetLayer(id: uid(), kind: "clock", x: 250, y: 15, w: 80, h: 30, fontSize: 20, weight: 600, align: "right", color: "FFFFFF"),
                
                // Central car with glowing platform
                WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 50, y: 200, w: 240, h: 10, color: accentHex, opacity: 0.4, radius: 5),
                WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 100, y: 198, w: 140, h: 4, color: accentHex, opacity: 1.0, radius: 2),
                WidgetLayer(id: uid(), kind: "image", src: "template_car", x: 40, y: 100, w: 260, h: 110),
                
                // Bottom metrics
                WidgetLayer(id: uid(), kind: "text", text: "SPEED", x: 30, y: 250, w: 60, h: 15, fontSize: 10, weight: 500, align: "left", color: "A0A0A0"),
                WidgetLayer(id: uid(), kind: "text", text: "124", x: 30, y: 270, w: 80, h: 40, fontSize: 36, weight: 800, align: "left", color: "FFFFFF"),
                WidgetLayer(id: uid(), kind: "text", text: "km/h", x: 30, y: 315, w: 40, h: 15, fontSize: 12, weight: 600, align: "left", color: accentHex),
                
                WidgetLayer(id: uid(), kind: "text", text: "BATTERY", x: 230, y: 250, w: 80, h: 15, fontSize: 10, weight: 500, align: "right", color: "A0A0A0"),
                WidgetLayer(id: uid(), kind: "text", text: "84%", x: 230, y: 270, w: 80, h: 40, fontSize: 36, weight: 800, align: "right", color: "FFFFFF"),
            ]
            
        case "Apex":
            spec.background = WidgetBackground(type: "gradient", from: "1E1E1E", to: "0A0A0A", imageSrc: nil)
            spec.layers = [
                WidgetLayer(id: uid(), kind: "date", x: 20, y: 20, w: 200, h: 20, fontSize: 12, weight: 600, align: "left", color: accentHex),
                WidgetLayer(id: uid(), kind: "clock", x: 20, y: 40, w: 200, h: 40, fontSize: 42, weight: 800, align: "left", color: "FFFFFF"),
                
                WidgetLayer(id: uid(), kind: "image", src: "template_car", x: 60, y: 110, w: 220, h: 100),
                
                // Analog gauge representation
                WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 20, y: 260, w: 300, h: 60, color: "000000", opacity: 0.5, radius: 16),
                WidgetLayer(id: uid(), kind: "battery", x: 40, y: 275, w: 100, h: 30, fontSize: 24, weight: 700, align: "left", color: "FFFFFF"),
                WidgetLayer(id: uid(), kind: "text", text: "Range: 320mi", x: 160, y: 280, w: 140, h: 20, fontSize: 16, weight: 500, align: "right", color: accentHex),
            ]
            
        case "Minimal":
            spec.background = WidgetBackground(type: "solid", from: "000000", to: nil, imageSrc: nil)
            spec.layers = [
                WidgetLayer(id: uid(), kind: "clock", x: 20, y: 150, w: 300, h: 80, fontSize: 80, weight: 300, align: "center", color: "FFFFFF"),
                WidgetLayer(id: uid(), kind: "date", x: 20, y: 240, w: 300, h: 20, fontSize: 16, weight: 500, align: "center", color: accentHex),
            ]
            
        // MARK: - Battery Focused
        case "Charge Arc":
            spec.background = WidgetBackground(type: "gradient", from: "0F172A", to: "020617", imageSrc: nil)
            spec.layers = [
                WidgetLayer(id: uid(), kind: "shape", label: "circle", x: 69, y: 77, w: 200, h: 200, color: "334155", opacity: 0.5, radius: 100),
                WidgetLayer(id: uid(), kind: "shape", label: "circle", x: 79, y: 87, w: 180, h: 180, color: accentHex, opacity: 1.0, radius: 90),
                WidgetLayer(id: uid(), kind: "shape", label: "circle", x: 89, y: 97, w: 160, h: 160, color: "0F172A", opacity: 1.0, radius: 80),
                
                WidgetLayer(id: uid(), kind: "battery", x: 119, y: 162, w: 100, h: 30, fontSize: 28, weight: 800, align: "center", color: "FFFFFF"),
                WidgetLayer(id: uid(), kind: "text", text: "CHARGING", x: 119, y: 140, w: 100, h: 15, fontSize: 12, weight: 700, align: "center", color: accentHex),
            ]
            
        case "Power Ring":
            spec.background = WidgetBackground(type: "solid", from: "111111", to: nil, imageSrc: nil)
            spec.layers = [
                WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 20, y: 20, w: 140, h: 140, color: "222222", opacity: 1.0, radius: 24),
                WidgetLayer(id: uid(), kind: "battery", x: 40, y: 75, w: 100, h: 30, fontSize: 24, weight: 800, align: "center", color: accentHex),
                
                WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 178, y: 20, w: 140, h: 140, color: "222222", opacity: 1.0, radius: 24),
                WidgetLayer(id: uid(), kind: "text", text: "RANGE", x: 198, y: 60, w: 100, h: 15, fontSize: 12, weight: 600, align: "center", color: "888888"),
                WidgetLayer(id: uid(), kind: "text", text: "284", x: 198, y: 80, w: 100, h: 40, fontSize: 32, weight: 800, align: "center", color: "FFFFFF"),
                
                WidgetLayer(id: uid(), kind: "image", src: "template_car", x: 40, y: 200, w: 260, h: 110),
            ]
            
        // MARK: - Speedometer Focused
        case "Apex Gauge":
            spec.background = WidgetBackground(type: "gradient", from: "1A0B0B", to: "000000", imageSrc: nil)
            spec.layers = [
                WidgetLayer(id: uid(), kind: "analog", x: 69, y: 77, w: 200, h: 200, color: accentHex, opacity: 1.0),
                WidgetLayer(id: uid(), kind: "text", text: "124", x: 119, y: 150, w: 100, h: 40, fontSize: 38, weight: 900, align: "center", color: "FFFFFF"),
                WidgetLayer(id: uid(), kind: "text", text: "MPH", x: 119, y: 190, w: 100, h: 20, fontSize: 14, weight: 700, align: "center", color: accentHex),
                
                WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 69, y: 290, w: 200, h: 30, color: "222222", opacity: 0.8, radius: 15),
                WidgetLayer(id: uid(), kind: "clock", x: 69, y: 295, w: 200, h: 20, fontSize: 14, weight: 600, align: "center", color: "FFFFFF"),
            ]
            
        case "Velocity":
            spec.background = WidgetBackground(type: "solid", from: "000000", to: nil, imageSrc: nil)
            spec.layers = [
                WidgetLayer(id: uid(), kind: "text", text: "VELOCITY", x: 20, y: 20, w: 100, h: 20, fontSize: 12, weight: 700, align: "left", color: "888888"),
                WidgetLayer(id: uid(), kind: "text", text: "124", x: 20, y: 40, w: 200, h: 100, fontSize: 96, weight: 900, align: "left", color: "FFFFFF"),
                WidgetLayer(id: uid(), kind: "text", text: "KM/H", x: 20, y: 140, w: 100, h: 30, fontSize: 24, weight: 800, align: "left", color: accentHex),
                
                WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 20, y: 180, w: 300, h: 4, color: "333333", opacity: 1.0, radius: 2),
                WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 20, y: 180, w: 200, h: 4, color: accentHex, opacity: 1.0, radius: 2),
                
                WidgetLayer(id: uid(), kind: "battery", x: 20, y: 220, w: 120, h: 30, fontSize: 20, weight: 600, align: "left", color: "FFFFFF"),
                WidgetLayer(id: uid(), kind: "clock", x: 198, y: 220, w: 120, h: 30, fontSize: 20, weight: 600, align: "right", color: "FFFFFF"),
            ]
        case "Carbon":
            spec.background = WidgetBackground(type: "solid", from: "121212", to: nil, imageSrc: nil)
            spec.layers = [
                WidgetLayer(id: uid(), kind: "text", text: "CARBON", x: 20, y: 20, w: 100, h: 20, fontSize: 12, weight: 800, align: "left", color: "888888"),
                WidgetLayer(id: uid(), kind: "image", src: "template_car", x: 40, y: 60, w: 260, h: 120),
                WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 20, y: 220, w: 300, h: 60, color: "1A1A1A", opacity: 1.0, radius: 12),
                WidgetLayer(id: uid(), kind: "text", text: "RANGE", x: 40, y: 230, w: 80, h: 20, fontSize: 12, weight: 600, align: "left", color: "888888"),
                WidgetLayer(id: uid(), kind: "text", text: "284", x: 40, y: 250, w: 80, h: 30, fontSize: 24, weight: 800, align: "left", color: accentHex),
                WidgetLayer(id: uid(), kind: "battery", x: 160, y: 240, w: 140, h: 40, fontSize: 32, weight: 800, align: "right", color: "FFFFFF"),
            ]
            
        case "Bolt Pill":
            spec.background = WidgetBackground(type: "solid", from: "000000", to: nil, imageSrc: nil)
            spec.layers = [
                WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 80, y: 40, w: 180, h: 260, color: "111111", opacity: 1.0, radius: 90),
                WidgetLayer(id: uid(), kind: "shape", label: "circle", x: 120, y: 60, w: 100, h: 100, color: accentHex, opacity: 0.2, radius: 50),
                WidgetLayer(id: uid(), kind: "battery", x: 120, y: 90, w: 100, h: 40, fontSize: 32, weight: 900, align: "center", color: accentHex),
                WidgetLayer(id: uid(), kind: "text", text: "CHARGING", x: 120, y: 140, w: 100, h: 20, fontSize: 12, weight: 700, align: "center", color: "888888"),
                WidgetLayer(id: uid(), kind: "clock", x: 120, y: 220, w: 100, h: 30, fontSize: 20, weight: 700, align: "center", color: "FFFFFF"),
            ]
            
        case "Cell Bar":
            spec.background = WidgetBackground(type: "gradient", from: "141414", to: "050505", imageSrc: nil)
            spec.layers = [
                WidgetLayer(id: uid(), kind: "text", text: "ENERGY", x: 20, y: 20, w: 100, h: 20, fontSize: 14, weight: 700, align: "left", color: "FFFFFF"),
                WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 20, y: 60, w: 300, h: 20, color: "333333", opacity: 1.0, radius: 10),
                WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 20, y: 60, w: 240, h: 20, color: accentHex, opacity: 1.0, radius: 10),
                WidgetLayer(id: uid(), kind: "battery", x: 20, y: 100, w: 140, h: 50, fontSize: 48, weight: 900, align: "left", color: "FFFFFF"),
                WidgetLayer(id: uid(), kind: "image", src: "template_car", x: 160, y: 180, w: 160, h: 80),
                WidgetLayer(id: uid(), kind: "date", x: 20, y: 280, w: 200, h: 30, fontSize: 16, weight: 500, align: "left", color: "AAAAAA"),
            ]
            
        case "Dial":
            spec.background = WidgetBackground(type: "solid", from: "18181A", to: nil, imageSrc: nil)
            spec.layers = [
                WidgetLayer(id: uid(), kind: "shape", label: "circle", x: 70, y: 70, w: 200, h: 200, color: "000000", opacity: 1.0, radius: 100),
                WidgetLayer(id: uid(), kind: "text", text: "124", x: 70, y: 130, w: 200, h: 60, fontSize: 56, weight: 900, align: "center", color: "FFFFFF"),
                WidgetLayer(id: uid(), kind: "text", text: "MPH", x: 70, y: 190, w: 200, h: 20, fontSize: 14, weight: 800, align: "center", color: accentHex),
                WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 100, y: 300, w: 140, h: 10, color: "333333", opacity: 1.0, radius: 5),
            ]
            
        case "Track":
            spec.background = WidgetBackground(type: "solid", from: "000000", to: nil, imageSrc: nil)
            spec.layers = [
                WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 20, y: 20, w: 300, h: 300, color: "111111", opacity: 1.0, radius: 30),
                WidgetLayer(id: uid(), kind: "image", src: "template_car", x: 40, y: 60, w: 260, h: 100),
                WidgetLayer(id: uid(), kind: "text", text: "124", x: 40, y: 200, w: 120, h: 60, fontSize: 52, weight: 900, align: "left", color: "FFFFFF"),
                WidgetLayer(id: uid(), kind: "text", text: "km/h", x: 160, y: 220, w: 60, h: 30, fontSize: 16, weight: 700, align: "left", color: accentHex),
                WidgetLayer(id: uid(), kind: "clock", x: 40, y: 260, w: 120, h: 20, fontSize: 14, weight: 500, align: "left", color: "888888"),
            ]
            
        default:
            spec.background = WidgetBackground(type: "solid", from: "18181A", to: nil, imageSrc: nil)
            spec.layers = [
                WidgetLayer(id: uid(), kind: "clock", x: 20, y: 20, w: 300, h: 40, fontSize: 32, weight: 700, align: "left", color: "FFFFFF"),
                WidgetLayer(id: uid(), kind: "date", x: 20, y: 60, w: 300, h: 20, fontSize: 16, weight: 500, align: "left", color: accentHex),
                WidgetLayer(id: uid(), kind: "image", src: "template_car", x: 60, y: 120, w: 220, h: 100),
                WidgetLayer(id: uid(), kind: "battery", x: 20, y: 280, w: 300, h: 30, fontSize: 24, weight: 600, align: "center", color: "FFFFFF"),
            ]
        }
        
        return spec
    }
}

struct Slot: Codable, Equatable {
    let index: Int
    let draftId: String?
    let name: String?
    let summary: [String: String?]?
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
