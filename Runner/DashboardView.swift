import SwiftUI
import UIKit
import PhotosUI
import CoreLocation

// MARK: - Dashboard (Home Tab)
struct DashboardView: View {
    @EnvironmentObject var store: AppStore
    var onOpenEditor: (String) -> Void
    @Binding var selectedTab: Int

    @State private var showSlotPicker = false
    @State private var targetSlotPicker: SlotPickerTarget? = nil
    @State private var showPhotosPicker = false
    @State private var shouldRemoveBackground = false
    @State private var showActionSheet = false
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var activeSlotForMenu: Int? = nil
    @State private var showSlotActionSheet = false
    @State private var showAutomationGuide = false

    // Live speed tick — bumped on every GPS fix whose value changed
    // (NotificationCenter.telemetrySpeedUpdated). Forces the Dashboard's
    // MetricBar to re-read `TelemetryService.shared.currentSpeed`
    // synchronously so changes feel instant, like Google Maps, instead
    // of being gated by the 60-second clock/battery heartbeat. Same
    // pattern as `WidgetCanvas.speedTick` (line 32) which already
    // makes the editor canvas feel real-time.
    @State private var speedTick: Int = 0

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // ── Header ───────────────────────────────────────────
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        MonoLabel(text: "Instrument cluster")
                        Text("Drive Studio")
                            .font(.system(size: 32, weight: .bold))
                            .tracking(-1)
                            .foregroundColor(DriveColors.foreground)
                    }
                    Spacer()
                    Button(action: {
                        showAutomationGuide = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 12))
                            Text("Auto Setup")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(DriveColors.primaryFg)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(DriveColors.primary)
                        .cornerRadius(999)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)

                // ── Telemetry Panel ──────────────────────────────────
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                MonoLabel(text: store.liveTimeString.isEmpty ? "Device telemetry" : "LIVE TELEMETRY · \(store.liveTimeString)")
                                Text("Live from this iPhone")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(DriveColors.foreground)
                            }
                            Spacer()
                            DrivePill(label: "Synced")
                        }

                        Text(batterySummary(for: store))
                            .font(.system(size: 13))
                            .lineSpacing(5)
                            .foregroundColor(DriveColors.mutedFg)

                        HStack(spacing: 16) {
                            MetricBar(icon: batteryIcon(for: store),
                                      label: "Battery",
                                      value: batteryValueText(for: store),
                                      progress: batteryProgress(for: store))
                            // TelemetryService.currentSpeed is now optional. `nil`
                            // means "no valid GPS fix yet" — render "-- km/h",
                            // not "0 km/h". Genuine 0 km/h still renders "0 km/h".
                            let currentSpeed = TelemetryService.shared.currentSpeed
                            MetricBar(icon: "gauge.with.dots.needle.bottom.50percent",
                                      label: "GPS speed",
                                      value: currentSpeed.map { "\(Int($0)) km/h" } ?? "-- km/h",
                                      progress: currentSpeed.map { min($0 / 240.0, 1.0) } ?? 0)
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 16)

                // ── Vehicle Profile Card ─────────────────────────────
                SurfaceCard(padding: .init(top: 0, leading: 0, bottom: 0, trailing: 0)) {
                    VStack(spacing: 0) {
                        ZStack {
                            if let img = store.vehicleImage {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 220)
                                    .clipped()
                            } else {
                                Button(action: { showActionSheet = true }) {
                                    ZStack {
                                        DriveColors.muted.opacity(0.3)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 220)
                                        VStack(spacing: 8) {
                                            Image(systemName: "icloud.and.arrow.up")
                                                .font(.system(size: 24))
                                                .foregroundColor(DriveColors.mutedFg)
                                            MonoLabel(text: "Tap to upload vehicle")
                                        }
                                    }
                                }
                            }
                        }

                        VStack(spacing: 10) {
                            Button(action: { selectedTab = 1 }) {
                                Text("Open Studio")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(DriveColors.primaryFg)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(DriveColors.primary)
                                    .cornerRadius(12)
                                    .contentShape(RoundedRectangle(cornerRadius: 12))
                            }

                            Button(action: { showSlotPicker = true }) {
                                Text("Manage Slots")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(DriveColors.foreground)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(DriveColors.secondary)
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(DriveColors.border, lineWidth: 1))
                                    .contentShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(20)
                    }
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 24)

                // ── Active Slots 2×2 ────────────────────────────────
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        MonoLabel(text: "Active slots")
                        Spacer()
                        Button(action: { showSlotPicker = true }) {
                            Text("Manage All")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(DriveColors.primary)
                        }
                    }
                    .padding(.horizontal, 20)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(0..<4, id: \.self) { i in
                            Button(action: {
                                if store.slots[i] != nil {
                                    activeSlotForMenu = i
                                    showSlotActionSheet = true
                                } else {
                                    targetSlotPicker = SlotPickerTarget(id: i)
                                }
                                // Single tap on a populated slot also
    // focuses it, so the user's manual focus and the
    // Shortcut-driven focus share the same persisted
    // preference and the same widget-reload trigger.
    store.setActiveSlot(i)
                            }) {
                                SlotCell(index: i, draftId: store.slots[i], isFocused: i == store.activeSlotIndex)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Spacer().frame(height: 24)

                // ── Setup Status Card ────────────────────────────────
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 0) {
                        MonoLabel(text: "Setup status")
                        Spacer().frame(height: 16)

                        // First row of the card now hosts the GPS status
                        // + the user-driven GPS action button (set up
                        // permission here, never at app launch).
                        StatusRow(
                            icon: gpsStatusIcon(),
                            iconColor: gpsStatusColor(),
                            label: "Telemetry permissions",
                            value: gpsStatusText()
                        )
                        Divider().background(DriveColors.border).padding(.vertical, 12)
                        Button(action: { handleGpsActionTap() }) {
                            HStack(spacing: 8) {
                                Image(systemName: gpsActionIcon())
                                    .font(.system(size: 14, weight: .semibold))
                                Text(gpsActionLabel())
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(gpsActionForeground())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(gpsActionBackground())
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(gpsActionBorder(), lineWidth: 1))
                            .contentShape(RoundedRectangle(cornerRadius: 12))
                        }
                        Divider().background(DriveColors.border).padding(.vertical, 12)
                        StatusRow(icon: "battery.100", iconColor: DriveColors.success,
                                  label: "Battery reporting", value: batteryValueText(for: store))
                        Divider().background(DriveColors.border).padding(.vertical, 12)
                        StatusRow(
                            icon: "checkmark.circle",
                            iconColor: store.slots.compactMap({$0}).isEmpty ? DriveColors.warning : DriveColors.success,
                            label: "WidgetKit sync",
                            value: store.slots.compactMap({$0}).isEmpty ? "No slots" : "Active"
                        )

                        Spacer().frame(height: 20)
                        Button(action: { showAutomationGuide = true }) {
                            Text("Install & live sync guide")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(DriveColors.foreground)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(DriveColors.secondary)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(DriveColors.border, lineWidth: 1))
                                .contentShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 40)
            }
        }
        .background(DriveColors.background)
        .confirmationDialog("Slot Options", isPresented: $showSlotActionSheet, titleVisibility: .visible) {
            if let i = activeSlotForMenu, let draftId = store.slots[i] {
                Button("✏️ Edit Widget") {
                    onOpenEditor(draftId)
                }
                Button("🔄 Replace Widget") {
                    targetSlotPicker = SlotPickerTarget(id: i)
                }
                Button("🗑️ Remove Widget", role: .destructive) {
                    store.assignSlot(i, draftId: nil)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Add Vehicle Image", isPresented: $showActionSheet, titleVisibility: .visible) {
            Button("Gallery (Remove Background)") { shouldRemoveBackground = true; showPhotosPicker = true }
            Button("Gallery (Original)") { shouldRemoveBackground = false; showPhotosPicker = true }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showPhotosPicker, selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) { _ in
            Task {
                if let item = selectedItem,
                   let data = try? await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    
                    var finalImage = uiImage
                    if shouldRemoveBackground {
                        if #available(iOS 17.0, *) {
                            if let cutout = try? await BgCutoutService.removeBackground(from: uiImage) {
                                finalImage = cutout
                            }
                        }
                    }
                    
                    let imageToSave = finalImage
                    await MainActor.run {
                        store.saveVehicleImage(imageToSave)
                    }
                }
            }
        }
        .sheet(isPresented: $showSlotPicker) {
            SlotManagerScreen().environmentObject(store)
        }
        .sheet(item: $targetSlotPicker) { target in
            DraftPickerSheet(slotIndex: target.id)
                .environmentObject(store)
        }
        .sheet(isPresented: $showAutomationGuide) {
            AutomationGuideSheet()
        }
        // Live speed: every GPS fix whose value differs from the last
        // bumps `speedTick` so the body re-renders and the MetricBar
        // shows the new km/h. Without this, Dashboard would only
        // refresh on the 60s heartbeat timer — not real-time.
        .onReceive(NotificationCenter.default.publisher(for: .telemetrySpeedUpdated)) { _ in
            speedTick &+= 1
        }
    }
}

