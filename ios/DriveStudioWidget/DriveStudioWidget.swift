import WidgetKit
import SwiftUI
import UIKit
import CryptoKit

// MARK: - App Group plumbing

enum AppGroupHelper {
    static let suiteName = "group.com.drivestudio.shared"

    struct Metadata: Codable {
        let schemaVersion: Int
        let generation: String
        let stateFile: String
        let checksum: String
        let updatedAt: String
    }

    static var currentGeneration: String?

    /// iOS-10 fix: cache the parsed `WidgetState` plus the generation it
    /// came from. Each `getTimeline` call otherwise re-reads up to ~10 MB
    /// from disk, hashes it with SHA-256, and re-decodes the JSON — all
    /// on the timeline thread. Subsequent calls for the same generation
    /// return the cached decode instantly. The cache is invalidated
    /// automatically when the generation changes (via the app calling
    /// `syncState` from the host process).
    private static var cachedState: (generation: String, state: WidgetState?)?

    static func loadState() -> WidgetState? {
        // Fast path: if the cached state is still for the same generation
        // we already on disk, return it without re-reading/hashing.
        if let cached = cachedState,
           let metadataData = UserDefaults(suiteName: suiteName)?.data(forKey: "widget_state_v2_metadata"),
           let metadata = try? JSONDecoder().decode(Metadata.self, from: metadataData),
           metadata.generation == cached.generation {
            currentGeneration = metadata.generation
            return cached.state
        }

        guard let defaults = UserDefaults(suiteName: suiteName),
              let metadataData = defaults.data(forKey: "widget_state_v2_metadata"),
              let metadata = try? JSONDecoder().decode(Metadata.self, from: metadataData),
              let sharedURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: suiteName)
        else {
            // V1 fallback
            if let defaults = UserDefaults(suiteName: suiteName),
               let json = defaults.string(forKey: "widget_state_v1"),
               let data = json.data(using: .utf8),
               let state = try? JSONDecoder().decode(WidgetState.self, from: data) {
                cachedState = (generation: "v1", state: state)
                return state
            }
            cachedState = (generation: "", state: nil)
            return nil
        }

        let fileURL = sharedURL.appendingPathComponent(metadata.stateFile)
        guard let data = try? Data(contentsOf: fileURL) else {
            cachedState = (generation: metadata.generation, state: nil)
            currentGeneration = metadata.generation
            return nil
        }
        let actual = SHA256.hash(data: data)
            .compactMap { String(format: "%02x", $0) }
            .joined()
        guard actual == metadata.checksum else {
            cachedState = (generation: metadata.generation, state: nil)
            currentGeneration = metadata.generation
            return nil
        }
        currentGeneration = metadata.generation
        let decoded = try? JSONDecoder().decode(WidgetState.self, from: data)
        cachedState = (generation: metadata.generation, state: decoded)
        return decoded
    }
}

// MARK: - Data models (must match Flutter side)

struct VehicleData: Codable {
    let brandId: String?
    let modelId: String?
    let artwork: String?
    let displayName: String?
    let hasCustomImage: Bool?
    let customImage: String?
}

struct TelemetrySnapshot: Codable {
    let carConnected: Bool
    let batteryPercent: Int?
    let isCharging: Bool
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
    let hidden: Bool?
    let strokes: String?
}

struct WidgetBackground: Codable {
    let type: String?
    let from: String?
    let to: String?
    let imageSrc: String?
}

struct WidgetSpec: Codable {
    let background: WidgetBackground?
    let layers: [WidgetLayer]?
}

struct Slot: Codable {
    let index: Int
    let draftId: String?
    let name: String?
    let summary: [String: String?]?
    let spec: WidgetSpec?
}

struct WidgetState: Codable {
    let schemaVersion: Int?
    let vehicle: VehicleData?
    let slots: [Slot]?
    let telemetry: TelemetrySnapshot?
    /// Optional absolute path to a pre-rendered PNG of the active slot's
    /// design. When present, the widget displays the image directly
    /// (matching the app preview pixel-for-pixel) instead of rendering
    /// individual layers. This is the **simple** path: no fit-to-canvas,
    /// no per-layer asset pipeline, no per-family scaling logic.
    let widgetImagePath: String?
}

