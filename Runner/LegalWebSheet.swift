import SwiftUI

enum LegalContentType: String, Identifiable {
    case privacyPolicy = "Privacy Policy"
    case termsOfUse = "Terms of Use"

    var id: String { rawValue }

    var title: String { rawValue }

    var bodyText: String {
        switch self {
        case .privacyPolicy:
            return """
            Privacy Policy for Drive Studio

            Last updated: August 13, 2026

            1. Data Storage & Privacy
            Drive Studio respects your privacy. All your vehicle designs, dashboard templates, custom images, and telemetry data (battery level, GPS speed) are stored strictly on your local device inside your secure App Group container (group.com.drivestudio.shared).

            2. No Third-Party Tracking
            Drive Studio does NOT collect, transmit, sell, or share any personal data, location data, or telemetry to external servers or third-party analytics services.

            3. Location Usage
            Drive Studio reads device location solely while the app is active to display real-time GPS speed on speedometer widgets. Location data is processed locally on-device and is never logged or exported.

            4. Photo Library Access
            Photo library permissions are used exclusively for importing vehicle artwork and layer graphics chosen by you.

            5. Contact Us
            If you have any questions regarding privacy, please contact support at support@drivestudio.app.
            """
        case .termsOfUse:
            return """
            Terms of Use for Drive Studio

            Last updated: August 13, 2026

            1. Acceptance of Terms
            By downloading or using Drive Studio, you agree to comply with and be bound by these Terms of Use.

            2. License & Intellectual Property
            Drive Studio grants you a personal, non-transferable, non-exclusive license to use the app for custom vehicle widget styling and instrument cluster customization.

            3. Safety Warning & Responsible Driving
            Drive Studio widgets are designed for vehicle customization and dashboard styling. Always obey traffic laws, maintain focus on the road, and never interact with your mobile device while operating a motor vehicle.

            4. Disclaimer of Warranties
            Drive Studio is provided "AS IS" without warranty of any kind. The developers are not liable for any vehicle operation issues or distracted driving incidents.

            5. Modifications
            We reserve the right to update these terms at any time. Continued use of the application constitutes acceptance of updated terms.
            """
        }
    }
}

struct LegalSheetView: View {
    let contentType: LegalContentType
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            DriveColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    Text(contentType.title)
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
                .padding(.top, 24)
                .padding(.bottom, 16)

                Divider().background(DriveColors.border)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(contentType.bodyText)
                            .font(.system(size: 13, weight: .regular))
                            .lineSpacing(6)
                            .foregroundColor(DriveColors.mutedFg)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
