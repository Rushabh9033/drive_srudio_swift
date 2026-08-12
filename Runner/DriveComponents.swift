import SwiftUI

// MARK: - Drive Studio Color System (exact Flutter hex values)
struct DriveColors {
    static let background    = Color(hex: "18181A")
    static let carbon        = Color(hex: "212226")
    static let graphite      = Color(hex: "2A2B30")
    static let secondary     = Color(hex: "2A2B30")
    static let muted         = Color(hex: "27282C")
    static let border        = Color(hex: "33343A")
    static let foreground    = Color(hex: "FAFAFA")
    static let mutedFg       = Color(hex: "A1A3A8")
    static let primary       = Color(hex: "F59E0B")  // amber — THE brand accent
    static let primaryFg     = Color(hex: "451A03")
    static let primaryGlow   = Color(hex: "FFB84D")
    static let destructive   = Color(hex: "EF4444")
    static let success       = Color(hex: "84CC16")
    static let warning       = Color(hex: "EAB308")
}

// Color extension is defined in Color+Hex.swift

// MARK: - Shared UI Components

/// JetBrains Mono style label — used for all data/telemetry text
struct MonoLabel: View {
    let text: String
    var color: Color = DriveColors.mutedFg
    var size: CGFloat = 11

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .medium, design: .monospaced))
            .tracking(1.32)
            .foregroundColor(color)
    }
}

/// SurfaceCard — carbon bg + border, matches Flutter SurfaceCard
struct SurfaceCard<Content: View>: View {
    var padding: EdgeInsets = .init(top: 20, leading: 20, bottom: 20, trailing: 20)
    var onTap: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        Group {
            if let onTap = onTap {
                Button(action: onTap) { inner }
            } else {
                inner
            }
        }
    }

    private var inner: some View {
        content()
            .padding(padding)
            .background(DriveColors.carbon)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(DriveColors.border, lineWidth: 1)
            )
    }
}

/// Amber pill badge
struct DrivePill: View {
    let label: String
    var selected: Bool = true

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .tracking(0.5)
            .foregroundColor(selected ? DriveColors.primary : DriveColors.mutedFg)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(selected ? DriveColors.primary.opacity(0.15) : DriveColors.secondary)
            .cornerRadius(999)
            .overlay(
                Capsule().stroke(selected ? DriveColors.primary.opacity(0.3) : DriveColors.border, lineWidth: 1)
            )
    }
}

/// Progress metric bar
struct MetricBar: View {
    let icon: String
    let label: String
    let value: String
    let progress: Double  // 0.0 – 1.0

    @State private var animatedProgress: Double = 0

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(DriveColors.muted).frame(height: 6)
                    Capsule().fill(DriveColors.primary)
                        .frame(width: geo.size.width * animatedProgress, height: 6)
                }
            }
            .frame(height: 6)

            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(DriveColors.mutedFg)
                MonoLabel(text: label)
                Spacer()
                Text(value)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(DriveColors.foreground)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { animatedProgress = progress }
        }
    }
}
