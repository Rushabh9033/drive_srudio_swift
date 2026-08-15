import SwiftUI

// MARK: - App Group UserDefaults (for widget-shared preferences)
//
// Settings that must be visible to the widget extension (speed unit)
// live in the App Group suite rather than the standard suite. Sound
// triggers already use the App Group suite (see `SoundsScreen.swift`)
// so the Settings screen reads them from the same place.
private let settingsAppGroupStore = UserDefaults(suiteName: "group.com.drivestudio.shared")

/// Section header style — uppercase mono label with horizontal padding
/// matching the card width below it. Inlined into each section header
/// to avoid an escaping-closure capture issue when wrapping content.
private func sectionHeader(_ title: String) -> some View {
    MonoLabel(text: title.uppercased())
        .padding(.horizontal, 20)
}

/// Bundle version (CFBundleShortVersionString) with build number
/// (CFBundleVersion) appended when available, e.g. "1.0.0 (42)".
/// Free function so the About card can evaluate it inline.
private func appVersionString() -> String {
    let info = Bundle.main.infoDictionary
    let short = info?["CFBundleShortVersionString"] as? String ?? "—"
    let build = info?["CFBundleVersion"] as? String
    if let build = build, !build.isEmpty {
        return "\(short) (\(build))"
    }
    return short
}

/// Format the most-recent App Group telemetry snapshot timestamp
/// as a human-readable relative time. Free function (not a method
/// on SettingsScreenView) so it can be evaluated at render time
/// without capturing `self`.
///
/// `@MainActor` because `AppStore` is `@MainActor`-isolated and the
/// body of this helper reaches into it.
@MainActor
private func lastSyncLabel(for store: AppStore) -> String {
    guard let date = store.lastTelemetrySyncDate() else {
        return "Last local sync: never"
    }
    let interval = Date().timeIntervalSince(date)
    if interval < 60 {
        return "Last local sync: just now"
    } else if interval < 60 * 60 {
        let mins = Int(interval / 60)
        return "Last local sync: \(mins) min ago"
    } else if interval < 60 * 60 * 24 {
        let hours = Int(interval / (60 * 60))
        return "Last local sync: \(hours) h ago"
    } else {
        let days = Int(interval / (60 * 60 * 24))
        return "Last local sync: \(days) d ago"
    }
}

// MARK: - Settings Screen
struct SettingsScreenView: View {
    @EnvironmentObject var store: AppStore
    @State private var showClearConfirm = false
    @State private var showAutomationGuide = false
    @State private var alertMessage = ""
    @State private var showAlertMessage = false
    @State private var selectedLegalType: LegalContentType? = nil

    // MARK: - Sound triggers (App Group)
    //
    // Reads the same `trigger_*` keys that `SoundsScreen.swift` writes
    // (`group.com.drivestudio.shared` suite). Defaults match the
    // bundled fallbacks in `TelemetryService.fallbackSound(for:)`.
    @AppStorage("trigger_Connect", store: settingsAppGroupStore) private var connectTrigger: String = "Welcome Back"
    @AppStorage("trigger_Disconnect", store: settingsAppGroupStore) private var disconnectTrigger: String = "Goodbye"
    @AppStorage("trigger_Reminder", store: settingsAppGroupStore) private var reminderTrigger: String = "Phone Keys Wallet"

    // MARK: - Speed unit (App Group)
    //
    // Stored in the App Group suite so the widget extension can read
    // the same value at render time. Default `kmh` matches today's
    // behavior — every speed site currently renders km/h — so the
    // change is a no-op until the user actively picks mph.
    @AppStorage("settings.speedUnit", store: settingsAppGroupStore) private var speedUnit: String = "kmh"

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {

                // Header
                Text("Settings")
                    .font(.system(size: 24, weight: .bold))
                    .tracking(-0.5)
                    .foregroundColor(DriveColors.foreground)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 4)

                // Driving
                sectionHeader("Driving")
                SurfaceCard(padding: .init(top: 16, leading: 16, bottom: 16, trailing: 16)) {
                    VStack(spacing: 0) {
                        statusRow(
                            icon: "iphone",
                            iconColor: DriveColors.primary,
                            title: "Live telemetry",
                            subtitle: "Battery, charging state, and GPS speed are read in real time from this device and written to your widgets.",
                            trailing: AnyView(DrivePill(label: "Live", selected: true))
                        )
                        divider()
                        statusRow(
                            icon: "location.viewfinder",
                            iconColor: DriveColors.success,
                            title: "Auto-detect driving",
                            subtitle: "Car link status is set automatically from GPS motion: linked above 7 km/h, unlinked after 5 minutes of no movement. No manual override.",
                            trailing: nil
                        )
                    }
                }
                .padding(.horizontal, 20)

