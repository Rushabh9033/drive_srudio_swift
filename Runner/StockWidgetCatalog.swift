import Foundation
import SwiftUI

struct StockWidgetCatalog {
    static let shared = StockWidgetCatalog()
    
    let widgets: [StockWidgetDefinition]
    
    private init() {
        let uid = { UUID().uuidString }
        
        // ─────────────────────────────────────────────────────────────
        // MARK: - Category 1: Night & Time (10 Widgets)
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
        
        let nightDrive = StockWidgetDefinition(
            stockWidgetId: "stock.night_drive",
            stockWidgetVersion: 1,
            name: "Night Drive",
            description: "Cyberpunk inspired neon matrix dashboard.",
            category: .nightTime,
            requiredDataSource: "Time",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "07070F", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "CYBER", x: 5.9, y: 5.6, w: 29.6, h: 5.6, fontSize: 7.5, weight: 800, align: "left", color: "FFB84D", opacity: 0.8),
                    WidgetLayer(id: uid(), kind: "clock", x: 74, y: 4.2, w: 23.7, h: 8.5, fontSize: 10.7, weight: 600, align: "right", color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 14.8, y: 56.5, w: 71, h: 2.8, color: "FFB84D", opacity: 0.4, radius: 5),
                    WidgetLayer(id: uid(), kind: "image", src: "template_car", x: 11.8, y: 28.2, w: 76.9, h: 31.1)
                ]
            )
        )
        
        let horizonDate = StockWidgetDefinition(
            stockWidgetId: "stock.horizon_date",
            stockWidgetVersion: 1,
            name: "Horizon Date",
            description: "Sunrise inspired date and time display.",
            category: .nightTime,
            requiredDataSource: "Time",
            document: WidgetSpec(
                background: WidgetBackground(type: "gradient", from: "1A0B00", to: "050505", imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "TODAY", x: 5.9, y: 5.6, w: 29.6, h: 5.6, fontSize: 7.5, weight: 700, color: "FF6B00"),
                    WidgetLayer(id: uid(), kind: "date", text: "EEE d", x: 5.9, y: 14.1, w: 59.2, h: 16.9, fontSize: 25.6, weight: 800, color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "clock", x: 5.9, y: 33.9, w: 29.6, h: 8.5, fontSize: 12.8, weight: 500, color: "AAAAAA")
                ]
            )
        )
        
        let minimalTime = StockWidgetDefinition(
            stockWidgetId: "stock.minimal_time",
            stockWidgetVersion: 1,
            name: "Minimal Time",
            description: "Clean and distraction-free time display.",
            category: .nightTime,
            requiredDataSource: "Time",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "111111", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "clock", x: 47.3, y: 19.8, w: 74, h: 28.2, fontSize: 38.3, weight: 300, align: "center", color: "FFFFFF")
                ]
            )
        )
        
        let tokyoNeon = StockWidgetDefinition(
            stockWidgetId: "stock.tokyo_neon",
            stockWidgetVersion: 1,
            name: "Tokyo Neon",
            description: "Vibrant neon magenta and cyan night clock.",
            category: .nightTime,
            requiredDataSource: "Time",
            document: WidgetSpec(
                background: WidgetBackground(type: "gradient", from: "0F001A", to: "000F1A", imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "TOKYO NIGHTS", x: 47.3, y: 8.0, w: 70, h: 6.0, fontSize: 7.0, weight: 800, align: "center", color: "00FFFF"),
                    WidgetLayer(id: uid(), kind: "clock", x: 47.3, y: 20.0, w: 75, h: 24.0, fontSize: 32.0, weight: 900, align: "center", color: "FF007F")
                ]
            )
        )
        
        let stealthTime = StockWidgetDefinition(
            stockWidgetId: "stock.stealth_time",
            stockWidgetVersion: 1,
            name: "Stealth Digital",
            description: "Matte dark theme with subtle metallic typography.",
            category: .nightTime,
            requiredDataSource: "Time",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "18181A", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "clock", x: 47.3, y: 16.0, w: 65, h: 20.0, fontSize: 28.0, weight: 700, align: "center", color: "E5E5EA"),
                    WidgetLayer(id: uid(), kind: "text", text: "STEALTH CLUSTER", x: 47.3, y: 40.0, w: 60, h: 5.0, fontSize: 6.0, weight: 600, align: "center", color: "8E8E93")
                ]
            )
        )
        
        let lunarPhase = StockWidgetDefinition(
            stockWidgetId: "stock.lunar_phase",
            stockWidgetVersion: 1,
            name: "Lunar Clock",
            description: "Deep space ambient clock with date background.",
            category: .nightTime,
            requiredDataSource: "Time & Date",
            document: WidgetSpec(
                background: WidgetBackground(type: "gradient", from: "050B14", to: "000000", imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "date", text: "MMMM d", x: 47.3, y: 12.0, w: 80, h: 8.0, fontSize: 9.0, weight: 600, align: "center", color: "64D2FF"),
                    WidgetLayer(id: uid(), kind: "clock", x: 47.3, y: 26.0, w: 70, h: 22.0, fontSize: 30.0, weight: 800, align: "center", color: "FFFFFF")
                ]
            )
        )
        
        let starlightDate = StockWidgetDefinition(
            stockWidgetId: "stock.starlight_date",
            stockWidgetVersion: 1,
            name: "Starlight Date",
            description: "Midnight blue layout displaying full date and time.",
            category: .nightTime,
            requiredDataSource: "Time & Date",
            document: WidgetSpec(
                background: WidgetBackground(type: "gradient", from: "0A1628", to: "020813", imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "NIGHT CRUISE", x: 10.0, y: 8.0, w: 40, h: 6.0, fontSize: 7.0, weight: 800, color: "30D158"),
                    WidgetLayer(id: uid(), kind: "clock", x: 10.0, y: 18.0, w: 60, h: 18.0, fontSize: 24.0, weight: 700, color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "date", text: "EEEE, MMM d", x: 10.0, y: 38.0, w: 70, h: 6.0, fontSize: 8.0, weight: 500, color: "8E8E93")
                ]
            )
        )
        
        let gridMatrix = StockWidgetDefinition(
            stockWidgetId: "stock.grid_matrix",
            stockWidgetVersion: 1,
            name: "Grid Matrix",
            description: "Futuristic HUD matrix clock design.",
            category: .nightTime,
            requiredDataSource: "Time",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "000A05", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "SYSTEM TIME", x: 47.3, y: 8.0, w: 60, h: 5.0, fontSize: 6.5, weight: 800, align: "center", color: "30D158"),
                    WidgetLayer(id: uid(), kind: "clock", x: 47.3, y: 22.0, w: 70, h: 22.0, fontSize: 32.0, weight: 900, align: "center", color: "FFFFFF")
                ]
            )
        )
        
        let apexChrono = StockWidgetDefinition(
            stockWidgetId: "stock.apex_chrono",
            stockWidgetVersion: 1,
            name: "Apex Chrono",
            description: "Motorsport chronograph styling.",
            category: .nightTime,
            requiredDataSource: "Time",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "140000", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "CHRONO CLUSTER", x: 47.3, y: 10.0, w: 70, h: 6.0, fontSize: 7.0, weight: 800, align: "center", color: "FF453A"),
                    WidgetLayer(id: uid(), kind: "clock", x: 47.3, y: 24.0, w: 70, h: 20.0, fontSize: 28.0, weight: 800, align: "center", color: "FFFFFF")
                ]
            )
        )

        // ─────────────────────────────────────────────────────────────
        // MARK: - Category 2: Phone Battery (10 Widgets)
        // ─────────────────────────────────────────────────────────────
        
        let batteryRing = StockWidgetDefinition(
            stockWidgetId: "stock.battery_ring",
            stockWidgetVersion: 1,
            name: "Battery Ring",
            description: "A sleek radial indicator for your phone battery.",
            category: .phoneBattery,
            requiredDataSource: "Phone Battery",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "18181A", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "shape", label: "circle", x: 29.6, y: 11.3, w: 35.5, h: 33.9, color: "333333", opacity: 1.0, radius: 60, strokes: "4"),
                    WidgetLayer(id: uid(), kind: "battery", x: 47.3, y: 22.6, w: 29.6, h: 11.3, fontSize: 14.9, weight: 700, align: "center", color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "text", text: "PHONE BATTERY", x: 47.3, y: 50.8, w: 59.2, h: 5.6, fontSize: 6.4, weight: 600, align: "center", color: "888888")
                ]
            )
        )
        
        let energyBars = StockWidgetDefinition(
            stockWidgetId: "stock.energy_bars",
            stockWidgetVersion: 1,
            name: "Energy Bars",
            description: "Performance-style bar graph for phone power.",
            category: .phoneBattery,
            requiredDataSource: "Phone Battery",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "0A0A0A", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "PHONE POWER", x: 5.9, y: 5.6, w: 44.4, h: 5.6, fontSize: 7.5, weight: 800, color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 5.9, y: 16.9, w: 82.8, h: 5.6, color: "222222", radius: 4),
                    WidgetLayer(id: uid(), kind: "battery", x: 5.9, y: 26.0, w: 40.0, h: 12.0, fontSize: 16.0, weight: 700, color: "FFB84D")
                ]
            )
        )
        
        let chargingArc = StockWidgetDefinition(
            stockWidgetId: "stock.charging_arc",
            stockWidgetVersion: 1,
            name: "Charging Arc",
            description: "Elegant arc displaying phone charge status.",
            category: .phoneBattery,
            requiredDataSource: "Phone Battery",
            document: WidgetSpec(
                background: WidgetBackground(type: "gradient", from: "1A1A1A", to: "050505", imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "PHONE", x: 47.3, y: 11.3, w: 29.6, h: 5.6, fontSize: 7.5, weight: 600, align: "center", color: "AAAAAA"),
                    WidgetLayer(id: uid(), kind: "battery", x: 47.3, y: 19.8, w: 44.4, h: 16.9, fontSize: 29.8, weight: 800, align: "center", color: "FFFFFF")
                ]
            )
        )
        
        let batteryMinimal = StockWidgetDefinition(
            stockWidgetId: "stock.battery_minimal",
            stockWidgetVersion: 1,
            name: "Battery Minimal",
            description: "Unobtrusive phone battery indicator.",
            category: .phoneBattery,
            requiredDataSource: "Phone Battery",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "000000", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "BATTERY", x: 5.9, y: 5.6, w: 29.6, h: 5.6, fontSize: 7.5, weight: 600, color: "888888"),
                    WidgetLayer(id: uid(), kind: "battery", x: 5.9, y: 14.1, w: 44.4, h: 14.1, fontSize: 21.3, weight: 700, color: "FFFFFF")
                ]
            )
        )
        
        let hyperCharge = StockWidgetDefinition(
            stockWidgetId: "stock.hyper_charge",
            stockWidgetVersion: 1,
            name: "Hyper Charge",
            description: "Neon green power cell monitor.",
            category: .phoneBattery,
            requiredDataSource: "Phone Battery",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "051408", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "POWER CELL", x: 47.3, y: 8.0, w: 60, h: 6.0, fontSize: 7.0, weight: 800, align: "center", color: "30D158"),
                    WidgetLayer(id: uid(), kind: "battery", x: 47.3, y: 20.0, w: 60, h: 20.0, fontSize: 28.0, weight: 900, align: "center", color: "FFFFFF")
                ]
            )
        )
        
        let powerMatrix = StockWidgetDefinition(
            stockWidgetId: "stock.power_matrix",
            stockWidgetVersion: 1,
            name: "Power Matrix",
            description: "Grid telemetry layout for battery health.",
            category: .phoneBattery,
            requiredDataSource: "Phone Battery",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "141419", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "DEVICE STATE", x: 10.0, y: 8.0, w: 50, h: 6.0, fontSize: 7.0, weight: 700, color: "64D2FF"),
                    WidgetLayer(id: uid(), kind: "battery", x: 10.0, y: 18.0, w: 50, h: 18.0, fontSize: 24.0, weight: 800, color: "FFFFFF")
                ]
            )
        )
        
        let titaniumPower = StockWidgetDefinition(
            stockWidgetId: "stock.titanium_power",
            stockWidgetVersion: 1,
            name: "Titanium Power",
            description: "Brushed titanium finish with gold telemetry.",
            category: .phoneBattery,
            requiredDataSource: "Phone Battery",
            document: WidgetSpec(
                background: WidgetBackground(type: "gradient", from: "2C2C2E", to: "1C1C1E", imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "TITANIUM BATTERY", x: 47.3, y: 10.0, w: 80, h: 6.0, fontSize: 7.0, weight: 800, align: "center", color: "FFD60A"),
                    WidgetLayer(id: uid(), kind: "battery", x: 47.3, y: 22.0, w: 70, h: 20.0, fontSize: 26.0, weight: 800, align: "center", color: "FFFFFF")
                ]
            )
        )
        
        let electricFlow = StockWidgetDefinition(
            stockWidgetId: "stock.electric_flow",
            stockWidgetVersion: 1,
            name: "Electric Flow",
            description: "Dynamic blue energy indicator.",
            category: .phoneBattery,
            requiredDataSource: "Phone Battery",
            document: WidgetSpec(
                background: WidgetBackground(type: "gradient", from: "001A33", to: "000B14", imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "battery", x: 47.3, y: 16.0, w: 60, h: 22.0, fontSize: 30.0, weight: 900, align: "center", color: "64D2FF"),
                    WidgetLayer(id: uid(), kind: "text", text: "LITHIUM LEVEL", x: 47.3, y: 40.0, w: 60, h: 5.0, fontSize: 6.5, weight: 600, align: "center", color: "0A84FF")
                ]
            )
        )
        
        let voltIndicator = StockWidgetDefinition(
            stockWidgetId: "stock.volt_indicator",
            stockWidgetVersion: 1,
            name: "Volt Indicator",
            description: "High-contrast motorsport telemetry battery status.",
            category: .phoneBattery,
            requiredDataSource: "Phone Battery",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "120014", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "VOLTAGE MON", x: 10.0, y: 8.0, w: 50, h: 6.0, fontSize: 7.0, weight: 800, color: "BF5AF2"),
                    WidgetLayer(id: uid(), kind: "battery", x: 10.0, y: 18.0, w: 50, h: 18.0, fontSize: 26.0, weight: 800, color: "FFFFFF")
                ]
            )
        )
        
        let ecoPercent = StockWidgetDefinition(
            stockWidgetId: "stock.eco_percent",
            stockWidgetVersion: 1,
            name: "Eco Percent",
            description: "Clean emerald green power display.",
            category: .phoneBattery,
            requiredDataSource: "Phone Battery",
            document: WidgetSpec(
                background: WidgetBackground(type: "gradient", from: "0A2912", to: "020F05", imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "battery", x: 47.3, y: 16.0, w: 65, h: 22.0, fontSize: 28.0, weight: 800, align: "center", color: "34C759"),
                    WidgetLayer(id: uid(), kind: "text", text: "ECO ENERGY", x: 47.3, y: 40.0, w: 60, h: 5.0, fontSize: 6.5, weight: 700, align: "center", color: "FFFFFF")
                ]
            )
        )

        // ─────────────────────────────────────────────────────────────
        // MARK: - Category 3: Driving (10 Widgets)
        // ─────────────────────────────────────────────────────────────
        
        let speedFocus = StockWidgetDefinition(
            stockWidgetId: "stock.speed_focus",
            stockWidgetVersion: 1,
            name: "Speed Focus",
            description: "Large, hyper-readable live GPS speed.",
            category: .driving,
            requiredDataSource: "Core Location",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "0A0A0A", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "speed", x: 47.3, y: 11.3, w: 74, h: 28.2, fontSize: 51.1, weight: 800, align: "center", color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "text", text: "KM/H", x: 47.3, y: 42.4, w: 29.6, h: 5.6, fontSize: 9.6, weight: 700, align: "center", color: "FFB84D")
                ]
            )
        )
        
        let lastDrive = StockWidgetDefinition(
            stockWidgetId: "stock.last_drive",
            stockWidgetVersion: 1,
            name: "Last Drive",
            description: "Summary of your last recorded speed and time.",
            category: .driving,
            requiredDataSource: "Core Location",
            document: WidgetSpec(
                background: WidgetBackground(type: "gradient", from: "111122", to: "050511", imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "LAST RECORDED", x: 5.9, y: 5.6, w: 44.4, h: 5.6, fontSize: 6.4, weight: 700, color: "8888AA"),
                    WidgetLayer(id: uid(), kind: "speed", x: 5.9, y: 14.1, w: 29.6, h: 14.1, fontSize: 25.6, weight: 800, color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "text", text: "km/h", x: 23.7, y: 19.8, w: 17.8, h: 5.6, fontSize: 8.5, weight: 600, color: "AAAAAA")
                ]
            )
        )
        
        let driveClock = StockWidgetDefinition(
            stockWidgetId: "stock.drive_clock",
            stockWidgetVersion: 1,
            name: "Drive Clock",
            description: "GPS speed paired with a distraction-free clock.",
            category: .driving,
            requiredDataSource: "Core Location & Time",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "1C1C1E", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "clock", x: 5.9, y: 5.6, w: 44.4, h: 11.3, fontSize: 17, weight: 700, color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "text", text: "SPEED", x: 5.9, y: 22.6, w: 29.6, h: 4.2, fontSize: 6.4, weight: 600, color: "888888"),
                    WidgetLayer(id: uid(), kind: "speed", x: 5.9, y: 28.2, w: 29.6, h: 11.3, fontSize: 19.2, weight: 800, color: "FFB84D")
                ]
            )
        )
        
        let hudSpeedometer = StockWidgetDefinition(
            stockWidgetId: "stock.hud_speedometer",
            stockWidgetVersion: 1,
            name: "HUD Speedometer",
            description: "Head-up digital cluster with live GPS speed.",
            category: .driving,
            requiredDataSource: "Core Location",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "030A14", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "GPS VELOCITY", x: 47.3, y: 8.0, w: 60, h: 6.0, fontSize: 7.0, weight: 800, align: "center", color: "64D2FF"),
                    WidgetLayer(id: uid(), kind: "speed", x: 47.3, y: 20.0, w: 70, h: 22.0, fontSize: 36.0, weight: 900, align: "center", color: "FFFFFF")
                ]
            )
        )
        
        let supercarGauge = StockWidgetDefinition(
            stockWidgetId: "stock.supercar_gauge",
            stockWidgetVersion: 1,
            name: "Supercar Gauge",
            description: "Redline supercar cockpit speedometer.",
            category: .driving,
            requiredDataSource: "Core Location",
            document: WidgetSpec(
                background: WidgetBackground(type: "gradient", from: "200000", to: "0A0000", imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "RACE CLUSTER", x: 10.0, y: 8.0, w: 50, h: 6.0, fontSize: 7.0, weight: 800, color: "FF453A"),
                    WidgetLayer(id: uid(), kind: "speed", x: 10.0, y: 18.0, w: 60, h: 22.0, fontSize: 32.0, weight: 900, color: "FFFFFF")
                ]
            )
        )
        
        let driftTelemetry = StockWidgetDefinition(
            stockWidgetId: "stock.drift_telemetry",
            stockWidgetVersion: 1,
            name: "Drift Telemetry",
            description: "Amber track telemetry readout.",
            category: .driving,
            requiredDataSource: "Core Location",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "140F00", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "speed", x: 47.3, y: 14.0, w: 70, h: 22.0, fontSize: 32.0, weight: 800, align: "center", color: "FF9500"),
                    WidgetLayer(id: uid(), kind: "text", text: "KM/H RECORDED", x: 47.3, y: 38.0, w: 65, h: 5.0, fontSize: 6.5, weight: 700, align: "center", color: "FFFFFF")
                ]
            )
        )
        
        let cityCruiser = StockWidgetDefinition(
            stockWidgetId: "stock.city_cruiser",
            stockWidgetVersion: 1,
            name: "City Cruiser",
            description: "Urban drive mode speed indicator.",
            category: .driving,
            requiredDataSource: "Core Location",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "1C1C1E", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "CITY PACER", x: 10.0, y: 10.0, w: 50, h: 6.0, fontSize: 7.0, weight: 700, color: "30D158"),
                    WidgetLayer(id: uid(), kind: "speed", x: 10.0, y: 20.0, w: 50, h: 18.0, fontSize: 26.0, weight: 800, color: "FFFFFF")
                ]
            )
        )
        
        let velocityRing = StockWidgetDefinition(
            stockWidgetId: "stock.velocity_ring",
            stockWidgetVersion: 1,
            name: "Velocity Ring",
            description: "Circular velocity layout.",
            category: .driving,
            requiredDataSource: "Core Location",
            document: WidgetSpec(
                background: WidgetBackground(type: "gradient", from: "120024", to: "05000A", imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "speed", x: 47.3, y: 16.0, w: 70, h: 22.0, fontSize: 32.0, weight: 800, align: "center", color: "BF5AF2"),
                    WidgetLayer(id: uid(), kind: "text", text: "VELOCITY", x: 47.3, y: 40.0, w: 50, h: 5.0, fontSize: 6.5, weight: 600, align: "center", color: "FFFFFF")
                ]
            )
        )
        
        let trackPace = StockWidgetDefinition(
            stockWidgetId: "stock.track_pace",
            stockWidgetVersion: 1,
            name: "Track Pace",
            description: "Minimal lap pacing speedometer.",
            category: .driving,
            requiredDataSource: "Core Location",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "001A18", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "TRACK PACE", x: 47.3, y: 10.0, w: 60, h: 6.0, fontSize: 7.0, weight: 800, align: "center", color: "64D2FF"),
                    WidgetLayer(id: uid(), kind: "speed", x: 47.3, y: 22.0, w: 60, h: 20.0, fontSize: 28.0, weight: 800, align: "center", color: "FFFFFF")
                ]
            )
        )
        
        let highwayRunner = StockWidgetDefinition(
            stockWidgetId: "stock.highway_runner",
            stockWidgetVersion: 1,
            name: "Highway Runner",
            description: "High visibility yellow velocity gauge.",
            category: .driving,
            requiredDataSource: "Core Location",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "191400", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "speed", x: 10.0, y: 12.0, w: 60, h: 22.0, fontSize: 34.0, weight: 900, color: "FFD60A"),
                    WidgetLayer(id: uid(), kind: "text", text: "HIGHWAY SPEED", x: 10.0, y: 36.0, w: 60, h: 6.0, fontSize: 7.0, weight: 700, color: "FFFFFF")
                ]
            )
        )

        // ─────────────────────────────────────────────────────────────
        // MARK: - Category 4: Vehicle (10 Widgets)
        // ─────────────────────────────────────────────────────────────
        
        let vehicleProfile = StockWidgetDefinition(
            stockWidgetId: "stock.vehicle_profile",
            stockWidgetVersion: 1,
            name: "Vehicle Profile",
            description: "Showcase your selected fictional vehicle.",
            category: .vehicle,
            requiredDataSource: "Selected Vehicle",
            document: WidgetSpec(
                background: WidgetBackground(type: "gradient", from: "222222", to: "000000", imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "MY VEHICLE", x: 47.3, y: 5.6, w: 59.2, h: 5.6, fontSize: 7.5, weight: 800, align: "center", color: "FFFFFF", opacity: 0.8),
                    WidgetLayer(id: uid(), kind: "image", src: "template_car", x: 25.1, y: 16.9, w: 44.4, h: 22.6),
                    WidgetLayer(id: uid(), kind: "vehicle_name", x: 47.3, y: 42.4, w: 74, h: 8.5, fontSize: 11.7, weight: 700, align: "center", color: "FFB84D")
                ]
            )
        )
        
        let cyberRoadster = StockWidgetDefinition(
            stockWidgetId: "stock.cyber_roadster",
            stockWidgetVersion: 1,
            name: "Cyber Roadster",
            description: "Futuristic roadster profile display.",
            category: .vehicle,
            requiredDataSource: "Selected Vehicle",
            document: WidgetSpec(
                background: WidgetBackground(type: "gradient", from: "0F001E", to: "000A19", imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "CYBER ROADSTER", x: 47.3, y: 8.0, w: 75, h: 6.0, fontSize: 7.5, weight: 800, align: "center", color: "BF5AF2"),
                    WidgetLayer(id: uid(), kind: "image", src: "template_car", x: 25.1, y: 18.0, w: 45.0, h: 22.0),
                    WidgetLayer(id: uid(), kind: "vehicle_name", x: 47.3, y: 42.0, w: 70, h: 8.0, fontSize: 10.5, weight: 700, align: "center", color: "64D2FF")
                ]
            )
        )
        
        let hyperCoupe = StockWidgetDefinition(
            stockWidgetId: "stock.hyper_coupe",
            stockWidgetVersion: 1,
            name: "Hyper Coupe",
            description: "High-performance sports coupe card.",
            category: .vehicle,
            requiredDataSource: "Selected Vehicle",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "140505", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "vehicle_name", x: 10.0, y: 8.0, w: 70, h: 8.0, fontSize: 12.0, weight: 900, color: "FF3B30"),
                    WidgetLayer(id: uid(), kind: "image", src: "template_car", x: 10.0, y: 18.0, w: 50.0, h: 22.0),
                    WidgetLayer(id: uid(), kind: "text", text: "HYPER EDITION", x: 10.0, y: 42.0, w: 50, h: 5.0, fontSize: 6.5, weight: 700, color: "E5E5EA")
                ]
            )
        )
        
        let apexSuv = StockWidgetDefinition(
            stockWidgetId: "stock.apex_suv",
            stockWidgetVersion: 1,
            name: "Apex SUV",
            description: "Luxury SUV status badge.",
            category: .vehicle,
            requiredDataSource: "Selected Vehicle",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "1A1A1E", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "LUXURY SPEC", x: 47.3, y: 8.0, w: 60, h: 6.0, fontSize: 7.0, weight: 800, align: "center", color: "FFD60A"),
                    WidgetLayer(id: uid(), kind: "image", src: "template_car", x: 25.1, y: 18.0, w: 45.0, h: 22.0),
                    WidgetLayer(id: uid(), kind: "vehicle_name", x: 47.3, y: 42.0, w: 70, h: 8.0, fontSize: 11.0, weight: 700, align: "center", color: "FFFFFF")
                ]
            )
        )
        
        let gtTrack = StockWidgetDefinition(
            stockWidgetId: "stock.gt_track",
            stockWidgetVersion: 1,
            name: "GT Track Edition",
            description: "Motorsport racing car profile.",
            category: .vehicle,
            requiredDataSource: "Selected Vehicle",
            document: WidgetSpec(
                background: WidgetBackground(type: "gradient", from: "190F00", to: "0A0500", imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "GT SPORT", x: 10.0, y: 8.0, w: 50, h: 6.0, fontSize: 7.5, weight: 800, color: "FF9500"),
                    WidgetLayer(id: uid(), kind: "image", src: "template_car", x: 10.0, y: 18.0, w: 50.0, h: 22.0),
                    WidgetLayer(id: uid(), kind: "vehicle_name", x: 10.0, y: 42.0, w: 70, h: 8.0, fontSize: 11.0, weight: 700, color: "FFFFFF")
                ]
            )
        )
        
        let stealthSedan = StockWidgetDefinition(
            stockWidgetId: "stock.stealth_sedan",
            stockWidgetVersion: 1,
            name: "Stealth Sedan",
            description: "Dark titanium luxury sedan card.",
            category: .vehicle,
            requiredDataSource: "Selected Vehicle",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "0D0D0D", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "vehicle_name", x: 47.3, y: 10.0, w: 75, h: 8.0, fontSize: 11.5, weight: 800, align: "center", color: "E5E5EA"),
                    WidgetLayer(id: uid(), kind: "image", src: "template_car", x: 25.1, y: 20.0, w: 45.0, h: 22.0)
                ]
            )
        )
        
        let retroSynth = StockWidgetDefinition(
            stockWidgetId: "stock.retro_synth",
            stockWidgetVersion: 1,
            name: "80s Synth Rider",
            description: "Retro 80s synthwave vehicle card.",
            category: .vehicle,
            requiredDataSource: "Selected Vehicle",
            document: WidgetSpec(
                background: WidgetBackground(type: "gradient", from: "1F001B", to: "001A1A", imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "SYNTH RIDER", x: 47.3, y: 8.0, w: 70, h: 6.0, fontSize: 7.5, weight: 900, align: "center", color: "FF007F"),
                    WidgetLayer(id: uid(), kind: "image", src: "template_car", x: 25.1, y: 18.0, w: 45.0, h: 22.0),
                    WidgetLayer(id: uid(), kind: "vehicle_name", x: 47.3, y: 42.0, w: 70, h: 8.0, fontSize: 10.5, weight: 700, align: "center", color: "00FFFF")
                ]
            )
        )
        
        let futureEv = StockWidgetDefinition(
            stockWidgetId: "stock.future_ev",
            stockWidgetVersion: 1,
            name: "Future EV Concept",
            description: "Clean cyan futuristic electric vehicle badge.",
            category: .vehicle,
            requiredDataSource: "Selected Vehicle",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "02121A", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "ELECTRIC ARCHITECTURE", x: 47.3, y: 8.0, w: 80, h: 6.0, fontSize: 6.5, weight: 800, align: "center", color: "64D2FF"),
                    WidgetLayer(id: uid(), kind: "image", src: "template_car", x: 25.1, y: 18.0, w: 45.0, h: 22.0),
                    WidgetLayer(id: uid(), kind: "vehicle_name", x: 47.3, y: 42.0, w: 70, h: 8.0, fontSize: 11.0, weight: 700, align: "center", color: "FFFFFF")
                ]
            )
        )
        
        let garageMaster = StockWidgetDefinition(
            stockWidgetId: "stock.garage_master",
            stockWidgetVersion: 1,
            name: "Garage Master",
            description: "Personal garage vehicle showcase card.",
            category: .vehicle,
            requiredDataSource: "Selected Vehicle",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "141414", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "GARAGE UNIT 01", x: 10.0, y: 8.0, w: 60, h: 6.0, fontSize: 7.0, weight: 700, color: "30D158"),
                    WidgetLayer(id: uid(), kind: "image", src: "template_car", x: 10.0, y: 18.0, w: 50.0, h: 22.0),
                    WidgetLayer(id: uid(), kind: "vehicle_name", x: 10.0, y: 42.0, w: 70, h: 8.0, fontSize: 11.0, weight: 700, color: "FFFFFF")
                ]
            )
        )
        
        let phantomGt = StockWidgetDefinition(
            stockWidgetId: "stock.phantom_gt",
            stockWidgetVersion: 1,
            name: "Phantom GT",
            description: "Deep obsidian dark purple car badge.",
            category: .vehicle,
            requiredDataSource: "Selected Vehicle",
            document: WidgetSpec(
                background: WidgetBackground(type: "gradient", from: "12051A", to: "05020B", imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "PHANTOM SPEC", x: 47.3, y: 8.0, w: 70, h: 6.0, fontSize: 7.0, weight: 800, align: "center", color: "BF5AF2"),
                    WidgetLayer(id: uid(), kind: "image", src: "template_car", x: 25.1, y: 18.0, w: 45.0, h: 22.0),
                    WidgetLayer(id: uid(), kind: "vehicle_name", x: 47.3, y: 42.0, w: 70, h: 8.0, fontSize: 11.0, weight: 700, align: "center", color: "FFFFFF")
                ]
            )
        )
        
        
        // ─────────────────────────────────────────────────────────────
        // MARK: - Category 5: Stitch Studio Widgets (16 Widgets)
        // ─────────────────────────────────────────────────────────────

        let stitchBatteryDots = StockWidgetDefinition(
            stockWidgetId: "stock.stitch_battery_dots",
            stockWidgetVersion: 1,
            name: "Battery Dots",
            description: "Cyan matrix grid dot battery status display.",
            category: .phoneBattery,
            requiredDataSource: "Phone Battery",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "0D1515", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 10, y: 10, w: 80, h: 80, color: "151D1E", opacity: 0.9, radius: 16),
                    WidgetLayer(id: uid(), kind: "shape", label: "circle", x: 25, y: 20, w: 50, h: 40, color: "00F0FF", opacity: 0.25, radius: 20),
                    WidgetLayer(id: uid(), kind: "text", text: "BATTERY DOTS", x: 10, y: 18, w: 80, h: 6, fontSize: 8, weight: 800, align: "center", color: "B9CACB"),
                    WidgetLayer(id: uid(), kind: "battery", x: 10, y: 40, w: 80, h: 24, fontSize: 26, weight: 900, align: "center", color: "00F0FF")
                ]
            )
        )

        let stitchBatteryMatrix = StockWidgetDefinition(
            stockWidgetId: "stock.stitch_battery_matrix",
            stockWidgetVersion: 1,
            name: "Battery Matrix",
            description: "Cyber matrix grid of power cells.",
            category: .phoneBattery,
            requiredDataSource: "Phone Battery",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "080F10", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "192122", opacity: 0.95, radius: 14),
                    WidgetLayer(id: uid(), kind: "text", text: "MATRIX POWER", x: 12, y: 15, w: 76, h: 8, fontSize: 9, weight: 800, align: "left", color: "00DBE9"),
                    WidgetLayer(id: uid(), kind: "battery", x: 12, y: 32, w: 76, h: 24, fontSize: 28, weight: 900, align: "left", color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 12, y: 68, w: 76, h: 4, color: "00DBE9", opacity: 0.9, radius: 2)
                ]
            )
        )

        let stitchClockPixelNeon = StockWidgetDefinition(
            stockWidgetId: "stock.stitch_clock_pixel_neon",
            stockWidgetVersion: 1,
            name: "Pixel Neon Clock",
            description: "Retro cyberpunk pixel digital clock display.",
            category: .nightTime,
            requiredDataSource: "Time",
            document: WidgetSpec(
                background: WidgetBackground(type: "gradient", from: "0D1515", to: "080F10", imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "B600F8", opacity: 0.12, radius: 16),
                    WidgetLayer(id: uid(), kind: "clock", x: 10, y: 22, w: 80, h: 32, fontSize: 32, weight: 900, align: "center", color: "00F0FF"),
                    WidgetLayer(id: uid(), kind: "text", text: "SYS.OK // SYNC", x: 10, y: 66, w: 80, h: 8, fontSize: 9, weight: 800, align: "center", color: "EBB2FF")
                ]
            )
        )

        let stitchClockSegments = StockWidgetDefinition(
            stockWidgetId: "stock.stitch_clock_segments",
            stockWidgetVersion: 1,
            name: "Segment LED Clock",
            description: "7-segment cyan LED digital HUD clock.",
            category: .nightTime,
            requiredDataSource: "Time",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "0D1515", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "151D1E", opacity: 0.9, radius: 14),
                    WidgetLayer(id: uid(), kind: "text", text: "7-SEGMENT HUD", x: 12, y: 16, w: 76, h: 8, fontSize: 8, weight: 700, align: "left", color: "7DF4FF"),
                    WidgetLayer(id: uid(), kind: "clock", x: 10, y: 30, w: 80, h: 32, fontSize: 34, weight: 900, align: "center", color: "00F0FF"),
                    WidgetLayer(id: uid(), kind: "text", text: "SYNC ACTIVE", x: 12, y: 68, w: 76, h: 8, fontSize: 8, weight: 600, align: "right", color: "7DF4FF")
                ]
            )
        )

        let stitchClockPill = StockWidgetDefinition(
            stockWidgetId: "stock.stitch_clock_pill",
            stockWidgetVersion: 1,
            name: "Clock Pill Capsule",
            description: "Capsule pill design displaying live clock and date.",
            category: .nightTime,
            requiredDataSource: "Time & Date",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "080F10", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 10, y: 15, w: 80, h: 42, color: "00363A", opacity: 0.6, radius: 21),
                    WidgetLayer(id: uid(), kind: "clock", x: 15, y: 22, w: 70, h: 28, fontSize: 26, weight: 900, align: "center", color: "00F0FF"),
                    WidgetLayer(id: uid(), kind: "date", x: 10, y: 65, w: 80, h: 12, fontSize: 11, weight: 700, align: "center", color: "FFB86F")
                ]
            )
        )

        let stitchCalendarMonth = StockWidgetDefinition(
            stockWidgetId: "stock.stitch_calendar_month",
            stockWidgetVersion: 1,
            name: "Calendar Month View",
            description: "Monthly calendar view with live date accent.",
            category: .nightTime,
            requiredDataSource: "Time & Date",
            document: WidgetSpec(
                background: WidgetBackground(type: "gradient", from: "0D1515", to: "080F10", imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "CALENDAR", x: 10, y: 10, w: 80, h: 8, fontSize: 9, weight: 800, align: "left", color: "00DBE9"),
                    WidgetLayer(id: uid(), kind: "date", x: 10, y: 24, w: 80, h: 16, fontSize: 16, weight: 800, align: "left", color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 10, y: 48, w: 80, h: 36, color: "00DBE9", opacity: 0.12, radius: 10),
                    WidgetLayer(id: uid(), kind: "clock", x: 15, y: 58, w: 70, h: 16, fontSize: 14, weight: 700, align: "center", color: "00DBE9")
                ]
            )
        )

        let stitchClockHalo = StockWidgetDefinition(
            stockWidgetId: "stock.stitch_clock_halo",
            stockWidgetVersion: 1,
            name: "Clock Halo Ring",
            description: "Glowing circular cyan halo ring with digital clock.",
            category: .nightTime,
            requiredDataSource: "Time",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "020408", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "shape", label: "ring", x: 15, y: 15, w: 70, h: 70, color: "00F0FF", radius: 35),
                    WidgetLayer(id: uid(), kind: "clock", x: 15, y: 34, w: 70, h: 22, fontSize: 24, weight: 900, align: "center", color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "date", x: 15, y: 58, w: 70, h: 8, fontSize: 9, weight: 600, align: "center", color: "B9CACB")
                ]
            )
        )

        let stitchClockLeather = StockWidgetDefinition(
            stockWidgetId: "stock.stitch_clock_leather",
            stockWidgetVersion: 1,
            name: "Clock Leather Stitched",
            description: "Luxury dark leather texture with warm gold clock.",
            category: .nightTime,
            requiredDataSource: "Time",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "1A1A1A", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "333333", opacity: 0.8, radius: 16),
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 10, y: 10, w: 80, h: 80, color: "1A1A1A", opacity: 1.0, radius: 14),
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 15, y: 15, w: 70, h: 2, color: "F5B041", opacity: 0.9, radius: 1),
                    WidgetLayer(id: uid(), kind: "clock", x: 10, y: 30, w: 80, h: 28, fontSize: 28, weight: 800, align: "center", color: "F5B041"),
                    WidgetLayer(id: uid(), kind: "text", text: "LUXURY EDITION", x: 10, y: 65, w: 80, h: 8, fontSize: 8, weight: 700, align: "center", color: "AAAAAA")
                ]
            )
        )

        let stitchClockSpeech = StockWidgetDefinition(
            stockWidgetId: "stock.stitch_clock_speech",
            stockWidgetVersion: 1,
            name: "Clock Speech Bubble",
            description: "Modern chat speech card typography display.",
            category: .nightTime,
            requiredDataSource: "Time",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "DCE4E5", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 8, y: 12, w: 84, h: 64, color: "0D1515", opacity: 0.95, radius: 18),
                    WidgetLayer(id: uid(), kind: "clock", x: 12, y: 22, w: 76, h: 26, fontSize: 28, weight: 900, align: "center", color: "DCE4E5"),
                    WidgetLayer(id: uid(), kind: "date", x: 12, y: 52, w: 76, h: 10, fontSize: 10, weight: 700, align: "center", color: "00F0FF")
                ]
            )
        )

        let stitchClockNoirGold = StockWidgetDefinition(
            stockWidgetId: "stock.stitch_clock_noir_gold",
            stockWidgetVersion: 1,
            name: "Clock Noir Gold",
            description: "Luxury black & metallic gold watch face.",
            category: .nightTime,
            requiredDataSource: "Time",
            document: WidgetSpec(
                background: WidgetBackground(type: "gradient", from: "1A1510", to: "0D0A08", imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "shape", label: "circle", x: 12, y: 12, w: 76, h: 76, color: "E6C57A", opacity: 0.15, radius: 38),
                    WidgetLayer(id: uid(), kind: "shape", label: "ring", x: 16, y: 16, w: 68, h: 68, color: "E6C57A", opacity: 0.8, radius: 34),
                    WidgetLayer(id: uid(), kind: "clock", x: 15, y: 32, w: 70, h: 24, fontSize: 24, weight: 900, align: "center", color: "F0D58B"),
                    WidgetLayer(id: uid(), kind: "date", x: 15, y: 58, w: 70, h: 8, fontSize: 9, weight: 700, align: "center", color: "E6C57A")
                ]
            )
        )

        let stitchClockVortex = StockWidgetDefinition(
            stockWidgetId: "stock.stitch_clock_vortex",
            stockWidgetVersion: 1,
            name: "Clock Cyber Vortex",
            description: "Cyberpunk radial vortex clock with sync status.",
            category: .nightTime,
            requiredDataSource: "Time",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "080F10", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "shape", label: "ring", x: 15, y: 15, w: 70, h: 70, color: "00DBE9", opacity: 0.6, radius: 35),
                    WidgetLayer(id: uid(), kind: "clock", x: 15, y: 32, w: 70, h: 24, fontSize: 28, weight: 900, align: "center", color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "text", text: "SYNC ACTV", x: 15, y: 60, w: 70, h: 8, fontSize: 8, weight: 800, align: "center", color: "00DBE9")
                ]
            )
        )

        let stitchCalendarGrid = StockWidgetDefinition(
            stockWidgetId: "stock.stitch_calendar_grid",
            stockWidgetVersion: 1,
            name: "Calendar Grid Accent",
            description: "Bold grid calendar with live date highlight.",
            category: .nightTime,
            requiredDataSource: "Time & Date",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "0D1515", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "MONTHLY VIEW", x: 10, y: 10, w: 80, h: 8, fontSize: 8, weight: 800, align: "left", color: "FF2A2A"),
                    WidgetLayer(id: uid(), kind: "date", x: 10, y: 22, w: 80, h: 16, fontSize: 16, weight: 800, align: "left", color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 10, y: 46, w: 80, h: 40, color: "FF2A2A", opacity: 0.15, radius: 10)
                ]
            )
        )

        let stitchClockNature = StockWidgetDefinition(
            stockWidgetId: "stock.stitch_clock_nature",
            stockWidgetVersion: 1,
            name: "Clock Nature Sunset",
            description: "Warm sunset horizon backdrop with digital clock.",
            category: .nightTime,
            requiredDataSource: "Time",
            document: WidgetSpec(
                background: WidgetBackground(type: "gradient", from: "F4A261", to: "0D1515", imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "shape", label: "circle", x: 25, y: 15, w: 50, h: 50, color: "FFD166", opacity: 0.4, radius: 25),
                    WidgetLayer(id: uid(), kind: "clock", x: 10, y: 32, w: 80, h: 26, fontSize: 28, weight: 800, align: "center", color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "date", x: 10, y: 62, w: 80, h: 10, fontSize: 10, weight: 600, align: "center", color: "FFD166")
                ]
            )
        )

        let stitchAnalogMinimal = StockWidgetDefinition(
            stockWidgetId: "stock.stitch_analog_minimal",
            stockWidgetVersion: 1,
            name: "Analog Minimal Luxury",
            description: "Minimalist dark analog watch face with PRO badge.",
            category: .nightTime,
            requiredDataSource: "Time",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "020408", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "analog", x: 15, y: 12, w: 70, h: 70, color: "FFFFFF", opacity: 1.0),
                    WidgetLayer(id: uid(), kind: "text", text: "PRO", x: 35, y: 78, w: 30, h: 8, fontSize: 8, weight: 900, align: "center", color: "FFB86F")
                ]
            )
        )

        let stitchBatteryLightning = StockWidgetDefinition(
            stockWidgetId: "stock.stitch_battery_lightning",
            stockWidgetVersion: 1,
            name: "Battery Lightning Bolt",
            description: "Electric cyan bolt theme with live battery %.",
            category: .phoneBattery,
            requiredDataSource: "Phone Battery",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "080F10", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "151D1E", opacity: 0.9, radius: 16),
                    WidgetLayer(id: uid(), kind: "text", text: "CHARGE // BOLT", x: 12, y: 16, w: 76, h: 8, fontSize: 8, weight: 800, align: "left", color: "00F0FF"),
                    WidgetLayer(id: uid(), kind: "battery", x: 10, y: 32, w: 80, h: 32, fontSize: 34, weight: 900, align: "center", color: "00F0FF"),
                    WidgetLayer(id: uid(), kind: "text", text: "POWER ACTIVE", x: 12, y: 68, w: 76, h: 8, fontSize: 8, weight: 700, align: "center", color: "B9CACB")
                ]
            )
        )

        let stitchBatteryPanel = StockWidgetDefinition(
            stockWidgetId: "stock.stitch_battery_panel",
            stockWidgetVersion: 1,
            name: "Battery Tactical Panel",
            description: "Dark tactical telemetry panel with battery level.",
            category: .phoneBattery,
            requiredDataSource: "Phone Battery",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "0D1515", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "192122", opacity: 0.95, radius: 14),
                    WidgetLayer(id: uid(), kind: "text", text: "BATTERY LEVEL", x: 12, y: 15, w: 76, h: 8, fontSize: 9, weight: 700, align: "left", color: "B9CACB"),
                    WidgetLayer(id: uid(), kind: "battery", x: 12, y: 30, w: 76, h: 26, fontSize: 28, weight: 900, align: "left", color: "00DBE9"),
                    WidgetLayer(id: uid(), kind: "text", text: "CHARGING ACTIVE", x: 12, y: 66, w: 76, h: 8, fontSize: 8, weight: 800, align: "left", color: "4DC98A")
                ]
            )
        )


        // ─────────────────────────────────────────────────────────────
        // MARK: - Category 6: Telemetry & Dashboard Widgets (18 Widgets)
        // ─────────────────────────────────────────────────────────────

        let orbitDateStock = StockWidgetDefinition(
            stockWidgetId: "stock.orbit_date",
            stockWidgetVersion: 1,
            name: "Orbit Date",
            description: "Day progress ring with live clock and date in orbital blue.",
            category: .nightTime,
            requiredDataSource: "Time & Date",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "05111F", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "shape", label: "ring", x: 10, y: 10, w: 80, h: 80, color: "185FA5", opacity: 0.8, radius: 40),
                    WidgetLayer(id: uid(), kind: "clock", x: 10, y: 32, w: 80, h: 22, fontSize: 26, weight: 900, align: "center", color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "date", x: 10, y: 58, w: 80, h: 10, fontSize: 10, weight: 600, align: "center", color: "378ADD")
                ]
            )
        )

        let noirGoldStock = StockWidgetDefinition(
            stockWidgetId: "stock.noir_gold",
            stockWidgetVersion: 1,
            name: "Noir Gold",
            description: "Black canvas with metallic gold border frame and clock.",
            category: .nightTime,
            requiredDataSource: "Time",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "0A0A0A", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "F0C040", opacity: 0.9, radius: 17),
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 9, y: 9, w: 82, h: 82, color: "0A0A0A", opacity: 1.0, radius: 14),
                    WidgetLayer(id: uid(), kind: "clock", x: 10, y: 26, w: 80, h: 32, fontSize: 34, weight: 900, align: "center", color: "F0C040"),
                    WidgetLayer(id: uid(), kind: "date", x: 10, y: 64, w: 80, h: 10, fontSize: 11, weight: 700, align: "center", color: "C8902A")
                ]
            )
        )

        let segmentsStock = StockWidgetDefinition(
            stockWidgetId: "stock.segments",
            stockWidgetVersion: 1,
            name: "Segments Dual Arc",
            description: "Dual arc rings for hours and minutes with tick marks.",
            category: .nightTime,
            requiredDataSource: "Time",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "040D18", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "shape", label: "ring", x: 10, y: 10, w: 80, h: 80, color: "378ADD", opacity: 0.9, radius: 40),
                    WidgetLayer(id: uid(), kind: "shape", label: "ring", x: 20, y: 20, w: 60, h: 60, color: "F59E0B", opacity: 0.9, radius: 30),
                    WidgetLayer(id: uid(), kind: "clock", x: 10, y: 34, w: 80, h: 22, fontSize: 24, weight: 900, align: "center", color: "DBEAFE"),
                    WidgetLayer(id: uid(), kind: "date", x: 10, y: 60, w: 80, h: 10, fontSize: 10, weight: 600, align: "center", color: "F59E0B")
                ]
            )
        )

        let auroraRingStock = StockWidgetDefinition(
            stockWidgetId: "stock.aurora_ring",
            stockWidgetVersion: 1,
            name: "Aurora Ring Analog",
            description: "Rainbow gradient ring with live analog hands.",
            category: .nightTime,
            requiredDataSource: "Time",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "050510", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "shape", label: "ring", x: 10, y: 10, w: 80, h: 80, color: "EC4899", opacity: 0.8, radius: 40),
                    WidgetLayer(id: uid(), kind: "analog", x: 20, y: 20, w: 60, h: 60, color: "FFFFFF", opacity: 1.0),
                    WidgetLayer(id: uid(), kind: "clock", x: 10, y: 76, w: 80, h: 10, fontSize: 10, weight: 600, align: "center", color: "E9D5FF")
                ]
            )
        )

        let batteryPieStock = StockWidgetDefinition(
            stockWidgetId: "stock.battery_pie",
            stockWidgetVersion: 1,
            name: "Battery Pie Radial",
            description: "Radial pie chart showing live battery percentage.",
            category: .phoneBattery,
            requiredDataSource: "Phone Battery",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "100505", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "shape", label: "circle", x: 15, y: 10, w: 70, h: 70, color: "E24B4A", opacity: 0.8, radius: 35),
                    WidgetLayer(id: uid(), kind: "battery", x: 10, y: 32, w: 80, h: 22, fontSize: 24, weight: 900, align: "center", color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "text", text: "BATTERY", x: 10, y: 56, w: 80, h: 8, fontSize: 9, weight: 700, align: "center", color: "E24B4A")
                ]
            )
        )

        let minimalDateStock = StockWidgetDefinition(
            stockWidgetId: "stock.minimal_date",
            stockWidgetVersion: 1,
            name: "Minimal Teal Date",
            description: "Clean teal dark card with large clock and date.",
            category: .nightTime,
            requiredDataSource: "Time & Date",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "0D3330", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "0A2825", opacity: 0.9, radius: 16),
                    WidgetLayer(id: uid(), kind: "clock", x: 10, y: 22, w: 80, h: 32, fontSize: 36, weight: 900, align: "center", color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "divider", x: 15, y: 58, w: 70, h: 2, color: "1D9E75", opacity: 0.8),
                    WidgetLayer(id: uid(), kind: "date", x: 10, y: 64, w: 80, h: 12, fontSize: 12, weight: 700, align: "center", color: "4DC98A")
                ]
            )
        )

        let commandCenterStock = StockWidgetDefinition(
            stockWidgetId: "stock.command_center",
            stockWidgetVersion: 1,
            name: "Command Center HUD",
            description: "Speed focus + digital clock + live battery arc.",
            category: .driving,
            requiredDataSource: "Speed & Telemetry",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "060C14", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 100, color: "0D1A2A", opacity: 0.95, radius: 14),
                    WidgetLayer(id: uid(), kind: "clock", x: 10, y: 14, w: 80, h: 18, fontSize: 24, weight: 900, align: "center", color: "00E5FF"),
                    WidgetLayer(id: uid(), kind: "divider", x: 15, y: 35, w: 70, h: 2, color: "0D2A3A", opacity: 0.8),
                    WidgetLayer(id: uid(), kind: "speed", x: 10, y: 40, w: 80, h: 24, fontSize: 26, weight: 900, align: "center", color: "FF6B35"),
                    WidgetLayer(id: uid(), kind: "battery", x: 10, y: 68, w: 80, h: 16, fontSize: 14, weight: 800, align: "center", color: "22C55E")
                ]
            )
        )

        let vortexDriveStock = StockWidgetDefinition(
            stockWidgetId: "stock.vortex_drive",
            stockWidgetVersion: 1,
            name: "Vortex Drive Dual Ring",
            description: "Outer minute progress + inner speed ring + clock center.",
            category: .driving,
            requiredDataSource: "Speed & Time",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "0A0515", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "shape", label: "ring", x: 10, y: 10, w: 80, h: 80, color: "7C3AED", opacity: 0.8, radius: 40),
                    WidgetLayer(id: uid(), kind: "shape", label: "ring", x: 20, y: 20, w: 60, h: 60, color: "F97316", opacity: 0.8, radius: 30),
                    WidgetLayer(id: uid(), kind: "clock", x: 10, y: 36, w: 80, h: 16, fontSize: 18, weight: 900, align: "center", color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "speed", x: 10, y: 54, w: 80, h: 14, fontSize: 14, weight: 800, align: "center", color: "F97316")
                ]
            )
        )

        let gridHudStock = StockWidgetDefinition(
            stockWidgetId: "stock.grid_hud",
            stockWidgetVersion: 1,
            name: "Grid HUD Telemetry",
            description: "2 top tiles (Speed | Battery) + bottom clock/date tile.",
            category: .driving,
            requiredDataSource: "Speed & Battery",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "090D0D", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 6, y: 6, w: 42, h: 42, color: "0D1A1A", opacity: 0.9, radius: 12),
                    WidgetLayer(id: uid(), kind: "speed", x: 8, y: 14, w: 38, h: 18, fontSize: 18, weight: 900, align: "center", color: "00F0FF"),
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 52, y: 6, w: 42, h: 42, color: "0D1A1A", opacity: 0.9, radius: 12),
                    WidgetLayer(id: uid(), kind: "battery", x: 54, y: 14, w: 38, h: 18, fontSize: 16, weight: 900, align: "center", color: "22C55E"),
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 6, y: 52, w: 88, h: 42, color: "1A2020", opacity: 0.9, radius: 12),
                    WidgetLayer(id: uid(), kind: "clock", x: 10, y: 58, w: 80, h: 20, fontSize: 22, weight: 900, align: "center", color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "date", x: 10, y: 80, w: 80, h: 10, fontSize: 9, weight: 700, align: "center", color: "4DC98A")
                ]
            )
        )

        let cockpitStock = StockWidgetDefinition(
            stockWidgetId: "stock.cockpit",
            stockWidgetVersion: 1,
            name: "Cockpit Telemetry",
            description: "Large analog clock + speed badge + battery bar.",
            category: .driving,
            requiredDataSource: "Speed & Time",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "0C0C0C", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "analog", x: 15, y: 15, w: 70, h: 70, color: "FFFFFF", opacity: 1.0),
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 25, y: 78, w: 50, h: 16, color: "1A0A0A", opacity: 0.9, radius: 8),
                    WidgetLayer(id: uid(), kind: "speed", x: 25, y: 80, w: 50, h: 12, fontSize: 12, weight: 900, align: "center", color: "FF6B35")
                ]
            )
        )

        let phantomStock = StockWidgetDefinition(
            stockWidgetId: "stock.phantom",
            stockWidgetVersion: 1,
            name: "Phantom EV Concept",
            description: "Purple gradient header + vehicle card + battery arc.",
            category: .vehicle,
            requiredDataSource: "Selected Vehicle",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "080512", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 36, color: "7C3AED", opacity: 0.9, radius: 14),
                    WidgetLayer(id: uid(), kind: "clock", x: 10, y: 6, w: 80, h: 22, fontSize: 24, weight: 900, align: "center", color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "vehicle_name", x: 10, y: 44, w: 80, h: 12, fontSize: 12, weight: 800, align: "center", color: "A78BFA"),
                    WidgetLayer(id: uid(), kind: "battery", x: 10, y: 68, w: 80, h: 18, fontSize: 16, weight: 900, align: "center", color: "A78BFA")
                ]
            )
        )

        let splitPanelStock = StockWidgetDefinition(
            stockWidgetId: "stock.split_panel",
            stockWidgetVersion: 1,
            name: "Split Panel Speed & Time",
            description: "Teal clock top half + orange speed bottom + battery bar.",
            category: .driving,
            requiredDataSource: "Speed & Telemetry",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "050A0A", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 0, y: 0, w: 100, h: 48, color: "0D1A1A", opacity: 0.9, radius: 14),
                    WidgetLayer(id: uid(), kind: "clock", x: 10, y: 8, w: 80, h: 24, fontSize: 26, weight: 900, align: "center", color: "00F0FF"),
                    WidgetLayer(id: uid(), kind: "speed", x: 10, y: 56, w: 80, h: 26, fontSize: 28, weight: 900, align: "center", color: "FF6B35"),
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 0, y: 88, w: 100, h: 12, color: "00F0FF", opacity: 0.9, radius: 0)
                ]
            )
        )

        let solarDashStock = StockWidgetDefinition(
            stockWidgetId: "stock.solar_dash",
            stockWidgetVersion: 1,
            name: "Solar Dash 3-Ring",
            description: "3 concentric rings (Day, Battery, Speed) + clock center.",
            category: .driving,
            requiredDataSource: "Telemetry",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "050810", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "shape", label: "ring", x: 10, y: 10, w: 80, h: 80, color: "378ADD", opacity: 0.8, radius: 40),
                    WidgetLayer(id: uid(), kind: "shape", label: "ring", x: 20, y: 20, w: 60, h: 60, color: "22C55E", opacity: 0.8, radius: 30),
                    WidgetLayer(id: uid(), kind: "shape", label: "ring", x: 30, y: 30, w: 40, h: 40, color: "F97316", opacity: 0.8, radius: 20),
                    WidgetLayer(id: uid(), kind: "clock", x: 10, y: 36, w: 80, h: 16, fontSize: 16, weight: 900, align: "center", color: "FFFFFF")
                ]
            )
        )

        let neonStripStock = StockWidgetDefinition(
            stockWidgetId: "stock.neon_strip",
            stockWidgetVersion: 1,
            name: "Neon Strip Cyber",
            description: "Pink neon speed + cyan battery bars + white clock.",
            category: .driving,
            requiredDataSource: "Speed & Telemetry",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "0A0A0A", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "speed", x: 10, y: 10, w: 80, h: 28, fontSize: 32, weight: 900, align: "center", color: "FF2D6B"),
                    WidgetLayer(id: uid(), kind: "clock", x: 10, y: 44, w: 80, h: 18, fontSize: 20, weight: 900, align: "center", color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "battery", x: 10, y: 66, w: 80, h: 14, fontSize: 12, weight: 800, align: "center", color: "00E5FF")
                ]
            )
        )

        let carbonStock = StockWidgetDefinition(
            stockWidgetId: "stock.carbon",
            stockWidgetVersion: 1,
            name: "Carbon Analog Matrix",
            description: "Carbon-fiber texture + analog watch face + battery strip.",
            category: .nightTime,
            requiredDataSource: "Time & Battery",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "0A0A0A", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "analog", x: 15, y: 10, w: 70, h: 70, color: "DBEAFE", opacity: 1.0),
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 10, y: 78, w: 80, h: 16, color: "111111", opacity: 0.9, radius: 8),
                    WidgetLayer(id: uid(), kind: "battery", x: 10, y: 80, w: 80, h: 12, fontSize: 11, weight: 800, align: "center", color: "22C55E")
                ]
            )
        )

        let radarStock = StockWidgetDefinition(
            stockWidgetId: "stock.radar",
            stockWidgetVersion: 1,
            name: "Radar Speedometer Sweep",
            description: "Large 3/4 speedometer arc sweep + clock center.",
            category: .driving,
            requiredDataSource: "Speedometer",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "030812", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "shape", label: "ring", x: 10, y: 10, w: 80, h: 80, color: "00E5FF", opacity: 0.8, radius: 40),
                    WidgetLayer(id: uid(), kind: "speed", x: 10, y: 30, w: 80, h: 22, fontSize: 24, weight: 900, align: "center", color: "00E5FF"),
                    WidgetLayer(id: uid(), kind: "clock", x: 10, y: 56, w: 80, h: 16, fontSize: 16, weight: 800, align: "center", color: "FFFFFF")
                ]
            )
        )

        let triZoneStock = StockWidgetDefinition(
            stockWidgetId: "stock.tri_zone",
            stockWidgetVersion: 1,
            name: "Tri-Zone Modular",
            description: "Top clock/date zone + bottom speed & battery ring zones.",
            category: .driving,
            requiredDataSource: "Speed & Telemetry",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "06080C", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 6, y: 6, w: 88, h: 42, color: "0D1020", opacity: 0.9, radius: 12),
                    WidgetLayer(id: uid(), kind: "clock", x: 10, y: 12, w: 80, h: 20, fontSize: 22, weight: 900, align: "center", color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 6, y: 52, w: 42, h: 42, color: "0D1A10", opacity: 0.9, radius: 12),
                    WidgetLayer(id: uid(), kind: "speed", x: 8, y: 60, w: 38, h: 18, fontSize: 18, weight: 900, align: "center", color: "FF6B35"),
                    WidgetLayer(id: uid(), kind: "shape", label: "rect", x: 52, y: 52, w: 42, h: 42, color: "0A1A10", opacity: 0.9, radius: 12),
                    WidgetLayer(id: uid(), kind: "battery", x: 54, y: 60, w: 38, h: 18, fontSize: 16, weight: 900, align: "center", color: "22C55E")
                ]
            )
        )

        let galaxyStock = StockWidgetDefinition(
            stockWidgetId: "stock.galaxy",
            stockWidgetVersion: 1,
            name: "Galaxy 4-Orbit Ring",
            description: "4 concentric orbit rings (Day, Battery, Speed, Minutes).",
            category: .driving,
            requiredDataSource: "Telemetry",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "020508", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "shape", label: "ring", x: 6, y: 6, w: 88, h: 88, color: "7C3AED", opacity: 0.8, radius: 44),
                    WidgetLayer(id: uid(), kind: "shape", label: "ring", x: 16, y: 16, w: 68, h: 68, color: "06B6D4", opacity: 0.8, radius: 34),
                    WidgetLayer(id: uid(), kind: "shape", label: "ring", x: 26, y: 26, w: 48, h: 48, color: "F59E0B", opacity: 0.8, radius: 24),
                    WidgetLayer(id: uid(), kind: "clock", x: 10, y: 40, w: 80, h: 14, fontSize: 14, weight: 900, align: "center", color: "FFFFFF")
                ]
            )
        )


        // ── 16 NEW INSPIRED CUSTOM STOCK WIDGETS ───────────────────────
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
                    WidgetLayer(id: uid(), kind: "clock", x: 8, y: 8, w: 50, h: 8, fontSize: 10, weight: 700, align: "left", color: "8899AA"),
                    WidgetLayer(id: uid(), kind: "speed", x: 8, y: 22, w: 60, h: 32, fontSize: 42, weight: 900, align: "left", color: "FF6B35"),
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
                    WidgetLayer(id: uid(), kind: "speed", x: 10, y: 12, w: 40, h: 22, fontSize: 24, weight: 900, align: "center", color: "FF6B35"),
                    WidgetLayer(id: uid(), kind: "battery", x: 50, y: 12, w: 40, h: 22, fontSize: 22, weight: 900, align: "center", color: "4DC98A"),
                    WidgetLayer(id: uid(), kind: "clock", x: 10, y: 56, w: 80, h: 20, fontSize: 20, weight: 800, align: "center", color: "FFFFFF")
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
                    WidgetLayer(id: uid(), kind: "speed", x: 15, y: 28, w: 70, h: 22, fontSize: 28, weight: 900, align: "center", color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "text", text: "KM/H", x: 15, y: 52, w: 70, h: 6, fontSize: 9, weight: 800, align: "center", color: "00E5FF"),
                    WidgetLayer(id: uid(), kind: "date", x: 10, y: 84, w: 80, h: 6, fontSize: 9, weight: 700, align: "center", color: "88CCDD")
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
                    WidgetLayer(id: uid(), kind: "clock", x: 10, y: 12, w: 80, h: 20, fontSize: 24, weight: 900, align: "center", color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "speed", x: 5, y: 50, w: 42, h: 22, fontSize: 22, weight: 900, align: "center", color: "FF6B35"),
                    WidgetLayer(id: uid(), kind: "battery", x: 53, y: 50, w: 42, h: 22, fontSize: 20, weight: 900, align: "center", color: "22C55E")
                ]
            )
        )

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
                    WidgetLayer(id: uid(), kind: "vehicle_name", x: 8, y: 8, w: 84, h: 8, fontSize: 11, weight: 800, align: "center", color: "A78BFA"),
                    WidgetLayer(id: uid(), kind: "image", src: "template_car", x: 12, y: 22, w: 76, h: 36),
                    WidgetLayer(id: uid(), kind: "battery", x: 8, y: 66, w: 84, h: 14, fontSize: 16, weight: 800, align: "center", color: "4DC98A")
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
                    WidgetLayer(id: uid(), kind: "vehicle_name", x: 8, y: 8, w: 84, h: 8, fontSize: 10, weight: 800, align: "left", color: "FFB84D"),
                    WidgetLayer(id: uid(), kind: "speed", x: 8, y: 22, w: 50, h: 26, fontSize: 32, weight: 900, align: "left", color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "clock", x: 60, y: 32, w: 32, h: 10, fontSize: 12, weight: 700, align: "right", color: "8899AA"),
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
                    WidgetLayer(id: uid(), kind: "vehicle_name", x: 15, y: 28, w: 70, h: 8, fontSize: 10, weight: 800, align: "center", color: "F0C040"),
                    WidgetLayer(id: uid(), kind: "battery", x: 15, y: 40, w: 70, h: 16, fontSize: 18, weight: 900, align: "center", color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "clock", x: 10, y: 84, w: 80, h: 6, fontSize: 10, weight: 700, align: "center", color: "D0A030")
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
                    WidgetLayer(id: uid(), kind: "speed", x: 10, y: 50, w: 40, h: 18, fontSize: 20, weight: 900, align: "center", color: "FFFFFF"),
                    WidgetLayer(id: uid(), kind: "battery", x: 50, y: 50, w: 40, h: 18, fontSize: 18, weight: 800, align: "center", color: "4DC98A")
                ]
            )
        )

        self.widgets = [
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
            minimalistCarCockpit,

            // Night & Time (10)
            midnightClock, nightDrive, horizonDate, minimalTime, tokyoNeon, stealthTime, lunarPhase, starlightDate, gridMatrix, apexChrono,
            // Phone Battery (10)
            batteryRing, energyBars, chargingArc, batteryMinimal, hyperCharge, powerMatrix, titaniumPower, electricFlow, voltIndicator, ecoPercent,
            // Driving (10)
            speedFocus, lastDrive, driveClock, hudSpeedometer, supercarGauge, driftTelemetry, cityCruiser, velocityRing, trackPace, highwayRunner,
            // Vehicle (10)
            vehicleProfile, cyberRoadster, hyperCoupe, apexSuv, gtTrack, stealthSedan, retroSynth, futureEv, garageMaster, phantomGt,
            // Stitch Studio Designs (16)
            stitchBatteryDots, stitchBatteryMatrix, stitchClockPixelNeon, stitchClockSegments, stitchClockPill, stitchCalendarMonth, stitchClockHalo, stitchClockLeather, stitchClockSpeech, stitchClockNoirGold, stitchClockVortex, stitchCalendarGrid, stitchClockNature, stitchAnalogMinimal, stitchBatteryLightning, stitchBatteryPanel,
            // Telemetry & Dashboard Mixed Designs (18)
            orbitDateStock, noirGoldStock, segmentsStock, auroraRingStock, batteryPieStock, minimalDateStock, commandCenterStock, vortexDriveStock, gridHudStock, cockpitStock, phantomStock, splitPanelStock, solarDashStock, neonStripStock, carbonStock, radarStock, triZoneStock, galaxyStock
        ]
    }
}
