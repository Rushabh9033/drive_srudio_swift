import SwiftUI

@available(iOS 15.0, *) // Fallback for standard iOS versions, assuming iOS 26+ compatible
public struct LiquidGlassTabView: View {
    @State private var selectedTab = 0
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            // Main Content Area with fading modifier applied
            TabView(selection: $selectedTab) {
                Color.red
                    .ignoresSafeArea()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(0)
                
                Color.blue
                    .ignoresSafeArea()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .tag(1)
                
                Color.green
                    .ignoresSafeArea()
                    .tabItem {
                        Label("Profile", systemImage: "person.crop.circle")
                    }
                    .tag(2)
            }
            // Apple standard translucent material effect for TabBar is automatic in iOS 15+,
            // but we apply our "Deliquified Glass" custom modifier to the background content
            // to ensure text readability underneath.
            .modifier(TabBarFadeModifier())
            
            // Floating accessory button (e.g., "Create")
            Button(action: {
                print("Create tapped")
            }) {
                Image(systemName: "plus")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                    .padding(16)
                    .background(Color.accentColor)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
            // Positioned slightly above the standard tab bar safe area
            .padding(.bottom, 90)
        }
    }
}

/// A "Deliquified Glass" fix modifier.
/// Since extreme liquid glass blur can make labels unreadable over colorful content,
/// this modifier fades the bottom of the content area behind the tab bar using a gradient.
public struct TabBarFadeModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .overlay(
                VStack {
                    Spacer()
                    // Gradient from clear to system background color at 85% opacity
                    // Adjust the opacity or height here to control the fade intensity.
                    LinearGradient(
                        colors: [
                            Color(UIColor.systemBackground).opacity(0.0),
                            Color(UIColor.systemBackground).opacity(0.85)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120) // Height of the fade covering the tab bar area
                    .allowsHitTesting(false) // Pass touches through to the TabView
                }
                .ignoresSafeArea(edges: .bottom)
            )
    }
}

#Preview {
    if #available(iOS 15.0, *) {
        LiquidGlassTabView()
    } else {
        Text("Requires iOS 15+")
    }
}
