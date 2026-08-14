import SwiftUI
import WidgetKit
import UIKit

// MARK: - Real Data Timeline Entry
struct OrbitDateEntry: TimelineEntry {
    let date: Date
    let batteryLevel: Double // 0.0 to 1.0 (real device battery)
    let isCharging: Bool
    let vehicleName: String
}

// MARK: - Real Data Timeline Provider (Live Battery, System Clock, & Vehicle Data)
struct OrbitDateProvider: TimelineProvider {
    func placeholder(in context: Context) -> OrbitDateEntry {
        OrbitDateEntry(
            date: Date(),
            batteryLevel: fetchRealBattery(),
            isCharging: fetchIsCharging(),
            vehicleName: fetchVehicleName()
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (OrbitDateEntry) -> Void) {
        completion(OrbitDateEntry(
            date: Date(),
            batteryLevel: fetchRealBattery(),
            isCharging: fetchIsCharging(),
            vehicleName: fetchVehicleName()
        ))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<OrbitDateEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .minute, value: 1, to: Date())!
        let entry = OrbitDateEntry(
            date: Date(),
            batteryLevel: fetchRealBattery(),
            isCharging: fetchIsCharging(),
            vehicleName: fetchVehicleName()
        )
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func fetchRealBattery() -> Double {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let lvl = Double(UIDevice.current.batteryLevel)
        if lvl >= 0 { return lvl }
        
        // Fallback to shared UserDefaults App Group if UIDevice isn't ready in background
        if let defaults = UserDefaults(suiteName: AppGroupContract.suiteName),
           let snapshotData = defaults.data(forKey: "drive_studio_telemetry"),
           let snapshot = try? JSONDecoder().decode(TelemetrySnapshot.self, from: snapshotData),
           let pct = snapshot.batteryPercent {
            return Double(pct) / 100.0
        }
        return 0.85
    }

    private func fetchIsCharging() -> Bool {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let state = UIDevice.current.batteryState
        if state == .charging || state == .full { return true }
        
        if let defaults = UserDefaults(suiteName: AppGroupContract.suiteName),
           let snapshotData = defaults.data(forKey: "drive_studio_telemetry"),
           let snapshot = try? JSONDecoder().decode(TelemetrySnapshot.self, from: snapshotData) {
            return snapshot.isCharging ?? false
        }
        return false
    }

    private func fetchVehicleName() -> String {
        let state = AppGroupState.loadState()
        return state?.vehicle?.displayName ?? "MY VEHICLE"
    }
}

// MARK: - 1. Orbit Date Widget
struct OrbitDateWidgetView: View {
    let entry: OrbitDateEntry

