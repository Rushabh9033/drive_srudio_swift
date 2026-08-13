import Foundation
import SwiftUI

struct StockWidgetCatalog {
    static let shared = StockWidgetCatalog()
    
    let widgets: [StockWidgetDefinition]
    
    private init() {
        let uid = { UUID().uuidString }
        
        // ─────────────────────────────────────────────────────────────
        // MARK: - Category 1: Night & Time
        // ─────────────────────────────────────────────────────────────
        
        let midnightClock = StockWidgetDefinition(
            stockWidgetId: "stock.midnight_clock",
            stockWidgetVersion: 1,
            name: "Midnight Clock",
            description: "A dark, elegant digital clock for night driving.",
            category: .nightTime,
            requiredDataSource: "Time",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "050505", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "clock", text: "HH:mm", x: 47.3, y: 14.1, w: 59.2, h: 22.6, fontSize: 34.1, weight: 800, align: "center", color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "text", text: "NIGHT DRIVE MODE", x: 47.3, y: 39.5, w: 59.2, h: 5.6, fontSize: 6.4, weight: 600, align: "center", color: "FFB84D", opacity: 0.8)
                ]
            )
        )
        
        let zenithDarkClock = StockWidgetDefinition(
            stockWidgetId: "stock.zenith_dark_clock",
            stockWidgetVersion: 2,
            name: "Zenith Dark Horizon",
            description: "Deep obsidian gradient background with glowing cyan date badge.",
            category: .nightTime,
            requiredDataSource: "Time",
            document: WidgetSpec(
                background: WidgetBackground(type: "gradient", from: "0B0C10", to: "1F2833", imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "ZENITH NIGHT", x: 8, y: 8, w: 50, h: 6, fontSize: 8, weight: 800, align: "left", color: "66FCF1"),
                    WidgetLayer(id: uid(), kind: "clock", text: "HH:mm", x: 8, y: 18, w: 84, h: 24, fontSize: 36, weight: 900, align: "left", color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "date", text: "EEE d MMM", x: 8, y: 46, w: 84, h: 10, fontSize: 11, weight: 700, align: "left", color: "45A29E")
                ]
            )
        )

        let cyberMidnightMatrix = StockWidgetDefinition(
            stockWidgetId: "stock.cyber_midnight",
            stockWidgetVersion: 2,
            name: "Cyber Midnight Matrix",
            description: "Amber status tag with giant neon cyan time display and accent bar.",
            category: .nightTime,
            requiredDataSource: "Time",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "05050A", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 8, y: 8, w: 40, h: 6, color: "FFB84D", opacity: 0.9, radius: 3),
                    WidgetLayer(id: uid(), kind: "text", text: "NIGHT HUD", x: 10, y: 9, w: 36, h: 4, fontSize: 7, weight: 800, align: "center", color: "000000"),
                    WidgetLayer(id: uid(), kind: "clock", text: "HH:mm", x: 8, y: 22, w: 84, h: 26, fontSize: 38, weight: 900, align: "center", color: "00F0FF"),
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 12, y: 56, w: 76, h: 3, color: "00F0FF", opacity: 0.6, radius: 2)
                ]
            )
        )

        let horizonDuskDial = StockWidgetDefinition(
            stockWidgetId: "stock.horizon_dusk",
            stockWidgetVersion: 2,
            name: "Horizon Dusk Dial",
            description: "Sunset inspired dark gradient background with pink divider accent.",
            category: .nightTime,
            requiredDataSource: "Time",
            document: WidgetSpec(
                background: WidgetBackground(type: "gradient", from: "1A0817", to: "0D0D0D", imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "clock", text: "HH:mm", x: 10, y: 15, w: 80, h: 28, fontSize: 36, weight: 900, align: "center", color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 20, y: 48, w: 60, h: 2, color: "FF007F", opacity: 0.9, radius: 1),
                    WidgetLayer(id: uid(), kind: "date", text: "EEEE, MMM d", x: 10, y: 55, w: 80, h: 10, fontSize: 12, weight: 700, align: "center", color: "FF77AA")
                ]
            )
        )

        let minimalStealthTime = StockWidgetDefinition(
            stockWidgetId: "stock.minimal_stealth",
            stockWidgetVersion: 2,
            name: "Minimal Stealth HUD",
            description: "Ultra-clean dark carbon background with subtle stealth opacity label.",
            category: .nightTime,
            requiredDataSource: "Time",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "111116", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "clock", text: "HH:mm", x: 10, y: 20, w: 80, h: 32, fontSize: 42, weight: 300, align: "center", color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "text", text: "STEALTH CLUSTER", x: 10, y: 60, w: 80, h: 6, fontSize: 8, weight: 700, align: "center", color: "888899", opacity: 0.7)
                ]
            )
        )

        // ─────────────────────────────────────────────────────────────
        // MARK: - Category 2: Phone Battery
        // ─────────────────────────────────────────────────────────────

        let hyperArcCharge = StockWidgetDefinition(
            stockWidgetId: "stock.hyper_arc_charge",
            stockWidgetVersion: 2,
            name: "Hyper Arc Battery",
            description: "Glowing green ring shape with live battery percentage and power label.",
            category: .phoneBattery,
            requiredDataSource: "Battery",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "07132B", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "shape", label: "ring", x: 20, y: 10, w: 60, h: 60, color: "4DC98A", opacity: 0.9, radius: 30),
                    WidgetLayer(id: uid(), kind: "battery", x: 20, y: 30, w: 60, h: 20, fontSize: 22, weight: 900, align: "center", color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "text", text: "SYSTEM POWER", x: 10, y: 75, w: 80, h: 6, fontSize: 8, weight: 800, align: "center", color: "4DC98A")
                ]
            )
        )

        let voltPulseMatrix = StockWidgetDefinition(
            stockWidgetId: "stock.volt_pulse",
            stockWidgetVersion: 2,
            name: "Volt Pulse Matrix",
            description: "Cyan battery readout with status badge and charging indicator bar.",
            category: .phoneBattery,
            requiredDataSource: "Battery",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "0D1B2A", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "BATTERY LEVEL", x: 10, y: 12, w: 80, h: 6, fontSize: 9, weight: 800, align: "left", color: "77AABB"),
                    WidgetLayer(id: uid(), kind: "battery", x: 10, y: 26, w: 80, h: 28, fontSize: 34, weight: 900, align: "left", color: "00F0FF"),
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 10, y: 60, w: 80, h: 4, color: "00F0FF", opacity: 0.8, radius: 2)
                ]
            )
        )

        let carbonEnergyRing = StockWidgetDefinition(
            stockWidgetId: "stock.carbon_energy_ring",
            stockWidgetVersion: 2,
            name: "Carbon Energy Ring",
            description: "Outer neon green ring accent with bold central battery percentage.",
            category: .phoneBattery,
            requiredDataSource: "Battery",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "18181F", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "shape", label: "ring", x: 15, y: 12, w: 70, h: 70, color: "22C55E", opacity: 0.85, radius: 35),
                    WidgetLayer(id: uid(), kind: "battery", x: 15, y: 34, w: 70, h: 24, fontSize: 26, weight: 900, align: "center", color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "text", text: "TELEMETRY OK", x: 10, y: 84, w: 80, h: 6, fontSize: 8, weight: 700, align: "center", color: "22C55E")
                ]
            )
        )

        let minimalPowerBar = StockWidgetDefinition(
            stockWidgetId: "stock.minimal_power_bar",
            stockWidgetVersion: 2,
            name: "Minimal Power Bar",
            description: "Crisp white battery percentage with emerald charging indicator line.",
            category: .phoneBattery,
            requiredDataSource: "Battery",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "0A0A0A", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "battery", x: 10, y: 20, w: 80, h: 32, fontSize: 40, weight: 900, align: "center", color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 25, y: 62, w: 50, h: 3, color: "4DC98A", opacity: 0.9, radius: 2)
                ]
            )
        )

        // ─────────────────────────────────────────────────────────────
        // MARK: - Category 3: Driving
        // ─────────────────────────────────────────────────────────────

        let apexDigitalSpeedo = StockWidgetDefinition(
            stockWidgetId: "stock.apex_digital_speedo",
            stockWidgetVersion: 2,
            name: "Apex Digital Speedometer",
            description: "Massive orange digital speed digits with KM/H unit badge and live clock.",
            category: .driving,
            requiredDataSource: "Speed",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "12131C", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "clock", text: "HH:mm", x: 8, y: 8, w: 50, h: 8, fontSize: 10, weight: 700, align: "left", color: "8899AA"),
                    WidgetLayer(id: uid(), kind: "speed", text: "0", x: 8, y: 22, w: 60, h: 32, fontSize: 42, weight: 900, align: "left", color: "FF6B35"),
                    WidgetLayer(id: uid(), kind: "text", text: "KM/H", x: 70, y: 38, w: 22, h: 8, fontSize: 11, weight: 800, align: "left", color: "FF6B35"),
                    WidgetLayer(id: uid(), kind: "battery", x: 8, y: 68, w: 84, h: 10, fontSize: 12, weight: 800, align: "left", color: "4DC98A")
                ]
            )
        )

        let trackTelemetrySuite = StockWidgetDefinition(
            stockWidgetId: "stock.track_telemetry",
            stockWidgetVersion: 2,
            name: "Track Telemetry Suite",
            description: "Race track dark background with live speed and battery columns.",
            category: .driving,
            requiredDataSource: "Speed",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "181822", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 6, y: 6, w: 88, h: 38, color: "FFFFFF", opacity: 0.06, radius: 10),
                    WidgetLayer(id: uid(), kind: "speed", text: "0", x: 10, y: 12, w: 40, h: 22, fontSize: 24, weight: 900, align: "center", color: "FF6B35"),
                    WidgetLayer(id: uid(), kind: "battery", text: "85%", x: 50, y: 12, w: 40, h: 22, fontSize: 22, weight: 900, align: "center", color: "4DC98A"),
                    WidgetLayer(id: uid(), kind: "clock", text: "HH:mm", x: 10, y: 56, w: 80, h: 20, fontSize: 20, weight: 800, align: "center", color: "FFFFFF")
                ]
            )
        )

        let radarSpeedPod = StockWidgetDefinition(
            stockWidgetId: "stock.radar_speed_pod",
            stockWidgetVersion: 2,
            name: "Radar Speed Arc",
            description: "Circular cyan ring frame with central speed readout and date stamp.",
            category: .driving,
            requiredDataSource: "Speed",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "021720", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "shape", label: "ring", x: 15, y: 10, w: 70, h: 70, color: "00E5FF", opacity: 0.85, radius: 35),
                    WidgetLayer(id: uid(), kind: "speed", text: "0", x: 15, y: 28, w: 70, h: 22, fontSize: 28, weight: 900, align: "center", color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "text", text: "KM/H", x: 15, y: 52, w: 70, h: 6, fontSize: 9, weight: 800, align: "center", color: "00E5FF"),
                    WidgetLayer(id: uid(), kind: "date", text: "EEE d", x: 10, y: 84, w: 80, h: 6, fontSize: 9, weight: 700, align: "center", color: "88CCDD")
                ]
            )
        )

        let triZoneCockpit = StockWidgetDefinition(
            stockWidgetId: "stock.trizone_cockpit",
            stockWidgetVersion: 2,
            name: "Tri-Zone Cockpit",
            description: "Supercar multi-pane layout with top clock, left speed, right battery.",
            category: .driving,
            requiredDataSource: "Telemetry",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "0D1020", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 5, y: 5, w: 90, h: 40, color: "FFFFFF", opacity: 0.08, radius: 10),
                    WidgetLayer(id: uid(), kind: "clock", text: "HH:mm", x: 10, y: 12, w: 80, h: 20, fontSize: 24, weight: 900, align: "center", color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "speed", text: "0", x: 5, y: 50, w: 42, h: 22, fontSize: 22, weight: 900, align: "center", color: "FF6B35"),
                    WidgetLayer(id: uid(), kind: "battery", text: "85%", x: 53, y: 50, w: 42, h: 22, fontSize: 20, weight: 900, align: "center", color: "22C55E")
                ]
            )
        )

        // ─────────────────────────────────────────────────────────────
        // MARK: - Category 4: Vehicle
        // ─────────────────────────────────────────────────────────────

        let cyberSilhouetteCluster = StockWidgetDefinition(
            stockWidgetId: "stock.cyber_silhouette",
            stockWidgetVersion: 2,
            name: "Cyber Vehicle Silhouette",
            description: "Central vehicle graphic overlay with top vehicle name and battery bar.",
            category: .vehicle,
            requiredDataSource: "Vehicle",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "0F0A1C", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "vehicle_name", text: "CYBER SEDAN", x: 8, y: 8, w: 84, h: 8, fontSize: 11, weight: 800, align: "center", color: "A78BFA"),
                    WidgetLayer(id: uid(), kind: "image", src: "template_car", x: 12, y: 22, w: 76, h: 36),
                    WidgetLayer(id: uid(), kind: "battery", text: "85%", x: 8, y: 66, w: 84, h: 14, fontSize: 16, weight: 800, align: "center", color: "4DC98A")
                ]
            )
        )

        let roadsterPerfBadge = StockWidgetDefinition(
            stockWidgetId: "stock.roadster_badge",
            stockWidgetVersion: 2,
            name: "Roadster Performance Badge",
            description: "Metallic dark background with vehicle name header and live speed.",
            category: .vehicle,
            requiredDataSource: "Vehicle",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "1A1A24", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "vehicle_name", text: "HYPER ROADSTER", x: 8, y: 8, w: 84, h: 8, fontSize: 10, weight: 800, align: "left", color: "FFB84D"),
                    WidgetLayer(id: uid(), kind: "speed", text: "0", x: 8, y: 22, w: 50, h: 26, fontSize: 32, weight: 900, align: "left", color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "clock", text: "HH:mm", x: 60, y: 32, w: 32, h: 10, fontSize: 12, weight: 700, align: "right", color: "8899AA"),
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 8, y: 56, w: 84, h: 3, color: "FFB84D", opacity: 0.8, radius: 2)
                ]
            )
        )

        let grandTouringDial = StockWidgetDefinition(
            stockWidgetId: "stock.grand_touring",
            stockWidgetVersion: 2,
            name: "Grand Touring Gold",
            description: "Gold ring shape accent with central vehicle badge, battery, and clock.",
            category: .vehicle,
            requiredDataSource: "Vehicle",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "141008", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "shape", label: "ring", x: 15, y: 10, w: 70, h: 70, color: "F0C040", opacity: 0.85, radius: 35),
                    WidgetLayer(id: uid(), kind: "vehicle_name", text: "GRAND TOURER", x: 15, y: 28, w: 70, h: 8, fontSize: 10, weight: 800, align: "center", color: "F0C040"),
                    WidgetLayer(id: uid(), kind: "battery", text: "85%", x: 15, y: 40, w: 70, h: 16, fontSize: 18, weight: 900, align: "center", color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "clock", text: "HH:mm", x: 10, y: 84, w: 80, h: 6, fontSize: 10, weight: 700, align: "center", color: "D0A030")
                ]
            )
        )

        let minimalistCarCockpit = StockWidgetDefinition(
            stockWidgetId: "stock.minimalist_car_cockpit",
            stockWidgetVersion: 2,
            name: "Minimalist Car Cockpit",
            description: "Charcoal background with vehicle silhouette, white speed, and battery pill.",
            category: .vehicle,
            requiredDataSource: "Vehicle",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "141419", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "image", src: "template_car", x: 15, y: 10, w: 70, h: 36),
                    WidgetLayer(id: uid(), kind: "speed", text: "0", x: 10, y: 50, w: 40, h: 18, fontSize: 20, weight: 900, align: "center", color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "battery", text: "85%", x: 50, y: 50, w: 40, h: 18, fontSize: 18, weight: 800, align: "center", color: "4DC98A")
                ]
            )
        )

        self.widgets = [
            midnightClock,
            zenithDarkClock,
            cyberMidnightMatrix,
            horizonDuskDial,
            minimalStealthTime,
            hyperArcCharge,
            voltPulseMatrix,
            carbonEnergyRing,
            minimalPowerBar,
            apexDigitalSpeedo,
            trackTelemetrySuite,
            radarSpeedPod,
            triZoneCockpit,
            cyberSilhouetteCluster,
            roadsterPerfBadge,
            grandTouringDial,
            minimalistCarCockpit
        ]
    }

    func findWidget(byId id: String) -> StockWidgetDefinition? {
        return widgets.first(where: { $0.stockWidgetId == id || $0.id == id })
    }
}
