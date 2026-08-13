import Foundation
import SwiftUI

struct StockWidgetCatalog {
    static let shared = StockWidgetCatalog()
    
    let widgets: [StockWidgetDefinition]
    
    private init() {
        let uid = { UUID().uuidString }
        
        // ─────────────────────────────────────────────────────────────
        // MARK: - Hyper-Professional Stock Widgets
        // ─────────────────────────────────────────────────────────────
        
        let commandCenter = StockWidgetDefinition(
            stockWidgetId: "stock.command_center",
            stockWidgetVersion: 2,
            name: "Command Center HUD",
            description: "Dual-zone glowing HUD with real-time GPS speed, battery arc, and clock.",
            category: .driving,
            requiredDataSource: "Telemetry",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "0D1A2A", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "COMMAND CENTER", x: 10, y: 10, w: 80, h: 10, fontSize: 10, weight: 800, align: "center", color: "00E5FF")
                ]
            )
        )

        let vortexDrive = StockWidgetDefinition(
            stockWidgetId: "stock.vortex_drive",
            stockWidgetVersion: 2,
            name: "Vortex Drive Hypercar",
            description: "Concentric neon speed rings with central metallic tachometer and vehicle silhouette.",
            category: .driving,
            requiredDataSource: "Telemetry",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "0B001A", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "VORTEX DRIVE", x: 10, y: 10, w: 80, h: 10, fontSize: 10, weight: 800, align: "center", color: "7C3AED")
                ]
            )
        )

        let gridHUD = StockWidgetDefinition(
            stockWidgetId: "stock.grid_hud",
            stockWidgetVersion: 2,
            name: "Grid HUD Telemetry",
            description: "Cyberpunk dual-column telemetry grid with live battery & speed cards.",
            category: .driving,
            requiredDataSource: "Telemetry",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "07070F", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "GRID HUD", x: 10, y: 10, w: 80, h: 10, fontSize: 10, weight: 800, align: "center", color: "00F0FF")
                ]
            )
        )

        let apexCockpit = StockWidgetDefinition(
            stockWidgetId: "stock.apex_cockpit",
            stockWidgetVersion: 2,
            name: "Apex Cockpit Cluster",
            description: "Race track instrumentation cluster with redline RPM meter and shift lights.",
            category: .driving,
            requiredDataSource: "Telemetry",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "12131C", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "COCKPIT", x: 10, y: 10, w: 80, h: 10, fontSize: 10, weight: 800, align: "center", color: "FF6B35")
                ]
            )
        )

        let phantomEV = StockWidgetDefinition(
            stockWidgetId: "stock.phantom_ev",
            stockWidgetVersion: 2,
            name: "Phantom EV Header",
            description: "Minimalist luxury EV instrument header with purple neon ambient glow.",
            category: .phoneBattery,
            requiredDataSource: "Battery",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "150B24", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "PHANTOM EV", x: 10, y: 10, w: 80, h: 10, fontSize: 10, weight: 800, align: "center", color: "A78BFA")
                ]
            )
        )

        let splitPanel = StockWidgetDefinition(
            stockWidgetId: "stock.split_panel",
            stockWidgetVersion: 2,
            name: "Split Panel Telemetry",
            description: "High-contrast split dashboard card for night driving.",
            category: .nightTime,
            requiredDataSource: "Telemetry",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "0D1A1A", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "SPLIT PANEL", x: 10, y: 10, w: 80, h: 10, fontSize: 10, weight: 800, align: "center", color: "00F0FF")
                ]
            )
        )

        let solarDash = StockWidgetDefinition(
            stockWidgetId: "stock.solar_dash",
            stockWidgetVersion: 2,
            name: "Solar Dash 3-Ring",
            description: "Triple concentric orbital gauges for battery, speed, and range.",
            category: .phoneBattery,
            requiredDataSource: "Telemetry",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "071424", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "SOLAR DASH", x: 10, y: 10, w: 80, h: 10, fontSize: 10, weight: 800, align: "center", color: "378ADD")
                ]
            )
        )

        let neonStrip = StockWidgetDefinition(
            stockWidgetId: "stock.neon_strip",
            stockWidgetVersion: 2,
            name: "Neon Strip Cyber",
            description: "Tokyo style magenta & cyan glowing LED matrix display.",
            category: .nightTime,
            requiredDataSource: "Telemetry",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "140212", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "NEON STRIP", x: 10, y: 10, w: 80, h: 10, fontSize: 10, weight: 800, align: "center", color: "FF2D6B")
                ]
            )
        )

        let carbonPerf = StockWidgetDefinition(
            stockWidgetId: "stock.carbon_perf",
            stockWidgetVersion: 2,
            name: "Carbon Fiber Performance",
            description: "Woven carbon texture background with brushed metallic battery badge.",
            category: .vehicle,
            requiredDataSource: "Telemetry",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "18181F", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "CARBON MATRIX", x: 10, y: 10, w: 80, h: 10, fontSize: 10, weight: 800, align: "center", color: "22C55E")
                ]
            )
        )

        let radarSpeed = StockWidgetDefinition(
            stockWidgetId: "stock.radar_speed",
            stockWidgetVersion: 2,
            name: "Radar Speed Arc",
            description: "Circular radar scanner UI with active target tracking and speed telemetry.",
            category: .driving,
            requiredDataSource: "Speed",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "021720", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "RADAR SPEED", x: 10, y: 10, w: 80, h: 10, fontSize: 10, weight: 800, align: "center", color: "00E5FF")
                ]
            )
        )

        let triZone = StockWidgetDefinition(
            stockWidgetId: "stock.tri_zone",
            stockWidgetVersion: 2,
            name: "Tri-Zone Modular",
            description: "Three-compartment modular supercar telemetry panel.",
            category: .vehicle,
            requiredDataSource: "Telemetry",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "0D1020", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "TRI-ZONE", x: 10, y: 10, w: 80, h: 10, fontSize: 10, weight: 800, align: "center", color: "FF6B35")
                ]
            )
        )

        let galaxyOrbit = StockWidgetDefinition(
            stockWidgetId: "stock.galaxy_orbit",
            stockWidgetVersion: 2,
            name: "Galaxy Orbit Ring",
            description: "Quad-orbit planetary ring dashboard clock and power meter.",
            category: .nightTime,
            requiredDataSource: "Telemetry",
            document: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "120324", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(id: uid(), kind: "text", text: "GALAXY ORBIT", x: 10, y: 10, w: 80, h: 10, fontSize: 10, weight: 800, align: "center", color: "7C3AED")
                ]
            )
        )

        self.widgets = [
            commandCenter,
            vortexDrive,
            gridHUD,
            apexCockpit,
            phantomEV,
            splitPanel,
            solarDash,
            neonStrip,
            carbonPerf,
            radarSpeed,
            triZone,
            galaxyOrbit
        ]
    }

    func findWidget(byId id: String) -> StockWidgetDefinition? {
        return widgets.first(where: { $0.stockWidgetId == id || $0.id == id })
    }
}
