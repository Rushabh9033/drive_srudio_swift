import SwiftUI

// MARK: - Template Registry

struct WidgetTemplate: Identifiable {
    let id: String
    let name: String
    let preview: AnyView
    let render: (_ config: SlotConfig, _ telemetry: NativeTelemetry?) -> AnyView
}

// All available templates
let allTemplates: [WidgetTemplate] = [
    darkClockTemplate,
    batteryGlowTemplate,
    carStatusTemplate,
    minimalTemplate,
    neonTemplate,
]

// MARK: - Telemetry (read from AppGroup)

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

// MARK: - Color helper

extension Color {
    init(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Template 1: Dark Clock

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

    var accent: Color { Color(hex: config.accentHex) }

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

// MARK: - Template 2: Battery Glow

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

    var accent: Color { Color(hex: config.accentHex) }
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

// MARK: - Template 3: Car Status

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

    var accent: Color { Color(hex: config.accentHex) }
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

// MARK: - Template 4: Minimal

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

    var accent: Color { Color(hex: config.accentHex) }

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

// MARK: - Template 5: Neon

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

    var accent: Color { Color(hex: config.accentHex) }
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