// MARK: - Battery text helpers
//
// The dashboard displays whatever the most recent telemetry refresh
// reported. Battery can legitimately be unknown (UIDevice returns -1
// before monitoring is enabled, on simulators, or when the OS
// deliberately withholds a reading). In every unknown case we surface
// "—" rather than a fake 100%.
@MainActor
private func batteryValueText(for store: AppStore) -> String {
    if let pct = store.liveBatteryPercent {
        return "\(pct)%"
    }
    return "—"
}

@MainActor
private func batteryIcon(for store: AppStore) -> String {
    return WidgetBatteryIcon.symbolName(
        percent: store.liveBatteryPercent,
        isCharging: store.liveIsCharging
    )
}

@MainActor
private func batteryProgress(for store: AppStore) -> Double {
    guard let pct = store.liveBatteryPercent else { return 0 }
    return Double(pct) / 100.0
}

// MARK: - Truthful status helpers
//
// The dashboard previously hardcoded "car linked · GPS speed available"
// regardless of state. That helper was removed when the Car link row
// was dropped from the home screen — the car-link state is now
// exclusively surfaced through the live widget itself, which reads the
// auto-detected value straight from the App Group snapshot.
@MainActor
private func gpsStatusText() -> String {
    switch CLLocationManager.authorizationStatus() {
    case .notDetermined:
        return "GPS permission: not requested"
    case .denied, .restricted:
        return "GPS permission: denied"
    case .authorizedAlways:
        return "GPS always authorized"
    case .authorizedWhenInUse:
        return "GPS when-in-use only"
    @unknown default:
        return "GPS permission: unknown"
    }
}

