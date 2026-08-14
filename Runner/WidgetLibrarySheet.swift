import SwiftUI

struct WidgetLibrarySheet: View {
    @Environment(\.dismiss) var dismiss
    
    var onSelect: ([WidgetLayer]) -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {

                    // Group UUIDs for the Premium Library assets so every layer
                    // of a given asset moves / resizes / deletes as one unit.
                    let dmSpeed    = UUID().uuidString
                    let dmClock    = UUID().uuidString
                    let dmBatSpd   = UUID().uuidString
                    let dmVehicle  = UUID().uuidString
                    let racRed     = UUID().uuidString
                    let racCarbon  = UUID().uuidString
                    let racAmber   = UUID().uuidString
                    let racDash    = UUID().uuidString
                    let clnSpeed   = UUID().uuidString
                    let clnClock   = UUID().uuidString
                    let clnBatSpd  = UUID().uuidString
                    let clnFull    = UUID().uuidString

                    // Group UUIDs for the Atomic Essentials assets
                    let clockGid   = UUID().uuidString
                    let speedGid   = UUID().uuidString
                    let batteryGid = UUID().uuidString
                    let vehicleGid = UUID().uuidString
                    let analogGid  = UUID().uuidString
                    let dualGid    = UUID().uuidString
                    let dashGid    = UUID().uuidString
                    let goldGid    = UUID().uuidString

                    // ── 0. Premium Library (Dark Minimal · Racing · Clean Light) ──
                    SectionView(
                        title: "Premium Library",
                        subtitle: "Hand-crafted dark, racing, and light themes",
                        items: [
                            // 1. Dark Minimal — Speed Only
                            LibraryItem(name: "Dark Speed", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "0A0A0F", opacity: 1.0, radius: 22, groupId: dmSpeed),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 10, y: 66, w: 80, h: 1, color: "2A2A35", opacity: 1.0, radius: 0, groupId: dmSpeed),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "SPEED", x: 10, y: 12, w: 80, h: 8, fontSize: 8, weight: 600, align: "center", color: "4B5563", groupId: dmSpeed),
                                WidgetLayer(id: UUID().uuidString, kind: "speed", x: 6, y: 26, w: 88, h: 36, fontSize: 44, weight: 800, align: "center", color: "F9FAFB", groupId: dmSpeed),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "KM/H", x: 10, y: 72, w: 80, h: 7, fontSize: 9, weight: 500, align: "center", color: "6B7280", groupId: dmSpeed)
                            ]),
                            // 2. Dark Minimal — Clock + Date stacked
                            LibraryItem(name: "Dark Clock", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "111116", opacity: 1.0, radius: 22, groupId: dmClock),
                                WidgetLayer(id: UUID().uuidString, kind: "clock", x: 6, y: 20, w: 88, h: 38, fontSize: 38, weight: 700, align: "center", color: "FFFFFF", groupId: dmClock),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 30, y: 62, w: 40, h: 1, color: "374151", opacity: 1.0, radius: 0, groupId: dmClock),
                                WidgetLayer(id: UUID().uuidString, kind: "date", x: 10, y: 67, w: 80, h: 8, fontSize: 9, weight: 400, align: "center", color: "6B7280", groupId: dmClock)
                            ]),
                            // 3. Dark Minimal — Battery + Speed split
                            LibraryItem(name: "Dark Bat + Speed", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "0A0A0F", opacity: 1.0, radius: 22, groupId: dmBatSpd),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 49, y: 14, w: 2, h: 72, color: "1F2937", opacity: 1.0, radius: 1, groupId: dmBatSpd),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "BAT", x: 6, y: 14, w: 38, h: 7, fontSize: 7, weight: 600, align: "center", color: "4B5563", groupId: dmBatSpd),
                                WidgetLayer(id: UUID().uuidString, kind: "battery", x: 4, y: 28, w: 42, h: 28, fontSize: 26, weight: 700, align: "center", color: "22C55E", groupId: dmBatSpd),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "%", x: 4, y: 60, w: 42, h: 7, fontSize: 8, weight: 400, align: "center", color: "374151", groupId: dmBatSpd),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "SPD", x: 54, y: 14, w: 40, h: 7, fontSize: 7, weight: 600, align: "center", color: "4B5563", groupId: dmBatSpd),
                                WidgetLayer(id: UUID().uuidString, kind: "speed", x: 53, y: 28, w: 42, h: 28, fontSize: 26, weight: 700, align: "center", color: "F9FAFB", groupId: dmBatSpd),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "KM/H", x: 53, y: 60, w: 42, h: 7, fontSize: 8, weight: 400, align: "center", color: "374151", groupId: dmBatSpd)
                            ]),
                            // 4. Dark Minimal — Vehicle Name card
                            LibraryItem(name: "Dark Vehicle", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "0D0D14", opacity: 1.0, radius: 22, groupId: dmVehicle),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "MY VEHICLE", x: 10, y: 12, w: 80, h: 7, fontSize: 7, weight: 500, align: "left", color: "374151", groupId: dmVehicle),
                                WidgetLayer(id: UUID().uuidString, kind: "vehicle_name", x: 8, y: 28, w: 84, h: 24, fontSize: 20, weight: 700, align: "left", color: "F9FAFB", groupId: dmVehicle),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 8, y: 62, w: 84, h: 1, color: "1F2937", opacity: 1.0, radius: 0, groupId: dmVehicle),
                                WidgetLayer(id: UUID().uuidString, kind: "clock", x: 8, y: 70, w: 84, h: 14, fontSize: 14, weight: 500, align: "right", color: "6B7280", groupId: dmVehicle)
                            ]),
                            // 5. Racing — Red Edge Speed
                            LibraryItem(name: "Racing Red Speed", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "0D0000", opacity: 1.0, radius: 22, groupId: racRed),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 6, y: 10, w: 4, h: 80, color: "DC2626", opacity: 1.0, radius: 2, groupId: racRed),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "SPEED", x: 16, y: 12, w: 76, h: 7, fontSize: 7, weight: 700, align: "left", color: "7F1D1D", groupId: racRed),
                                WidgetLayer(id: UUID().uuidString, kind: "speed", x: 14, y: 26, w: 78, h: 34, fontSize: 38, weight: 900, align: "left", color: "FFFFFF", groupId: racRed),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "KM/H", x: 14, y: 63, w: 78, h: 7, fontSize: 8, weight: 700, align: "left", color: "DC2626", groupId: racRed),
                                WidgetLayer(id: UUID().uuidString, kind: "battery", x: 14, y: 76, w: 78, h: 10, fontSize: 10, weight: 500, align: "right", color: "6B7280", groupId: racRed)
                            ]),
                            // 6. Racing — Carbon + Speed + Clock
                            LibraryItem(name: "Racing Carbon HUD", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "141414", opacity: 1.0, radius: 22, groupId: racCarbon),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 5, color: "B91C1C", opacity: 1.0, radius: 0, groupId: racCarbon),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "HUD", x: 8, y: 10, w: 50, h: 7, fontSize: 7, weight: 700, align: "left", color: "6B7280", groupId: racCarbon),
                                WidgetLayer(id: UUID().uuidString, kind: "clock", x: 8, y: 10, w: 84, h: 10, fontSize: 10, weight: 500, align: "right", color: "4B5563", groupId: racCarbon),
                                WidgetLayer(id: UUID().uuidString, kind: "speed", x: 6, y: 26, w: 88, h: 36, fontSize: 42, weight: 900, align: "center", color: "F9FAFB", groupId: racCarbon),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "KM/H", x: 6, y: 64, w: 88, h: 7, fontSize: 8, weight: 700, align: "center", color: "B91C1C", groupId: racCarbon),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 8, y: 74, w: 84, h: 1, color: "292929", opacity: 1.0, radius: 0, groupId: racCarbon),
                                WidgetLayer(id: UUID().uuidString, kind: "battery", x: 8, y: 79, w: 84, h: 10, fontSize: 9, weight: 500, align: "center", color: "4B5563", groupId: racCarbon)
                            ]),
                            // 7. Racing — Amber Sport
                            LibraryItem(name: "Sport Amber", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "0F0A00", opacity: 1.0, radius: 22, groupId: racAmber),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 88, w: 100, h: 12, color: "D97706", opacity: 1.0, radius: 0, groupId: racAmber),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "DRIVE", x: 8, y: 10, w: 84, h: 7, fontSize: 7, weight: 700, align: "left", color: "78350F", groupId: racAmber),
                                WidgetLayer(id: UUID().uuidString, kind: "speed", x: 6, y: 22, w: 88, h: 40, fontSize: 46, weight: 900, align: "center", color: "FACC15", groupId: racAmber),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "KM/H", x: 6, y: 65, w: 88, h: 7, fontSize: 9, weight: 600, align: "center", color: "D97706", groupId: racAmber),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "SPEED", x: 8, y: 90, w: 84, h: 8, fontSize: 8, weight: 700, align: "center", color: "0F0A00", groupId: racAmber)
                            ]),
                            // 8. Racing — Full Dashboard
                            LibraryItem(name: "Sport Dashboard", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "0A0A0A", opacity: 1.0, radius: 22, groupId: racDash),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 18, color: "161616", opacity: 1.0, radius: 0, groupId: racDash),
                                WidgetLayer(id: UUID().uuidString, kind: "vehicle_name", x: 8, y: 4, w: 54, h: 10, fontSize: 9, weight: 600, align: "left", color: "9CA3AF", groupId: racDash),
                                WidgetLayer(id: UUID().uuidString, kind: "clock", x: 8, y: 4, w: 84, h: 10, fontSize: 10, weight: 500, align: "right", color: "4B5563", groupId: racDash),
                                WidgetLayer(id: UUID().uuidString, kind: "speed", x: 6, y: 22, w: 60, h: 38, fontSize: 38, weight: 900, align: "left", color: "FFFFFF", groupId: racDash),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "KM/H", x: 6, y: 62, w: 60, h: 7, fontSize: 8, weight: 600, align: "left", color: "DC2626", groupId: racDash),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "BAT", x: 68, y: 26, w: 26, h: 7, fontSize: 7, weight: 600, align: "center", color: "4B5563", groupId: racDash),
                                WidgetLayer(id: UUID().uuidString, kind: "battery", x: 66, y: 36, w: 28, h: 18, fontSize: 16, weight: 700, align: "center", color: "22C55E", groupId: racDash),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "%", x: 66, y: 57, w: 28, h: 7, fontSize: 7, weight: 400, align: "center", color: "374151", groupId: racDash),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 6, y: 73, w: 88, h: 1, color: "1F1F1F", opacity: 1.0, radius: 0, groupId: racDash),
                                WidgetLayer(id: UUID().uuidString, kind: "date", x: 6, y: 78, w: 88, h: 8, fontSize: 8, weight: 400, align: "left", color: "4B5563", groupId: racDash)
                            ]),
                            // 9. Clean Light — Minimal Speed
                            LibraryItem(name: "Light Speed", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "F8F9FA", opacity: 1.0, radius: 22, groupId: clnSpeed),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "SPEED", x: 10, y: 12, w: 80, h: 8, fontSize: 8, weight: 500, align: "center", color: "9CA3AF", groupId: clnSpeed),
                                WidgetLayer(id: UUID().uuidString, kind: "speed", x: 6, y: 26, w: 88, h: 38, fontSize: 44, weight: 700, align: "center", color: "111827", groupId: clnSpeed),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 30, y: 68, w: 40, h: 1, color: "E5E7EB", opacity: 1.0, radius: 0, groupId: clnSpeed),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "KM/H", x: 10, y: 74, w: 80, h: 7, fontSize: 8, weight: 400, align: "center", color: "D1D5DB", groupId: clnSpeed)
                            ]),
                            // 10. Clean Light — Clock card
                            LibraryItem(name: "Light Clock", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "FFFFFF", opacity: 1.0, radius: 22, groupId: clnClock),
                                WidgetLayer(id: UUID().uuidString, kind: "clock", x: 6, y: 18, w: 88, h: 40, fontSize: 40, weight: 300, align: "center", color: "1F2937", groupId: clnClock),
                                WidgetLayer(id: UUID().uuidString, kind: "date", x: 10, y: 64, w: 80, h: 8, fontSize: 9, weight: 400, align: "center", color: "9CA3AF", groupId: clnClock)
                            ]),
                            // 11. Clean Light — Battery + Speed pill layout
                            LibraryItem(name: "Light Bat + Speed", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "F3F4F6", opacity: 1.0, radius: 22, groupId: clnBatSpd),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 6, y: 16, w: 40, h: 68, color: "FFFFFF", opacity: 1.0, radius: 14, groupId: clnBatSpd),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "BAT", x: 8, y: 22, w: 36, h: 7, fontSize: 7, weight: 600, align: "center", color: "9CA3AF", groupId: clnBatSpd),
                                WidgetLayer(id: UUID().uuidString, kind: "battery", x: 8, y: 34, w: 36, h: 26, fontSize: 22, weight: 700, align: "center", color: "16A34A", groupId: clnBatSpd),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "%", x: 8, y: 63, w: 36, h: 7, fontSize: 8, weight: 400, align: "center", color: "D1D5DB", groupId: clnBatSpd),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 54, y: 16, w: 40, h: 68, color: "FFFFFF", opacity: 1.0, radius: 14, groupId: clnBatSpd),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "SPD", x: 56, y: 22, w: 36, h: 7, fontSize: 7, weight: 600, align: "center", color: "9CA3AF", groupId: clnBatSpd),
                                WidgetLayer(id: UUID().uuidString, kind: "speed", x: 56, y: 34, w: 36, h: 26, fontSize: 22, weight: 700, align: "center", color: "111827", groupId: clnBatSpd),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "KM/H", x: 56, y: 63, w: 36, h: 7, fontSize: 7, weight: 400, align: "center", color: "D1D5DB", groupId: clnBatSpd)
                            ]),
                            // 12. Clean Light — Full info card
                            LibraryItem(name: "Light Full Info", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "FFFFFF", opacity: 1.0, radius: 22, groupId: clnFull),
                                WidgetLayer(id: UUID().uuidString, kind: "vehicle_name", x: 8, y: 10, w: 60, h: 10, fontSize: 10, weight: 600, align: "left", color: "374151", groupId: clnFull),
                                WidgetLayer(id: UUID().uuidString, kind: "battery", x: 68, y: 10, w: 24, h: 10, fontSize: 10, weight: 600, align: "right", color: "16A34A", groupId: clnFull),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 8, y: 24, w: 84, h: 1, color: "F3F4F6", opacity: 1.0, radius: 0, groupId: clnFull),
                                WidgetLayer(id: UUID().uuidString, kind: "speed", x: 6, y: 30, w: 88, h: 34, fontSize: 38, weight: 700, align: "center", color: "111827", groupId: clnFull),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "KM/H", x: 6, y: 66, w: 88, h: 7, fontSize: 8, weight: 400, align: "center", color: "D1D5DB", groupId: clnFull),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 8, y: 76, w: 84, h: 1, color: "F3F4F6", opacity: 1.0, radius: 0, groupId: clnFull),
                                WidgetLayer(id: UUID().uuidString, kind: "clock", x: 8, y: 82, w: 40, h: 10, fontSize: 10, weight: 500, align: "left", color: "9CA3AF", groupId: clnFull),
                                WidgetLayer(id: UUID().uuidString, kind: "date", x: 52, y: 82, w: 40, h: 10, fontSize: 10, weight: 400, align: "right", color: "9CA3AF", groupId: clnFull)
                            ])
                        ],
                        onSelect: onSelect,
                        dismiss: dismiss
                    )

                    // ── 0b. Atomic Essentials — single-purpose composites ─────────
                    SectionView(
                        title: "Atomic Essentials",
                        subtitle: "Focused single-purpose composites",
                        items: [
                            // 1. Clean Digital Clock
                            LibraryItem(name: "Digital Clock", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "0A0A0F", opacity: 1.0, radius: 22, groupId: clockGid),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 4, y: 4, w: 92, h: 92, color: "141419", opacity: 1.0, radius: 18, groupId: clockGid),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "CURRENT TIME", x: 10, y: 14, w: 80, h: 6, fontSize: 7, weight: 700, align: "center", color: "94A3B8", groupId: clockGid),
                                WidgetLayer(id: UUID().uuidString, kind: "clock", x: 8, y: 28, w: 84, h: 36, fontSize: 34, weight: 900, align: "center", color: "FFFFFF", groupId: clockGid),
                                WidgetLayer(id: UUID().uuidString, kind: "date", x: 10, y: 68, w: 80, h: 10, fontSize: 10, weight: 600, align: "center", color: "22D3EE", groupId: clockGid)
                            ]),
                            // 2. Racing Speedometer
                            LibraryItem(name: "Racing Speed", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "000000", opacity: 1.0, radius: 22, groupId: speedGid),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 4, y: 4, w: 92, h: 92, color: "0F0F0F", opacity: 1.0, radius: 18, groupId: speedGid),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "ring", x: 10, y: 10, w: 80, h: 80, color: "DC2626", opacity: 0.3, radius: 40, groupId: speedGid),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "SPEED", x: 10, y: 14, w: 80, h: 6, fontSize: 7, weight: 800, align: "center", color: "DC2626", groupId: speedGid),
                                WidgetLayer(id: UUID().uuidString, kind: "speed", x: 8, y: 30, w: 84, h: 32, fontSize: 36, weight: 900, align: "center", color: "FFFFFF", groupId: speedGid),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "KM/H", x: 10, y: 64, w: 80, h: 6, fontSize: 8, weight: 700, align: "center", color: "FB923C", groupId: speedGid)
                            ]),
                            // 3. Battery Status Card
                            // Dynamic progress bar — fill width driven by actual
                            // device battery level at render time, so it always
                            // matches the percentage shown in the big text below.
                            LibraryItem(name: "Battery Card", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "0A0A0F", opacity: 1.0, radius: 22, groupId: batteryGid),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 4, y: 4, w: 92, h: 92, color: "141419", opacity: 1.0, radius: 18, groupId: batteryGid),
                                WidgetLayer(id: UUID().uuidString, kind: "battery_bar", label: "1E1E24", x: 8, y: 40, w: 84, h: 8, color: "22C55E", radius: 4, groupId: batteryGid),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "BATTERY", x: 10, y: 14, w: 80, h: 6, fontSize: 7, weight: 800, align: "center", color: "94A3B8", groupId: batteryGid),
                                WidgetLayer(id: UUID().uuidString, kind: "battery", x: 8, y: 54, w: 84, h: 28, fontSize: 30, weight: 900, align: "center", color: "22C55E", groupId: batteryGid)
                            ]),
                            // 4. Vehicle Header
                            LibraryItem(name: "Vehicle Header", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "0A0A0F", opacity: 1.0, radius: 22, groupId: vehicleGid),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 45, color: "1E3A5F", opacity: 1.0, radius: 22, groupId: vehicleGid),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 20, w: 100, h: 80, color: "0A0A0F", opacity: 1.0, radius: 22, groupId: vehicleGid),
                                WidgetLayer(id: UUID().uuidString, kind: "image", src: "template_car", x: 30, y: 8, w: 40, h: 28, groupId: vehicleGid),
                                WidgetLayer(id: UUID().uuidString, kind: "vehicle_name", x: 8, y: 42, w: 84, h: 14, fontSize: 14, weight: 700, align: "center", color: "FFFFFF", groupId: vehicleGid),
                                WidgetLayer(id: UUID().uuidString, kind: "date", x: 8, y: 62, w: 84, h: 10, fontSize: 10, weight: 500, align: "center", color: "94A3B8", groupId: vehicleGid),
                                WidgetLayer(id: UUID().uuidString, kind: "clock", x: 8, y: 76, w: 84, h: 14, fontSize: 14, weight: 600, align: "center", color: "22D3EE", groupId: vehicleGid)
                            ]),
                            // 5. Minimal Analog Clock
                            LibraryItem(name: "Analog Clock", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "0A0A0F", opacity: 1.0, radius: 22, groupId: analogGid),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "circle", x: 10, y: 10, w: 80, h: 80, color: "141419", opacity: 1.0, radius: 40, groupId: analogGid),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "ring", x: 10, y: 10, w: 80, h: 80, color: "22D3EE", opacity: 0.6, radius: 40, groupId: analogGid),
                                WidgetLayer(id: UUID().uuidString, kind: "analog", x: 10, y: 10, w: 80, h: 80, color: "FFFFFF", opacity: 1.0, groupId: analogGid),
                                WidgetLayer(id: UUID().uuidString, kind: "date", x: 10, y: 82, w: 80, h: 8, fontSize: 8, weight: 600, align: "center", color: "94A3B8", groupId: analogGid)
                            ]),
                            // 6. Dual Info Card
                            LibraryItem(name: "Dual Info", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "0A0A0F", opacity: 1.0, radius: 22, groupId: dualGid),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 4, y: 4, w: 44, h: 92, color: "141419", opacity: 1.0, radius: 16, groupId: dualGid),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 52, y: 4, w: 44, h: 92, color: "141419", opacity: 1.0, radius: 16, groupId: dualGid),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "SPEED", x: 6, y: 14, w: 40, h: 6, fontSize: 7, weight: 800, align: "center", color: "FB923C", groupId: dualGid),
                                WidgetLayer(id: UUID().uuidString, kind: "speed", x: 6, y: 28, w: 40, h: 24, fontSize: 24, weight: 900, align: "center", color: "FFFFFF", groupId: dualGid),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "KM/H", x: 6, y: 54, w: 40, h: 6, fontSize: 7, weight: 700, align: "center", color: "94A3B8", groupId: dualGid),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "BATTERY", x: 54, y: 14, w: 40, h: 6, fontSize: 7, weight: 800, align: "center", color: "22C55E", groupId: dualGid),
                                WidgetLayer(id: UUID().uuidString, kind: "battery", x: 54, y: 28, w: 40, h: 24, fontSize: 24, weight: 900, align: "center", color: "FFFFFF", groupId: dualGid),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "%", x: 54, y: 54, w: 40, h: 6, fontSize: 7, weight: 700, align: "center", color: "94A3B8", groupId: dualGid)
                            ]),
                            // 7. Modern Dashboard Tile
                            LibraryItem(name: "Dashboard Tile", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "0A0A0F", opacity: 1.0, radius: 22, groupId: dashGid),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 4, y: 4, w: 92, h: 92, color: "141419", opacity: 1.0, radius: 18, groupId: dashGid),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 4, y: 4, w: 92, h: 2, color: "0EA5E9", opacity: 1.0, radius: 1, groupId: dashGid),
                                WidgetLayer(id: UUID().uuidString, kind: "vehicle_name", x: 8, y: 12, w: 84, h: 10, fontSize: 10, weight: 700, align: "left", color: "FFFFFF", groupId: dashGid),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 8, y: 28, w: 84, h: 1, color: "1E1E24", opacity: 1.0, radius: 0, groupId: dashGid),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "SPEED", x: 8, y: 34, w: 40, h: 6, fontSize: 7, weight: 700, align: "left", color: "94A3B8", groupId: dashGid),
                                WidgetLayer(id: UUID().uuidString, kind: "speed", x: 8, y: 42, w: 40, h: 20, fontSize: 22, weight: 900, align: "left", color: "FFFFFF", groupId: dashGid),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "BATTERY", x: 52, y: 34, w: 40, h: 6, fontSize: 7, weight: 700, align: "left", color: "94A3B8", groupId: dashGid),
                                WidgetLayer(id: UUID().uuidString, kind: "battery", x: 52, y: 42, w: 40, h: 20, fontSize: 22, weight: 900, align: "left", color: "FFFFFF", groupId: dashGid),
                                WidgetLayer(id: UUID().uuidString, kind: "date", x: 8, y: 72, w: 84, h: 8, fontSize: 8, weight: 500, align: "left", color: "94A3B8", groupId: dashGid),
                                WidgetLayer(id: UUID().uuidString, kind: "clock", x: 8, y: 82, w: 84, h: 10, fontSize: 10, weight: 600, align: "left", color: "0EA5E9", groupId: dashGid)
                            ]),
                            // 8. Gold Luxury Clock
                            LibraryItem(name: "Luxury Clock", layers: [
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "0A0A0F", opacity: 1.0, radius: 22, groupId: goldGid),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect", x: 4, y: 4, w: 92, h: 92, color: "141419", opacity: 1.0, radius: 18, groupId: goldGid),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "ring", x: 8, y: 8, w: 84, h: 84, color: "D4AF37", opacity: 0.4, radius: 42, groupId: goldGid),
                                WidgetLayer(id: UUID().uuidString, kind: "shape", label: "ring", x: 12, y: 12, w: 76, h: 76, color: "D4AF37", opacity: 0.2, radius: 38, groupId: goldGid),
                                WidgetLayer(id: UUID().uuidString, kind: "text", text: "LUXURY", x: 10, y: 16, w: 80, h: 6, fontSize: 7, weight: 800, align: "center", color: "D4AF37", groupId: goldGid),
                                WidgetLayer(id: UUID().uuidString, kind: "clock", x: 8, y: 30, w: 84, h: 30, fontSize: 32, weight: 900, align: "center", color: "F5DEB3", groupId: goldGid),
                                WidgetLayer(id: UUID().uuidString, kind: "date", x: 10, y: 66, w: 80, h: 8, fontSize: 9, weight: 600, align: "center", color: "B08D57", groupId: goldGid)
                            ])
                        ],
                        onSelect: onSelect,
                        dismiss: dismiss
                    )

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
