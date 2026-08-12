import SwiftUI

struct EditorTarget: Identifiable {
    let id: String
}

// MARK: - App Shell using native iOS Liquid Glass TabBar
struct HomeScreen: View {
    @EnvironmentObject var store: AppStore
    @State private var editorTarget: EditorTarget? = nil
    @State private var selectedTab: Int = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab Content
            Group {
                switch selectedTab {
                case 0:
                    DashboardView(
                        onOpenEditor: { id in
                            editorTarget = EditorTarget(id: id)
                        },
                        selectedTab: $selectedTab
                    )
                case 1:
                    PremiumWidgetGalleryView(onOpenEditor: { id in
                        editorTarget = EditorTarget(id: id)
                    })
                case 2:
                    SoundsScreenView()
                case 3:
                    SettingsScreenView()
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Floating Liquid Glass Tab Bar (Centered Pill)
            HStack(spacing: 16) {
                TabButton(icon: "house.fill", title: "Home", isSelected: selectedTab == 0) { selectedTab = 0 }
                TabButton(icon: "square.grid.2x2.fill", title: "Studio", isSelected: selectedTab == 1) { selectedTab = 1 }
                
                // Elevated Center "Custom" Creator Button
                Button(action: {
                    editorTarget = EditorTarget(id: "new")
                }) {
                    VStack(spacing: 2) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [DriveColors.primary, DriveColors.primary.opacity(0.85), Color(hex: "00FFFF")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 46, height: 46)
                                .shadow(color: DriveColors.primary.opacity(0.55), radius: 10, x: 0, y: 4)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .black))
                                .foregroundColor(.black)
                        }
                        Text("Custom")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(DriveColors.primary)
                    }
                }
                .offset(y: -10)
                
                TabButton(icon: "music.note", title: "Sounds", isSelected: selectedTab == 2) { selectedTab = 2 }
                TabButton(icon: "gearshape.fill", title: "Settings", isSelected: selectedTab == 3) { selectedTab = 3 }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
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
            .padding(.bottom, 2)
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(item: $editorTarget) { target in
            EditorScreen(draftId: target.id)
                .environmentObject(store)
        }
    }
}

struct TabButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: isSelected ? .bold : .medium))
                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
            }
            .foregroundColor(isSelected ? DriveColors.primary : .gray)
            .frame(width: 50, height: 44)
            .contentShape(Rectangle())
            .scaleEffect(isSelected ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
    }
}