@MainActor
private func gpsStatusIcon() -> String {
    switch CLLocationManager.authorizationStatus() {
    case .authorizedAlways, .authorizedWhenInUse:
        return "checkmark.circle"
    default:
        return "exclamationmark.triangle"
    }
}

@MainActor
private func gpsStatusColor() -> Color {
    switch CLLocationManager.authorizationStatus() {
    case .authorizedAlways, .authorizedWhenInUse:
        return DriveColors.success
    default:
        return DriveColors.warning
    }
}

// MARK: - GPS action button (user-driven, never automatic)
@MainActor
private func gpsActionIcon() -> String {
    switch CLLocationManager.authorizationStatus() {
    case .authorizedAlways, .authorizedWhenInUse: return "location.fill"
    case .denied, .restricted:                   return "gearshape.fill"
    default:                                      return "location"
    }
}

@MainActor
private func gpsActionLabel() -> String {
    switch CLLocationManager.authorizationStatus() {
    case .authorizedAlways, .authorizedWhenInUse: return "GPS monitoring"
    case .denied, .restricted:                   return "Open Settings"
    default:                                      return "Enable GPS speed"
    }
}

@MainActor
private func gpsActionForeground() -> Color {
    switch CLLocationManager.authorizationStatus() {
    case .authorizedAlways, .authorizedWhenInUse: return DriveColors.success
    default:                                      return DriveColors.foreground
    }
}

