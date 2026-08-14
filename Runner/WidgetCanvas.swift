import SwiftUI

// ─── PreferenceKey: reports natural (unstretched) size of each text layer ────
struct TextNaturalSizeKey: PreferenceKey {
    static var defaultValue: [String: CGSize] = [:]
    static func reduce(value: inout [String: CGSize], nextValue: () -> [String: CGSize]) {
        value.merge(nextValue()) { _, new in new }
    }
}

struct WidgetCanvas: View {
    @Binding var spec: WidgetSpec
    @Binding var selectedLayerIndex: Int?
    var onInspect: ((Int) -> Void)? = nil

    let logicalSize: CGFloat = 340

    // Actual natural (content) sizes reported by text layers
    @State private var naturalTextSizes: [String: CGSize] = [:]
    @State private var currentDate = Date()
    // Battery ticker — bumped on every `batteryLevelDidChange` notification
    // so the canvas re-renders the instant the device battery crosses a
    // 1% boundary. Reading `UIDevice.current.batteryLevel` returns the
    // cached value, so this `@State` change is what forces the view to
    // recompute `resolvedText` for any `battery` / `battery_text` layers.
    @State private var batteryTick: Int = 0
    // Live speed tick — bumped on every GPS fix whose value changed
    // (NotificationCenter.telemetrySpeedUpdated). Forces the speed layer
    // to re-read `TelemetryService.shared.currentSpeed` synchronously so
    // changes feel instant, like Google Maps, instead of gated by the
    // 60-second clock/battery timer above.
    @State private var speedTick: Int = 0
    // Was 1 Hz before — clock displays only need minute precision, and
    // 1 Hz caused needless SwiftUI re-renders for thumbnails that were
    // not even visible on screen.
    private let timer = Timer.publish(every: 60.0, on: .main, in: .common).autoconnect()

    /// Spec with ALL legacy hardcoded placeholder layers auto-upgraded to live kinds.
    /// Applied at render time — gallery, detail sheet, editor, library all get live data
    /// without the user needing to manually edit existing drafts.
    ///
    /// Delegates to the shared `LayerMigration` enum so the editor canvas
    /// and the home-screen widget use identical upgrade rules.
    private var liveSpec: WidgetSpec {
        return LayerMigration.upgrade(spec)
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)

