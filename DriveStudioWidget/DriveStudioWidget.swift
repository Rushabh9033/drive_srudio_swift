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
// Models are now in WidgetModels.swift

// MARK: - Helpers

// Color extension is defined in DriveComponents.swift

struct DriveStudioImageLoader {
    private static let imageCache = NSCache<NSString, UIImage>()

    static func load(from src: String, generation: String? = nil) -> UIImage? {
        if src.hasPrefix("data:image") {
            guard let c = src.firstIndex(of: ","),
                  let d = Data(base64Encoded: String(src[src.index(after: c)...])) else { return nil }
            return UIImage(data: d)
        }

        let cacheKey = src as NSString
        if let cached = imageCache.object(forKey: cacheKey) { return cached }

        // 1. Check Asset Catalog (bundle images)
        if let assetImg = UIImage(named: src) {
            imageCache.setObject(assetImg, forKey: cacheKey)
            return assetImg
        }

        // 2. Check App Group Shared Container (permanent cross-process location)
        if let shared = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroupHelper.suiteName) {
            // Check generation subfolder if snapshot is generation-tracked
            let gen = generation ?? AppGroupHelper.currentGeneration
            if let g = gen {
                let genURL = shared.appendingPathComponent("SharedImages").appendingPathComponent("generation_\(g)").appendingPathComponent(src)
                if let img = UIImage(contentsOfFile: genURL.path) {
                    imageCache.setObject(img, forKey: cacheKey)
                    return img
                }
            }

            // Check SharedImages root
            let sharedImagesURL = shared.appendingPathComponent("SharedImages").appendingPathComponent(src)
            if let img = UIImage(contentsOfFile: sharedImagesURL.path) {
                imageCache.setObject(img, forKey: cacheKey)
                return img
            }

            // Check App Group root
            let appGroupRootURL = shared.appendingPathComponent(src)
            if let img = UIImage(contentsOfFile: appGroupRootURL.path) {
                imageCache.setObject(img, forKey: cacheKey)
                return img
            }
        }

        // 3. Fallback: private Documents directory (when running inside app)
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let docsURL = docs.appendingPathComponent(src)
            if let img = UIImage(contentsOfFile: docsURL.path) {
                imageCache.setObject(img, forKey: cacheKey)
                return img
            }
        }

        // 4. Absolute path
        if let img = UIImage(contentsOfFile: src) {
            imageCache.setObject(img, forKey: cacheKey)
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




struct DriveStudioSlot1Widget: Widget {
    var body: some WidgetConfiguration {
        let config = StaticConfiguration(kind: "CustomWidget", provider: StaticProvider(slotIndex: 0)) { entry in
            DriveStudioWidgetEntryView(entry: entry)
                .widgetContainerBackground(spec: entry.activeSpec)
        }
        .configurationDisplayName("Drive Studio Slot 1")
        .description("Renders the widget assigned to Slot 1.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        
        if #available(iOS 17.0, *) {
            return config.contentMarginsDisabled()
        } else {
            return config
        }
    }
}

struct DriveStudioSlot2Widget: Widget {
    var body: some WidgetConfiguration {
        let config = StaticConfiguration(kind: "CustomWidget2", provider: StaticProvider(slotIndex: 1)) { entry in
            DriveStudioWidgetEntryView(entry: entry)
                .widgetContainerBackground(spec: entry.activeSpec)
        }
        .configurationDisplayName("Drive Studio Slot 2")
        .description("Renders the widget assigned to Slot 2.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        
        if #available(iOS 17.0, *) {
            return config.contentMarginsDisabled()
        } else {
            return config
        }
    }
}

struct DriveStudioSlot3Widget: Widget {
    var body: some WidgetConfiguration {
        let config = StaticConfiguration(kind: "CustomWidget3", provider: StaticProvider(slotIndex: 2)) { entry in
            DriveStudioWidgetEntryView(entry: entry)
                .widgetContainerBackground(spec: entry.activeSpec)
        }
        .configurationDisplayName("Drive Studio Slot 3")
        .description("Renders the widget assigned to Slot 3.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        
        if #available(iOS 17.0, *) {
            return config.contentMarginsDisabled()
        } else {
            return config
        }
    }
}

struct DriveStudioSlot4Widget: Widget {
    var body: some WidgetConfiguration {
        let config = StaticConfiguration(kind: "CustomWidget4", provider: StaticProvider(slotIndex: 3)) { entry in
            DriveStudioWidgetEntryView(entry: entry)
                .widgetContainerBackground(spec: entry.activeSpec)
        }
        .configurationDisplayName("Drive Studio Slot 4")
        .description("Renders the widget assigned to Slot 4.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        
        if #available(iOS 17.0, *) {
            return config.contentMarginsDisabled()
        } else {
            return config
        }
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
        .systemSmall, .systemMedium, .systemLarge,
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
    var generation: String?
    /// True when rendered inside the iOS Widget Gallery.
    var isPreview: Bool = false

    /// Resolves the spec to render.
    var activeSpec: WidgetSpec? {
        return slot?.spec
    }
}

struct StaticProvider: TimelineProvider {
    let slotIndex: Int

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), slotIndex: slotIndex, slot: nil, vehicle: nil, telemetry: nil, generation: nil, isPreview: true)
    }
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(makeEntry(slotIndex: slotIndex, isPreview: context.isPreview))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let entry = makeEntry(slotIndex: slotIndex, isPreview: context.isPreview)
        // Refresh every minute so clock and battery stay current
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 1, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func makeEntry(slotIndex: Int, isPreview: Bool) -> SimpleEntry {
        let state = AppGroupHelper.loadState()
        let slot = state?.slots?.first(where: { $0.index == slotIndex })
        
        var currentTelemetry = state?.telemetry
        if let liveData = UserDefaults(suiteName: AppGroupHelper.suiteName)?.data(forKey: "live_telemetry"),
           let liveTelemetry = try? JSONDecoder().decode(TelemetrySnapshot.self, from: liveData) {
            currentTelemetry = liveTelemetry
        }
        
        // Fetch real device battery
        UIDevice.current.isBatteryMonitoringEnabled = true
        let realBatteryLevel = UIDevice.current.batteryLevel
        let realBatteryState = UIDevice.current.batteryState
        
        if currentTelemetry == nil {
            currentTelemetry = TelemetrySnapshot(carConnected: false, batteryPercent: nil, isCharging: false, speed: nil)
        }
        
        if realBatteryLevel >= 0 {
            currentTelemetry?.batteryPercent = Int(realBatteryLevel * 100)
            currentTelemetry?.isCharging = (realBatteryState == .charging || realBatteryState == .full)
        }
        
        return SimpleEntry(
            date: Date(),
            slotIndex: slotIndex,
            slot: slot,
            vehicle: state?.vehicle,
            telemetry: currentTelemetry,
            widgetImagePath: state?.widgetImagePath,
            generation: AppGroupHelper.currentGeneration,
            isPreview: isPreview
        )
    }
}