    private var dayFraction: Double {
        let c = Calendar.current
        let h = Double(c.component(.hour, from: entry.date))
        let m = Double(c.component(.minute, from: entry.date))
        let s = Double(c.component(.second, from: entry.date))
        return (h * 3600 + m * 60 + s) / 86400
    }

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f.string(from: entry.date)
    }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEE · MMM d"
        return f.string(from: entry.date).uppercased()
    }

    var body: some View {
        let bgColor = Color(hex: "05111F")
        
        let content = ZStack {
            bgColor

            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height)
                let cx = geo.size.width / 2
                let cy = geo.size.height / 2
                let trackR = size * 0.40
                let strokeW = size * 0.052

                ZStack {
                    Circle()
                        .stroke(Color(hex: "0C2A45"), lineWidth: strokeW)
                        .frame(width: trackR * 2, height: trackR * 2)
                        .position(x: cx, y: cy)

                    Circle()
                        .trim(from: 0, to: CGFloat(dayFraction))
                        .stroke(
                            AngularGradient(
                                colors: [Color(hex: "185FA5"), Color(hex: "378ADD"), Color(hex: "00C8FF")],
                                center: .center,
                                startAngle: .degrees(-90),
                                endAngle: .degrees(270)
                            ),
                            style: StrokeStyle(lineWidth: strokeW, lineCap: .round)
                        )
                        .frame(width: trackR * 2, height: trackR * 2)
                        .rotationEffect(.degrees(-90))
                        .position(x: cx, y: cy)

                    Circle()
                        .fill(bgColor)
                        .frame(width: (trackR - strokeW) * 2, height: (trackR - strokeW) * 2)
                        .position(x: cx, y: cy)

                    Text(timeString)
                        .font(.system(size: size * 0.22, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .position(x: cx, y: cy - size * 0.04)

                    Text(dateString)
                        .font(.system(size: size * 0.07, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: "378ADD"))
                        .position(x: cx, y: cy + size * 0.15)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

        if #available(iOS 17.0, *) {
            content.containerBackground(bgColor, for: .widget)
        } else {
            content
        }
    }
}

struct OrbitDateWidget: Widget {
    let kind = "OrbitDateWidget"
    var body: some WidgetConfiguration {
        let config = StaticConfiguration(kind: kind, provider: OrbitDateProvider()) { entry in
            OrbitDateWidgetView(entry: entry)
        }
        .configurationDisplayName("Orbit Date")
        .description("Day progress ring with live clock and date.")
        .supportedFamilies([.systemSmall, .systemMedium])
        
        if #available(iOS 17.0, *) {
            return config.contentMarginsDisabled()
        } else {
            return config
        }
    }
}

// MARK: - 2. Noir Gold Widget
struct NoirGoldWidgetView: View {
    let entry: OrbitDateEntry

    private var timeString: String {
        let f = DateFormatter(); f.dateFormat = "h:mm"; return f.string(from: entry.date)
    }
    private var dayString: String {
        let f = DateFormatter(); f.dateFormat = "EEE  d"; return f.string(from: entry.date).uppercased()
    }

    var body: some View {
        let bgColor = Color(hex: "0A0A0A")
        
        let content = ZStack {
            bgColor

            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "C8902A"), Color(hex: "F0C040"), Color(hex: "A07010"), Color(hex: "F0C040")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2.5
                )
                .padding(6)

            VStack(spacing: 4) {
                Text(timeString)
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundColor(Color(hex: "F0C040"))
                    .minimumScaleFactor(0.5)

                Text("· · · · ·")
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(Color(hex: "8A6A10"))

                Text(dayString)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "C8902A"))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

        if #available(iOS 17.0, *) {
            content.containerBackground(bgColor, for: .widget)
        } else {
            content
        }
    }
}

struct NoirGoldWidget: Widget {
    let kind = "NoirGoldWidget"
    var body: some WidgetConfiguration {
        let config = StaticConfiguration(kind: kind, provider: OrbitDateProvider()) { entry in
            NoirGoldWidgetView(entry: entry)
        }
        .configurationDisplayName("Noir Gold")
        .description("Black canvas with gold border frame and clock.")
        .supportedFamilies([.systemSmall, .systemMedium])
        
        if #available(iOS 17.0, *) {
            return config.contentMarginsDisabled()
        } else {
            return config
        }
    }
}

// MARK: - 3. Segments Widget
struct SegmentsWidgetView: View {
    let entry: OrbitDateEntry

    private var hourFraction: Double {
        let c = Calendar.current
        let h = Double(c.component(.hour, from: entry.date)).truncatingRemainder(dividingBy: 12)
        let m = Double(c.component(.minute, from: entry.date))
        return (h + m / 60) / 12
    }
    private var minuteFraction: Double {
        let c = Calendar.current
        let m = Double(c.component(.minute, from: entry.date))
        let s = Double(c.component(.second, from: entry.date))
        return (m + s / 60) / 60
    }
    private var timeString: String {
        let f = DateFormatter(); f.dateFormat = "h:mm"; return f.string(from: entry.date)
    }
    private var dateString: String {
        let f = DateFormatter(); f.dateFormat = "EEE MMM d"; return f.string(from: entry.date).uppercased()
    }

