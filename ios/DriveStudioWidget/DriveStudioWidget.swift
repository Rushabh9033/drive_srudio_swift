import WidgetKit
import SwiftUI
import AppIntents
import Intents
import CryptoKit

// MARK: - Native Swift Widget Engine

struct SlotConfig: Codable {
    var templateId: String
    var accentHex: String
    var title: String
    var subtitle: String
    var updatedAt: Date

    static func defaultFor(slot: Int) -> SlotConfig {
        switch slot {
        case 1:
            return SlotConfig(
                templateId: "battery_glow",
                accentHex: "#00FF88",
                title: "Battery Glow",
                subtitle: "Phone SOC",
                updatedAt: .distantPast
            )
        case 2:
            return SlotConfig(
                templateId: "car_status",
                accentHex: "#34C759",
                title: "Car Status",
                subtitle: "Drive Link",
                updatedAt: .distantPast
            )
        case 3:
            return SlotConfig(
                templateId: "neon",
                accentHex: "#AF52DE",
                title: "Neon HUD",
                subtitle: "Performance",
                updatedAt: .distantPast
            )
        default: // Slot 0
            return SlotConfig(
                templateId: "dark_clock",
                accentHex: "#00D4FF",
                title: "Dark Clock",
                subtitle: "My Car",
                updatedAt: .distantPast
            )
        }
    }

    static let empty = defaultFor(slot: 0)

    var isEmpty: Bool { updatedAt == .distantPast }
}

enum WidgetStore {
    static let suiteName = "group.com.drivestudio.shared"
    private static func key(slot: Int) -> String { "swift_slot_\(slot)" }

    static func save(_ config: SlotConfig, forSlot slot: Int) {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = try? JSONEncoder().encode(config) else { return }
        defaults.set(data, forKey: key(slot: slot))
        defaults.synchronize()
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    static func load(slot: Int) -> SlotConfig? {
        guard
            let defaults = UserDefaults(suiteName: suiteName),
            let data = defaults.data(forKey: key(slot: slot)),
            let config = try? JSONDecoder().decode(SlotConfig.self, from: data)
        else { return nil }
        return config
    }
}

struct SummarySlotView: View {
    let summary: Summary
    let name: String?
    let telemetry: TelemetrySnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "car.fill")
                    .foregroundColor(telemetry?.carConnected == true ? .blue : .gray)
                Text(name ?? summary.title ?? "Drive Studio")
                    .font(.headline)
                    .bold()
                    .foregroundColor(.white)
                Spacer()
                if let level = telemetry?.batteryPercent {
                    Image(systemName: telemetry?.isCharging == true ? "battery.100.bolt" : "battery.100")
                        .foregroundColor(telemetry?.isCharging == true ? .green : .white)
                    Text("\(level)%")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.white)
                }
            }
            Spacer()
            Text(Date(), style: .time)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.5)
            Spacer()
            HStack {
                Text(summary.badge ?? "LIVE")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.blue)
                Spacer()
                Text(telemetry?.carConnected == true ? "Connected" : "Disconnected")
                    .font(.caption)
                    .bold()
                    .foregroundColor(telemetry?.carConnected == true ? .blue : .gray)
            }
        }
        .padding()
    }
}

struct UnassignedSlotView: View {
    let slotIndex: Int
    let telemetry: TelemetrySnapshot?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 28))
                .foregroundColor(.gray)
            Text("Slot \(slotIndex + 1)")
                .font(.headline)
                .bold()
                .foregroundColor(.white)
            Text("Assign widget in Drive Studio")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
    }
}

struct DriveStudioWidgetEntryView : View {
    var entry: SimpleEntry

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if entry.slotData == nil || entry.slotData?.spec?.layers?.isEmpty != false {
                    let json = """
                    [
                        {
                            "id": "fallback-text",
                            "kind": "text",
                            "text": "Open Drive Studio\\nto select a widget for Slot \\(entry.slotIndex + 1)",
                            "x": 10.0,
                            "y": 35.0,
                            "w": 80.0,
                            "h": 30.0,
                            "fontSize": 14.0,
                            "weight": 500,
                            "align": "center",
                            "color": "#8B95A5"
                        }
                    ]
                    """
                    if let fallbackLayers = try? JSONDecoder().decode([WidgetLayer].self, from: json.data(using: .utf8)!) {
                        ForEach(fallbackLayers) { layer in
                            LayerView(layer: layer, canvasSize: geo.size, telemetry: entry.telemetry, vehicle: entry.vehicle)
                        }
                    }
                } else if let spec = entry.slotData?.spec, let layers = spec.layers, !layers.isEmpty {
                    // 1. App Assigned Custom Widget (Spec Layers)
                    ForEach(layers) { layer in
                        LayerView(layer: layer, canvasSize: geo.size, telemetry: entry.telemetry, vehicle: entry.vehicle)
                    }
                } else if let summary = entry.slotData?.summary {
                    // 2. App Assigned Stock Widget (Summary)
                    SummarySlotView(summary: summary, name: entry.slotData?.name, telemetry: entry.telemetry)
                } else {
                    // 3. Unassigned Empty Slot
                    UnassignedSlotView(slotIndex: entry.slotIndex, telemetry: entry.telemetry)
                }
            }
        }
    }
}

struct NativeTelemetry {
    let batteryPercent: Int
    let isCharging: Bool
    let carConnected: Bool
}

