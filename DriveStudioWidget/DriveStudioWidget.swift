import WidgetKit
import SwiftUI
import UIKit
import CryptoKit

// MARK: - Data models (must match Flutter side)
// Models are now in WidgetModels.swift

// MARK: - Helpers

// Color extension is defined in DriveComponents.swift

// `DriveStudioImageLoader` now lives in its own file
// (`DriveStudioImageLoader.swift`) so the same loader is
// available to both the in-app editor preview and the widget
// extension — compiled into both targets via the
// file-system-synchronized `DriveStudioWidget/` group.

// MARK: - Widget

/// iOS-2 fix: `.containerBackground(for: .widget)` is iOS 17+. The widget
/// extension's deployment target is iOS 16, so calling it on iOS 16 would
/// crash. We conditionally apply it and rely on the entry view's own
/// ZStack `BackgroundView` for the iOS 16 fallback path.
@available(iOS 16.0, *)
extension View {
    @ViewBuilder
    func widgetContainerBackground(spec: WidgetSpec?, generation: String? = nil) -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(for: .widget) {
                BackgroundView(spec: spec, generation: generation)
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
                .widgetContainerBackground(spec: entry.activeSpec, generation: entry.generation)
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
                .widgetContainerBackground(spec: entry.activeSpec, generation: entry.generation)
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
                .widgetContainerBackground(spec: entry.activeSpec, generation: entry.generation)
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
                .widgetContainerBackground(spec: entry.activeSpec, generation: entry.generation)
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
        completion(WidgetTelemetryFactory.simpleEntry(
            slotIndex: slotIndex,
            at: Date(),
            isPreview: context.isPreview
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        // Apple-documented normal-provider model: first entry's date is
        // the current time; subsequent entries are spaced at least ~5
        // minutes apart; `.atEnd` asks WidgetKit to call us again after
        // the last entry is consumed. Telemetry stays frozen on the
        // snapshot WidgetKit hands to each entry — clock/date text
        // advances when WidgetKit advances the entry.
        let now = Date()
        let timeline = WidgetTimelineSchedule.makeProviderTimeline(
            startingAt: now,
            providerEntryCount: WidgetTimelineSchedule.defaultProviderEntryCount
        ) { date in
            WidgetTelemetryFactory.simpleEntry(
                slotIndex: self.slotIndex,
                at: date,
                isPreview: context.isPreview
            )
        }
        completion(timeline)
    }
}

// MARK: - Entry view — renders user design fit-to-canvas

@available(iOS 16.0, *)
struct DriveStudioWidgetEntryView: View {
    let entry: SimpleEntry

    /// Captured at view-build time so the `TimelineView(.everyMinute)`
    /// closure sees a stable view of the entry's telemetry and spec —
    /// it MUST NOT re-read telemetry, `UIDevice`, or App Group state
    /// inside the closure. The closure uses `context.date` only.
    private struct Captured {
        let telemetry: TelemetrySnapshot?
        let vehicle: VehicleData?
        let spec: WidgetSpec?
        /// Immutable generation snapshot from the entry — used as
        /// the cache namespace for image loads so a new generation
        /// never reads the previous generation's cached UIImage.
        let generation: String?
    }

    var body: some View {
        let activeSpec = entry.slot?.spec
        let captured = Captured(
            telemetry: entry.telemetry,
            vehicle: entry.vehicle,
            spec: activeSpec,
            generation: entry.generation
        )
        return MinuteClockView(data: captured) { displayDate, cap in
            GeometryReader { g in
                ZStack {
                    if let spec = cap.spec,
                       let specialView = NativeSpecialRenderer.renderIfSpecial(
                        spec: spec, telemetry: cap.telemetry, vehicle: cap.vehicle,
                        displayDate: displayDate
                       ) {
                        specialView
                    } else {
                        BackgroundView(spec: cap.spec, generation: cap.generation)
                        if let spec = cap.spec, let rawLayers = spec.layers, !rawLayers.isEmpty {
                            let layers = LayerMigration.upgrade(rawLayers)
                            FitToCanvasLayers(
                                layers: layers,
                                canvasSize: g.size,
                                telemetry: cap.telemetry,
                                vehicle: cap.vehicle,
                                generation: cap.generation,
                                entryDate: displayDate
                            )
                        } else {
                            VStack(spacing: 4) {
                                Image(systemName: "square.grid.2x2")
                                    .font(.system(size: max(14, g.size.width * 0.15)))
                                    .foregroundColor(.gray)
                                Text("Slot \(entry.slotIndex + 1)")
                                    .font(.system(size: max(9, g.size.width * 0.08), weight: .semibold, design: .rounded))
                                    .foregroundColor(.gray)
                            }
                            .multilineTextAlignment(.center)
                        }
                    }
                }
            }
            .widgetContainerBackground(spec: cap.spec, generation: cap.generation)
        }
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
    /// Generation to scope image-cache lookups by. Propagated from
    /// `DriveStudioWidgetEntryView` so a fresh generation never
    /// reads a stale cache slot from the previous generation.
    var generation: String? = nil
    var body: some View {
        if let bg = spec?.background {
            if let img = bg.imageSrc.flatMap({
                DriveStudioImageLoader.load(from: $0, generation: generation)
            }) {
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
    /// Generation to scope image-cache lookups by. Threaded all the
    /// way through to `ScaledLayerView` so the same filename across
    /// two generations resolves to two distinct cached images.
    var generation: String? = nil
    var entryDate: Date = Date()

    /// Reference design canvas side (square). `computeFitTransform` was
    /// hardcoded to 340.0; named here so the magic number has one home.
    private static let designSide: CGFloat = 340

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
                        generation: generation,
                        entryDate: entryDate
                    )
                }
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }

    private static func computeFitTransform(for canvas: CGSize) -> CGAffineTransform {
        let scaleX = canvas.width  / designSide
        let scaleY = canvas.height / designSide
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
    /// Generation to scope image-cache lookups by. When the user
    /// edits an image, the host writes a new generation with the
    /// new bytes; without this thread the widget would return the
    /// previous generation's cached UIImage.
    var generation: String? = nil
    var entryDate: Date = Date()

    private static let designSize = CGSize(width: 340, height: 340)

    var body: some View {
        let design = Self.designSize
        let x = (layer.x ?? 0) / 100 * design.width
        let y = (layer.y ?? 0) / 100 * design.height
        let w = (layer.w ?? 100) / 100 * design.width
        let h = (layer.h ?? 100) / 100 * design.height
        // `x` is always the top-left of the layer frame, regardless of
        // `align`. The `align` field only affects how text is justified
        // inside the bounding box (see the per-`kind` rendering below).
        let rect = CGRect(x: x, y: y, width: w, height: h).applying(transform)
        let fontSize = (layer.fontSize ?? 14) * (canvasSize.width / 180)
        let layerColor = Color(hex: layer.color ?? "#FFFFFF", fallback: .white)
        let opacityVal = layer.opacity ?? 1
        Group {
            switch layer.kind {
            case "text":
                // The check above (`!= ""`) already proves `layer.text`
                // is non-nil; the explicit `??` here lets the compiler
                // see the optional is unwrapped safely without a `!`.
                let text = layer.text?.isEmpty == false
                    ? (layer.text ?? "")
                    : (layer.label ?? " ")
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
                // Both kinds show battery icon + percentage. Unknown
                // battery renders as a dash — we never substitute 100%.
                HStack(spacing: max(2, fontSize * 0.2)) {
                    Image(systemName: ScaledLayerView.batterySymbolName(
                        percent: telemetry?.batteryPercent,
                        isCharging: telemetry?.isCharging == true
                    ))

                    if let level = telemetry?.batteryPercent {
                        Text("\(WidgetBatteryMath.clamp(level))%")
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
                    // TelemetryService already converts m/s → km/h, so do not
                    // multiply by 3.6 again. The variable name `mph` was also
                    // misleading: the user sees km/h.
                    let kmh = Int(speed)
                    Text("\(kmh)")
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
                // Vehicle-unavailable marker: never substitute a placeholder
                // brand name; show "—" when no vehicle is selected.
                Text(WidgetDisplayMath.vehicleLabel(vehicle?.displayName))
                    .font(.system(size: fontSize, weight: weight(for: layer.weight ?? 400), design: .rounded))
                    .foregroundColor(layerColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
            case "shape":
                let r = (layer.radius ?? 0) * (canvasSize.width / 180)
                let color = Color(hex: layer.color ?? "#FFFFFF", fallback: .white).opacity(layer.opacity ?? 1)
                if (layer.radius ?? 0) >= 50 {
                    Circle().fill(color)
                } else {
                    RoundedRectangle(cornerRadius: r).fill(color)
                }
            case "battery_bar":
                // Battery progress bar — fill width is driven by the
                // telemetry snapshot the host app wrote to the App Group.
                // Unknown battery (snapshot's `batteryPercent == nil`)
                // renders as an empty bar; we never invent a number.
                let pct = telemetry?.batteryPercent
                    .map { Double(WidgetBatteryMath.clamp($0)) / 100.0 } ?? 0
                let trackHex = layer.label ?? "1E1E24"
                let trackColor = Color(hex: trackHex, fallback: Color(hex: "#1E1E24", fallback: .black))
                let fillColor = Color(hex: layer.color ?? "#22C55E", fallback: .green)
                let barRadius = CGFloat(layer.radius ?? 4) * (canvasSize.width / 180)
                GeometryReader { barGeo in
                    let totalW = barGeo.size.width
                    let fillW  = max(0, totalW * CGFloat(pct) - 2)
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: barRadius)
                            .fill(trackColor)
                        RoundedRectangle(cornerRadius: barRadius)
                            .fill(fillColor)
                            .frame(width: fillW)
                            .padding(1)
                    }
                }
            case "image":
                let src = layer.src ?? ""
                if ImageSource.symbolicVehicleGuideNames.contains(src) {
                    // Symbolic editor guide — NOT a real image
                    // filename. Render the neutral "CAR PHOTO"
                    // placeholder box the same way the editor
                    // canvas does, so the home-screen widget and
                    // the in-app preview agree. We never load
                    // `template_car` from a bundle or the App
                    // Group; there is no such file.
                    VehiclePositionGuideBox()
                } else if !src.isEmpty, let img = DriveStudioImageLoader.load(
                    from: src, generation: generation) {
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
                    .fill(Color(hex: layer.color ?? "#FFFFFF", fallback: .white).opacity(layer.opacity ?? 1))
                    .frame(height: CGFloat(thickness) * (canvasSize.width / 338))
            case "draw":
                DrawStrokesCanvas(strokesJSON: layer.strokes, color: layerColor, opacity: opacityVal)
            case "analog":
                AnalogClockView(color: layerColor, opacity: opacityVal, displayDate: entryDate)
            default:
                EmptyView()
            }
        }
        // Constrain the Group's content to the layer's rect so the inner
        // Text views (which each have `lineLimit(1)` + `minimumScaleFactor`)
        // can actually scale down to fit. Without this the Text views
        // report their natural intrinsic width and clip past the layer
        // edge — the PM-clipping bug on the clock layer.
        .frame(maxWidth: rect.width, maxHeight: rect.height,
               alignment: parseAlignment(layer.align ?? "center"))
        .position(x: rect.midX, y: rect.midY)
    }

    private func parseAlignment(_ s: String) -> Alignment {
        switch s.lowercased() {
        case "left", "leading":   return .leading
        case "right", "trailing": return .trailing
        default:                  return .center
        }
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
    /// via the shared `WidgetBatteryIcon` helper. Unknown battery
    /// returns the neutral `bolt.slash` symbol rather than pretending
    /// the battery is full.
    static func batterySymbolName(percent: Int?, isCharging: Bool) -> String {
        return WidgetBatteryIcon.symbolName(percent: percent, isCharging: isCharging)
    }
}

// MARK: - Free helper for other files in this target
//
// `WidgetBatteryMath.clamp` is the canonical place to clamp a battery
// percentage to the displayable 0–100 range. We never invent a value
// when battery is unknown — that case is handled at the call site by
// checking `telemetry?.batteryPercent == nil`.
enum WidgetBatteryMath {
    static func clamp(_ pct: Int) -> Int {
        return max(0, min(100, pct))
    }
}

/// Renders a live analog clock face for `kind == "analog"` layers.
/// The clock uses the `displayDate` supplied by the caller so the
/// minute-clock mechanism (`MinuteClockView` /
/// `TimelineView(.everyMinute)`) controls when the hands advance.
/// The view itself does NOT call `Date()` — callers must wrap this
/// in a minute-clock context for the hands to refresh. The editor's
/// pre-rendered PNG stays static underneath this overlay.
struct AnalogClockView: View {
    let color: Color
    let opacity: Double
    let displayDate: Date

    var body: some View {
        Canvas { context, size in
            let cal = Calendar.current
            let comps = cal.dateComponents([.hour, .minute, .second], from: displayDate)
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