    var body: some View {
        let bgColor = Color(hex: "040D18")
        
        let content = ZStack {
            bgColor

            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height)
                let cx = geo.size.width / 2
                let cy = geo.size.height / 2
                let outerR = size * 0.44
                let innerR = size * 0.34
                let sw = size * 0.045

                ZStack {
                    ForEach(0..<60, id: \.self) { i in
                        let angle = Double(i) / 60.0 * 360.0 - 90
                        let isHour = i % 5 == 0
                        let len: Double = isHour ? 10 : 5
                        let r1 = outerR - CGFloat(len)
                        let r2 = outerR
                        let rad = angle * .pi / 180
                        Path { p in
                            p.move(to: CGPoint(x: cx + cos(rad) * r1, y: cy + sin(rad) * r1))
                            p.addLine(to: CGPoint(x: cx + cos(rad) * r2, y: cy + sin(rad) * r2))
                        }
                        .stroke(isHour ? Color(hex: "1A5080") : Color(hex: "0C2F50"),
                                lineWidth: isHour ? 2 : 1)
                    }

                    Circle()
                        .trim(from: 0, to: CGFloat(minuteFraction))
                        .stroke(Color(hex: "378ADD"), style: StrokeStyle(lineWidth: sw, lineCap: .round))
                        .frame(width: outerR * 2, height: outerR * 2)
                        .rotationEffect(.degrees(-90))
                        .position(x: cx, y: cy)

                    Circle()
                        .trim(from: 0, to: CGFloat(hourFraction))
                        .stroke(Color(hex: "F59E0B"), style: StrokeStyle(lineWidth: sw, lineCap: .round))
                        .frame(width: innerR * 2, height: innerR * 2)
                        .rotationEffect(.degrees(-90))
                        .position(x: cx, y: cy)

                    Circle()
                        .fill(bgColor)
                        .frame(width: (innerR - sw) * 2, height: (innerR - sw) * 2)
                        .position(x: cx, y: cy)

                    Text(timeString)
                        .font(.system(size: size * 0.20, weight: .black, design: .rounded))
                        .foregroundColor(Color(hex: "DBEAFE"))
                        .position(x: cx, y: cy - size * 0.03)

                    Text(dateString)
                        .font(.system(size: size * 0.065, weight: .medium))
                        .foregroundColor(Color(hex: "F59E0B"))
                        .position(x: cx, y: cy + size * 0.15)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

        if #available(iOS 17.0, *) {
            content.containerBackground(bgColor, for: .widget)
        } else {
            content
        }
    }
}

struct SegmentsWidget: Widget {
    let kind = "SegmentsWidget"
    var body: some WidgetConfiguration {
        let config = StaticConfiguration(kind: kind, provider: OrbitDateProvider()) { entry in
            SegmentsWidgetView(entry: entry)
        }
        .configurationDisplayName("Segments")
        .description("Dual arc rings for hours and minutes with tick marks.")
        .supportedFamilies([.systemSmall, .systemMedium])
        
        if #available(iOS 17.0, *) {
            return config.contentMarginsDisabled()
        } else {
            return config
        }
    }
}

// MARK: - 4. Aurora Ring Widget
struct AuroraRingWidgetView: View {
    let entry: OrbitDateEntry

    private var hourAngle: Angle {
        let c = Calendar.current
        let h = Double(c.component(.hour, from: entry.date)).truncatingRemainder(dividingBy: 12)
        let m = Double(c.component(.minute, from: entry.date))
        return .degrees((h + m / 60) / 12 * 360 - 90)
    }
    private var minuteAngle: Angle {
        let c = Calendar.current
        let m = Double(c.component(.minute, from: entry.date))
        let s = Double(c.component(.second, from: entry.date))
        return .degrees((m + s / 60) / 60 * 360 - 90)
    }
    private var timeString: String {
        let f = DateFormatter(); f.dateFormat = "h:mm"; return f.string(from: entry.date)
    }

