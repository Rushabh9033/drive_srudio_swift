import SwiftUI

extension Color {
    /// Parse a hex color string. Returns opaque black for malformed input
    /// to preserve backward compatibility with the dozens of call sites
    /// that assume a non-optional `Color`.
    init(hex: String) {
        var s = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        if s.count == 6 {
            self.init(.sRGB, red: Double((v & 0xFF0000) >> 16) / 255, green: Double((v & 0x00FF00) >> 8) / 255, blue: Double(v & 0x0000FF) / 255, opacity: 1.0)
        } else if s.count == 8 {
            self.init(.sRGB, red: Double((v & 0x00FF0000) >> 16) / 255, green: Double((v & 0x0000FF00) >> 8) / 255, blue: Double(v & 0x000000FF) / 255, opacity: Double((v & 0xFF000000) >> 24) / 255)
        } else {
            self.init(.sRGB, red: 0, green: 0, blue: 0, opacity: 1)
        }
    }

    /// Convenience used by canvas-rendering sites that want to swap in a
    /// sensible fallback for unparseable strings instead of opaque black.
    init(hex: String, fallback: Color) {
        self = Color(hexOptional: hex) ?? fallback
    }

    init(_ hex: String) {
        self.init(hex: hex)
    }

    /// Failable hex initializer for callers that want to react to
    /// malformed input (e.g. by swapping in a default color).
    init?(hexOptional: String?) {
        guard let hex = hexOptional, !hex.isEmpty else { return nil }
        self.init(hex: hex)
    }
}