            ZStack(alignment: .topLeading) {
                // ── Clipped content (bg + layers stay inside the rounded square) ──
                ZStack(alignment: .topLeading) {
                    if let specialView = NativeSpecialRenderer.renderIfSpecial(
                        spec: liveSpec,
                        telemetry: hostTelemetrySnapshot(),
                        vehicle: hostSelectedVehicle(),
                        displayDate: currentDate
                    ) {
                        specialView
                            .frame(width: side, height: side)
                    } else {
                        backgroundView
                            .frame(width: side, height: side)

                        // ── Layer rendering — uses liveSpec so old "85%" text auto-shows real battery
                        ForEach(liveSpec.layers ?? []) { layer in
                            let w = (CGFloat(layer.w ?? 50) / 100.0) * side
                            let h = (CGFloat(layer.h ?? 30) / 100.0) * side
                            let x = (CGFloat(layer.x ?? 0) / 100.0) * side
                            let y = (CGFloat(layer.y ?? 0) / 100.0) * side

                            // `x` is always the top-left of the layer
                            // frame in 0-100% design space, regardless of
                            // `align`. The `align` field only affects how
                            // the text is justified within the bounding
                            // box (see `LayerView`).

                            LayerView(layer: layer, canvasSide: side, batteryTick: batteryTick, speedTick: speedTick)
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
                                                value: [layer.id: tg.size]
                                            )
                                        }
                                    )
                                    .position(x: -9999, y: -9999)
                            }
                        }
                    }
                }
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: 24))

                // ── Group bounding box indicator ─────────────────────────
                // When the selected layer is part of a group, draw a faint
                // dashed rectangle around the group's bbox so the user can
                // see what's linked together.
                if let idx = selectedLayerIndex,
                   let layers = liveSpec.layers,
                   idx < layers.count,
                   let gid = layers[idx].groupId {
                    let bbox = computeGroupBBox(layers: layers, groupId: gid, canvasSide: side)
                    if let bbox {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(
                                style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                            )
                            .foregroundColor(Color.blue.opacity(0.55))
                            .frame(width: bbox.width, height: bbox.height)
                            .position(x: bbox.midX, y: bbox.midY)
                            .allowsHitTesting(false)
                    }
                }

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
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)) { _ in
                batteryTick &+= 1
            }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification)) { _ in
                batteryTick &+= 1
            }
            .onReceive(NotificationCenter.default.publisher(for: .telemetrySpeedUpdated)) { _ in
                // Every GPS fix whose speed changed — repaint speed layers
                // immediately. With this subscription the editor canvas
                // catches up to driving speed in well under a second.
                speedTick &+= 1
            }
        }
    }

    // ── Helpers ─────────────────────────────────────────────────────────
    private func computeGroupBBox(layers: [WidgetLayer], groupId: String, canvasSide: CGFloat) -> CGRect? {
        let grouped = layers.filter { $0.groupId == groupId }
        guard !grouped.isEmpty else { return nil }
        var minX: CGFloat =  .greatestFiniteMagnitude
        var minY: CGFloat =  .greatestFiniteMagnitude
        var maxX: CGFloat = -.greatestFiniteMagnitude
        var maxY: CGFloat = -.greatestFiniteMagnitude
        for l in grouped {
            let x = CGFloat(l.x ?? 0) / 100 * canvasSide
            let y = CGFloat(l.y ?? 0) / 100 * canvasSide
            let w = CGFloat(l.w ?? 0) / 100 * canvasSide
            let h = CGFloat(l.h ?? 0) / 100 * canvasSide
            minX = min(minX, x); minY = min(minY, y)
            maxX = max(maxX, x + w); maxY = max(maxY, y + h)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func isTextKind(_ kind: String) -> Bool {
        ["text", "speed", "vehicle_name", "battery_text", "clock"].contains(kind)
    }

    private func resolvedText(for layer: WidgetLayer) -> String {
        switch layer.kind {
        case "clock":
            if let fmt = layer.format, !fmt.isEmpty {
                // Per-layer custom format — build a one-off formatter
                // rather than caching every possible user-supplied pattern.
                let f = DateFormatter()
                f.dateFormat = fmt
                return f.string(from: currentDate)
            }
            return FormatterCache.timeFormatter.string(from: currentDate)
        case "date":
            if let fmt = layer.format, !fmt.isEmpty {
                let f = DateFormatter()
                f.dateFormat = fmt
                return f.string(from: currentDate)
            }
            return FormatterCache.mediumDateFormatter.string(from: currentDate)
        case "speed":
            // TelemetryService.currentSpeed is already in km/h. Nil means
            // "no valid GPS fix yet" — render "--". Genuine 0 km/h must
            // render as "0".
            if let spd = TelemetryService.shared.currentSpeed {
                return "\(Int(spd))"
            }
            return "--"
        case "vehicle_name":
            // Vehicle-name layers display the selected vehicle's name.
            // Unknown vehicle renders as "—"; we never invent a
            // placeholder like "Cyber Sedan" or "My Vehicle".
            return WidgetDisplayMath.vehicleLabel(hostSelectedVehicle()?.displayName)
        case "battery", "battery_text":
            // Unknown battery (UIDevice returns -1 or telemetry never
            // published) renders as "—" via the shared helper. Genuine
            // 0% renders as "0%". We never substitute 88 or 100.
            let raw = hostLiveBatteryPercent()
            if let pct = WidgetDisplayMath.clampedBatteryPercent(raw) {
                return "\(pct)%"
            }
            return "—"
        default:
            return layer.text ?? ""
        }
    }

    // ── Live host telemetry for canvas preview ──────────────────────────
    //
    // The canvas renders the same widget content the user will see on
    // the home screen, so it must read the same truthful telemetry the
    // widget extension reads. We reuse the host-side AppStore values
    // (which already wrote the App Group snapshot the widget reads)
    // and the App Group state for the selected vehicle.
    private func hostLiveBatteryPercent() -> Int? {
        return AppStore.shared.liveBatteryPercent
    }

    private func hostSelectedVehicle() -> VehicleData? {
        return AppGroupState.loadState()?.vehicle
    }

    private func hostTelemetrySnapshot() -> TelemetrySnapshot? {
        // Compose the same shape the widget extension would read:
        // timestamp from the host's latest write, battery + charging
        // from AppStore, speed from CLLocationManager (km/h).
        let timestamp = Date()
        let speed = TelemetryService.shared.currentSpeed
        return TelemetrySnapshot(
            carConnected: TelemetryService.shared.carConnected,
            batteryPercent: AppStore.shared.liveBatteryPercent,
            isCharging: AppStore.shared.liveIsCharging,
            speed: speed,
            timestamp: timestamp
        )
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
    // Bumped by `WidgetCanvas` whenever the device battery level changes.
    // Reading it here forces SwiftUI to re-evaluate `resolvedText` for any
    // `battery` / `battery_text` layer so the canvas updates in real time.
    var batteryTick: Int = 0
    // Bumped by `WidgetCanvas` on every GPS fix whose speed changed.
    // Forces the speed layer to re-read `TelemetryService.shared.currentSpeed`
    // synchronously so changes feel like Google Maps, not the 60s clock timer.
    var speedTick: Int = 0

    private var resolvedText: String {
        // Touch the ticks so SwiftUI sees this computation as dependent on them.
        _ = batteryTick
        _ = speedTick
        switch layer.kind {
        // ── Live data ────────────────────────────────────────
        case "battery", "battery_text":
            // Unknown battery (UIDevice returns -1 or telemetry never
            // published) renders as "—" via the shared helper. Genuine
            // 0% renders as "0%". We never substitute 0 (which would
            // look like a full discharge reading) when battery is
            // actually unknown.
            let raw = AppStore.shared.liveBatteryPercent
            let charging = AppStore.shared.liveIsCharging
            if let pct = WidgetDisplayMath.clampedBatteryPercent(raw) {
                return charging ? "\(pct)% ⚡" : "\(pct)%"
            }
            return charging ? "— ⚡" : "—"
        case "clock":
            return FormatterCache.timeFormatter.string(from: Date())
        case "date":
            return FormatterCache.mediumDateFormatter.string(from: Date())
        case "speed":
            // Read live from TelemetryService — `speedTick` invalidation
            // guarantees this is evaluated on every GPS fix. Nil means
            // "no valid GPS fix yet" — render "--". Genuine 0 km/h
            // renders as "0".
            if let spd = TelemetryService.shared.currentSpeed {
                return "\(Int(spd))"
            }
            return "--"
        case "vehicle_name":
            // Live vehicle-name layers render the selected vehicle's
            // name. Unknown vehicle (no selection, missing snapshot)
            // renders as "—" via the shared helper. We never invent
            // a placeholder like "My Vehicle" or "Cyber Sedan".
            // A user-authored `text` field is treated as a fallback
            // for **static** vehicle-name layers; live vehicle-name
            // layers (no `text` set) read the App Group selection.
            if let t = layer.text, !t.isEmpty { return t }
            return WidgetDisplayMath.vehicleLabel(AppGroupState.loadState()?.vehicle?.displayName)
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
            // ── Analog clock preview — proper clock face with hour ticks,
            // hands, and center pin. Uses the shared `AnalogClockView` from
            // the widget extension target (compiled into both via the file
            // system synchronized group). The canvas drives its own
            // 60-second timer (line 36) and passes the current date so
            // the hands advance every minute without WidgetKit.
            AnalogClockView(
                color: Color(hex: layer.color ?? "FFFFFF") ?? .white,
                opacity: layer.opacity ?? 1.0,
                displayDate: Date()
            )
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
        } else if kind == "battery_bar" {
            // ── Live battery progress bar ──────────────────────────────────
            // Unlike a static `shape/rect`, this layer's fill width is driven
            // by the actual device battery level at render time. Reads
            // `UIDevice.current.batteryLevel` directly — the host process
            // (TelemetryService.init) has already enabled battery monitoring.
            let lvl = UIDevice.current.batteryLevel
            let pct = max(0, min(1, lvl >= 0 ? lvl : 0))
            let trackColor = Color(hex: layer.label ?? "1E1E24", fallback: Color(hex: "1E1E24", fallback: .black))
            let fillColor  = Color(hex: layer.color ?? "22C55E", fallback: .green)
            let hPadding: CGFloat = 1
            let radius: CGFloat = CGFloat(layer.radius ?? 4)
            GeometryReader { barGeo in
                let totalW = barGeo.size.width
                let fillW  = max(0, totalW * CGFloat(pct) - hPadding * 2)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: radius)
                        .fill(trackColor)
                    RoundedRectangle(cornerRadius: radius)
                        .fill(fillColor)
                        .frame(width: fillW)
                        .padding(hPadding)
                }
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