    private let auroraColors: [Color] = [
        Color("7C3AED"), Color("9333EA"), Color("EC4899"),
        Color("F97316"), Color("F59E0B"), Color("10B981"),
        Color("06B6D4"), Color("3B82F6")
    ]

    var body: some View {
        let bgColor = Color(hex: "050510")
        
        let content = ZStack {
            bgColor

            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height)
                let cx = geo.size.width / 2
                let cy = geo.size.height / 2
                let outerR = size * 0.44
                let sw: CGFloat = size * 0.052
                let innerR = outerR - sw - 4

                ZStack {
                    Circle()
                        .stroke(Color(hex: "12103A"), lineWidth: sw)
                        .frame(width: outerR * 2, height: outerR * 2)
                        .position(x: cx, y: cy)

                    ForEach(0..<auroraColors.count, id: \.self) { i in
                        let start = Double(i) / Double(auroraColors.count)
                        let end = Double(i + 1) / Double(auroraColors.count)
                        Circle()
                            .trim(from: CGFloat(start), to: CGFloat(end))
                            .stroke(auroraColors[i], style: StrokeStyle(lineWidth: sw, lineCap: .butt))
                            .frame(width: outerR * 2, height: outerR * 2)
                            .rotationEffect(.degrees(-90))
                            .position(x: cx, y: cy)
                    }

                    Circle()
                        .fill(bgColor)
                        .frame(width: innerR * 2, height: innerR * 2)
                        .position(x: cx, y: cy)

                    let hRad = (hourAngle.degrees + 90) * .pi / 180
                    let hLen = innerR * 0.52
                    Path { p in
                        p.move(to: CGPoint(x: cx, y: cy))
                        p.addLine(to: CGPoint(x: cx + cos(hRad) * hLen, y: cy + sin(hRad) * hLen))
                    }
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))

                    let mRad = (minuteAngle.degrees + 90) * .pi / 180
                    let mLen = innerR * 0.78
                    Path { p in
                        p.move(to: CGPoint(x: cx, y: cy))
                        p.addLine(to: CGPoint(x: cx + cos(mRad) * mLen, y: cy + sin(mRad) * mLen))
                    }
                    .stroke(Color(hex: "C084FC"), style: StrokeStyle(lineWidth: 2, lineCap: .round))

                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .position(x: cx, y: cy)
                    Circle()
                        .fill(Color(hex: "7C3AED"))
                        .frame(width: 5, height: 5)
                        .position(x: cx, y: cy)

                    Text(timeString)
                        .font(.system(size: size * 0.08, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: "E9D5FF"))
                        .position(x: cx, y: cy + innerR + sw + 10)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

        if #available(iOS 17.0, *) {
            content.containerBackground(bgColor, for: .widget)
        } else {
            content
        }
    }
}

struct AuroraRingWidget: Widget {
    let kind = "AuroraRingWidget"
    var body: some WidgetConfiguration {
        let config = StaticConfiguration(kind: kind, provider: OrbitDateProvider()) { entry in
            AuroraRingWidgetView(entry: entry)
        }
        .configurationDisplayName("Aurora Ring")
        .description("Rainbow gradient ring with live analog hands.")
        .supportedFamilies([.systemSmall, .systemMedium])
        
        if #available(iOS 17.0, *) {
            return config.contentMarginsDisabled()
        } else {
            return config
        }
    }
}

// MARK: - 5. Battery Pie Widget (Real Live Hardware Battery Level)
struct BatteryPieWidgetView: View {
    let entry: OrbitDateEntry

    private var dateString: String {
        let f = DateFormatter(); f.dateFormat = "EEE, d MMM"; return f.string(from: entry.date)
    }

