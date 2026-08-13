import SwiftUI

// MARK: - Settings Screen
struct SettingsScreenView: View {
    @EnvironmentObject var store: AppStore
    @State private var useLiveData = true
    @State private var carConnected = true
    @State private var playSoundsOnCarLink = true
    @State private var playbackOutput = "iPhone"
    @State private var showClearConfirm = false
    @State private var showAutomationGuide = false
    @State private var alertMessage = ""
    @State private var showAlertMessage = false

    private let playbackOptions = ["iPhone", "Car Audio", "Both"]

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

                        ToggleRow(label: "Use live device data",
                                  hint: "Read battery and GPS from this device",
                                  isOn: $useLiveData)

                        Divider().background(DriveColors.border).padding(.vertical, 12)

                        ToggleRow(label: "Car connected",
                                  hint: "Manual override for the car link state",
                                  isOn: $carConnected)

                        Divider().background(DriveColors.border).padding(.vertical, 12)

                        ToggleRow(label: "Play sounds on car link",
                                  hint: nil,
                                  isOn: $playSoundsOnCarLink)

                        Spacer().frame(height: 16)
                        MonoLabel(text: "Playback output").padding(.bottom, 8)

                        HStack(spacing: 8) {
                            ForEach(playbackOptions, id: \.self) { opt in
                                Button(action: { playbackOutput = opt }) {
                                    Text(opt)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(playbackOutput == opt ? DriveColors.primary : DriveColors.mutedFg)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(playbackOutput == opt ? DriveColors.primary.opacity(0.15) : DriveColors.secondary)
                                        .cornerRadius(999)
                                        .overlay(
                                            Capsule().stroke(playbackOutput == opt ? DriveColors.primary : DriveColors.border, lineWidth: 1)
                                        )
                                }
                            }
                        }
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

                // Card 5: Premium
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            MonoLabel(text: "Premium")
                            Spacer()
                            DrivePill(label: "Free", selected: false)
                        }

                        Text("Unlock all templates, sounds, and advanced layer tools.")
                            .font(.system(size: 12))
                            .lineSpacing(5)
                            .foregroundColor(DriveColors.mutedFg)

                        Button(action: {}) {
                            HStack(spacing: 8) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 14))
                                Text("Unlock Premium")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(DriveColors.primaryFg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(DriveColors.primary)
                            .cornerRadius(12)
                        }

                        Button("Restore purchases") {}
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(DriveColors.foreground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(DriveColors.secondary)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(DriveColors.border, lineWidth: 1))
                    }
                }
                .padding(.horizontal, 20)

                // Card 6: About & Legal
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 0) {
                        MonoLabel(text: "About & legal")
                        Text("Drive Studio · Version 1.0.0")
                            .font(.system(size: 12))
                            .foregroundColor(DriveColors.mutedFg)
                            .padding(.top, 4)
                            .padding(.bottom, 12)

                        ForEach(["Privacy Policy", "Terms of Use", "Setup guide"], id: \.self) { item in
                            Button(action: {}) {
                                Text(item)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(DriveColors.foreground)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 12)
                            }
                            if item != "Setup guide" {
                                Divider().background(DriveColors.border)
                            }
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
