import SwiftUI

// ─── PreferenceKey: reports natural (unstretched) size of each text layer ────
struct TextNaturalSizeKey: PreferenceKey {
    static var defaultValue: [Int: CGSize] = [:]
    static func reduce(value: inout [Int: CGSize], nextValue: () -> [Int: CGSize]) {
        value.merge(nextValue()) { _, new in new }
    }
}

struct WidgetCanvas: View {
    @Binding var spec: WidgetSpec
    @Binding var selectedLayerIndex: Int?
    var onInspect: ((Int) -> Void)? = nil

    let logicalSize: CGFloat = 340

    // Actual natural (content) sizes reported by text layers
    @State private var naturalTextSizes: [Int: CGSize] = [:]
    @State private var currentDate = Date()
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    /// Spec with ALL legacy hardcoded placeholder layers auto-upgraded to live kinds.
    /// Applied at render time — gallery, detail sheet, editor, library all get live data
    /// without the user needing to manually edit existing drafts.
    private var liveSpec: WidgetSpec {
        guard var layers = spec.layers else { return spec }
        var changed = false
        for i in layers.indices {
            let layer = layers[i]
            guard layer.kind == "text", let txt = layer.text else { continue }
            let t = txt.trimmingCharacters(in: .whitespaces)

            // ── Battery: "85%", "100 %", "72%" ─────────────────────────────
            let digits = t.hasSuffix("%")
                ? t.dropLast().trimmingCharacters(in: .whitespaces)
                : ""
            if !digits.isEmpty && digits.allSatisfy({ $0.isNumber }) {
                layers[i].kind = "battery"; layers[i].text = nil; changed = true; continue
            }

            // ── Clock: "12:00", "6:12 PM", "23:59", "12:00:00" ─────────────
            let clockRx = #"^\d{1,2}:\d{2}(:\d{2})?(\s*(AM|PM|am|pm))?$"#
            if t.range(of: clockRx, options: .regularExpression) != nil {
                layers[i].kind = "clock"; layers[i].text = nil; changed = true; continue
            }

            // ── Date: "MON 24", "Mon 24 Jan", "Sun", "Monday", "Jan 2025"
            let dateRx = #"(?i)^(mon|tue|wed|thu|fri|sat|sun|monday|tuesday|wednesday|thursday|friday|saturday|sunday)"#
            let monthRx = #"(?i)^(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)"#
            if t.range(of: dateRx, options: .regularExpression) != nil
               || t.range(of: monthRx, options: .regularExpression) != nil {
                layers[i].kind = "date"; layers[i].text = nil; changed = true; continue
            }

            // ── Speed: pure 1–3 digit integer "0" – "999" ──────────────────
            // (Only upgrade if text is ONLY digits — avoids touching labels like "SLOT 1")
            if t.count <= 3 && !t.isEmpty && t.allSatisfy({ $0.isNumber }) {
                layers[i].kind = "speed"; layers[i].text = nil; changed = true; continue
            }

            // ── Vehicle name placeholders ────────────────────────────────────
            let vehicleHints = ["cyber sedan", "my vehicle", "select vehicle",
                                "vehicle name", "car name", "vehicle"]
            if vehicleHints.contains(t.lowercased()) {
                layers[i].kind = "vehicle_name"; layers[i].text = nil; changed = true; continue
            }
        }
        if !changed { return spec }
        var s = spec; s.layers = layers; return s
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)