func loadNativeTelemetry() -> NativeTelemetry? {
    guard
        let defaults = UserDefaults(suiteName: WidgetStore.suiteName),
        let json = defaults.string(forKey: "widget_state_v1"),
        let data = json.data(using: .utf8),
        let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let tele = obj["telemetry"] as? [String: Any]
    else { return nil }

    return NativeTelemetry(
        batteryPercent: tele["batteryPercent"] as? Int ?? 0,
        isCharging: tele["isCharging"] as? Bool ?? false,
        carConnected: tele["carConnected"] as? Bool ?? false
    )
}

struct WidgetTemplate: Identifiable {
    let id: String
    let name: String
    let preview: AnyView
    let render: (_ config: SlotConfig, _ telemetry: NativeTelemetry?) -> AnyView
}

let darkClockTemplate = WidgetTemplate(
    id: "dark_clock",
    name: "Dark Clock",
    preview: AnyView(DarkClockView(config: .empty, telemetry: nil, isPreview: true)),
    render: { config, tele in AnyView(DarkClockView(config: config, telemetry: tele, isPreview: false)) }
)

struct DarkClockView: View {
    let config: SlotConfig
    let telemetry: NativeTelemetry?
    let isPreview: Bool

    var accent: Color { Color(hex: config.accentHex) ?? .blue }

    var body: some View {
        ZStack {
            Color.black
            LinearGradient(
                colors: [accent.opacity(0.18), Color.black],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(config.subtitle.isEmpty ? "Drive Studio" : config.subtitle)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(accent)
                    .tracking(1.5)
                    .textCase(.uppercase)
                Spacer()
                Text(Date(), style: .time)
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(Date(), style: .date)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

let batteryGlowTemplate = WidgetTemplate(
    id: "battery_glow",
    name: "Battery Glow",
    preview: AnyView(BatteryGlowView(config: .empty, telemetry: nil, isPreview: true)),
    render: { config, tele in AnyView(BatteryGlowView(config: config, telemetry: tele, isPreview: false)) }
)

struct BatteryGlowView: View {
    let config: SlotConfig
    let telemetry: NativeTelemetry?
    let isPreview: Bool

    var accent: Color { Color(hex: config.accentHex) ?? .cyan }
    var level: Int { isPreview ? 87 : (telemetry?.batteryPercent ?? 0) }
    var charging: Bool { isPreview ? true : (telemetry?.isCharging ?? false) }
    var fraction: Double { Double(level) / 100.0 }

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.08)
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(
                            AngularGradient(colors: [accent.opacity(0.6), accent], center: .center),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Image(systemName: charging ? "bolt.fill" : "battery.100")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(accent)
                        Text("\(level)%")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 90, height: 90)
                .shadow(color: accent.opacity(0.5), radius: 16)
                Text(charging ? "Charging" : "On Battery")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(accent)
                    .tracking(1)
                    .textCase(.uppercase)
            }
        }
    }
}

let carStatusTemplate = WidgetTemplate(
    id: "car_status",
    name: "Car Status",
    preview: AnyView(CarStatusView(config: .empty, telemetry: nil, isPreview: true)),
    render: { config, tele in AnyView(CarStatusView(config: config, telemetry: tele, isPreview: false)) }
)

struct CarStatusView: View {
    let config: SlotConfig
    let telemetry: NativeTelemetry?
    let isPreview: Bool

    var accent: Color { Color(hex: config.accentHex) ?? .blue }
    var connected: Bool { isPreview ? true : (telemetry?.carConnected ?? false) }
    var battery: Int { isPreview ? 100 : (telemetry?.batteryPercent ?? 0) }
    var charging: Bool { isPreview ? true : (telemetry?.isCharging ?? false) }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.08, blue: 0.14), Color.black],
                startPoint: .top, endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "car.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(connected ? accent : .gray)
                    Text(connected ? "Connected" : "Disconnected")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(connected ? accent : .gray)
                    Spacer()
                }
                Spacer()
                Text(Date(), style: .time)
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: charging ? "battery.100.bolt" : "battery.75")
                        .foregroundColor(charging ? .green : .white.opacity(0.7))
                    Text(battery > 0 ? "\(battery)%" : "—")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                    Spacer()
                    Circle()
                        .fill(connected ? accent : Color.gray)
                        .frame(width: 7, height: 7)
                        .shadow(color: connected ? accent : .clear, radius: 4)
                }
            }
            .padding(14)
        }
    }
}

let minimalTemplate = WidgetTemplate(
    id: "minimal",
    name: "Minimal",
    preview: AnyView(MinimalView(config: .empty, telemetry: nil, isPreview: true)),
    render: { config, tele in AnyView(MinimalView(config: config, telemetry: tele, isPreview: false)) }
)

struct MinimalView: View {
    let config: SlotConfig
    let telemetry: NativeTelemetry?
    let isPreview: Bool

    var accent: Color { Color(hex: config.accentHex) ?? .white }

    var body: some View {
        ZStack {
            Color(white: 0.06)
            VStack(spacing: 0) {
                Rectangle()
                    .fill(accent)
                    .frame(height: 3)
                    .frame(maxWidth: .infinity)
                Spacer()
                VStack(spacing: 6) {
                    Text(Date(), style: .time)
                        .font(.system(size: 42, weight: .ultraLight, design: .default))
                        .foregroundColor(.white)
                        .monospacedDigit()
                    Text(Date(), style: .date)
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(0.5)
                }
                Spacer()
            }
        }
    }
}

let neonTemplate = WidgetTemplate(
    id: "neon",
    name: "Neon",
    preview: AnyView(NeonView(config: .empty, telemetry: nil, isPreview: true)),
    render: { config, tele in AnyView(NeonView(config: config, telemetry: tele, isPreview: false)) }
)

struct NeonView: View {
    let config: SlotConfig
    let telemetry: NativeTelemetry?
    let isPreview: Bool

