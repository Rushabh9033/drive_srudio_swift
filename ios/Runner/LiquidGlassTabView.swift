import SwiftUI
import Flutter

@available(iOS 15.0, *)
struct LiquidGlassTabView: View {
    let flutterViewController: FlutterViewController
    let methodChannel: FlutterMethodChannel
    
    @State private var selectedTab: Int = 0
    @State private var hideNav: Bool = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 1. Flutter Engine Background Layer
            FlutterViewWrapper(viewController: flutterViewController)
                .ignoresSafeArea()
            
            // 2. Liquid Glass Tab Bar Layer
            if !hideNav {
                VStack(spacing: 0) {
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    HStack(spacing: 0) {
                        TabItem(icon: "house.fill", label: "Home", index: 0, selectedIndex: $selectedTab)
                        TabItem(icon: "square.grid.2x2.fill", label: "Studio", index: 1, selectedIndex: $selectedTab)
                        TabItem(icon: "music.note", label: "Sounds", index: 2, selectedIndex: $selectedTab)
                        TabItem(icon: "gearshape", label: "Settings", index: 3, selectedIndex: $selectedTab)
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                    .padding(.bottom, safeAreaBottom) // Add bottom safe area manually if needed
                }
                .background(.regularMaterial)
                .environment(\.colorScheme, .dark) // Force dark mode for Drive Studio aesthetic
            }
        }
        .onAppear {
            methodChannel.setMethodCallHandler { call, result in
                if call.method == "didSetTab" {
                    if let index = call.arguments as? Int {
                        // Keep SwiftUI state in sync if Flutter initiates a route change
                        if selectedTab != index {
                            selectedTab = index
                        }
                    }
                } else if call.method == "setNavHidden" {
                    if let hidden = call.arguments as? Bool {
                        hideNav = hidden
                    }
                }
                result(nil)
            }
        }
        .onChange(of: selectedTab) { newValue in
            // Send new selected tab to Flutter
            methodChannel.invokeMethod("setTab", arguments: newValue)
        }
    }
    
    // Safely grab the bottom safe area
    private var safeAreaBottom: CGFloat {
        let window = UIApplication.shared.windows.first
        return window?.safeAreaInsets.bottom ?? 20
    }
}

@available(iOS 15.0, *)
struct TabItem: View {
    let icon: String
    let label: String
    let index: Int
    @Binding var selectedIndex: Int
    
    var body: some View {
        Button(action: {
            selectedIndex = index
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: selectedIndex == index ? .semibold : .regular))
                Text(label)
                    .font(.system(size: 10, weight: selectedIndex == index ? .bold : .medium))
            }
            .foregroundColor(selectedIndex == index ? Color(red: 0.25, green: 0.55, blue: 1.0) : .gray)
            .frame(maxWidth: .infinity)
        }
    }
}

@available(iOS 15.0, *)
struct FlutterViewWrapper: UIViewControllerRepresentable {
    let viewController: FlutterViewController
    
    func makeUIViewController(context: Context) -> FlutterViewController {
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: FlutterViewController, context: Context) {
        // No update needed
    }
}