// MARK: - Helpers

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8,
              let v = UInt64(s, radix: 16) else { return nil }
        if s.count == 6 {
            self.init(red: Double((v & 0xFF0000) >> 16) / 255,
                      green: Double((v & 0x00FF00) >> 8) / 255,
                      blue:  Double(v & 0x0000FF) / 255)
        } else {
            self.init(red: Double((v & 0x00FF0000) >> 16) / 255,
                      green: Double((v & 0x0000FF00) >> 8) / 255,
                      blue:  Double(v & 0x000000FF) / 255,
                      opacity: Double((v & 0xFF000000) >> 24) / 255)
        }
    }
}

struct DriveStudioImageLoader {
    /// iOS-11 fix: NSCache keyed by the resolved absolute file path so
    /// repeated layer renders within the same generation don't hit the
    /// filesystem each time. NSCache evicts automatically under memory
    /// pressure (the widget process is small). The cache is automatically
    /// cleared when the OS reclaims memory or the process restarts, so
    /// stale entries can never persist across generations.
    private static let imageCache = NSCache<NSString, UIImage>()

    /// iOS-9 + iOS-11 fix: prefer the per-call generation (snapshotted
    /// on the `SimpleEntry`) so concurrent timelines see a stable value.
    static func load(from src: String, generation: String? = nil) -> UIImage? {
        // Build a stable cache key from the absolute file path we're
        // about to load so different paths don't collide.
        var cacheKey: NSString?
        if src.hasPrefix("data:image") {
            // Data URIs are decoded synchronously (no filesystem); they
            // don't benefit from caching because the work is in decode,
            // not file I/O. Skip the cache for these.
            guard let c = src.firstIndex(of: ","),
                  let d = Data(base64Encoded: String(src[src.index(after: c)...])) else { return nil }
            return UIImage(data: d)
        }
        if let shared = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroupHelper.suiteName) {
            var fileURL = shared.appendingPathComponent("SharedImages")
            let gen = generation ?? AppGroupHelper.currentGeneration
            if let g = gen {
                fileURL = fileURL.appendingPathComponent("generation_\(g)")
            }
            fileURL = fileURL.appendingPathComponent(src)
            cacheKey = fileURL.path as NSString
            if let cached = imageCache.object(forKey: cacheKey!) { return cached }
            if let img = UIImage(contentsOfFile: fileURL.path) {
                if let key = cacheKey { imageCache.setObject(img, forKey: key) }
                return img
            }
        }
        // Fallback: absolute path passed straight in (e.g. custom image).
        let fallbackKey = src as NSString
        if let cached = imageCache.object(forKey: fallbackKey) { return cached }
        if let img = UIImage(contentsOfFile: src) {
            imageCache.setObject(img, forKey: fallbackKey)
            return img
        }
        return nil
    }
}

// MARK: - Widget

/// iOS-2 fix: `.containerBackground(for: .widget)` is iOS 17+. The widget
/// extension's deployment target is iOS 16, so calling it on iOS 16 would
/// crash. We conditionally apply it and rely on the entry view's own
/// ZStack `BackgroundView` for the iOS 16 fallback path.
@available(iOS 16.0, *)
extension View {
    @ViewBuilder
    func widgetContainerBackground(spec: WidgetSpec?) -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(for: .widget) {
                BackgroundView(spec: spec)
            }
        } else {
            // iOS 16 fallback: the entry view already paints its own
            // background via the leading `BackgroundView` inside its
            // top-level ZStack, so we just return the content untouched.
            self
        }
    }
}

@available(iOS 16.0, *)
struct DriveStudioSlotWidget: Widget {
    let slotIndex: Int

    /// WidgetKit requires each widget to expose a unique `kind` string so
    /// iOS can distinguish them in the widget gallery and persist user
    /// selections across installs. Each slot gets its own kind derived
    /// from the slot index, so all 20 slots show up as separate widgets.
    var kind: String { "DriveStudioSlotWidget-\(slotIndex)" }

    /// The `Widget` protocol requires a parameterless `init()`. Swift
    /// does not synthesize `init()` when any stored property lacks a
    /// default value, so we declare it explicitly. Default slot is 0.
    init() {
        self.slotIndex = 0
    }

    /// Used by the bundle to register each of the 20 slots.
    init(slotIndex: Int) {
        self.slotIndex = slotIndex
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StaticProvider(slotIndex: slotIndex)) { entry in
            DriveStudioWidgetEntryView(entry: entry)
                .widgetContainerBackground(spec: entry.slot?.spec)
        }
        .configurationDisplayName("Drive Studio Slot \(slotIndex + 1)")
        .description("Renders the widget assigned to Slot \(slotIndex + 1).")
        .supportedFamilies(SupportedFamilies.list)
    }
}