    var accent: Color { Color(hex: config.accentHex) ?? .green }
    var battery: Int { isPreview ? 100 : (telemetry?.batteryPercent ?? 0) }

    var body: some View {
        ZStack {
            Color.black
            VStack(alignment: .leading, spacing: 4) {
                Text(config.title.isEmpty ? "DRIVE" : config.title.uppercased())
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundColor(accent)
                    .shadow(color: accent, radius: 6)
                    .tracking(3)
                Spacer()
                Text(Date(), style: .time)
                    .font(.system(size: 46, weight: .black, design: .monospaced))
                    .foregroundColor(accent)
                    .shadow(color: accent.opacity(0.8), radius: 12)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                Spacer()
                if battery > 0 {
                    HStack(spacing: 4) {
                        ForEach(0..<5) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Double(i) / 5.0 < Double(battery) / 100.0
                                      ? accent : Color.white.opacity(0.1))
                                .frame(width: 16, height: 6)
                        }
                        Text("\(battery)%")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(accent.opacity(0.8))
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

let allTemplates: [WidgetTemplate] = [
    darkClockTemplate,
    batteryGlowTemplate,
    carStatusTemplate,
    minimalTemplate,
    neonTemplate,
]

// MARK: - App Group Data Models

struct VehicleData: Codable {
    let brandId: String?
    let modelId: String?
    let artwork: String?
    let displayName: String?
    let hasCustomImage: Bool?
    let customImage: String?
}

struct WidgetState: Codable {
    let schemaVersion: Int?
    let vehicle: VehicleData?
    let slots: [Slot]?
    let telemetry: TelemetrySnapshot?
}

struct Slot: Codable {
    let index: Int
    let draftId: String?
    let name: String?
    let summary: Summary?
    let spec: WidgetSpec?
}

struct Summary: Codable {
    let title: String?
    let clockFormat: String?
    let dateFormat: String?
    let badge: String?
    let bgFrom: String?
    let bgTo: String?
    let bgType: String?
}

struct WidgetSpec: Codable {
    let background: WidgetBackground?
    let layers: [WidgetLayer]?
}

struct WidgetBackground: Codable {
    let type: String?
    let from: String?
    let to: String?
    let imageSrc: String?
}

struct ImageLoader {
    static func loadImage(from src: String) -> UIImage? {
        if src.hasPrefix("data:image") {
            guard let commaIdx = src.firstIndex(of: ","),
                  let data = Data(base64Encoded: String(src[src.index(after: commaIdx)...])) else { return nil }
            return UIImage(data: data)
        }
        
        if src.hasPrefix("assets/") {
            var url = Bundle.main.bundleURL
            url.deleteLastPathComponent() // removes DriveStudioWidget.appex
            url.deleteLastPathComponent() // removes PlugIns
            url.appendPathComponent("Frameworks/App.framework/flutter_assets/\(src)")
            if let img = UIImage(contentsOfFile: url.path) {
                return img
            }
            // Fallback just in case
            let filename = URL(fileURLWithPath: src).deletingPathExtension().lastPathComponent
            return UIImage(named: filename)
        }
        
        if let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroupHelper.suiteName) {
            var fileURL = sharedURL.appendingPathComponent("SharedImages")
            if let gen = AppGroupHelper.currentGeneration {
                fileURL = fileURL.appendingPathComponent("generation_\(gen)")
            }
            fileURL = fileURL.appendingPathComponent(src)
            if let uiImg = UIImage(contentsOfFile: fileURL.path) {
                return uiImg
            }
        }
        
        // Fallback for absolute paths
        return UIImage(contentsOfFile: src)
    }
}

struct WidgetLayer: Codable, Identifiable {
    let id: String
    let kind: String
    let label: String?
    let text: String?
    let src: String?
    let x: Double?
    let y: Double?
    let w: Double?
    let h: Double?
    let fontSize: Double?
    let weight: Int?
    let align: String?
    let color: String?
    let opacity: Double?
    let radius: Double?
    let shadow: Bool?
    let hidden: Bool?
    let format: String?
    let color2: String?
    let color3: String?
    let trackColor: String?
    let shadowColor: String?
    let showSeconds: Bool?
}

struct TelemetrySnapshot: Codable {
    let carConnected: Bool
    let batteryPercent: Int?
    let isCharging: Bool
}

// MARK: - State Loader

struct AppGroupHelper {
    static let suiteName = "group.com.drivestudio.shared"
    static let stateKey = "widget_state_v1"
    
    struct Metadata: Codable {
        let schemaVersion: Int
        let generation: String
        let stateFile: String
        let checksum: String
        let updatedAt: String
    }

    static var currentGeneration: String?

    static func loadState() -> WidgetState? {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return nil }
        
        // Try V2
        if let metadataData = defaults.data(forKey: "widget_state_v2_metadata"),
           let metadata = try? JSONDecoder().decode(Metadata.self, from: metadataData),
           let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName) {
           
           let fileURL = sharedURL.appendingPathComponent(metadata.stateFile)
           if let data = try? Data(contentsOf: fileURL) {
               let checksum = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
               if checksum == metadata.checksum {
                   currentGeneration = metadata.generation
                   return try? JSONDecoder().decode(WidgetState.self, from: data)
               }
           }
        }
        
        // Fallback V1
        currentGeneration = nil
        if let jsonString = defaults.string(forKey: stateKey),
           let data = jsonString.data(using: .utf8) {
           return try? JSONDecoder().decode(WidgetState.self, from: data)
        }
        return nil
    }

    static func getSlot(index: Int) -> Slot? {
        let state = loadState()
        return state?.slots?.first(where: { $0.index == index })
    }
    
    static func getVehicle() -> VehicleData? {
        return loadState()?.vehicle
    }

    static func getTelemetry() -> TelemetrySnapshot? {
        return loadState()?.telemetry
    }
}

// MARK: - Color Parser

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        if hexSanitized.count == 6 {
            self.init(
                red: Double((rgb & 0xFF0000) >> 16) / 255.0,
                green: Double((rgb & 0x00FF00) >> 8) / 255.0,
                blue: Double(rgb & 0x0000FF) / 255.0
            )
        } else if hexSanitized.count == 8 {
            self.init(
                red: Double((rgb & 0x00FF0000) >> 16) / 255.0,
                green: Double((rgb & 0x0000FF00) >> 8) / 255.0,
                blue: Double(rgb & 0x000000FF) / 255.0,
                opacity: Double((rgb & 0xFF000000) >> 24) / 255.0
            )
        } else {
            return nil
        }
    }
}