            ZStack(alignment: .topLeading) {
                // ── Clipped content (bg + layers stay inside the rounded square) ──
                ZStack(alignment: .topLeading) {
                    if let specialView = NativeSpecialRenderer.renderIfSpecial(spec: liveSpec, telemetry: nil, vehicle: nil) {
                        specialView
                            .frame(width: side, height: side)
                    } else {
                        backgroundView
                            .frame(width: side, height: side)

                        // ── Layer rendering — uses liveSpec so old "85%" text auto-shows real battery
                        if let layers = liveSpec.layers {
                        ForEach(layers.indices, id: \.self) { i in
                            let layer = layers[i]
                            let w = (CGFloat(layer.w ?? 50) / 100.0) * side
                            let h = (CGFloat(layer.h ?? 30) / 100.0) * side
                            let x = (CGFloat(layer.x ?? 0) / 100.0) * side
                            let y = (CGFloat(layer.y ?? 0) / 100.0) * side

                            LayerView(layer: layer, canvasSide: side)
                                .frame(width: w, height: h)
                                .position(x: x + w / 2, y: y + h / 2)
                                .allowsHitTesting(false)

                            // Hidden natural-size measurement for text layers
                            if isTextKind(layer.kind) {
                                let scaledFontSize = CGFloat(layer.fontSize ?? 14) * (side / 180.0)
                                Text(resolvedText(for: layer))
                                    .font(.system(size: scaledFontSize, weight: parseWeight(layer.weight)))
                                    .lineLimit(nil)
                                    .fixedSize()
                                    .hidden()
                                    .background(
                                        GeometryReader { tg in
                                            Color.clear.preference(
                                                key: TextNaturalSizeKey.self,
                                                value: [i: tg.size]
                                            )
                                        }
                                    )
                                    .position(x: -9999, y: -9999)
                            }
                        }
                    }
                }
                }
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: 24))

                // ── Interaction overlay — NOT clipped so handles show at edges ──
                LayerEditorOverlay(
                    spec: $spec,
                    selectedLayerIndex: $selectedLayerIndex,
                    onInspect: onInspect,
                    canvasSide: side,
                    naturalTextSizes: naturalTextSizes
                )
            }
            .frame(width: side, height: side)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
            .onPreferenceChange(TextNaturalSizeKey.self) { sizes in
                naturalTextSizes = sizes
            }
            .onReceive(timer) { input in
                currentDate = input
            }
        }
    }

    // ── Helpers ─────────────────────────────────────────────────────────
    private func isTextKind(_ kind: String) -> Bool {
        ["text", "speed", "vehicle_name", "battery_text", "clock"].contains(kind)
    }

    private func resolvedText(for layer: WidgetLayer) -> String {
        switch layer.kind {
        case "clock":
            let formatter = DateFormatter()
            formatter.dateFormat = (layer.format?.isEmpty == false) ? layer.format! : "h:mm"
            return formatter.string(from: currentDate)
        case "date":
            let formatter = DateFormatter()
            formatter.dateFormat = (layer.format?.isEmpty == false) ? layer.format! : "EEE, MMM d"
            return formatter.string(from: currentDate)
        case "speed":
            let spd = Int(TelemetryService.shared.currentSpeed)
            return spd > 0 ? "\(spd)" : "0"
        case "vehicle_name":
            return "Cyber Sedan"
        case "battery", "battery_text":
            UIDevice.current.isBatteryMonitoringEnabled = true
            let level = UIDevice.current.batteryLevel
            let pct = level >= 0 ? Int(level * 100) : 88
            return "\(pct)%"
        default:
            return layer.text ?? ""
        }
    }

    private func parseWeight(_ weight: Int?) -> Font.Weight {
        switch weight {
        case 400: return .regular; case 500: return .medium
        case 600: return .semibold; case 700: return .bold
        case 800: return .heavy;   default:  return .bold
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        if let bg = spec.background {
            if bg.type == "solid", let from = bg.from {
                Color(hex: from)
            } else if bg.type == "gradient", let from = bg.from, let to = bg.to {
                LinearGradient(colors: [Color(hex: from), Color(hex: to)],
                               startPoint: .top, endPoint: .bottom)
            } else if bg.type == "image", let src = bg.imageSrc,
                      let uiImage = loadImage(path: src) {
                Image(uiImage: uiImage).resizable().scaledToFill()
            } else {
                Color(hex: "18181A")
            }
        } else {
            Color(hex: "18181A")
        }
    }

    func loadImage(path: String) -> UIImage? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = docs.appendingPathComponent(path)
        if let data = try? Data(contentsOf: url) { return UIImage(data: data) }
        return nil
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - LayerView
// ─────────────────────────────────────────────────────────────────────────────
struct LayerView: View {
    let layer: WidgetLayer
    var canvasSide: CGFloat = 340

    private var resolvedText: String {
        switch layer.kind {
        // ── Live data ────────────────────────────────────────
        case "battery", "battery_text":
            UIDevice.current.isBatteryMonitoringEnabled = true
            let lvl = UIDevice.current.batteryLevel
            let pct = lvl >= 0 ? Int(lvl * 100) : 0
            let charging = UIDevice.current.batteryState == .charging
                        || UIDevice.current.batteryState == .full
            return charging ? "\(pct)% ⚡" : "\(pct)%"
        case "clock":
            let f = DateFormatter(); f.timeStyle = .short
            return f.string(from: Date())
        case "date":
            let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none
            return f.string(from: Date())
        case "speed":
            return "-- km/h"
        case "vehicle_name":
            return layer.text ?? "My Vehicle"
        case "analog":
            return "🕐 Analog"
        // ── Static text ──────────────────────────────────────
        default:
            return layer.text ?? ""
        }
    }

    @ViewBuilder
    var layerContent: some View {
        let kind = layer.kind
        let scaledFontSize = CGFloat(layer.fontSize ?? 14) * (canvasSide / 180.0)

        if kind == "text" || kind == "speed" || kind == "vehicle_name"
            || kind == "battery" || kind == "battery_text"
            || kind == "clock" || kind == "date" {
            // ── Text / live-data text layers (Line limit 1 + minimum scale to prevent PM cropping) ──
            Text(resolvedText)
                .font(.system(size: scaledFontSize, weight: parseWeight(layer.weight)))
                .foregroundColor(Color(hex: layer.color ?? "FFFFFF") ?? .white)
                .multilineTextAlignment(parseAlignment(layer.align))
                .lineLimit(1)
                .minimumScaleFactor(0.2)
                .frame(maxWidth: .infinity, maxHeight: .infinity,
                       alignment: parseFrameAlignment(layer.align))
        } else if kind == "analog" {
            // ── Analog clock preview ─────────────────────────────────────
            ZStack {
                Circle().stroke(Color(hex: layer.color ?? "FFFFFF") ?? .white, lineWidth: 1.5)
                Text(resolvedText)
                    .font(.system(size: scaledFontSize * 0.35))
                    .foregroundColor(Color(hex: layer.color ?? "FFFFFF") ?? .white)
            }
        } else if kind == "image" {
            // ── Image / Vehicle Position Guide ───────────────────────────
            if let src = layer.src, let uiImage = loadImage(path: src) {
                Image(uiImage: uiImage).resizable().scaledToFit()
            } else {
                // Vehicle Position Guide Box
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                        .foregroundColor(DriveColors.primary.opacity(0.7))
                    
                    VStack(spacing: 2) {
                        Image(systemName: "car.side.fill")
                            .font(.system(size: max(14, scaledFontSize * 0.7), weight: .bold))
                            .foregroundColor(DriveColors.primary)
                        Text("CAR PHOTO")
                            .font(.system(size: max(7, scaledFontSize * 0.28), weight: .bold))
                            .foregroundColor(DriveColors.primary)
                    }
                }
                .padding(2)
            }
        } else if kind == "shape" || kind == "draw" || kind == "divider" {
            // ── Shapes ───────────────────────────────────────────────────
            if layer.label == "circle" || layer.label == "ring" {
                Circle().fill(Color(hex: layer.color ?? "FFFFFF") ?? .white)
            } else if layer.label == "line" || kind == "draw" || kind == "divider" {
                Capsule().fill(Color(hex: layer.color ?? "00FFFF") ?? .cyan)
            } else {
                RoundedRectangle(cornerRadius: CGFloat(layer.radius ?? 4))
                    .fill(Color(hex: layer.color ?? "FFFFFF") ?? .white)
            }
        } else {
            Color.clear
        }
    }

    var body: some View {
        layerContent.opacity(layer.opacity ?? 1.0)
    }

    func parseWeight(_ weight: Int?) -> Font.Weight {
        switch weight {
        case 400: return .regular; case 500: return .medium
        case 600: return .semibold; case 700: return .bold
        case 800: return .heavy;   default:  return .bold
        }
    }

    func parseAlignment(_ align: String?) -> TextAlignment {
        switch align?.lowercased() {
        case "center": return .center
        case "right", "trailing": return .trailing
        default: return .leading
        }
    }

    func parseFrameAlignment(_ align: String?) -> Alignment {
        switch align?.lowercased() {
        case "left", "leading":   return .leading
        case "right", "trailing": return .trailing
        default:                  return .center
        }
    }

    func loadImage(path: String) -> UIImage? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = docs.appendingPathComponent(path)
        if let data = try? Data(contentsOf: url) { return UIImage(data: data) }
        return nil
    }
}
