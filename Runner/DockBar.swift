import SwiftUI

/// Editor dock bar — extracted from `EditorScreen` so SwiftUI's
/// type-checker can finish inside the time budget when there are
/// six items (the original inline body timed out with the new
/// `LAYERS` dock item).
///
/// Each item is a button with an SF Symbol and a label; the active
/// dock is highlighted with the brand primary color. The whole bar
/// is rendered as a Liquid Glass capsule with two layered shadows.
struct DockBar: View {
    @Binding var activeDock: String
    let items: [(label: String, icon: String)]
    let onTap: (String) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.label) { item in
                dockButton(item: item)
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.7), .white.opacity(0.15), Color(hex: "00FFFF").opacity(0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color.black.opacity(0.4), radius: 16, x: 0, y: 8)
        .shadow(color: DriveColors.primary.opacity(0.15), radius: 10, x: 0, y: 2)
    }

    private func dockButton(item: (label: String, icon: String)) -> some View {
        let isActive = (activeDock == item.label)
        return Button(action: {
            activeDock = item.label
            onTap(item.label)
        }) {
            VStack(spacing: 4) {
                Image(systemName: item.icon)
                    .font(.system(size: 18, weight: isActive ? .bold : .medium))
                Text(item.label)
                    .font(.system(size: 9, weight: isActive ? .bold : .medium, design: .monospaced))
                    .tracking(1.2)
            }
            .foregroundColor(isActive ? DriveColors.primary : DriveColors.mutedFg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isActive ? DriveColors.primary.opacity(0.18) : Color.clear)
            .cornerRadius(18)
        }
        .buttonStyle(.plain)
    }
}