// MARK: - Widget Provider

@available(iOS 16.0, *)
struct StaticProvider: TimelineProvider {
    let slotIndex: Int

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), slotIndex: slotIndex, slotData: nil, vehicle: nil, telemetry: nil, isPreview: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), slotIndex: slotIndex, slotData: AppGroupHelper.getSlot(index: slotIndex), vehicle: AppGroupHelper.getVehicle(), telemetry: AppGroupHelper.getTelemetry(), isPreview: context.isPreview)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let entry = SimpleEntry(date: Date(), slotIndex: slotIndex, slotData: AppGroupHelper.getSlot(index: slotIndex), vehicle: AppGroupHelper.getVehicle(), telemetry: AppGroupHelper.getTelemetry(), isPreview: false)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let slotIndex: Int
    var slotData: Slot?
    var vehicle: VehicleData?
    var telemetry: TelemetrySnapshot?
    var isPreview: Bool = false
}

// MARK: - Native Rendering Engine

struct BackgroundView: View {
    var spec: WidgetSpec?
    var summary: Summary?

    var body: some View {
        ZStack {
            if let bgFrom = spec?.background?.from ?? summary?.bgFrom, let colorFrom = Color(hex: bgFrom) {
                let bgTo = spec?.background?.to ?? summary?.bgTo
                if let bgTo = bgTo, let colorTo = Color(hex: bgTo) {
                    LinearGradient(colors: [colorFrom, colorTo], startPoint: .topLeading, endPoint: .bottomTrailing)
                } else {
                    colorFrom
                }
            } else {
                Color.black
            }
            
            if let imgSrc = spec?.background?.imageSrc, !imgSrc.isEmpty {
                if let uiImg = ImageLoader.loadImage(from: imgSrc) {
                    Image(uiImage: uiImg)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
            }
        }
    }
}

struct LayerView: View {
    let layer: WidgetLayer
    let canvasSize: CGSize
    let telemetry: TelemetrySnapshot?
    var vehicle: VehicleData? = nil