// MARK: - Entry view — renders user design fit-to-canvas

@available(iOS 16.0, *)
struct DriveStudioWidgetEntryView: View {
    let entry: SimpleEntry

    var body: some View {
        let content = GeometryReader { geo in
            ZStack {
                let activeSpec = entry.slot?.spec
                
                if let spec = activeSpec, let specialView = NativeSpecialRenderer.renderIfSpecial(spec: spec, telemetry: entry.telemetry, vehicle: entry.vehicle) {
                    specialView
                } else {
                    BackgroundView(spec: activeSpec)
                    
                    if let spec = activeSpec, let rawLayers = spec.layers, !rawLayers.isEmpty {
                        // Auto-migrate legacy hardcoded placeholder layers → live kinds
                        let layers = Self.migrateLayers(rawLayers)
                        FitToCanvasLayers(
                            layers: layers,
                            canvasSize: geo.size,
                            telemetry: entry.telemetry,
                            vehicle: entry.vehicle,
                            entryDate: entry.date
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

        if #available(iOS 17.0, *) {
            content.containerBackground(for: .widget) {
                BackgroundView(spec: entry.slot?.spec)
            }
        } else {
            content
        }
    }

    /// Auto-upgrades legacy hardcoded placeholder text layers to live kinds.
    /// Mirrors the liveSpec logic in WidgetCanvas so the home screen widget
    /// shows real data even for drafts saved before the live-data feature.
    static func migrateLayers(_ layers: [WidgetLayer]) -> [WidgetLayer] {
        var result = layers
        for i in result.indices {
            let layer = result[i]
            guard layer.kind == "text", let txt = layer.text else { continue }
            let t = txt.trimmingCharacters(in: .whitespaces)

            // Battery: "85%", "100%", "72 %"
            let digits = t.hasSuffix("%")
                ? t.dropLast().trimmingCharacters(in: .whitespaces) : ""
            if !digits.isEmpty && digits.allSatisfy({ $0.isNumber }) {
                result[i].kind = "battery"; result[i].text = nil; continue
            }
            // Clock: "12:00", "6:12 PM", "23:59", "12:00:00"
            let clockRx = #"^\d{1,2}:\d{2}(:\d{2})?(\s*(AM|PM|am|pm))?$"#
            if t.range(of: clockRx, options: .regularExpression) != nil {
                result[i].kind = "clock"; result[i].text = nil; continue
            }
            // Date: starts with weekday or month abbreviation
            let dateRx  = #"(?i)^(mon|tue|wed|thu|fri|sat|sun|monday|tuesday|wednesday|thursday|friday|saturday|sunday)"#
            let monthRx = #"(?i)^(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)"#
            if t.range(of: dateRx, options: .regularExpression) != nil
               || t.range(of: monthRx, options: .regularExpression) != nil {
                result[i].kind = "date"; result[i].text = nil; continue
            }
            // Speed: pure 1–3 digit integer
            if t.count <= 3 && !t.isEmpty && t.allSatisfy({ $0.isNumber }) {
                result[i].kind = "speed"; result[i].text = nil; continue
            }
            // Vehicle name placeholders
            let vehicleHints = ["cyber sedan", "my vehicle", "select vehicle",
                                "vehicle name", "car name", "vehicle"]
            if vehicleHints.contains(t.lowercased()) {
                result[i].kind = "vehicle_name"; result[i].text = nil; continue
            }
        }
        return result
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
    var entryDate: Date = Date()

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
                        transform: LiveDataOverlayView.fitTransform(for: canvasSize),
                        entryDate: entryDate
                    )
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
        }
    }

    private static func isLive(_ layer: WidgetLayer) -> Bool {
        switch layer.kind {
        case "clock", "date", "battery", "analog", "speed", "vehicle_name":
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
            } else if let fromHex = bg.from.flatMap({ Color(hexOptional: $0) }) {
                let toColor = bg.to.flatMap { Color(hexOptional: $0) } ?? fromHex
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
    var entryDate: Date = Date()

    /// Reference design canvas (340x340 square 1:1 ratio matching Editor canvas).
    private static let designSize = CGSize(width: 340, height: 340)

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
                        transform: transform,
                        entryDate: entryDate
                    )
                }
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }

    private static func computeFitTransform(for canvas: CGSize) -> CGAffineTransform {
        let scaleX = canvas.width / 340.0
        let scaleY = canvas.height / 340.0
        return CGAffineTransform.identity
            .scaledBy(x: scaleX, y: scaleY)
    }
}

struct ScaledLayerView: View {
    let layer: WidgetLayer
    let canvasSize: CGSize
    let telemetry: TelemetrySnapshot?
    let vehicle: VehicleData?
    let transform: CGAffineTransform
    var entryDate: Date = Date()