                // Display
                sectionHeader("Display")
                SurfaceCard(padding: .init(top: 16, leading: 16, bottom: 16, trailing: 16)) {
                    VStack(spacing: 0) {
                        speedUnitRow
                        divider()
                        infoRow(
                            icon: "checkmark.shield.fill",
                            iconColor: DriveColors.success,
                            title: "Background removal",
                            subtitle: "Uploaded vehicle images are automatically processed to remove backgrounds for a clean widget look."
                        )
                    }
                }
                .padding(.horizontal, 20)

                // Sounds
                sectionHeader("Sounds")
                SurfaceCard(padding: .init(top: 16, leading: 16, bottom: 16, trailing: 16)) {
                    VStack(spacing: 0) {
                        triggerRow(icon: "link.circle.fill", iconColor: DriveColors.primary, label: "Connect", assigned: connectTrigger)
                        divider()
                        triggerRow(icon: "power", iconColor: DriveColors.destructive, label: "Disconnect", assigned: disconnectTrigger)
                        divider()
                        triggerRow(icon: "bell.fill", iconColor: Color.orange, label: "Reminder", assigned: reminderTrigger)
                    }
                }
                .padding(.horizontal, 20)

                // Local Data
                sectionHeader("Local data")
                SurfaceCard(padding: .init(top: 16, leading: 16, bottom: 16, trailing: 16)) {
                    VStack(spacing: 0) {
                        // Real "last sync" label — reads the most
                        // recent telemetry snapshot timestamp from the
                        // App Group. The previous version hardcoded
                        // "just now" which never updated. The label
                        // re-renders whenever the body is invalidated
                        // (settings open, app foreground, etc.) and
                        // because AppStore is an `@EnvironmentObject`
                        // any live-telemetry write will also invalidate
                        // it.
                        Text(lastSyncLabel(for: store))
                            .font(.system(size: 12))
                            .foregroundColor(DriveColors.mutedFg)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 8)

                        localDataButton("Export drafts to clipboard") {
                            if let data = try? JSONEncoder().encode(store.drafts),
                               let json = String(data: data, encoding: .utf8) {
                                UIPasteboard.general.string = json
                                alertMessage = "Exported \(store.drafts.count) draft(s) to clipboard!"
                                showAlertMessage = true
                            } else {
                                alertMessage = "No drafts available to export."
                                showAlertMessage = true
                            }
                        }
                        divider()
                        localDataButton("Import drafts from clipboard") {
                            if let json = UIPasteboard.general.string,
                               let data = json.data(using: .utf8),
                               let importedDrafts = try? JSONDecoder().decode([Draft].self, from: data) {
                                for d in importedDrafts {
                                    store.saveDraft(d)
                                }
                                alertMessage = "Successfully imported \(importedDrafts.count) draft(s)!"
                                showAlertMessage = true
                            } else {
                                alertMessage = "Clipboard does not contain valid draft JSON."
                                showAlertMessage = true
                            }
                        }
                        divider()
                        localDataButton("Clear custom vehicle image") {
                            store.clearCustomVehicleImage()
                            alertMessage = "Custom vehicle image cleared!"
                            showAlertMessage = true
                        }
                        divider()
                        localDataButton("Reset introduction") {
                            UserDefaults.standard.set(false, forKey: "has_seen_intro")
                            alertMessage = "Introduction reset!"
                            showAlertMessage = true
                        }
                        divider()
                        Button(action: { showClearConfirm = true }) {
                            Text("Clear drafts")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(DriveColors.destructive)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 12)
                        }
                    }
                }
                .padding(.horizontal, 20)

                // About & Legal
                sectionHeader("About & legal")
                SurfaceCard(padding: .init(top: 16, leading: 16, bottom: 16, trailing: 16)) {
                    VStack(spacing: 0) {
                        // Bundle version + build, read from Info.plist
                        // at runtime. The previous hardcoded "1.0.0"
                        // would silently drift from the actual shipped
                        // version as soon as the build number changed.
                        Text("Drive Studio · Version \(appVersionString())")
                            .font(.system(size: 12))
                            .foregroundColor(DriveColors.mutedFg)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 12)

                        localDataButton("Privacy Policy") {
                            selectedLegalType = .privacyPolicy
                        }
                        divider()
                        localDataButton("Terms of Use") {
                            selectedLegalType = .termsOfUse
                        }
                        divider()
                        localDataButton("Setup guide") {
                            showAutomationGuide = true
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 104)
            }
        }
        .background(DriveColors.background)
        .alert("Clear all drafts?", isPresented: $showClearConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                store.clearAllDrafts()
                alertMessage = "All drafts cleared!"
                showAlertMessage = true
            }
        } message: {
            Text("This will permanently remove all your saved widget drafts.")
        }
        .alert(alertMessage, isPresented: $showAlertMessage) {
            Button("OK", role: .cancel) {}
        }
        .sheet(isPresented: $showAutomationGuide) {
            AutomationGuideSheet()
        }
        .sheet(item: $selectedLegalType) { legalType in
            LegalSheetView(contentType: legalType)
        }
    }

    // MARK: - Row builders

    // All rows share the same icon column (28pt, center-aligned at the
    // top of the row) and the same HStack spacing so multi-line content
    // rows don't visually drift apart when stacked in a single card.
    private let iconColumnWidth: CGFloat = 28
    private let rowSpacing: CGFloat = 14

    private func statusRow(icon: String, iconColor: Color, title: String, subtitle: String, trailing: AnyView?) -> some View {
        HStack(alignment: .top, spacing: rowSpacing) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: iconColumnWidth, alignment: .center)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DriveColors.foreground)
                Text(subtitle)
                    .font(.system(size: 12))
                    .lineSpacing(4)
                    .foregroundColor(DriveColors.mutedFg)
            }
            Spacer(minLength: 8)
            if let trailing = trailing {
                trailing
            }
        }
    }

    private func infoRow(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: rowSpacing) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: iconColumnWidth, alignment: .center)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DriveColors.foreground)
                Text(subtitle)
                    .font(.system(size: 12))
                    .lineSpacing(4)
                    .foregroundColor(DriveColors.mutedFg)
            }
            Spacer(minLength: 8)
        }
    }

    private func localDataButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DriveColors.foreground)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
        }
    }

    private var speedUnitRow: some View {
        HStack(alignment: .top, spacing: rowSpacing) {
            Image(systemName: "speedometer")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(DriveColors.primary)
                .frame(width: iconColumnWidth, alignment: .center)
            VStack(alignment: .leading, spacing: 8) {
                Text("Speed unit")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DriveColors.foreground)
                Picker("Speed unit", selection: $speedUnit) {
                    Text("km/h").tag("kmh")
                    Text("mph").tag("mph")
                }
                .pickerStyle(.segmented)
            }
            Spacer(minLength: 8)
        }
    }

    private func triggerRow(icon: String, iconColor: Color, label: String, assigned: String) -> some View {
        HStack(alignment: .center, spacing: rowSpacing) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: iconColumnWidth, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DriveColors.foreground)
                Text(displayName(for: assigned))
                    .font(.system(size: 12))
                    .foregroundColor(displayColor(for: assigned))
            }
            Spacer(minLength: 8)
        }
    }

    private func displayName(for value: String) -> String {
        if value.isEmpty || value == "none" { return "Not assigned" }
        return value
    }

    private func displayColor(for value: String) -> Color {
        if value.isEmpty || value == "none" { return DriveColors.mutedFg }
        return DriveColors.primary
    }

    private func divider() -> some View {
        Divider().background(DriveColors.border)
    }
}

// MARK: - Toggle Row
//
// Kept here because some sheets may still reference it; no longer used
// by `SettingsScreenView` after the manual `carConnected` toggle was
// removed (the car-link state is auto-detected from GPS).
struct ToggleRow: View {
    let label: String
    let hint: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: hint != nil ? .top : .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DriveColors.foreground)
                if let hint = hint {
                    Text(hint)
                        .font(.system(size: 12))
                        .foregroundColor(DriveColors.mutedFg)
                }
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .tint(DriveColors.primary)
                .labelsHidden()
        }
    }
}