    var body: some View {
        let w = layer.w ?? 100.0
        let h = layer.h ?? 100.0
        let x = layer.x ?? 0.0
        let y = layer.y ?? 0.0
        let label = layer.label ?? ""
        let text = layer.text ?? ""
        let fontSize = layer.fontSize ?? 14.0
        let weightVal = layer.weight ?? 400
        let alignStr = layer.align ?? "left"
        let colorStr = layer.color ?? "#FFFFFF"
        let opacityVal = layer.opacity ?? 1.0
        let radiusVal = layer.radius ?? 0.0
        let isHidden = layer.hidden ?? false

        let width = canvasSize.width * (w / 100.0)
        let height = canvasSize.height * (h / 100.0)
        let left = canvasSize.width * (x / 100.0)
        let top = canvasSize.height * (y / 100.0)
        
        let scaledFontSize = fontSize * (canvasSize.width / 180.0)
        let layerColor = Color(hex: colorStr) ?? .white
        let weight = fontWeight(for: weightVal)
        
        Group {
            if isHidden {
                EmptyView()
            } else if layer.kind == "text" {
                Text(text.isEmpty ? label : text)
                    .font(.system(size: scaledFontSize, weight: weight, design: .default))
                    .foregroundColor(layerColor)
                    .opacity(opacityVal)
                    .multilineTextAlignment(textAlignment(for: alignStr))
            } else if layer.kind == "clock" {
                Text(Date(), style: .time)
                    .font(.system(size: scaledFontSize, weight: weight, design: .monospaced))
                    .foregroundColor(layerColor)
                    .opacity(opacityVal)
            } else if layer.kind == "date" {
                Text(Date(), style: .date)
                    .font(.system(size: scaledFontSize, weight: weight, design: .default))
                    .foregroundColor(layerColor)
                    .opacity(opacityVal)
            } else if layer.kind == "battery" {
                NativeBatteryView(layer: layer, telemetry: telemetry, size: CGSize(width: width, height: height))
                    .opacity(opacityVal)
            } else if layer.kind == "shape" {
                if radiusVal >= 50 {
                    if opacityVal < 0.4 && colorStr.uppercased() == "#FFFFFF" {
                        Circle().fill(.ultraThinMaterial).environment(\.colorScheme, .dark)
                    } else {
                        Circle().fill(layerColor.opacity(opacityVal))
                    }
                } else {
                    let r = radiusVal * (canvasSize.width / 100.0)
                    if opacityVal < 0.4 && colorStr.uppercased() == "#FFFFFF" {
                        RoundedRectangle(cornerRadius: r).fill(.ultraThinMaterial).environment(\.colorScheme, .dark)
                    } else {
                        RoundedRectangle(cornerRadius: r).fill(layerColor.opacity(opacityVal))
                    }
                }
            } else if layer.kind == "badge" {
                Text(text.isEmpty ? label : text)
                    .font(.system(size: scaledFontSize * 0.55, weight: .bold, design: .default))
                    .foregroundColor(Color(hex: layer.color3 ?? "#000000") ?? .black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(layerColor.opacity(opacityVal))
                    .cornerRadius(radiusVal > 0 ? radiusVal : 12)
            } else if layer.kind == "image" {
                let src = (layer.src == nil || layer.src?.isEmpty == true) ? (vehicle?.customImage ?? "") : (layer.src ?? "")
                if src.hasPrefix("sf:") || src.hasPrefix("symbol:") {
                    let sysName = src.replacingOccurrences(of: "sf:", with: "").replacingOccurrences(of: "symbol:", with: "")
                    Image(systemName: sysName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(layerColor)
                        .opacity(opacityVal)
                } else if let url = URL(string: src), src.hasPrefix("http"),
                          let data = try? Data(contentsOf: url), let uiImg = UIImage(data: data) {
                    Image(uiImage: uiImg)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .opacity(opacityVal)
                } else if let uiImg = ImageLoader.loadImage(from: src) {
                    Image(uiImage: uiImg)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .opacity(opacityVal)
                } else {
                    // Truthful error state for missing/corrupt asset
                    ZStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                        Image(systemName: "photo.badge.exclamationmark")
                            .foregroundColor(.gray)
                    }
                }
            } else if layer.kind == "analog" {
                ZStack {
                    Circle()
                        .stroke(layerColor.opacity(0.4), lineWidth: 3)
                    Circle()
                        .fill(layerColor.opacity(0.15))
                    Rectangle()
                        .fill(layerColor)
                        .frame(width: 2, height: scaledFontSize * 0.8)
                        .offset(y: -scaledFontSize * 0.4)
                    Rectangle()
                        .fill(layerColor)
                        .frame(width: 3, height: scaledFontSize * 0.6)
                        .offset(y: -scaledFontSize * 0.3)
                }
            } else if layer.kind == "divider" {
                Rectangle()
                    .fill(layerColor.opacity(opacityVal))
                    .frame(height: 2)
            } else {
                EmptyView()
            }
        }
        .frame(width: width, height: height, alignment: .center)
        .position(x: left + width / 2, y: top + height / 2)
    }
    
    func fontWeight(for weight: Int) -> Font.Weight {
        switch weight {
        case 100...300: return .light
        case 400: return .regular
        case 500: return .medium
        case 600: return .semibold
        case 700...900: return .bold
        default: return .regular
        }
    }
    
    func textAlignment(for align: String) -> TextAlignment {
        switch align {
        case "center": return .center
        case "right": return .trailing
        default: return .leading
        }
    }
}

// MARK: - Dynamic Widgets

@available(iOS 16.0, *)
struct DriveStudioSlot1Widget: Widget {
    let kind: String = "DriveStudioSlot1Widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StaticProvider(slotIndex: 0)) { entry in
            if #available(iOS 17.0, *) {
                DriveStudioWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        BackgroundView(spec: entry.slotData?.spec, summary: entry.slotData?.summary)
                    }
            } else {
                ZStack {
                    BackgroundView(spec: entry.slotData?.spec, summary: entry.slotData?.summary)
                    DriveStudioWidgetEntryView(entry: entry)
                }
            }
        }
        .configurationDisplayName("Drive Studio - Slot 1")
        .description("Displays the widget assigned to Slot 1.")
        .supportedFamilies([.systemSmall])
    }
}

@available(iOS 16.0, *)
struct DriveStudioSlot2Widget: Widget {
    let kind: String = "DriveStudioSlot2Widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StaticProvider(slotIndex: 1)) { entry in
            if #available(iOS 17.0, *) {
                DriveStudioWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        BackgroundView(spec: entry.slotData?.spec, summary: entry.slotData?.summary)
                    }
            } else {
                ZStack {
                    BackgroundView(spec: entry.slotData?.spec, summary: entry.slotData?.summary)
                    DriveStudioWidgetEntryView(entry: entry)
                }
            }
        }
        .configurationDisplayName("Drive Studio - Slot 2")
        .description("Displays the widget assigned to Slot 2.")
        .supportedFamilies([.systemSmall])
    }
}

@available(iOS 16.0, *)
struct DriveStudioSlot3Widget: Widget {
    let kind: String = "DriveStudioSlot3Widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StaticProvider(slotIndex: 2)) { entry in
            if #available(iOS 17.0, *) {
                DriveStudioWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        BackgroundView(spec: entry.slotData?.spec, summary: entry.slotData?.summary)
                    }
            } else {
                ZStack {
                    BackgroundView(spec: entry.slotData?.spec, summary: entry.slotData?.summary)
                    DriveStudioWidgetEntryView(entry: entry)
                }
            }
        }
        .configurationDisplayName("Drive Studio - Slot 3")
        .description("Displays the widget assigned to Slot 3.")
        .supportedFamilies([.systemSmall])
    }
}

@available(iOS 16.0, *)
struct DriveStudioSlot4Widget: Widget {
    let kind: String = "DriveStudioSlot4Widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StaticProvider(slotIndex: 3)) { entry in
            if #available(iOS 17.0, *) {
                DriveStudioWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        BackgroundView(spec: entry.slotData?.spec, summary: entry.slotData?.summary)
                    }
            } else {
                ZStack {
                    BackgroundView(spec: entry.slotData?.spec, summary: entry.slotData?.summary)
                    DriveStudioWidgetEntryView(entry: entry)
                }
            }
        }
        .configurationDisplayName("Drive Studio - Slot 4")
        .description("Displays the widget assigned to Slot 4.")
        .supportedFamilies([.systemSmall])
    }
}
struct NativeBatteryView: View {
    let layer: WidgetLayer
    let telemetry: TelemetrySnapshot?
    let size: CGSize
    