    private static let designSize = CGSize(width: 340, height: 340)

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
                    .foregroundColor(layerColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
            case "clock":
                Text(entryDate, style: .time)
                    .font(.system(size: fontSize, weight: .semibold, design: .monospaced))
                    .foregroundColor(layerColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
            case "date":
                Text(entryDate, style: .date)
                    .font(.system(size: fontSize, weight: .regular))
                    .foregroundColor(layerColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
            case "battery", "battery_text":
                // Both kinds show live battery icon + percentage
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
                .foregroundColor(layerColor)
                .lineLimit(1)
                .minimumScaleFactor(0.3)
            case "speed":
                if let speed = telemetry?.speed, telemetry?.isStale == false {
                    let mph = Int(speed * 3.6) // km/h
                    Text("\(mph)")
                        .font(.system(size: fontSize, weight: weight(for: layer.weight ?? 400), design: .rounded))
                        .foregroundColor(layerColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.3)
                } else {
                    Text("--")
                        .font(.system(size: fontSize, weight: weight(for: layer.weight ?? 400), design: .rounded))
                        .foregroundColor(layerColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.3)
                }
            case "vehicle_name":
                Text(vehicle?.displayName ?? "Select Vehicle")
                    .font(.system(size: fontSize, weight: weight(for: layer.weight ?? 400), design: .rounded))
                    .foregroundColor(layerColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
            case "shape":
                let r = (layer.radius ?? 0) * (canvasSize.width / 180)
                let color = Color(hex: layer.color ?? "#FFFFFF").opacity(layer.opacity ?? 1)
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
                    .fill(Color(hex: layer.color ?? "#FFFFFF").opacity(layer.opacity ?? 1))
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

    static func formatDate(_ date: Date, format: String?, isClock: Bool) -> String {
        let formatter = DateFormatter()
        let fmt = format ?? ""
        
        if isClock {
            switch fmt {
            case "h:mm:ss": formatter.dateFormat = "h:mm:ss"
            case "h:mm:ss a": formatter.dateFormat = "h:mm:ss a"
            case "h:mm a": formatter.dateFormat = "h:mm a"
            case "hh", "hour": formatter.dateFormat = "HH"
            case "h12": formatter.dateFormat = "h"
            case "mm", "minute": formatter.dateFormat = "mm"
            case "ss", "second": formatter.dateFormat = "ss"
            case "HH:mm:ss": formatter.dateFormat = "HH:mm:ss"
            case "HH:mm": formatter.dateFormat = "HH:mm"
            case "h:mm": formatter.dateFormat = "h:mm"
            default:
                formatter.timeStyle = .short
                return formatter.string(from: date)
            }
        } else {
            switch fmt {
            case "short": formatter.dateFormat = "MMM d"
            case "medium": formatter.dateFormat = "MMMM d"
            case "full": formatter.dateFormat = "EEEE, MMMM d"
            case "abbrev": formatter.dateFormat = "E d MMM"
            case "day", "daynum": formatter.dateFormat = "d"
            case "weekday": formatter.dateFormat = "EEEE"
            case "weekdayShort": formatter.dateFormat = "E"
            case "month": formatter.dateFormat = "MMM"
            case "monthFull": formatter.dateFormat = "MMMM"
            case "year": formatter.dateFormat = "yyyy"
            case "md": formatter.dateFormat = "M/d"
            default: formatter.dateFormat = "E, d MMM"
            }
        }
        return formatter.string(from: date)
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

import SwiftUI
import WidgetKit

@available(iOS 16.0, *)
enum ApexMockups {
    static func spec(for slotIndex: Int) -> WidgetSpec? {
        let index = slotIndex % specs.count
        let jsonStr = specs[index]
        guard let data = jsonStr.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(WidgetSpec.self, from: data)
    }

    // Auto-generated mockups from Dart
  static let specs: [String] = [
    """
    {\"background\":{\"type\":\"gradient\",\"from\":\"#05080C\",\"to\":\"#101720\"},\"layers\":[{\"id\":\"c09638d1-a977-46ad-812f-3c29853830ed\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":5.0,\"y\":5.0,\"w\":90.0,\"h\":90.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#0D141C\",\"opacity\":1.0,\"radius\":18.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"3c6be3b3-f5a4-4faa-a8fd-12c648637d2b\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":10.0,\"y\":11.0,\"w\":3.0,\"h\":3.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#66D9FF\",\"opacity\":1.0,\"radius\":50.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"2c543b3e-3941-46c8-93ce-e7825388900c\",\"kind\":\"text\",\"label\":\"LOCAL TIME\",\"text\":\"LOCAL TIME\",\"x\":16.0,\"y\":9.0,\"w\":48.0,\"h\":6.0,\"fontSize\":11.0,\"weight\":700,\"align\":\"left\",\"color\":\"#7E8A98\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1},{\"id\":\"e4727f96-317d-4d6c-a56e-a7bea5a1c7ca\",\"kind\":\"text\",\"label\":\"24 HOUR\",\"text\":\"24 HOUR\",\"x\":68.0,\"y\":9.0,\"w\":22.0,\"h\":6.0,\"fontSize\":11.0,\"weight\":700,\"align\":\"right\",\"color\":\"#7E8A98\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1},{\"id\":\"b957caec-16ea-4681-a481-280760d10509\",\"kind\":\"clock\",\"label\":\"Current time\",\"text\":\"\",\"x\":10.0,\"y\":28.0,\"w\":80.0,\"h\":23.0,\"fontSize\":58.0,\"weight\":700,\"align\":\"center\",\"color\":\"#F7F9FC\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1,\"format\":\"24\",\"showSeconds\":false},{\"id\":\"d0f7fb62-b8cb-4ee1-951b-a87b8a7faf52\",\"kind\":\"divider\",\"label\":\"Divider\",\"text\":\"\",\"x\":10.0,\"y\":64.0,\"w\":80.0,\"h\":1.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#26313D\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"74562e10-45c2-437f-baed-07b57a3b5ef5\",\"kind\":\"date\",\"label\":\"Current date\",\"text\":\"\",\"x\":10.0,\"y\":72.0,\"w\":80.0,\"h\":9.0,\"fontSize\":16.0,\"weight\":600,\"align\":\"center\",\"color\":\"#F7F9FC\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1,\"format\":\"abbrev\"},{\"id\":\"2e20928a-6e49-46f1-b3fc-86533fc17069\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":34.0,\"y\":87.0,\"w\":32.0,\"h\":1.5,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#66D9FF\",\"opacity\":1.0,\"radius\":2.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2}]}
    """,
    """
    {\"background\":{\"type\":\"gradient\",\"from\":\"#05080C\",\"to\":\"#101720\"},\"layers\":[{\"id\":\"faa0ba74-912e-4356-8c76-7b9bfcb560a1\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":5.0,\"y\":5.0,\"w\":90.0,\"h\":90.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#0D141C\",\"opacity\":1.0,\"radius\":18.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"a07b80e0-14c8-4524-ba9b-1dedee722aa9\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":8.0,\"y\":8.0,\"w\":5.0,\"h\":5.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#BDA6FF\",\"opacity\":1.0,\"radius\":50.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"b4d05b74-a6a3-441d-a2da-a53eaabf4c47\",\"kind\":\"text\",\"label\":\"TODAY\",\"text\":\"TODAY\",\"x\":16.0,\"y\":8.0,\"w\":32.0,\"h\":6.0,\"fontSize\":11.0,\"weight\":700,\"align\":\"left\",\"color\":\"#BDA6FF\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1},{\"id\":\"d0ea3711-28d5-4d76-b520-bdb1cb797ba5\",\"kind\":\"text\",\"label\":\"CALENDAR\",\"text\":\"CALENDAR\",\"x\":62.0,\"y\":8.0,\"w\":28.0,\"h\":6.0,\"fontSize\":11.0,\"weight\":700,\"align\":\"right\",\"color\":\"#7E8A98\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1},{\"id\":\"e3bc0772-4a2f-479a-be2a-61d9f48118a0\",\"kind\":\"date\",\"label\":\"Current date\",\"text\":\"\",\"x\":9.0,\"y\":29.0,\"w\":82.0,\"h\":18.0,\"fontSize\":28.0,\"weight\":600,\"align\":\"center\",\"color\":\"#F7F9FC\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1,\"format\":\"abbrev\"},{\"id\":\"b4512456-fac0-4f88-a803-d67c5d3a2f33\",\"kind\":\"divider\",\"label\":\"Divider\",\"text\":\"\",\"x\":14.0,\"y\":57.0,\"w\":72.0,\"h\":1.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#302A42\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"97d5b7f2-baa5-4503-a4b8-f13e83371292\",\"kind\":\"text\",\"label\":\"CURRENT TIME\",\"text\":\"CURRENT TIME\",\"x\":10.0,\"y\":67.0,\"w\":35.0,\"h\":6.0,\"fontSize\":11.0,\"weight\":700,\"align\":\"left\",\"color\":\"#7E8A98\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1},{\"id\":\"06031288-f978-46db-b788-fa8d1ab104eb\",\"kind\":\"clock\",\"label\":\"Current time\",\"text\":\"\",\"x\":48.0,\"y\":64.0,\"w\":42.0,\"h\":13.0,\"fontSize\":29.0,\"weight\":700,\"align\":\"right\",\"color\":\"#BDA6FF\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1,\"format\":\"24\",\"showSeconds\":false},{\"id\":\"dbdb785b-3086-4c28-b185-27de38e7e46d\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":10.0,\"y\":86.0,\"w\":80.0,\"h\":1.5,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#BDA6FF\",\"opacity\":1.0,\"radius\":2.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2}]}
    """,
    """
    {\"background\":{\"type\":\"gradient\",\"from\":\"#05080C\",\"to\":\"#101720\"},\"layers\":[{\"id\":\"28106b4f-434c-48ea-bf4a-4d38b7086c85\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":5.0,\"y\":5.0,\"w\":90.0,\"h\":90.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#0D141C\",\"opacity\":1.0,\"radius\":18.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"2110a383-698c-4735-8075-88ac3807cb78\",\"kind\":\"text\",\"label\":\"IPHONE POWER\",\"text\":\"IPHONE POWER\",\"x\":10.0,\"y\":9.0,\"w\":48.0,\"h\":6.0,\"fontSize\":11.0,\"weight\":700,\"align\":\"left\",\"color\":\"#A8FF60\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1},{\"id\":\"73e698c3-d4b1-490e-ae08-056cbd2b1607\",\"kind\":\"text\",\"label\":\"DEVICE\",\"text\":\"DEVICE\",\"x\":68.0,\"y\":9.0,\"w\":22.0,\"h\":6.0,\"fontSize\":11.0,\"weight\":700,\"align\":\"right\",\"color\":\"#7E8A98\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1},{\"id\":\"827c5d7e-c427-4a85-b133-81fdac569100\",\"kind\":\"battery\",\"label\":\"iPhone battery\",\"text\":\"\",\"x\":13.0,\"y\":26.0,\"w\":74.0,\"h\":25.0,\"fontSize\":32.0,\"weight\":700,\"align\":\"center\",\"color\":\"#A8FF60\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2,\"format\":\"minimal\"},{\"id\":\"f9553234-e8ed-444a-91c4-712947483414\",\"kind\":\"divider\",\"label\":\"Divider\",\"text\":\"\",\"x\":10.0,\"y\":62.0,\"w\":80.0,\"h\":1.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#26372B\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"abe89b69-4dd0-444b-81b7-49cc999242dc\",\"kind\":\"text\",\"label\":\"UPDATED BY IPHONE\",\"text\":\"UPDATED BY IPHONE\",\"x\":10.0,\"y\":71.0,\"w\":47.0,\"h\":6.0,\"fontSize\":11.0,\"weight\":700,\"align\":\"left\",\"color\":\"#7E8A98\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1},{\"id\":\"eed645aa-6ed6-422a-8b0b-6259ca6cf59f\",\"kind\":\"date\",\"label\":\"Current date\",\"text\":\"\",\"x\":56.0,\"y\":68.0,\"w\":34.0,\"h\":9.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"right\",\"color\":\"#F7F9FC\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1,\"format\":\"abbrev\"},{\"id\":\"267d0a6c-ccab-4b53-864a-5ddfaec22b05\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":10.0,\"y\":86.0,\"w\":52.0,\"h\":1.5,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#A8FF60\",\"opacity\":1.0,\"radius\":2.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"9edb6107-5bd1-4892-ac5d-03af4b16aaf1\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":64.0,\"y\":86.0,\"w\":26.0,\"h\":1.5,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#24302A\",\"opacity\":1.0,\"radius\":2.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2}]}
    """,
    """
    {\"background\":{\"type\":\"gradient\",\"from\":\"#05080C\",\"to\":\"#101720\"},\"layers\":[{\"id\":\"8e8ea330-67ec-42ed-826d-a87c11e68225\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":5.0,\"y\":5.0,\"w\":90.0,\"h\":90.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#0D141C\",\"opacity\":1.0,\"radius\":18.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"dd247248-a610-4061-bdcf-99c46da09d8e\",\"kind\":\"text\",\"label\":\"DRIVE DECK\",\"text\":\"DRIVE DECK\",\"x\":10.0,\"y\":9.0,\"w\":40.0,\"h\":6.0,\"fontSize\":11.0,\"weight\":700,\"align\":\"left\",\"color\":\"#66D9FF\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1},{\"id\":\"ce4dd18f-56d3-4e42-850a-ad8005738b5d\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":86.0,\"y\":11.0,\"w\":3.0,\"h\":3.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#66D9FF\",\"opacity\":1.0,\"radius\":50.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"c9b898f2-ef00-4c41-900b-4359f9f5e2c4\",\"kind\":\"clock\",\"label\":\"Current time\",\"text\":\"\",\"x\":10.0,\"y\":25.0,\"w\":80.0,\"h\":19.0,\"fontSize\":48.0,\"weight\":700,\"align\":\"center\",\"color\":\"#F7F9FC\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1,\"format\":\"24\",\"showSeconds\":false},{\"id\":\"76c7bac3-c74e-4418-81af-1afb46775a3e\",\"kind\":\"divider\",\"label\":\"Divider\",\"text\":\"\",\"x\":10.0,\"y\":53.0,\"w\":80.0,\"h\":1.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#26313D\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"d6533e8d-4d0e-4684-8cfe-5c874d2f934b\",\"kind\":\"text\",\"label\":\"PHONE\",\"text\":\"PHONE\",\"x\":10.0,\"y\":62.0,\"w\":20.0,\"h\":6.0,\"fontSize\":11.0,\"weight\":700,\"align\":\"left\",\"color\":\"#7E8A98\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1},{\"id\":\"07008b3a-fcf9-47c9-80fe-a95b996d50e1\",\"kind\":\"battery\",\"label\":\"iPhone battery\",\"text\":\"\",\"x\":10.0,\"y\":69.0,\"w\":38.0,\"h\":12.0,\"fontSize\":18.0,\"weight\":700,\"align\":\"center\",\"color\":\"#66D9FF\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2,\"format\":\"minimal\"},{\"id\":\"c9bc5451-46a9-4116-864a-f6895fc359fc\",\"kind\":\"text\",\"label\":\"DATE\",\"text\":\"DATE\",\"x\":55.0,\"y\":62.0,\"w\":35.0,\"h\":6.0,\"fontSize\":11.0,\"weight\":700,\"align\":\"right\",\"color\":\"#7E8A98\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1},{\"id\":\"d3f1dfb6-ec59-4ebd-b1c3-bd3b574c3da4\",\"kind\":\"date\",\"label\":\"Current date\",\"text\":\"\",\"x\":50.0,\"y\":70.0,\"w\":40.0,\"h\":10.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"right\",\"color\":\"#F7F9FC\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1,\"format\":\"abbrev\"},{\"id\":\"a4b0b6fd-6b21-4da7-8e0a-df15aca159a7\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":10.0,\"y\":88.0,\"w\":80.0,\"h\":1.5,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#66D9FF\",\"opacity\":1.0,\"radius\":2.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2}]}
    """,
    """
    {\"background\":{\"type\":\"gradient\",\"from\":\"#07090C\",\"to\":\"#0B0F14\"},\"layers\":[{\"id\":\"7f880fd2-8f20-48c3-a573-d173500be5c8\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":8.0,\"y\":8.0,\"w\":84.0,\"h\":84.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#090D12\",\"opacity\":1.0,\"radius\":18.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"9c13ded3-8bef-41d6-a55e-bade47bade39\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":10.0,\"y\":10.0,\"w\":18.0,\"h\":1.5,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#66D9FF\",\"opacity\":1.0,\"radius\":2.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"c19f0c39-a028-4f0c-b7a1-69f4f18b0237\",\"kind\":\"clock\",\"label\":\"Current time\",\"text\":\"\",\"x\":9.0,\"y\":31.0,\"w\":82.0,\"h\":23.0,\"fontSize\":60.0,\"weight\":700,\"align\":\"center\",\"color\":\"#F7F9FC\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1,\"format\":\"24\",\"showSeconds\":false},{\"id\":\"d8fb2c51-0dd1-4122-ba3a-4332e89cdd95\",\"kind\":\"date\",\"label\":\"Current date\",\"text\":\"\",\"x\":16.0,\"y\":68.0,\"w\":68.0,\"h\":9.0,\"fontSize\":15.0,\"weight\":600,\"align\":\"center\",\"color\":\"#7E8A98\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1,\"format\":\"abbrev\"},{\"id\":\"1857cad8-778e-41eb-9a79-890a442c9eba\",\"kind\":\"text\",\"label\":\"APEX\",\"text\":\"APEX\",\"x\":36.0,\"y\":84.0,\"w\":28.0,\"h\":6.0,\"fontSize\":11.0,\"weight\":700,\"align\":\"center\",\"color\":\"#7E8A98\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1}]}
    """,
    """
    {\"background\":{\"type\":\"gradient\",\"from\":\"#05080C\",\"to\":\"#101720\"},\"layers\":[{\"id\":\"9ae869bc-2b5e-435c-9c64-a9b499ae15e7\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":5.0,\"y\":5.0,\"w\":90.0,\"h\":90.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#0D141C\",\"opacity\":1.0,\"radius\":18.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"e72dcbee-453e-470d-9678-928d9a7d77a6\",\"kind\":\"text\",\"label\":\"TIME\",\"text\":\"TIME\",\"x\":10.0,\"y\":9.0,\"w\":35.0,\"h\":6.0,\"fontSize\":11.0,\"weight\":700,\"align\":\"left\",\"color\":\"#FFB55C\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1},{\"id\":\"407d792d-c084-4a9d-b055-7b86eae91bdb\",\"kind\":\"text\",\"label\":\"POWER\",\"text\":\"POWER\",\"x\":55.0,\"y\":9.0,\"w\":35.0,\"h\":6.0,\"fontSize\":11.0,\"weight\":700,\"align\":\"left\",\"color\":\"#FFB55C\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1},{\"id\":\"fb3a6e5b-22fe-4e39-9ede-6c8a2efefdf5\",\"kind\":\"divider\",\"label\":\"Divider\",\"text\":\"\",\"x\":49.7,\"y\":19.0,\"w\":0.6,\"h\":62.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#3A3025\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"7bf18e9c-0692-4dbf-83b7-b66ba34772be\",\"kind\":\"clock\",\"label\":\"Current time\",\"text\":\"\",\"x\":8.0,\"y\":31.0,\"w\":38.0,\"h\":18.0,\"fontSize\":33.0,\"weight\":700,\"align\":\"center\",\"color\":\"#F7F9FC\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1,\"format\":\"24\",\"showSeconds\":false},{\"id\":\"ded5b7e9-4662-4c32-88ee-0e35b5e13021\",\"kind\":\"battery\",\"label\":\"iPhone battery\",\"text\":\"\",\"x\":54.0,\"y\":31.0,\"w\":38.0,\"h\":18.0,\"fontSize\":24.0,\"weight\":700,\"align\":\"center\",\"color\":\"#FFB55C\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2,\"format\":\"minimal\"},{\"id\":\"6a024f00-9380-42fe-ba85-6976501c2495\",\"kind\":\"date\",\"label\":\"Current date\",\"text\":\"\",\"x\":12.0,\"y\":69.0,\"w\":76.0,\"h\":9.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"center\",\"color\":\"#7E8A98\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1,\"format\":\"abbrev\"},{\"id\":\"59785f78-2bed-4294-aebd-e8b5d3179802\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":10.0,\"y\":87.0,\"w\":35.0,\"h\":1.5,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#FFB55C\",\"opacity\":1.0,\"radius\":2.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"6be93eed-1fff-4321-a026-b102c43dd904\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":55.0,\"y\":87.0,\"w\":35.0,\"h\":1.5,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#3A3025\",\"opacity\":1.0,\"radius\":2.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2}]}
    """,
    """
    {\"background\":{\"type\":\"gradient\",\"from\":\"#05080C\",\"to\":\"#101720\"},\"layers\":[{\"id\":\"84a780ee-a180-4cb8-a929-3cb7ab1e4a7c\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":5.0,\"y\":5.0,\"w\":90.0,\"h\":90.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#0D141C\",\"opacity\":1.0,\"radius\":18.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"61f91a97-6c78-4677-a826-2ade58ceb24b\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":23.0,\"y\":18.0,\"w\":54.0,\"h\":54.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#172019\",\"opacity\":1.0,\"radius\":50.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"ba514fc2-43e0-41fc-994a-29b4491ba7af\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":29.0,\"y\":24.0,\"w\":42.0,\"h\":42.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#0D141C\",\"opacity\":1.0,\"radius\":50.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"6b2f3f3f-8410-46eb-b60e-fb5f0c7681c8\",\"kind\":\"battery\",\"label\":\"iPhone battery\",\"text\":\"\",\"x\":31.0,\"y\":37.0,\"w\":38.0,\"h\":14.0,\"fontSize\":22.0,\"weight\":700,\"align\":\"center\",\"color\":\"#A8FF60\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2,\"format\":\"minimal\"},{\"id\":\"c38f7b97-a94d-4402-8034-3dba9a4e4f70\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":48.0,\"y\":14.0,\"w\":4.0,\"h\":4.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#A8FF60\",\"opacity\":1.0,\"radius\":50.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"c6fbaba0-7d0e-4716-9e4d-2b96eb2f3031\",\"kind\":\"text\",\"label\":\"PHONE ENERGY\",\"text\":\"PHONE ENERGY\",\"x\":25.0,\"y\":76.0,\"w\":50.0,\"h\":6.0,\"fontSize\":11.0,\"weight\":700,\"align\":\"center\",\"color\":\"#A8FF60\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1},{\"id\":\"9ebbbd34-e9ac-4ac6-a843-077c406d77cc\",\"kind\":\"clock\",\"label\":\"Current time\",\"text\":\"\",\"x\":30.0,\"y\":84.0,\"w\":40.0,\"h\":8.0,\"fontSize\":15.0,\"weight\":700,\"align\":\"center\",\"color\":\"#F7F9FC\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1,\"format\":\"24\",\"showSeconds\":false}]}
    """,
    """
    {\"background\":{\"type\":\"gradient\",\"from\":\"#07070C\",\"to\":\"#141020\"},\"layers\":[{\"id\":\"3dcdf3d6-6743-4183-87ad-766b47caf4d4\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":6.0,\"y\":6.0,\"w\":88.0,\"h\":88.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#0C0B13\",\"opacity\":1.0,\"radius\":20.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"a97a5fbd-3343-4114-9d2e-975ebcba900e\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":8.0,\"y\":8.0,\"w\":2.0,\"h\":84.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#BDA6FF\",\"opacity\":1.0,\"radius\":2.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"4d572b36-a1ec-4f11-87bc-b131a15d95c2\",\"kind\":\"text\",\"label\":\"NIGHTLINE\",\"text\":\"NIGHTLINE\",\"x\":15.0,\"y\":10.0,\"w\":44.0,\"h\":6.0,\"fontSize\":11.0,\"weight\":700,\"align\":\"left\",\"color\":\"#BDA6FF\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1},{\"id\":\"c75be7dc-08c2-445e-b527-0f0f6133b88f\",\"kind\":\"clock\",\"label\":\"Current time\",\"text\":\"\",\"x\":15.0,\"y\":29.0,\"w\":75.0,\"h\":23.0,\"fontSize\":56.0,\"weight\":700,\"align\":\"center\",\"color\":\"#F7F9FC\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1,\"format\":\"24\",\"showSeconds\":false},{\"id\":\"af006cee-0bd3-4e95-a55f-2aeb66dbb544\",\"kind\":\"divider\",\"label\":\"Divider\",\"text\":\"\",\"x\":15.0,\"y\":63.0,\"w\":75.0,\"h\":1.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#322A43\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"78d37d8f-7839-491b-9ad9-e3881e6f91a7\",\"kind\":\"date\",\"label\":\"Current date\",\"text\":\"\",\"x\":15.0,\"y\":72.0,\"w\":75.0,\"h\":9.0,\"fontSize\":15.0,\"weight\":600,\"align\":\"left\",\"color\":\"#F7F9FC\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1,\"format\":\"abbrev\"},{\"id\":\"edf5be0f-46e0-4930-9ad5-86bb0a9bcb20\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":85.0,\"y\":84.0,\"w\":3.0,\"h\":3.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#BDA6FF\",\"opacity\":1.0,\"radius\":50.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2}]}
    """,
    """
    {\"background\":{\"type\":\"gradient\",\"from\":\"#05080C\",\"to\":\"#101720\"},\"layers\":[{\"id\":\"d23a8561-5f3c-4bed-a4aa-3836d9deb47e\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":5.0,\"y\":5.0,\"w\":90.0,\"h\":90.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#0D141C\",\"opacity\":1.0,\"radius\":18.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"a93591c4-045c-40a1-9b69-7873e9113c2b\",\"kind\":\"text\",\"label\":\"DATE FOCUS\",\"text\":\"DATE FOCUS\",\"x\":10.0,\"y\":9.0,\"w\":40.0,\"h\":6.0,\"fontSize\":11.0,\"weight\":700,\"align\":\"left\",\"color\":\"#BDA6FF\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1},{\"id\":\"1e01ddfd-46d8-43a8-9188-b4ecd4e6b92d\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":65.0,\"y\":11.0,\"w\":25.0,\"h\":1.5,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#BDA6FF\",\"opacity\":1.0,\"radius\":2.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"b13817be-26e1-4bdb-8cd4-c15117202c0f\",\"kind\":\"date\",\"label\":\"Current date\",\"text\":\"\",\"x\":9.0,\"y\":30.0,\"w\":82.0,\"h\":18.0,\"fontSize\":29.0,\"weight\":600,\"align\":\"center\",\"color\":\"#F7F9FC\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1,\"format\":\"abbrev\"},{\"id\":\"8b92d9f1-77fd-4160-942b-8855a9c9d178\",\"kind\":\"divider\",\"label\":\"Divider\",\"text\":\"\",\"x\":10.0,\"y\":59.0,\"w\":80.0,\"h\":1.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#26313D\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"2122497d-1a77-4439-879f-50d523a6d909\",\"kind\":\"text\",\"label\":\"LOCAL\",\"text\":\"LOCAL\",\"x\":10.0,\"y\":69.0,\"w\":22.0,\"h\":6.0,\"fontSize\":11.0,\"weight\":700,\"align\":\"left\",\"color\":\"#7E8A98\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1},{\"id\":\"34e7d11e-4902-4018-8c72-38379c991a5b\",\"kind\":\"clock\",\"label\":\"Current time\",\"text\":\"\",\"x\":38.0,\"y\":66.0,\"w\":52.0,\"h\":13.0,\"fontSize\":29.0,\"weight\":700,\"align\":\"right\",\"color\":\"#BDA6FF\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1,\"format\":\"24\",\"showSeconds\":false},{\"id\":\"d6eef3c9-a75e-4ae7-917b-96a0f5fbc5e7\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":10.0,\"y\":86.0,\"w\":80.0,\"h\":2.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#241F30\",\"opacity\":1.0,\"radius\":2.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"a06fdee8-daf5-4a8a-8519-0daa34494495\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":10.0,\"y\":86.0,\"w\":46.0,\"h\":2.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#BDA6FF\",\"opacity\":1.0,\"radius\":2.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2}]}
    """,
    """
    {\"background\":{\"type\":\"gradient\",\"from\":\"#05080C\",\"to\":\"#101720\"},\"layers\":[{\"id\":\"78a57fec-b845-42f4-95ac-32c319d42beb\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":5.0,\"y\":5.0,\"w\":90.0,\"h\":90.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#0D141C\",\"opacity\":1.0,\"radius\":18.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"d19d84e4-d255-41e4-b861-0f267e92818d\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":8.0,\"y\":8.0,\"w\":84.0,\"h\":16.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#142019\",\"opacity\":1.0,\"radius\":8.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"21550760-bc6d-45e1-bd36-465749719ce5\",\"kind\":\"text\",\"label\":\"IPHONE STATUS\",\"text\":\"IPHONE STATUS\",\"x\":13.0,\"y\":11.0,\"w\":44.0,\"h\":6.0,\"fontSize\":11.0,\"weight\":700,\"align\":\"left\",\"color\":\"#A8FF60\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1},{\"id\":\"6eb8aab2-20cb-441c-81df-daf80aa93bd1\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":85.0,\"y\":13.0,\"w\":3.0,\"h\":3.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#A8FF60\",\"opacity\":1.0,\"radius\":50.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"9519d08a-d3ea-4b58-89e8-3c31882de854\",\"kind\":\"battery\",\"label\":\"iPhone battery\",\"text\":\"\",\"x\":12.0,\"y\":34.0,\"w\":76.0,\"h\":22.0,\"fontSize\":30.0,\"weight\":700,\"align\":\"center\",\"color\":\"#A8FF60\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2,\"format\":\"minimal\"},{\"id\":\"38761332-d79b-42e0-aea5-498709af0fe9\",\"kind\":\"divider\",\"label\":\"Divider\",\"text\":\"\",\"x\":12.0,\"y\":66.0,\"w\":76.0,\"h\":1.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#2B382F\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"4fe6f60b-6262-448c-89c9-43a364b1d462\",\"kind\":\"date\",\"label\":\"Current date\",\"text\":\"\",\"x\":12.0,\"y\":75.0,\"w\":46.0,\"h\":9.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#F7F9FC\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1,\"format\":\"abbrev\"},{\"id\":\"62b6dada-3516-4979-914d-675a2e1d272b\",\"kind\":\"clock\",\"label\":\"Current time\",\"text\":\"\",\"x\":61.0,\"y\":74.0,\"w\":27.0,\"h\":9.0,\"fontSize\":17.0,\"weight\":700,\"align\":\"right\",\"color\":\"#F7F9FC\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1,\"format\":\"24\",\"showSeconds\":false}]}
    """,
    """
    {\"background\":{\"type\":\"gradient\",\"from\":\"#05080C\",\"to\":\"#101720\"},\"layers\":[{\"id\":\"a082dadf-1db5-4b03-8be4-e6ae44d394d0\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":6.0,\"y\":6.0,\"w\":88.0,\"h\":88.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#091019\",\"opacity\":1.0,\"radius\":19.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"21f5879d-fdcf-4b73-b0c3-68bc42803c46\",\"kind\":\"text\",\"label\":\"HORIZON\",\"text\":\"HORIZON\",\"x\":10.0,\"y\":10.0,\"w\":35.0,\"h\":6.0,\"fontSize\":11.0,\"weight\":700,\"align\":\"left\",\"color\":\"#66D9FF\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1},{\"id\":\"b6404463-5134-4270-a44c-3355f8780d1b\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":68.0,\"y\":12.0,\"w\":22.0,\"h\":1.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#66D9FF\",\"opacity\":1.0,\"radius\":2.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"317253d8-3435-4d6f-85d2-4050054e4a4f\",\"kind\":\"clock\",\"label\":\"Current time\",\"text\":\"\",\"x\":10.0,\"y\":31.0,\"w\":80.0,\"h\":22.0,\"fontSize\":57.0,\"weight\":700,\"align\":\"center\",\"color\":\"#F7F9FC\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1,\"format\":\"24\",\"showSeconds\":false},{\"id\":\"637ae10d-e789-4ce4-8218-dd1532743300\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":10.0,\"y\":62.0,\"w\":80.0,\"h\":2.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#192D3A\",\"opacity\":1.0,\"radius\":2.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"cb6151c0-90e0-4fd8-95dc-f5128aeb5a33\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":10.0,\"y\":62.0,\"w\":58.0,\"h\":2.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#66D9FF\",\"opacity\":1.0,\"radius\":2.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"1df9c02a-fbd5-4244-a41a-61e20e01cc2b\",\"kind\":\"date\",\"label\":\"Current date\",\"text\":\"\",\"x\":10.0,\"y\":73.0,\"w\":80.0,\"h\":9.0,\"fontSize\":15.0,\"weight\":600,\"align\":\"center\",\"color\":\"#F7F9FC\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1,\"format\":\"abbrev\"},{\"id\":\"31c45db1-e8aa-4f5e-88db-3ea38c4d6843\",\"kind\":\"text\",\"label\":\"LOCAL DEVICE TIME\",\"text\":\"LOCAL DEVICE TIME\",\"x\":25.0,\"y\":86.0,\"w\":50.0,\"h\":6.0,\"fontSize\":11.0,\"weight\":700,\"align\":\"center\",\"color\":\"#7E8A98\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1}]}
    """,
    """
    {\"background\":{\"type\":\"gradient\",\"from\":\"#05080C\",\"to\":\"#101720\"},\"layers\":[{\"id\":\"5524f5bb-d7f1-47dd-93b9-8db54b051fb0\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":5.0,\"y\":5.0,\"w\":90.0,\"h\":90.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#0D141C\",\"opacity\":1.0,\"radius\":18.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"f4925309-2fc4-4dcf-942d-4945178fc4ae\",\"kind\":\"text\",\"label\":\"APEX ESSENTIAL\",\"text\":\"APEX ESSENTIAL\",\"x\":10.0,\"y\":9.0,\"w\":52.0,\"h\":6.0,\"fontSize\":11.0,\"weight\":700,\"align\":\"left\",\"color\":\"#66D9FF\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1},{\"id\":\"ff9ffab1-839c-4f04-839d-5223dd69ea2b\",\"kind\":\"clock\",\"label\":\"Current time\",\"text\":\"\",\"x\":10.0,\"y\":25.0,\"w\":80.0,\"h\":19.0,\"fontSize\":48.0,\"weight\":700,\"align\":\"center\",\"color\":\"#F7F9FC\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1,\"format\":\"24\",\"showSeconds\":false},{\"id\":\"c3783a65-f3a8-4f94-9ca0-06310987105e\",\"kind\":\"date\",\"label\":\"Current date\",\"text\":\"\",\"x\":10.0,\"y\":50.0,\"w\":80.0,\"h\":9.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"center\",\"color\":\"#7E8A98\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1,\"format\":\"abbrev\"},{\"id\":\"e4d9baee-8b53-4dca-9fb7-2947310aede8\",\"kind\":\"divider\",\"label\":\"Divider\",\"text\":\"\",\"x\":10.0,\"y\":64.0,\"w\":80.0,\"h\":1.0,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#26313D\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"bb89f0ea-4695-4c10-84c6-b09228dab9bd\",\"kind\":\"text\",\"label\":\"PHONE\",\"text\":\"PHONE\",\"x\":10.0,\"y\":73.0,\"w\":25.0,\"h\":6.0,\"fontSize\":11.0,\"weight\":700,\"align\":\"left\",\"color\":\"#7E8A98\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":1},{\"id\":\"a2eb9ca1-dbb5-4c7f-815e-36724f89005a\",\"kind\":\"battery\",\"label\":\"iPhone battery\",\"text\":\"\",\"x\":46.0,\"y\":70.0,\"w\":44.0,\"h\":12.0,\"fontSize\":19.0,\"weight\":700,\"align\":\"center\",\"color\":\"#66D9FF\",\"opacity\":1.0,\"radius\":0.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2,\"format\":\"minimal\"},{\"id\":\"485e714d-9a56-4e0e-9d9f-6d08a83d3a7d\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":10.0,\"y\":88.0,\"w\":80.0,\"h\":1.5,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#1B2A34\",\"opacity\":1.0,\"radius\":2.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2},{\"id\":\"a8150123-5a6e-4d6e-a247-4f52d383cee3\",\"kind\":\"shape\",\"label\":\"Decoration\",\"text\":\"\",\"x\":10.0,\"y\":88.0,\"w\":34.0,\"h\":1.5,\"fontSize\":14.0,\"weight\":600,\"align\":\"left\",\"color\":\"#66D9FF\",\"opacity\":1.0,\"radius\":2.0,\"letterSpacing\":0.0,\"shadow\":false,\"locked\":false,\"hidden\":false,\"fit\":\"cover\",\"flipH\":false,\"maxLines\":2}]}
    """,
  ]
}