@MainActor
private func gpsActionBackground() -> Color {
    switch CLLocationManager.authorizationStatus() {
    case .authorizedAlways, .authorizedWhenInUse: return DriveColors.success.opacity(0.15)
    default:                                      return DriveColors.secondary
    }
}

@MainActor
private func gpsActionBorder() -> Color {
    switch CLLocationManager.authorizationStatus() {
    case .authorizedAlways, .authorizedWhenInUse: return DriveColors.success.opacity(0.6)
    default:                                      return DriveColors.border
    }
}

@MainActor
private func handleGpsActionTap() {
    let status = CLLocationManager.authorizationStatus()
    if status == .denied || status == .restricted {
        // Take the user to this app's settings page. They can flip the
        // permission on there and come back.
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    } else {
        _ = TelemetryService.shared.beginLocationIfAuthorized()
    }
}

@MainActor
private func batterySummary(for store: AppStore) -> String {
    let battery: String
    if let pct = store.liveBatteryPercent {
        battery = "\(pct)%"
    } else {
        battery = "—"
    }
    let charging = store.liveIsCharging ? "charging · " : ""
    return "Battery \(battery) · \(charging)\(gpsStatusText())"
}

// MARK: - Slot Cell
struct SlotCell: View {
    let index: Int
    let draftId: String?
    var isFocused: Bool = false
    @EnvironmentObject var store: AppStore

    var resolvedSpec: WidgetSpec? {
        guard let dId = draftId else { return nil }
        if let custom = store.drafts.first(where: { $0.id == dId }) {
            return custom.spec
        } else if let stock = StockWidgetCatalog.shared.widgets.first(where: { $0.stockWidgetId == dId }) {
            return stock.document
        }
        return nil
    }

    var resolvedName: String {
        guard let dId = draftId else { return "Tap to Add" }
        if let custom = store.drafts.first(where: { $0.id == dId }) {
            return custom.name
        } else if let stock = StockWidgetCatalog.shared.widgets.first(where: { $0.stockWidgetId == dId }) {
            return stock.name
        }
        return "Tap to Add"
    }

    var body: some View {
        SurfaceCard(padding: .init(top: 10, leading: 10, bottom: 10, trailing: 10)) {
            VStack(spacing: 8) {
                ZStack {
                    if let spec = resolvedSpec {
                        WidgetCanvas(spec: .constant(spec), selectedLayerIndex: .constant(nil))
                            .frame(height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        isFocused ? DriveColors.primary : DriveColors.border.opacity(0.4),
                                        lineWidth: isFocused ? 2.5 : 1
                                    )
                            )
                            .allowsHitTesting(false)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(DriveColors.muted.opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(DriveColors.border.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            )
                            .frame(height: 120)

                        VStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(DriveColors.primary)
                            MonoLabel(text: "Add Widget")
                        }
                    }
                }

                HStack {
                    HStack(spacing: 4) {
                        MonoLabel(text: "Slot \(index + 1)")
                        if isFocused {
                            Image(systemName: "scope")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(DriveColors.primary)
                        }
                    }
                    Spacer()
                    Text(resolvedName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(draftId != nil ? DriveColors.primary : DriveColors.mutedFg)
                        .lineLimit(1)
                }
                .padding(.horizontal, 4)
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Status Row
struct StatusRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(DriveColors.foreground)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(DriveColors.mutedFg)
        }
    }
}