    var body: some View {
        let level = telemetry?.batteryPercent ?? 0
        let charging = telemetry?.isCharging ?? false
        let known = telemetry?.batteryPercent != nil
        let fraction = Double(level) / 100.0
        
        let format = layer.format?.lowercased() ?? "panel"
        let accent = Color(hex: layer.color ?? "#FFFFFF") ?? .white
        let accent2 = Color(hex: layer.color2 ?? layer.color ?? "#00FF00") ?? .green
        let ink = Color(hex: layer.color3 ?? "#FFFFFF") ?? .white
        let track = Color(hex: layer.trackColor ?? "#333333") ?? .gray
        
        Group {
            switch format {
            case "metrics":
                AnyView(metricsView(level: level, charging: charging, known: known, accent: accent, track: track, ink: ink, size: size))
            case "icon":
                AnyView(iconView(fraction: fraction, charging: charging, known: known, accent: accent, track: track, ink: ink, size: size))
            case "dots":
                AnyView(dotsView(fraction: fraction, accent: accent, track: track, ink: ink, size: size))
            case "matrix":
                AnyView(matrixView(fraction: fraction, accent: accent, track: track, ink: ink, size: size))
            case "lightning":
                AnyView(lightningView(fraction: fraction, charging: charging, accent: accent, accent2: accent2, ink: ink, size: size))
            case "pill":
                AnyView(pillView(fraction: fraction, accent: accent, accent2: accent2, track: track, size: size))
            case "pie", "orbit", "ring", "dayprogress":
                AnyView(ringView(fraction: fraction, charging: charging, known: known, accent: accent, track: track, ink: ink, size: size))
            case "large", "batterylive", "charging":
                AnyView(largeView(level: level, charging: charging, known: known, accent: accent, ink: ink, size: size))
            case "bars":
                AnyView(barsView(fraction: fraction, accent: accent, track: track, muted: ink.opacity(0.5), size: size))
            case "segmented":
                AnyView(segmentedView(fraction: fraction, accent: accent, track: track, muted: ink.opacity(0.5), size: size))
            case "vertbar":
                AnyView(vertbarView(fraction: fraction, accent: accent, track: track, size: size))

            case "hud":
                AnyView(hudView(fraction: fraction, charging: charging, known: known, accent: accent, track: track, ink: ink, size: size))
            case "minimal":
                AnyView(minimalView(level: level, known: known, accent: accent))
            case "dual":
                AnyView(dualView(fraction: fraction, accent: accent, track: track, ink: ink, size: size))
            case "wave":
                AnyView(waveView(fraction: fraction, accent: accent, track: track, size: size))
            default:
                AnyView(panelView(level: level, fraction: fraction, charging: charging, known: known, accent: accent, accent2: accent2, track: track, ink: ink, size: size))
            }
        }
    }
    
    // MARK: - Format Implementations
    