enum SupportedFamilies {
    // Lock Screen / CarPlay accessory families render the full SwiftUI tree
    // in tight spaces; small/medium system families render the same complex
    // view at scaled-down sizes that look broken. We restrict supported
    // families to only those where the editor's design fits cleanly:
    //   - .systemLarge (home screen, large canvas)
    //   - .accessoryCircular / .accessoryRectangular / .accessoryInline
    //     (Lock Screen + CarPlay)
    // iOS-5: removed .systemSmall and .systemMedium to avoid broken rendering.
    static let list: [WidgetFamily] = [
        .systemLarge,
        .accessoryCircular, .accessoryRectangular, .accessoryInline,
    ]
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let slotIndex: Int
    var slot: Slot?
    var vehicle: VehicleData?
    var telemetry: TelemetrySnapshot?
    /// Pre-rendered PNG of the design (or nil if not yet rendered).
    var widgetImagePath: String?
    /// iOS-9 fix: this generation's identifier is now carried per-entry
    /// (snapshotted in `makeEntry`) instead of being mutated on a shared
    /// static var. This removes the data race when `getSnapshot` and
    /// `getTimeline` (or two concurrent timelines) read `currentGeneration`
    /// while another call is rewriting it.
    var generation: String?
}

struct StaticProvider: TimelineProvider {
    let slotIndex: Int

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), slotIndex: slotIndex, slot: nil, vehicle: nil, telemetry: nil, generation: nil)
    }
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(makeEntry(slotIndex: slotIndex))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let entry = makeEntry(slotIndex: slotIndex)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    /// Shared entry builder so `getSnapshot` and `getTimeline` always carry
    /// the same fields (including `widgetImagePath` and `generation`).
    /// Without this, the widget gallery preview shows the pre-rendered PNG
    /// while the live widget falls back to layered rendering. iOS-9 fix:
    /// the active generation is captured here and passed on the entry,
    /// so downstream renderers see a consistent snapshot instead of a
    /// shared mutable static.
    private func makeEntry(slotIndex: Int) -> SimpleEntry {
        let state = AppGroupHelper.loadState()
        let slot = state?.slots?.first(where: { $0.index == slotIndex })
        return SimpleEntry(
            date: Date(),
            slotIndex: slotIndex,
            slot: slot,
            vehicle: state?.vehicle,
            telemetry: state?.telemetry,
            widgetImagePath: state?.widgetImagePath,
            generation: AppGroupHelper.currentGeneration
        )
    }
}

// MARK: - Entry view — renders user design fit-to-canvas

@available(iOS 16.0, *)
struct DriveStudioWidgetEntryView: View {
    let entry: SimpleEntry

    var body: some View {
        GeometryReader { geo in
            ZStack {
                BackgroundView(spec: entry.slot?.spec)
                if let imgPath = entry.widgetImagePath,
                   let img = UIImage(contentsOfFile: imgPath) {
                    // Hybrid rendering: Flutter app pre-rendered the
                    // static parts of the design to this PNG (background,
                    // images, fixed text, shapes). The widget displays it
                    // as a base layer and overlays live data (clock,
                    // battery, analog, date) on top using the spec's
                    // layer positions + telemetry from the App Group.
                    // This gives pixel-perfect static parts + auto-
                    // updating live data.
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                    LiveDataOverlayView(
                        spec: entry.slot?.spec,
                        canvasSize: geo.size,
                        telemetry: entry.telemetry,
                        vehicle: entry.vehicle
                    )
                } else if let spec = entry.slot?.spec, let layers = spec.layers, !layers.isEmpty {
                    FitToCanvasLayers(
                        layers: layers,
                        canvasSize: geo.size,
                        telemetry: entry.telemetry,
                        vehicle: entry.vehicle
                    )
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: max(14, geo.size.width * 0.15)))
                            .foregroundColor(.gray)
                        Text("Slot \(entry.slotIndex + 1)")
                            .font(.system(size: max(9, geo.size.width * 0.08), weight: .semibold, design: .rounded))
                            .foregroundColor(.gray)
                    }
                    .multilineTextAlignment(.center)
                }
            }
        }
    }
}

