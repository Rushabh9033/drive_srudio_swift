import SwiftUI

// MARK: - Settings Screen
struct SettingsScreenView: View {
    @EnvironmentObject var store: AppStore
    @AppStorage(AppStore.carConnectedPrefKey) private var carConnected = true
    @State private var showClearConfirm = false
    @State private var showAutomationGuide = false
    @State private var alertMessage = ""
    @State private var showAlertMessage = false
    @State private var selectedLegalType: LegalContentType? = nil

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {

                // Header
                Text("Settings")
                    .font(.system(size: 24, weight: .bold))
                    .tracking(-0.5)
                    .foregroundColor(DriveColors.foreground)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 8)

                // Card 1: Telemetry Status
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                MonoLabel(text: "This iPhone")
                                HStack(spacing: 8) {
                                    Image(systemName: "iphone")
                                        .font(.system(size: 16))
                                        .foregroundColor(DriveColors.primary)
                                    Text("Live telemetry enabled")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(DriveColors.foreground)
                                }
                            }
                            Spacer()
                            DrivePill(label: "Live", selected: true)
                        }
                        Text("Battery level, charging state, and GPS speed are read in real time from this device and written to your widgets.")
                            .font(.system(size: 12))
                            .lineSpacing(5)
                            .foregroundColor(DriveColors.mutedFg)
                    }
                }
                .padding(.horizontal, 20)

                // Card 2: Background Removal
                SurfaceCard {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 16))
                            .foregroundColor(DriveColors.success)
                        Text("Background removal")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(DriveColors.foreground)
                    }
                    Text("Vehicle images are automatically processed to remove backgrounds for a clean widget look.")
                        .font(.system(size: 12))
                        .lineSpacing(5)
                        .foregroundColor(DriveColors.mutedFg)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)

                // Card 3: Device Sync
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 0) {
                        MonoLabel(text: "Device sync").padding(.bottom, 8)

                        ToggleRow(label: "Car connected",
                                  hint: "Manual override for the car link state",
                                  isOn: $carConnected)
                    }
                }
                .padding(.horizontal, 20)



                // Card 4: Local Data
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 0) {
                        MonoLabel(text: "Local data")
                        Text("Last local sync: just now")
                            .font(.system(size: 12))
                            .foregroundColor(DriveColors.mutedFg)
                            .padding(.top, 4)
                            .padding(.bottom, 8)

                        Button(action: {
                            if let data = try? JSONEncoder().encode(store.drafts),
                               let json = String(data: data, encoding: .utf8) {
                                UIPasteboard.general.string = json
                                alertMessage = "Exported \(store.drafts.count) draft(s) to clipboard!"
                                showAlertMessage = true
                            } else {
                                alertMessage = "No drafts available to export."
                                showAlertMessage = true
                            }
                        }) {
                            Text("Export drafts to clipboard")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(DriveColors.foreground)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 12)
                        }
                        Divider().background(DriveColors.border)

                        Button(action: {
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
                        }) {
                            Text("Import drafts from clipboard")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(DriveColors.foreground)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 12)
                        }
                        Divider().background(DriveColors.border)

                        Button(action: {
                            store.clearCustomVehicleImage()
                            alertMessage = "Custom vehicle image cleared!"
                            showAlertMessage = true
                        }) {
                            Text("Clear custom vehicle image")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(DriveColors.foreground)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 12)
                        }
                        Divider().background(DriveColors.border)

                        Button(action: {
                            UserDefaults.standard.set(false, forKey: "has_seen_intro")
                            alertMessage = "Introduction reset!"
                            showAlertMessage = true
                        }) {
                            Text("Reset introduction")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(DriveColors.foreground)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 12)
                        }
                        Divider().background(DriveColors.border)

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

                // Card 5: About & Legal
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 0) {
                        MonoLabel(text: "About & legal")
                        Text("Drive Studio · Version 1.0.0")
                            .font(.system(size: 12))
                            .foregroundColor(DriveColors.mutedFg)
                            .padding(.top, 4)
                            .padding(.bottom, 12)

                        Button(action: {
                            selectedLegalType = .privacyPolicy
                        }) {
                            Text("Privacy Policy")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(DriveColors.foreground)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 12)
                        }
                        Divider().background(DriveColors.border)

                        Button(action: {
                            selectedLegalType = .termsOfUse
                        }) {
                            Text("Terms of Use")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(DriveColors.foreground)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 12)
                        }
                        Divider().background(DriveColors.border)

                        Button(action: {
                            showAutomationGuide = true
                        }) {
                            Text("Setup guide")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(DriveColors.foreground)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 12)
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 104)
            }
        }
        .background(DriveColors.background)
        .onChange(of: carConnected) { newValue in
            // Push the user's manual car-link state into TelemetryService so the
            // next snapshotAndSave() reflects it on the widget timeline.
            TelemetryService.shared.carConnected = newValue
            TelemetryService.shared.snapshotAndSave()
        }
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
}

// MARK: - Toggle Row
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