    @ViewBuilder
    func panelView(level: Int, fraction: Double, charging: Bool, known: Bool, accent: Color, accent2: Color, track: Color, ink: Color, size: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.black.opacity(0.35))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(known ? (charging ? "CHARGING" : "BATTERY") : "UNAVAILABLE")
                        .font(.system(size: size.width * 0.07, weight: .bold, design: .monospaced))
                        .foregroundColor(accent.opacity(0.85))
                        .tracking(2.2)
                    Spacer()
                    if charging {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(accent)
                            .font(.system(size: size.width * 0.12))
                    }
                }
                
                HStack(alignment: .lastTextBaseline, spacing: 0) {
                    Text(known ? "\(level)" : "—")
                        .font(.system(size: size.width * 0.28, weight: .heavy))
                        .foregroundColor(ink)
                    if known {
                        Text("%")
                            .font(.system(size: size.width * 0.12, weight: .semibold))
                            .foregroundColor(Color.gray)
                    }
                }
                Spacer()
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(track)
                        if known && fraction > 0 {
                            Capsule()
                                .fill(LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(geo.size.width * fraction, geo.size.height))
                        }
                    }
                }
                .frame(height: size.height * 0.1)
                .padding(.bottom, size.height * 0.1)
            }
            .padding(size.width * 0.1)
        }
    }
    
    @ViewBuilder
    func metricsView(level: Int, charging: Bool, known: Bool, accent: Color, track: Color, ink: Color, size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: size.height * 0.04) {
            Text(known ? (charging ? "CHARGING" : "ON BATTERY") : "UNAVAILABLE")
                .font(.system(size: size.width * 0.065, weight: .bold, design: .monospaced))
                .foregroundColor(charging ? accent : Color.gray)
                .tracking(1.8)
            
            Text(known ? "\(level)%" : "—")
                .font(.system(size: size.width * 0.22, weight: .heavy))
                .foregroundColor(ink)
            
            Spacer()
            
            metricRow(label: "SOURCE", value: known ? "PHONE" : "—", size: size, accent: accent)
            metricRow(label: "STATUS", value: known ? (charging ? "CHARGING" : "READY") : "UNAVAILABLE", size: size, accent: accent)
            
            Rectangle()
                .fill(accent)
                .frame(width: size.width * 0.35, height: 3)
                .padding(.top, size.height * 0.05)
        }
        .padding(size.width * 0.08)
    }
    
    @ViewBuilder
    func metricRow(label: String, value: String, size: CGSize, accent: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: size.width * 0.055, design: .monospaced))
                .foregroundColor(Color.gray)
                .tracking(1.4)
            Spacer()
            Text(value)
                .font(.system(size: size.width * 0.07, weight: .bold))
                .foregroundColor(accent)
        }
    }
    
    @ViewBuilder
    func iconView(fraction: Double, charging: Bool, known: Bool, accent: Color, track: Color, ink: Color, size: CGSize) -> some View {
        VStack {
            HStack(spacing: 2) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(accent, lineWidth: 3.5)
                        .frame(width: size.width * 0.42, height: size.height * 0.28)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(track)
                        .padding(5)
                        .frame(width: size.width * 0.42, height: size.height * 0.28)
                    
                    if known && fraction > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(accent)
                            .padding(5)
                            .frame(width: max((size.width * 0.42 - 10) * fraction + 10, 10), height: size.height * 0.28)
                    }
                }
                
                Path { path in
                    path.addRoundedRect(in: CGRect(x: 0, y: 0, width: size.width * 0.045, height: size.height * 0.12), cornerSize: CGSize(width: 3, height: 3))
                }
                .fill(accent)
                .frame(width: size.width * 0.045, height: size.height * 0.12)
            }
            .padding(.bottom, size.height * 0.1)
            
            Text(known ? "\(Int(fraction * 100))%" : "—")
                .font(.system(size: size.width * 0.14, weight: .heavy))
                .foregroundColor(ink)
        }
    }
    
    @ViewBuilder
    func dotsView(fraction: Double, accent: Color, track: Color, ink: Color, size: CGSize) -> some View {
        let filled = Int(round(fraction * 10))
        VStack(spacing: size.height * 0.05) {
            Text("CHARGE")
                .font(.system(size: size.width * 0.065, weight: .bold, design: .monospaced))
                .foregroundColor(Color.gray)
                .tracking(2)
                
            VStack(spacing: size.width * 0.04) {
                HStack(spacing: size.width * 0.04) {
                    ForEach(0..<5) { i in
                        Capsule()
                            .fill(i < filled ? accent : track)
                            .frame(width: size.width * 0.1, height: size.width * 0.055)
                    }
                }
                HStack(spacing: size.width * 0.04) {
                    ForEach(5..<10) { i in
                        Capsule()
                            .fill(i < filled ? accent : track)
                            .frame(width: size.width * 0.1, height: size.width * 0.055)
                    }
                }
            }
            
            Text("\(Int(fraction * 100))%")
                .font(.system(size: size.width * 0.12, weight: .heavy))
                .foregroundColor(ink)
        }
    }
    
    @ViewBuilder
    func matrixView(fraction: Double, accent: Color, track: Color, ink: Color, size: CGSize) -> some View {
        let filled = Int(round(fraction * 16))
        VStack {
            VStack(spacing: size.width * 0.03) {
                ForEach(0..<4) { row in
                    HStack(spacing: size.width * 0.03) {
                        ForEach(0..<4) { col in
                            let i = (3 - row) * 4 + col
                            let on = i < filled
                            let alpha = on ? 0.55 + 0.45 * (Double(i % 4) / 4.0) : 1.0
                            RoundedRectangle(cornerRadius: size.width * 0.02)
                                .fill(on ? accent.opacity(alpha) : track)
                                .frame(width: size.width * 0.15, height: size.width * 0.15)
                        }
                    }
                }
            }
            .padding(.bottom, size.height * 0.05)
            
            Text("\(Int(fraction * 100))")
                .font(.system(size: size.width * 0.11, weight: .bold, design: .monospaced))
                .foregroundColor(ink)
        }
    }
    
    @ViewBuilder
    func lightningView(fraction: Double, charging: Bool, accent: Color, accent2: Color, ink: Color, size: CGSize) -> some View {
        VStack {
            Image(systemName: "bolt.fill")
                .font(.system(size: size.height * 0.6))
                .foregroundStyle(LinearGradient(colors: [accent2, accent], startPoint: .top, endPoint: .bottom))
                .shadow(color: accent.opacity(0.5), radius: 10)
            
            Text("\(Int(fraction * 100))%")
                .font(.system(size: size.width * 0.13, weight: .heavy))
                .foregroundColor(ink)
                .shadow(color: Color.black.opacity(0.5), radius: 12)
        }
    }
    
    @ViewBuilder
    func pillView(fraction: Double, accent: Color, accent2: Color, track: Color, size: CGSize) -> some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(track)
                .frame(width: size.width * 0.78, height: size.height * 0.28)
            
            if fraction > 0 {
                Capsule()
                    .fill(LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max((size.width * 0.78) * fraction, size.height * 0.28), height: size.height * 0.28)
            }
        }
    }
    
    @ViewBuilder
    func ringView(fraction: Double, charging: Bool, known: Bool, accent: Color, track: Color, ink: Color, size: CGSize) -> some View {
        ZStack {
            Circle()
                .stroke(track, lineWidth: size.width * 0.08)
                .frame(width: size.width * 0.8, height: size.height * 0.8)
            
            if known && fraction > 0 {
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(accent, style: StrokeStyle(lineWidth: size.width * 0.08, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: size.width * 0.8, height: size.height * 0.8)
            }
            
            VStack(spacing: 0) {
                if charging {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(accent)
                        .font(.system(size: size.width * 0.15))
                }
                Text(known ? "\(Int(fraction * 100))%" : "—")
                    .font(.system(size: size.width * 0.18, weight: .heavy))
                    .foregroundColor(ink)
            }
        }
    }
    
    @ViewBuilder
    func largeView(level: Int, charging: Bool, known: Bool, accent: Color, ink: Color, size: CGSize) -> some View {
        VStack(spacing: 0) {
            Text(known ? "\(level)%" : "—")
                .font(.system(size: size.width * 0.35, weight: .heavy))
                .foregroundColor(ink)
            
            if charging {
                Text("CHARGING")
                    .font(.system(size: size.width * 0.08, weight: .bold))
                    .foregroundColor(accent)
            }
        }
    }
    
    @ViewBuilder
    func barsView(fraction: Double, accent: Color, track: Color, muted: Color, size: CGSize) -> some View {
        let n = 8
        let gap = size.width * 0.02
        let barW = (size.width * 0.72 - gap * Double(n - 1)) / Double(n)
        let baseY = size.height * 0.78
        let maxH = size.height * 0.55
        let lit = Int(ceil(fraction * Double(n)))
        let originX = size.width * 0.14
        
        ZStack(alignment: .topLeading) {
            Text("PHONE LEVEL")
                .font(.system(size: size.width * 0.06, weight: .bold))
                .foregroundColor(muted)
                .kerning(1.8)
                .offset(x: size.width * 0.14, y: size.height * 0.1)
            
            ForEach(0..<n, id: \.self) { i in
                let h = maxH * (0.35 + 0.65 * (Double(i + 1) / Double(n)))
                let on = i < lit
                let rectX = originX + Double(i) * (barW + gap)
                let rectY = baseY - h
                
                RoundedRectangle(cornerRadius: barW * 0.35)
                    .fill(on ? accent.opacity(0.45 + 0.55 * (Double(i) / Double(n))) : track)
                    .frame(width: barW, height: h)
                    .offset(x: rectX, y: rectY)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    @ViewBuilder
    func segmentedView(fraction: Double, accent: Color, track: Color, muted: Color, size: CGSize) -> some View {
        let segs = 10
        let gap = size.width * 0.015
        let segW = (size.width * 0.8 - gap * Double(segs - 1)) / Double(segs)
        let rectY = size.height * 0.48
        let h = size.height * 0.16
        let lit = Int(round(fraction * Double(segs)))
        let x0 = size.width * 0.1
        
        ZStack(alignment: .topLeading) {
            Text("CELLS")
                .font(.system(size: size.width * 0.065, weight: .bold))
                .foregroundColor(muted)
                .kerning(2.0)
                .offset(x: x0, y: size.height * 0.18)
            
            ForEach(0..<segs, id: \.self) { i in
                let on = i < lit
                let rectX = x0 + Double(i) * (segW + gap)
                
                RoundedRectangle(cornerRadius: segW * 0.25)
                    .fill(on ? accent : track)
                    .frame(width: segW, height: h)
                    .offset(x: rectX, y: rectY)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    @ViewBuilder
    func vertbarView(fraction: Double, accent: Color, track: Color, size: CGSize) -> some View {
        let rectX = size.width * 0.38
        let rectY = size.height * 0.12
        let rectW = size.width * 0.24
        let maxH = size.height * 0.62
        let fillH = maxH * fraction
        let fillY = rectY + (maxH - fillH)
        
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 14)
                .fill(track)
                .frame(width: rectW, height: maxH)
                .offset(x: rectX, y: rectY)
            
            RoundedRectangle(cornerRadius: 14)
                .fill(accent)
                .frame(width: rectW, height: fillH)
                .offset(x: rectX, y: fillY)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
    
    @ViewBuilder
    func hudView(fraction: Double, charging: Bool, known: Bool, accent: Color, track: Color, ink: Color, size: CGSize) -> some View {
        ZStack {
            Circle()
                .trim(from: 0.1, to: 0.9)
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                .foregroundColor(track)
                .frame(width: size.width * 0.9, height: size.height * 0.9)
                .rotationEffect(.degrees(90))
                
            Circle()
                .trim(from: 0.1, to: 0.1 + 0.8 * fraction)
                .stroke(accent, lineWidth: 6)
                .frame(width: size.width * 0.9, height: size.height * 0.9)
                .rotationEffect(.degrees(90))
                
            VStack {
                Text(known ? "\(Int(fraction * 100))" : "—")
                    .font(.system(size: size.width * 0.25, weight: .bold, design: .monospaced))
                    .foregroundColor(ink)
                Text("PWR")
                    .font(.system(size: size.width * 0.08, weight: .bold))
                    .foregroundColor(accent)
            }
        }
    }
    
    @ViewBuilder
    func minimalView(level: Int, known: Bool, accent: Color) -> some View {
        Text(known ? "\(level)%" : "—")
            .font(.system(size: size.width * 0.15, weight: .medium))
            .foregroundColor(accent)
    }
    
    @ViewBuilder
    func dualView(fraction: Double, accent: Color, track: Color, ink: Color, size: CGSize) -> some View {
        // Fallback to segmented for dual
        barsView(fraction: fraction, accent: accent, track: track, muted: ink.opacity(0.5), size: size)
    }
    
    @ViewBuilder
    func waveView(fraction: Double, accent: Color, track: Color, size: CGSize) -> some View {
        // Simplified wave: A rect that fills from bottom up
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: size.width * 0.1)
                .fill(track)
                .frame(width: size.width * 0.6, height: size.height * 0.8)
                
            if fraction > 0 {
                RoundedRectangle(cornerRadius: size.width * 0.1)
                    .fill(accent)
                    .frame(width: size.width * 0.6, height: size.height * 0.8 * fraction)
            }
        }
    }
}
