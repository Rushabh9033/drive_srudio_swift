import SwiftUI

struct AutomationGuideSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            DriveColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Top Bar ─────────────────────────────────────────────
                HStack {
                    Spacer()

                    Text("CarPlay Automation Setup")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(DriveColors.foreground)

                    Spacer()

                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(DriveColors.primary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 16)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {

                        // Header Banner
                        VStack(alignment: .leading, spacing: 6) {
                            MonoLabel(text: "AUTOMATIC HANDS-FREE SYNC")
                            Text("How to Enable Auto-Refresh on Car Link")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(DriveColors.foreground)

                            Text("Set up a 1-time iOS Personal Automation so Drive Studio updates widget timelines and plays sound cues automatically when you connect to your car.")
                                .font(.system(size: 13))
                                .lineSpacing(4)
                                .foregroundColor(DriveColors.mutedFg)
                        }

                        // Bluetooth Notice Callout
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(DriveColors.primary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Bluetooth / USB Connection Required")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(DriveColors.foreground)
                                Text("Make sure your iPhone Bluetooth is turned ON and paired to your vehicle (or connected via USB cable) for automatic car link detection.")
                                    .font(.system(size: 12))
                                    .lineSpacing(3)
                                    .foregroundColor(DriveColors.mutedFg)
                            }
                        }
                        .padding(.all, 14)
                        .background(DriveColors.primary.opacity(0.12))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(DriveColors.primary.opacity(0.4), lineWidth: 1))

                        Divider().background(DriveColors.border)

                        // Step 1
                        GuideStepRow(
                            stepNumber: "1",
                            title: "Open Shortcuts -> Automation Tab",
                            description: "Open Shortcuts App on your iPhone and tap the 'Automation' tab at the bottom middle. Tap 'New Automation' (or '+' icon at the top right if you already have existing automations).",
                            icon: "clock.fill"
                        )

                        // Step 2
                        GuideStepRow(
                            stepNumber: "2",
                            title: "Search & Select 'CarPlay'",
                            description: "Search for 'CarPlay' in the search bar and tap 'CarPlay (\"When CarPlay is connected\")'.",
                            icon: "car.fill"
                        )

                        // Step 3
                        GuideStepRow(
                            stepNumber: "3",
                            title: "Select 'Is Connected' & 'Run Immediately'",
                            description: "Select 'Is Connected' for Connect (or 'Is Disconnected' for Disconnect). Select 'Run Immediately' and tap 'Next' at the top right.",
                            icon: "bolt.fill"
                        )

                        // Step 4
                        GuideStepRow(
                            stepNumber: "4",
                            title: "Search 'Drive Studio' & Choose Cue",
                            description: "Search for 'Drive Studio' in the action bar. Choose 'Play Connect Cue' (or 'Status' / 'Refresh Widget') -> Tap Done! (Repeat same steps tapping '+' for Disconnect Cue).",
                            icon: "speaker.wave.2.fill"
                        )

                        Spacer().frame(height: 10)

                        // Open Shortcuts App Button
                        Button(action: {
                            if let url = URL(string: "shortcuts://") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 15))
                                Text("Open iOS Shortcuts App Now")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .foregroundColor(DriveColors.primaryFg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(DriveColors.primary)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct GuideStepRow: View {
    let stepNumber: String
    let title: String
    let description: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(DriveColors.primary.opacity(0.15))
                    .frame(width: 36, height: 36)
                Text(stepNumber)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(DriveColors.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundColor(DriveColors.primary)
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(DriveColors.foreground)
                }

                Text(description)
                    .font(.system(size: 13))
                    .lineSpacing(3)
                    .foregroundColor(DriveColors.mutedFg)
            }
        }
        .padding(.all, 14)
        .background(DriveColors.carbon)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(DriveColors.border, lineWidth: 1))
    }
}