/// Overlays live data (clock / battery / analog / date) on top of the
/// pre-rendered PNG base. The PNG already contains the static design
/// (background, images, fixed text, shapes); this view only renders the
/// dynamic layers so they update with telemetry.
@available(iOS 16.0, *)
struct LiveDataOverlayView: View {
    let spec: WidgetSpec?
    let canvasSize: CGSize
    let telemetry: TelemetrySnapshot?
    let vehicle: VehicleData?

    private static let designSize = CGSize(width: 338, height: 354)

    var body: some View {
        let liveLayers: [WidgetLayer] = (spec?.layers ?? []).filter(Self.isLive)
        if !liveLayers.isEmpty {
            // The PNG was rendered with hideLiveLayers: true, which used
            // the same coordinates we use here. So the overlay lines up
            // pixel-for-pixel with the PNG.
            ZStack {
                ForEach(liveLayers) { layer in
                    ScaledLayerView(
                        layer: layer,
                        canvasSize: canvasSize,
                        telemetry: telemetry,
                        vehicle: vehicle,
                        transform: LiveDataOverlayView.fitTransform(for: canvasSize)
                    )
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
        }
    }

    private static func isLive(_ layer: WidgetLayer) -> Bool {
        switch layer.kind {
        case "clock", "date", "battery", "analog":
            return true
        default:
            return false
        }
    }

    private static func fitTransform(for canvas: CGSize) -> CGAffineTransform {
        let design = designSize
        let scale = min(canvas.width / design.width, canvas.height / design.height)
        let scaledW = design.width * scale
        let scaledH = design.height * scale
        let offsetX = (canvas.width - scaledW) / 2
        let offsetY = (canvas.height - scaledH) / 2
        return CGAffineTransform.identity
            .translatedBy(x: offsetX, y: offsetY)
            .scaledBy(x: scale, y: scale)
    }
}

/// Renders the editor's free-form draw strokes as SwiftUI Canvas paths.
/// Strokes are stored as a JSON-encoded list of point arrays in 0-100
/// percent design space (see `Layer.strokes` in the Dart editor).
struct DrawStrokesCanvas: View {
    let strokesJSON: String?
    let color: Color
    let opacity: Double

    var body: some View {
        Canvas { context, size in
            guard let json = strokesJSON,
                  let data = json.data(using: .utf8),
                  let strokes = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            else { return }
            let designSize: CGFloat = 100
            for stroke in strokes {
                guard let points = stroke["points"] as? [[String: Any]],
                      !points.isEmpty else { continue }
                var path = Path()
                for (i, p) in points.enumerated() {
                    let x = (p["x"] as? Double ?? 0) / Double(designSize) * Double(size.width)
                    let y = (p["y"] as? Double ?? 0) / Double(designSize) * Double(size.height)
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                let width = (stroke["width"] as? Double ?? 2) * (size.width / 180)
                context.stroke(path, with: .color(color.opacity(opacity)),
                               style: StrokeStyle(lineWidth: max(CGFloat(width), 0.5), lineCap: .round, lineJoin: .round))
            }
        }
    }
}

struct BackgroundView: View {
    let spec: WidgetSpec?
    var body: some View {
        if let bg = spec?.background {
            if let img = bg.imageSrc.flatMap({ DriveStudioImageLoader.load(from: $0) }) {
                Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
            } else if let fromHex = bg.from.flatMap({ Color(hex: $0) }) {
                let toColor = bg.to.flatMap { Color(hex: $0) } ?? fromHex
                LinearGradient(colors: [fromHex, toColor], startPoint: .topLeading, endPoint: .bottomTrailing)
            } else {
                Color.black
            }
        } else {
            Color.black
        }
    }
}

// MARK: - Fit-to-canvas scaling

struct FitToCanvasLayers: View {
    let layers: [WidgetLayer]
    let canvasSize: CGSize
    let telemetry: TelemetrySnapshot?
    let vehicle: VehicleData?

    /// Reference design canvas that the editor uses for x/y/w/h percentages.
    private static let designSize = CGSize(width: 338, height: 354)

    var body: some View {
        let transform = Self.computeFitTransform(for: canvasSize)
        ZStack {
            ForEach(layers) { layer in
                if layer.hidden != true {
                    ScaledLayerView(
                        layer: layer,
                        canvasSize: canvasSize,
                        telemetry: telemetry,
                        vehicle: vehicle,
                        transform: transform
                    )
                }
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }

    private static func computeFitTransform(for canvas: CGSize) -> CGAffineTransform {
        let design = Self.designSize
        let scale = min(canvas.width / design.width, canvas.height / design.height)
        let scaledW = design.width * scale
        let scaledH = design.height * scale
        let offsetX = (canvas.width - scaledW) / 2
        let offsetY = (canvas.height - scaledH) / 2
        return CGAffineTransform.identity
            .translatedBy(x: offsetX, y: offsetY)
            .scaledBy(x: scale, y: scale)
    }
}

struct ScaledLayerView: View {
    let layer: WidgetLayer
    let canvasSize: CGSize
    let telemetry: TelemetrySnapshot?
    let vehicle: VehicleData?
    let transform: CGAffineTransform

    private static let designSize = CGSize(width: 338, height: 354)

    var body: some View {
        let design = Self.designSize
        let x = (layer.x ?? 0) / 100 * design.width
        let y = (layer.y ?? 0) / 100 * design.height
        let w = (layer.w ?? 100) / 100 * design.width
        let h = (layer.h ?? 100) / 100 * design.height
        let rect = CGRect(x: x, y: y, width: w, height: h).applying(transform)
        let fontSize = (layer.fontSize ?? 14) * (canvasSize.width / 180)
        let layerColor = Color(hex: layer.color ?? "#FFFFFF") ?? .white
        let opacityVal = layer.opacity ?? 1
        Group {
            switch layer.kind {
            case "text":
                let text = layer.text?.isEmpty == false ? layer.text! : (layer.label ?? " ")
                Text(text)
                    .font(.system(size: fontSize, weight: weight(for: layer.weight ?? 400), design: .rounded))
                    .foregroundColor(Color(hex: layer.color ?? "#FFFFFF") ?? .white)
            case "clock":
                Text(Date(), style: .time)
                    .font(.system(size: fontSize, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(hex: layer.color ?? "#FFFFFF") ?? .white)
            case "date":
                Text(Date(), style: .date)
                    .font(.system(size: fontSize, weight: .regular))
                    .foregroundColor(Color(hex: layer.color ?? "#FFFFFF") ?? .white)
            case "battery":
                HStack(spacing: max(2, fontSize * 0.2)) {
                    Image(systemName: ScaledLayerView.batterySymbolName(
                        percent: telemetry?.batteryPercent,
                        isCharging: telemetry?.isCharging == true
                    ))
                    if let level = telemetry?.batteryPercent {
                        Text("\(level)%")
                    } else {
                        Text("—")
                    }
                }
                .font(.system(size: fontSize, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(hex: layer.color ?? "#FFFFFF") ?? .white)
            case "shape":
                let r = (layer.radius ?? 0) * (canvasSize.width / 180)
                let color = Color(hex: layer.color ?? "#FFFFFF")?.opacity(layer.opacity ?? 1) ?? .white
                if (layer.radius ?? 0) >= 50 {
                    Circle().fill(color)
                } else {
                    RoundedRectangle(cornerRadius: r).fill(color)
                }
            case "image":
                let src = layer.src ?? ""
                if !src.isEmpty, let img = DriveStudioImageLoader.load(from: src) {
                    Image(uiImage: img).resizable().aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "photo.badge.exclamationmark").foregroundColor(.gray)
                }
            case "divider":
                // Divider is rendered as a thin horizontal line (matches
                // the Flutter editor: height = h/6, clamped to 1–4pt). The
                // layer's h field represents the row height, not the
                // divider's visual thickness.
                let thickness = max(1, min(4, (layer.h ?? 0) / 6))
                Rectangle()
                    .fill(Color(hex: layer.color ?? "#FFFFFF")?.opacity(layer.opacity ?? 1) ?? .white)
                    .frame(height: CGFloat(thickness) * (canvasSize.width / 338))
            case "draw":
                DrawStrokesCanvas(strokesJSON: layer.strokes, color: layerColor, opacity: opacityVal)
            case "analog":
                AnalogClockView(color: layerColor, opacity: opacityVal)
            default:
                EmptyView()
            }
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
    }

    private func weight(for w: Int) -> Font.Weight {
        switch w {
        case 100...300: return .light
        case 400: return .regular
        case 500: return .medium
        case 600: return .semibold
        case 700...900: return .bold
        default: return .regular
        }
    }

    /// Maps the current battery percentage to the matching SF Symbol
    /// so the icon reflects the actual charge level rather than always
    /// showing 100%. Falls back to `battery.100` when no telemetry is
    /// available so the widget still has a sensible empty-state icon.
    /// iOS-6 fix.
    static func batterySymbolName(percent: Int?, isCharging: Bool) -> String {
        let base: String
        if let p = percent {
            switch p {
            case 0: base = "battery.0"
            case 1...24: base = "battery.25"
            case 25...49: base = "battery.25"
            case 50...74: base = "battery.50"
            case 75...94: base = "battery.75"
            default: base = "battery.100" // 95...100
            }
        } else {
            base = "battery.100"
        }
        return isCharging ? "\(base).bolt" : base
    }
}

/// Renders a live analog clock face for `kind == "analog"` layers.
/// Uses SwiftUI Canvas driven by `Date()` so the widget auto-refreshes
/// the hands via the system timeline; the editor's pre-rendered PNG
/// stays static underneath this overlay. iOS-7 fix.
struct AnalogClockView: View {
    let color: Color
    let opacity: Double

    var body: some View {
        Canvas { context, size in
            let now = Date()
            let cal = Calendar.current
            let comps = cal.dateComponents([.hour, .minute, .second], from: now)
            // Pre-existing bug fix: Swift removed `Double % Int`, so compute
            // the modular reduction on the integer hour first, then convert.
            // Behavior is identical to the original `Double(...) % 12`.
            let h = Double((comps.hour ?? 0) % 12)
            let m = Double(comps.minute ?? 0)
            let s = Double(comps.second ?? 0)

            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2
            let strokeColor = GraphicsContext.Shading.color(color.opacity(opacity))
            let baseWidth = max(1, radius * 0.04)

            // Outer ring
            let ringRect = CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            context.stroke(
                Path(ellipseIn: ringRect),
                with: strokeColor,
                style: StrokeStyle(lineWidth: baseWidth)
            )

            // Hour ticks (12 around the face, longer at 12/3/6/9)
            for i in 0..<12 {
                let angle = Double(i) * (.pi / 6) - .pi / 2
                let inner = radius * (i % 3 == 0 ? 0.78 : 0.88)
                let outer = radius * 0.96
                let p1 = CGPoint(
                    x: center.x + cos(angle) * inner,
                    y: center.y + sin(angle) * inner
                )
                let p2 = CGPoint(
                    x: center.x + cos(angle) * outer,
                    y: center.y + sin(angle) * outer
                )
                var path = Path()
                path.move(to: p1)
                path.addLine(to: p2)
                context.stroke(
                    path,
                    with: strokeColor,
                    style: StrokeStyle(lineWidth: baseWidth * (i % 3 == 0 ? 1.4 : 0.7))
                )
            }

            // Hour hand
            let hourAngle = (h + m / 60) * (.pi / 6) - .pi / 2
            drawHand(
                context: context,
                center: center,
                length: radius * 0.55,
                angle: hourAngle,
                width: baseWidth * 2.2,
                color: strokeColor
            )

            // Minute hand
            let minuteAngle = (m + s / 60) * (.pi / 30) - .pi / 2
            drawHand(
                context: context,
                center: center,
                length: radius * 0.82,
                angle: minuteAngle,
                width: baseWidth * 1.4,
                color: strokeColor
            )

            // Second hand (thinner, slightly shorter)
            let secondAngle = s * (.pi / 30) - .pi / 2
            drawHand(
                context: context,
                center: center,
                length: radius * 0.88,
                angle: secondAngle,
                width: max(0.5, baseWidth * 0.6),
                color: strokeColor
            )

            // Center pin
            let pinRect = CGRect(
                x: center.x - baseWidth,
                y: center.y - baseWidth,
                width: baseWidth * 2,
                height: baseWidth * 2
            )
            context.fill(Path(ellipseIn: pinRect), with: strokeColor)
        }
    }

    private func drawHand(
        context: GraphicsContext,
        center: CGPoint,
        length: CGFloat,
        angle: Double,
        width: CGFloat,
        color: GraphicsContext.Shading
    ) {
        let tip = CGPoint(
            x: center.x + cos(angle) * length,
            y: center.y + sin(angle) * length
        )
        var path = Path()
        path.move(to: center)
        path.addLine(to: tip)
        context.stroke(
            path,
            with: color,
            style: StrokeStyle(lineWidth: width, lineCap: .round)
        )
    }
}