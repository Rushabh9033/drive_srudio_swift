import SwiftUI

struct WidgetLibrarySheet: View {
    @Environment(\.dismiss) var dismiss
    
    var onSelect: ([WidgetLayer]) -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    
                    // ── 1. Full Stock Widgets (Ready-to-Use Dashboards) ──────
                    SectionView(
                        title: "Full Stock Widgets",
                        subtitle: "Complete pre-built dashboard layouts",
                        items: [
                            LibraryItem(name: "Neon Cyber Matrix", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "07070F", opacity: 1.0, radius: 20),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "CYBER MATRIX", x: 8, y: 8, w: 45, h: 8, fontSize: 11, weight: 800, align: "left", color: "FFB84D", opacity: 0.9),
                                WidgetLayer(id: UUID().uuidString, kind: "clock", x: 55, y: 8, w: 37, h: 10, fontSize: 13, weight: 600, align: "right", color: "FFFFFF"),
                                WidgetLayer(id: UUID().uuidString, kind: "image", src: "template_car", x: 12, y: 22, w: 76, h: 32),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 15, y: 55, w: 70, h: 2, color: "FFB84D", opacity: 0.6, radius: 1),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 6, y: 62, w: 88, h: 28, color: "FFFFFF", opacity: 0.06, radius: 12),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "SPEED", x: 10, y: 65, w: 30, h: 6, fontSize: 9, weight: 600, align: "left", color: "A0A0A0"),
                                WidgetLayer(id: UUID().uuidString, kind: "speed", x: 10, y: 72, w: 35, h: 14, fontSize: 20, weight: 900, align: "left", color: "FFFFFF"),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "BATTERY", x: 52, y: 65, w: 38, h: 6, fontSize: 9, weight: 600, align: "right", color: "A0A0A0"),
                                WidgetLayer(id: UUID().uuidString, kind: "battery", x: 52, y: 72, w: 38, h: 14, fontSize: 18, weight: 800, align: "right", color: "4DC98A")
                            ]),
                            LibraryItem(name: "Apex Cockpit", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "12131C", opacity: 1.0, radius: 20),
                                WidgetLayer(id: UUID().uuidString, kind: "date", x: 8, y: 8, w: 50, h: 8, fontSize: 10, weight: 600, align: "left", color: "00FFFF"),
                                WidgetLayer(id: UUID().uuidString, kind: "clock", x: 8, y: 16, w: 55, h: 14, fontSize: 20, weight: 800, align: "left", color: "FFFFFF"),
                                WidgetLayer(id: UUID().uuidString, kind: "image", src: "template_car", x: 18, y: 32, w: 64, h: 30),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 8, y: 66, w: 84, h: 24, color: "000000", opacity: 0.4, radius: 12),
                                WidgetLayer(id: UUID().uuidString, kind: "battery", x: 14, y: 71, w: 36, h: 12, fontSize: 14, weight: 700, align: "left", color: "4DC98A"),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "DRIVE MODE", x: 50, y: 72, w: 36, h: 10, fontSize: 9, weight: 600, align: "right", color: "00FFFF")
                            ]),
                            LibraryItem(name: "Charge Arc Horizon", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "0B132B", opacity: 1.0, radius: 20),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "circle", x: 20, y: 15, w: 60, h: 60, color: "1C2541", opacity: 0.8, radius: 30),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "ring", x: 24, y: 19, w: 52, h: 52, color: "4DC98A", opacity: 1.0, radius: 26),
                                WidgetLayer(id: UUID().uuidString, kind: "battery", x: 24, y: 34, w: 52, h: 14, fontSize: 16, weight: 900, align: "center", color: "FFFFFF"),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "SYSTEM POWER", x: 20, y: 52, w: 60, h: 6, fontSize: 8, weight: 700, align: "center", color: "4DC98A"),
                                WidgetLayer(id: UUID().uuidString, kind: "clock", x: 10, y: 80, w: 80, h: 10, fontSize: 12, weight: 600, align: "center", color: "FFFFFF")
                            ]),
                            LibraryItem(name: "Tokyo Neon HUD", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "0D021A", opacity: 1.0, radius: 20),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "TOKYO HUD", x: 8, y: 8, w: 45, h: 8, fontSize: 10, weight: 800, align: "left", color: "FF007F"),
                                WidgetLayer(id: UUID().uuidString, kind: "clock", x: 55, y: 8, w: 37, h: 10, fontSize: 12, weight: 700, align: "right", color: "00FFFF"),
                                WidgetLayer(id: UUID().uuidString, kind: "speed", x: 8, y: 22, w: 50, h: 22, fontSize: 32, weight: 900, align: "left", color: "FFFFFF"),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "KM/H", x: 60, y: 32, w: 25, h: 8, fontSize: 10, weight: 800, align: "left", color: "FF007F"),
                                WidgetLayer(id: UUID().uuidString, kind: "image", src: "template_car", x: 15, y: 50, w: 70, h: 28),
                                WidgetLayer(id: UUID().uuidString, kind: "battery", x: 8, y: 81, w: 84, h: 10, fontSize: 12, weight: 700, align: "center", color: "00FFFF")
                            ]),
                            LibraryItem(name: "Carbon Performance", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "18181F", opacity: 1.0, radius: 20),
                                WidgetLayer(id: UUID().uuidString, kind: "vehicle_name", x: 8, y: 8, w: 50, h: 8, fontSize: 11, weight: 800, align: "left", color: "FFFFFF"),
                                WidgetLayer(id: UUID().uuidString, kind: "image", src: "template_car", x: 12, y: 20, w: 76, h: 36),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 8, y: 60, w: 84, h: 30, color: "FFFFFF", opacity: 0.08, radius: 12),
                                WidgetLayer(id: UUID().uuidString, kind: "battery", x: 14, y: 68, w: 38, h: 14, fontSize: 16, weight: 800, align: "left", color: "4DC98A"),
                                WidgetLayer(id: UUID().uuidString, kind: "clock", x: 52, y: 68, w: 36, h: 14, fontSize: 14, weight: 700, align: "right", color: "F59E0B")
                            ])
                        ],
                        onSelect: onSelect,
                        dismiss: dismiss
                    )
                    



                    // ── 6. Telemetry & Cockpit Dashboard Widgets (18 Widgets) ─
                    SectionView(
                        title: "Telemetry & Cockpit Widgets",
                        subtitle: "High-detail telemetry gauges & cockpits",
                        items: [
                            LibraryItem(name: "Orbit Date Ring", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "ring", x: 10, y: 10, w: 80, h: 80, color: "185FA5", opacity: 0.8, radius: 40),
                                WidgetLayer(id: UUID().uuidString, kind: "clock", x: 10, y: 32, w: 80, h: 22, fontSize: 26, weight: 900, align: "center", color: "FFFFFF"),
                                WidgetLayer(id: UUID().uuidString, kind: "date", x: 10, y: 58, w: 80, h: 10, fontSize: 10, weight: 600, align: "center", color: "378ADD")
                            ]),
                            LibraryItem(name: "Noir Gold Frame", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "F0C040", opacity: 0.9, radius: 17),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 9, y: 9, w: 82, h: 82, color: "0A0A0A", opacity: 1.0, radius: 14),
                                WidgetLayer(id: UUID().uuidString, kind: "clock", x: 10, y: 26, w: 80, h: 32, fontSize: 34, weight: 900, align: "center", color: "F0C040"),
                                WidgetLayer(id: UUID().uuidString, kind: "date", x: 10, y: 64, w: 80, h: 10, fontSize: 11, weight: 700, align: "center", color: "C8902A")
                            ]),
                            LibraryItem(name: "Command Center HUD", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "0D1A2A", opacity: 0.95, radius: 14),
                                WidgetLayer(id: UUID().uuidString, kind: "clock", x: 10, y: 14, w: 80, h: 18, fontSize: 24, weight: 900, align: "center", color: "00E5FF"),
                                WidgetLayer(id: UUID().uuidString, kind: "speed", x: 10, y: 40, w: 80, h: 24, fontSize: 26, weight: 900, align: "center", color: "FF6B35"),
                                WidgetLayer(id: UUID().uuidString, kind: "battery", x: 10, y: 68, w: 80, h: 16, fontSize: 14, weight: 800, align: "center", color: "22C55E")
                            ]),
                            LibraryItem(name: "Vortex Drive Ring", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "ring", x: 10, y: 10, w: 80, h: 80, color: "7C3AED", opacity: 0.8, radius: 40),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "ring", x: 20, y: 20, w: 60, h: 60, color: "F97316", opacity: 0.8, radius: 30),
                                WidgetLayer(id: UUID().uuidString, kind: "clock", x: 10, y: 36, w: 80, h: 16, fontSize: 18, weight: 900, align: "center", color: "FFFFFF"),
                                WidgetLayer(id: UUID().uuidString, kind: "speed", x: 10, y: 54, w: 80, h: 14, fontSize: 14, weight: 800, align: "center", color: "F97316")
                            ]),
                            LibraryItem(name: "Grid HUD Telemetry", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 6, y: 6, w: 42, h: 42, color: "0D1A1A", opacity: 0.9, radius: 12),
                                WidgetLayer(id: UUID().uuidString, kind: "speed", x: 8, y: 14, w: 38, h: 18, fontSize: 18, weight: 900, align: "center", color: "00F0FF"),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 52, y: 6, w: 42, h: 42, color: "0D1A1A", opacity: 0.9, radius: 12),
                                WidgetLayer(id: UUID().uuidString, kind: "battery", x: 54, y: 14, w: 38, h: 18, fontSize: 16, weight: 900, align: "center", color: "22C55E"),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 6, y: 52, w: 88, h: 42, color: "1A2020", opacity: 0.9, radius: 12),
                                WidgetLayer(id: UUID().uuidString, kind: "clock", x: 10, y: 58, w: 80, h: 20, fontSize: 22, weight: 900, align: "center", color: "FFFFFF")
                            ]),
                            LibraryItem(name: "Cockpit Analog & Speed", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "analog", x: 15, y: 15, w: 70, h: 70, color: "FFFFFF", opacity: 1.0),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 25, y: 78, w: 50, h: 16, color: "1A0A0A", opacity: 0.9, radius: 8),
                                WidgetLayer(id: UUID().uuidString, kind: "speed", x: 25, y: 80, w: 50, h: 12, fontSize: 12, weight: 900, align: "center", color: "FF6B35")
                            ]),
                            LibraryItem(name: "Phantom EV Header", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 36, color: "7C3AED", opacity: 0.9, radius: 14),
                                WidgetLayer(id: UUID().uuidString, kind: "clock", x: 10, y: 6, w: 80, h: 22, fontSize: 24, weight: 900, align: "center", color: "FFFFFF"),
                                WidgetLayer(id: UUID().uuidString, kind: "vehicle_name", x: 10, y: 44, w: 80, h: 12, fontSize: 12, weight: 800, align: "center", color: "A78BFA"),
                                WidgetLayer(id: UUID().uuidString, kind: "battery", x: 10, y: 68, w: 80, h: 18, fontSize: 16, weight: 900, align: "center", color: "A78BFA")
                            ]),
                            LibraryItem(name: "Split Panel Speed/Time", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 48, color: "0D1A1A", opacity: 0.9, radius: 14),
                                WidgetLayer(id: UUID().uuidString, kind: "clock", x: 10, y: 8, w: 80, h: 24, fontSize: 26, weight: 900, align: "center", color: "00F0FF"),
                                WidgetLayer(id: UUID().uuidString, kind: "speed", x: 10, y: 56, w: 80, h: 26, fontSize: 28, weight: 900, align: "center", color: "FF6B35")
                            ]),
                            LibraryItem(name: "Solar Dash 3-Ring", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "ring", x: 10, y: 10, w: 80, h: 80, color: "378ADD", opacity: 0.8, radius: 40),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "ring", x: 20, y: 20, w: 60, h: 60, color: "22C55E", opacity: 0.8, radius: 30),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "ring", x: 30, y: 30, w: 40, h: 40, color: "F97316", opacity: 0.8, radius: 20),
                                WidgetLayer(id: UUID().uuidString, kind: "clock", x: 10, y: 36, w: 80, h: 16, fontSize: 16, weight: 900, align: "center", color: "FFFFFF")
                            ]),
                            LibraryItem(name: "Neon Strip Cyber", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "speed", x: 10, y: 10, w: 80, h: 28, fontSize: 32, weight: 900, align: "center", color: "FF2D6B"),
                                WidgetLayer(id: UUID().uuidString, kind: "clock", x: 10, y: 44, w: 80, h: 18, fontSize: 20, weight: 900, align: "center", color: "FFFFFF"),
                                WidgetLayer(id: UUID().uuidString, kind: "battery", x: 10, y: 66, w: 80, h: 14, fontSize: 12, weight: 800, align: "center", color: "00E5FF")
                            ]),
                            LibraryItem(name: "Carbon Analog Matrix", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "analog", x: 15, y: 10, w: 70, h: 70, color: "DBEAFE", opacity: 1.0),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 10, y: 78, w: 80, h: 16, color: "111111", opacity: 0.9, radius: 8),
                                WidgetLayer(id: UUID().uuidString, kind: "battery", x: 10, y: 80, w: 80, h: 12, fontSize: 11, weight: 800, align: "center", color: "22C55E")
                            ]),
                            LibraryItem(name: "Radar Speed Arc", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "ring", x: 10, y: 10, w: 80, h: 80, color: "00E5FF", opacity: 0.8, radius: 40),
                                WidgetLayer(id: UUID().uuidString, kind: "speed", x: 10, y: 30, w: 80, h: 22, fontSize: 24, weight: 900, align: "center", color: "00E5FF"),
                                WidgetLayer(id: UUID().uuidString, kind: "clock", x: 10, y: 56, w: 80, h: 16, fontSize: 16, weight: 800, align: "center", color: "FFFFFF")
                            ]),
                            LibraryItem(name: "Tri-Zone Modular", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 6, y: 6, w: 88, h: 42, color: "0D1020", opacity: 0.9, radius: 12),
                                WidgetLayer(id: UUID().uuidString, kind: "clock", x: 10, y: 12, w: 80, h: 20, fontSize: 22, weight: 900, align: "center", color: "FFFFFF"),
                                WidgetLayer(id: UUID().uuidString, kind: "speed", x: 8, y: 60, w: 38, h: 18, fontSize: 18, weight: 900, align: "center", color: "FF6B35"),
                                WidgetLayer(id: UUID().uuidString, kind: "battery", x: 54, y: 60, w: 38, h: 18, fontSize: 16, weight: 900, align: "center", color: "22C55E")
                            ]),
                            LibraryItem(name: "Galaxy 4-Orbit Ring", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "ring", x: 6, y: 6, w: 88, h: 88, color: "7C3AED", opacity: 0.8, radius: 44),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "ring", x: 16, y: 16, w: 68, h: 68, color: "06B6D4", opacity: 0.8, radius: 34),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "ring", x: 26, y: 26, w: 48, h: 48, color: "F59E0B", opacity: 0.8, radius: 24),
                                WidgetLayer(id: UUID().uuidString, kind: "clock", x: 10, y: 40, w: 80, h: 14, fontSize: 14, weight: 900, align: "center", color: "FFFFFF")
                            ])
                        ],
                        onSelect: onSelect,
                        dismiss: dismiss
                    )

                    // ── 5. Stitch Studio Designs (16 Widgets) ───────────────
                    SectionView(
                        title: "Stitch Studio Designs",
                        subtitle: "Converted Stitch widget layouts",
                        items: [
                            LibraryItem(name: "Battery Dots", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 10, y: 10, w: 80, h: 80, color: "151D1E", opacity: 0.9, radius: 16),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "circle", x: 25, y: 20, w: 50, h: 40, color: "00F0FF", opacity: 0.25, radius: 20),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "BATTERY DOTS", x: 10, y: 18, w: 80, h: 6, fontSize: 8, weight: 800, align: "center", color: "B9CACB"),
                                WidgetLayer(id: UUID().uuidString, kind: "battery", x: 10, y: 40, w: 80, h: 24, fontSize: 26, weight: 900, align: "center", color: "00F0FF")
                            ]),
                            LibraryItem(name: "Battery Matrix", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "192122", opacity: 0.95, radius: 14),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "MATRIX POWER", x: 12, y: 15, w: 76, h: 8, fontSize: 9, weight: 800, align: "left", color: "00DBE9"),
                                WidgetLayer(id: UUID().uuidString, kind: "battery", x: 12, y: 32, w: 76, h: 24, fontSize: 28, weight: 900, align: "left", color: "FFFFFF"),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 12, y: 68, w: 76, h: 4, color: "00DBE9", opacity: 0.9, radius: 2)
                            ]),
                            LibraryItem(name: "Pixel Neon Clock", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "B600F8", opacity: 0.12, radius: 16),
                                WidgetLayer(id: UUID().uuidString, kind: "clock", x: 10, y: 22, w: 80, h: 32, fontSize: 32, weight: 900, align: "center", color: "00F0FF"),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "SYS.OK // SYNC", x: 10, y: 66, w: 80, h: 8, fontSize: 9, weight: 800, align: "center", color: "EBB2FF")
                            ]),
                            LibraryItem(name: "Segment LED Clock", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "151D1E", opacity: 0.9, radius: 14),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "7-SEGMENT HUD", x: 12, y: 16, w: 76, h: 8, fontSize: 8, weight: 700, align: "left", color: "7DF4FF"),
                                WidgetLayer(id: UUID().uuidString, kind: "clock", x: 10, y: 30, w: 80, h: 32, fontSize: 34, weight: 900, align: "center", color: "00F0FF"),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "SYNC ACTIVE", x: 12, y: 68, w: 76, h: 8, fontSize: 8, weight: 600, align: "right", color: "7DF4FF")
                            ]),
                            LibraryItem(name: "Clock Pill Capsule", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 10, y: 15, w: 80, h: 42, color: "00363A", opacity: 0.6, radius: 21),
                                WidgetLayer(id: UUID().uuidString, kind: "clock", x: 15, y: 22, w: 70, h: 28, fontSize: 26, weight: 900, align: "center", color: "00F0FF"),
                                WidgetLayer(id: UUID().uuidString, kind: "date", x: 10, y: 65, w: 80, h: 12, fontSize: 11, weight: 700, align: "center", color: "FFB86F")
                            ]),
                            LibraryItem(name: "Clock Halo Ring", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "ring", x: 15, y: 15, w: 70, h: 70, color: "00F0FF", radius: 35),
                                WidgetLayer(id: UUID().uuidString, kind: "clock", x: 15, y: 34, w: 70, h: 22, fontSize: 24, weight: 900, align: "center", color: "FFFFFF"),
                                WidgetLayer(id: UUID().uuidString, kind: "date", x: 15, y: 58, w: 70, h: 8, fontSize: 9, weight: 600, align: "center", color: "B9CACB")
                            ]),
                            LibraryItem(name: "Clock Leather Stitched", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "333333", opacity: 0.8, radius: 16),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 10, y: 10, w: 80, h: 80, color: "1A1A1A", opacity: 1.0, radius: 14),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 15, y: 15, w: 70, h: 2, color: "F5B041", opacity: 0.9, radius: 1),
                                WidgetLayer(id: UUID().uuidString, kind: "clock", x: 10, y: 30, w: 80, h: 28, fontSize: 28, weight: 800, align: "center", color: "F5B041"),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "LUXURY EDITION", x: 10, y: 65, w: 80, h: 8, fontSize: 8, weight: 700, align: "center", color: "AAAAAA")
                            ]),
                            LibraryItem(name: "Clock Noir Gold", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "circle", x: 12, y: 12, w: 76, h: 76, color: "E6C57A", opacity: 0.15, radius: 38),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "ring", x: 16, y: 16, w: 68, h: 68, color: "E6C57A", opacity: 0.8, radius: 34),
                                WidgetLayer(id: UUID().uuidString, kind: "clock", x: 15, y: 32, w: 70, h: 24, fontSize: 24, weight: 900, align: "center", color: "F0D58B"),
                                WidgetLayer(id: UUID().uuidString, kind: "date", x: 15, y: 58, w: 70, h: 8, fontSize: 9, weight: 700, align: "center", color: "E6C57A")
                            ]),
                            LibraryItem(name: "Battery Lightning Bolt", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "151D1E", opacity: 0.9, radius: 16),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "CHARGE // BOLT", x: 12, y: 16, w: 76, h: 8, fontSize: 8, weight: 800, align: "left", color: "00F0FF"),
                                WidgetLayer(id: UUID().uuidString, kind: "battery", x: 10, y: 32, w: 80, h: 32, fontSize: 34, weight: 900, align: "center", color: "00F0FF"),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "POWER ACTIVE", x: 12, y: 68, w: 76, h: 8, fontSize: 8, weight: 700, align: "center", color: "B9CACB")
                            ]),
                            LibraryItem(name: "Battery Tactical Panel", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "192122", opacity: 0.95, radius: 14),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "BATTERY LEVEL", x: 12, y: 15, w: 76, h: 8, fontSize: 9, weight: 700, align: "left", color: "B9CACB"),
                                WidgetLayer(id: UUID().uuidString, kind: "battery", x: 12, y: 30, w: 76, h: 26, fontSize: 28, weight: 900, align: "left", color: "00DBE9"),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "CHARGING ACTIVE", x: 12, y: 66, w: 76, h: 8, fontSize: 8, weight: 800, align: "left", color: "4DC98A")
                            ])
                        ],
                        onSelect: onSelect,
                        dismiss: dismiss
                    )


                }
                .padding(.vertical, 20)
            }
            .background(DriveColors.background.ignoresSafeArea())
            .navigationTitle("Widget Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(DriveColors.primary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Component Models & Views
// ─────────────────────────────────────────────────────────────────────────────

struct LibraryItem {
    let name: String
    let layers: [WidgetLayer]
}

struct SectionView: View {
    let title: String
    let subtitle: String
    let items: [LibraryItem]
    let onSelect: ([WidgetLayer]) -> Void
    let dismiss: DismissAction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(DriveColors.mutedFg)
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(items, id: \.name) { item in
                        Button {
                            onSelect(item.layers)
                            dismiss()
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(DriveColors.carbon)
                                        .frame(width: 140, height: 140)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18)
                                                .stroke(DriveColors.border, lineWidth: 1)
                                        )
                                        .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 3)
                                    
                                    // Mini canvas preview — FULL-BLEED without safe margins
                                    GeometryReader { _ in
                                        let tempSpec = WidgetSpec(
                                            background: WidgetBackground(type: "solid", from: "141419", to: nil, imageSrc: nil),
                                            layers: item.layers
                                        )
                                        WidgetCanvas(spec: .constant(tempSpec), selectedLayerIndex: .constant(nil))
                                    }
                                    .frame(width: 138, height: 138)
                                    .clipShape(RoundedRectangle(cornerRadius: 17))
                                    .allowsHitTesting(false)
                                }
                                
                                Text(item.name)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(DriveColors.foreground)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}
