import SwiftUI
import UIKit
import PhotosUI

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
                        if let url = URL(string: "https://www.icloud.com/shortcuts/0c111a625ad34db185cfe6556fe87323") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.system(size: 11))
                            Text("Install Shortcut")
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

                        Text("Battery \(store.batteryPercent)% · \(store.isCharging ? "charging · " : "")car linked · GPS speed available")
                            .font(.system(size: 13))
                            .lineSpacing(5)
                            .foregroundColor(DriveColors.mutedFg)

                        HStack(spacing: 16) {
                            MetricBar(icon: store.isCharging ? "battery.100.bolt" : "battery.100",
                                      label: "Battery",
                                      value: "\(store.batteryPercent)%",
                                      progress: Double(store.batteryPercent) / 100)
                            let currentSpeed = Int(TelemetryService.shared.currentSpeed)
                            MetricBar(icon: "gauge.with.dots.needle.bottom.50percent",
                                      label: "GPS speed",
                                      value: currentSpeed > 0 ? "\(currentSpeed) km/h" : "-- km/h",
                                      progress: min(Double(currentSpeed) / 240.0, 1.0))
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
                            }) {
                                SlotCell(index: i, draftId: store.slots[i])
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

                        StatusRow(icon: "checkmark.circle", iconColor: DriveColors.success,
                                  label: "Telemetry permissions", value: "Granted")
                        Divider().background(DriveColors.border).padding(.vertical, 12)
                        StatusRow(icon: "battery.100", iconColor: DriveColors.success,
                                  label: "Battery reporting", value: "\(store.batteryPercent)%")
                        Divider().background(DriveColors.border).padding(.vertical, 12)
                        StatusRow(
                            icon: "checkmark.circle",
                            iconColor: store.slots.compactMap({$0}).isEmpty ? DriveColors.warning : DriveColors.success,
                            label: "WidgetKit sync",
                            value: store.slots.compactMap({$0}).isEmpty ? "No slots" : "Active"
                        )

                        Spacer().frame(height: 20)
                        Button(action: {}) {
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
    }
}

// MARK: - Slot Cell
struct SlotCell: View {
    let index: Int
    let draftId: String?
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
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(DriveColors.border.opacity(0.4), lineWidth: 1))
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
                    MonoLabel(text: "Slot \(index + 1)")
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
