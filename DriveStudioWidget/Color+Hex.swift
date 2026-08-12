import SwiftUI

extension Color {
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

    init(_ hex: String) {
        self.init(hex: hex)
    }

    init?(hexOptional: String?) {
        guard let hex = hexOptional, !hex.isEmpty else { return nil }
        self.init(hex: hex)
    }
}