    var body: some View {
        let bgColor = Color(hex: "100505")
        let realBattery = max(0.05, min(1.0, entry.batteryLevel))
        
        let content = ZStack {
            bgColor

            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height)
                let cx = geo.size.width / 2
                let cy = geo.size.height / 2 - size * 0.04
                let R = size * 0.38

                ZStack {
                    Circle()
                        .fill(Color(hex: "2A0808"))
                        .frame(width: R * 2, height: R * 2)
                        .position(x: cx, y: cy)

                    Path { p in
                        p.move(to: CGPoint(x: cx, y: cy))
                        p.addArc(
                            center: CGPoint(x: cx, y: cy),
                            radius: R,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(-90 + realBattery * 360),
                            clockwise: false
                        )
                        p.closeSubpath()
                    }
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "E24B4A"), Color(hex: "991B1B")],
                            center: .center,
                            startRadius: 0,
                            endRadius: R
                        )
                    )

                    Circle()
                        .fill(bgColor)
                        .frame(width: R * 1.04, height: R * 1.04)
                        .position(x: cx, y: cy)

                    VStack(spacing: 2) {
                        HStack(spacing: 2) {
                            Text("\(Int(realBattery * 100))%")
                                .font(.system(size: size * 0.165, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            if entry.isCharging {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: size * 0.12))
                                    .foregroundColor(Color(hex: "FFD166"))
                            }
                        }
                        
                        Text("BATTERY")
                            .font(.system(size: size * 0.065, weight: .bold))
                            .foregroundColor(Color(hex: "E24B4A"))
                    }
                    .position(x: cx, y: cy + size * 0.02)

                    Text(dateString)
                        .font(.system(size: size * 0.065, weight: .regular))
                        .foregroundColor(Color(hex: "6B2020"))
                        .position(x: cx, y: cy + size * 0.42)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

        if #available(iOS 17.0, *) {
            content.containerBackground(bgColor, for: .widget)
        } else {
            content
        }
    }
}

struct BatteryPieWidget: Widget {
    let kind = "BatteryPieWidget"
    var body: some WidgetConfiguration {
        let config = StaticConfiguration(kind: kind, provider: OrbitDateProvider()) { entry in
            BatteryPieWidgetView(entry: entry)
        }
        .configurationDisplayName("Battery Pie")
        .description("Pie chart showing live battery percentage.")
        .supportedFamilies([.systemSmall, .systemMedium])
        
        if #available(iOS 17.0, *) {
            return config.contentMarginsDisabled()
        } else {
            return config
        }
    }
}

// MARK: - 6. Minimal Date Widget
struct MinimalDateWidgetView: View {
    let entry: OrbitDateEntry

    private var timeString: String {
        let f = DateFormatter(); f.dateFormat = "h:mm"; return f.string(from: entry.date)
    }
    private var dateString: String {
        let f = DateFormatter(); f.dateFormat = "EEE d MMM"; return f.string(from: entry.date)
    }
    private var ampm: String {
        Calendar.current.component(.hour, from: entry.date) < 12 ? "AM" : "PM"
    }

    var body: some View {
        let bgColor = Color(hex: "0D3330")
        
        let content = ZStack {
            bgColor

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: "0A2825"))
                .padding(10)

            VStack(spacing: 0) {
                Spacer()

                Text(timeString)
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)

                Rectangle()
                    .fill(Color(hex: "1D9E75"))
                    .frame(height: 1)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 8)

                Text(dateString)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "4DC98A"))

                Spacer()

                Text(ampm)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(Color(hex: "0F6E56"))
                    .padding(.bottom, 14)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

        if #available(iOS 17.0, *) {
            content.containerBackground(bgColor, for: .widget)
        } else {
            content
        }
    }
}

struct MinimalDateWidget: Widget {
    let kind = "MinimalDateWidget"
    var body: some WidgetConfiguration {
        let config = StaticConfiguration(kind: kind, provider: OrbitDateProvider()) { entry in
            MinimalDateWidgetView(entry: entry)
        }
        .configurationDisplayName("Minimal Date")
        .description("Clean teal dark card with large clock and date.")
        .supportedFamilies([.systemSmall, .systemMedium])
        
        if #available(iOS 17.0, *) {
            return config.contentMarginsDisabled()
        } else {
            return config
        }
    }
}
