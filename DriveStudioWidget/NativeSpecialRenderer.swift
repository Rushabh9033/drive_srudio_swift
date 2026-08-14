import SwiftUI

// NativeSpecialRenderer builds the entry structs from the App Group
// reader. It MUST NOT touch UIDevice — the widget extension cannot
// poll sensors, and the host app is the single owner of telemetry.
// All fields are optional on purpose: unknown stays unknown.
//
// **Display date is injected by the caller.** The renderer never
// calls `Date()` to "advance" the clock. WidgetKit controls when an
// entry's `date` advances, and `TimelineView(.everyMinute)` is the
// mechanism that lets the clock hands/text tick within an entry —
// that wrapper is the caller's responsibility, not the renderer's.
struct NativeSpecialRenderer {
    @ViewBuilder
    static func renderIfSpecial(
        spec: WidgetSpec,
        telemetry: TelemetrySnapshot?,
        vehicle: VehicleData?,
        displayDate: Date
    ) -> AnyView? {
        let textHints = (spec.layers ?? []).compactMap { $0.text ?? $0.kind }.joined(separator: " ").lowercased()

        let realBatt: Double? = telemetry?.batteryPercent
            .map { Double(WidgetBatteryMath.clamp($0)) / 100.0 }
        let spd: Double? = telemetry?.speed
        let vName: String? = vehicle?.displayName
        let isChg: Bool = telemetry?.isCharging ?? false

        // Project the snapshot against the entry's display date so a
        // stale captured speed is treated as nil even when the host
        // hasn't written a fresh snapshot recently. This is the same
        // policy every provider entry uses via WidgetTelemetryFactory.
        let projected: TelemetrySnapshot? = telemetry.map {
            WidgetSnapshotFreshness.projected(snapshot: $0, at: displayDate)
        }
        let projSpeed: Double? = projected?.speed
        let projBatt: Double? = projected?.batteryPercent
            .map { Double(WidgetBatteryMath.clamp($0)) / 100.0 }
        let projChg: Bool = projected?.isCharging ?? false

        let driveEntry = DriveEntry(date: displayDate, speed: projSpeed,
                                    batteryLevel: projBatt, isCharging: projChg,
                                    vehicleName: vName)
        let orbitEntry = OrbitDateEntry(date: displayDate, batteryLevel: projBatt,
                                        isCharging: projChg, vehicleName: vName)

        if textHints.contains("command center") {
            return AnyView(CommandCenterView(e: driveEntry))
        } else if textHints.contains("vortex") {
            return AnyView(VortexDriveView(e: driveEntry))
        } else if textHints.contains("grid hud") {
            return AnyView(GridHUDView(e: driveEntry))
        } else if textHints.contains("cockpit") {
            return AnyView(CockpitView(e: driveEntry))
        } else if textHints.contains("phantom") {
            return AnyView(PhantomView(e: driveEntry))
        } else if textHints.contains("split panel") {
            return AnyView(SplitPanelView(e: driveEntry))
        } else if textHints.contains("solar dash") {
            return AnyView(SolarDashView(e: driveEntry))
        } else if textHints.contains("neon strip") {
            return AnyView(NeonStripView(e: driveEntry))
        } else if textHints.contains("carbon") {
            return AnyView(CarbonView(e: driveEntry))
        } else if textHints.contains("radar") {
            return AnyView(RadarView(e: driveEntry))
        } else if textHints.contains("tri-zone") || textHints.contains("trizone") {
            return AnyView(TriZoneView(e: driveEntry))
        } else if textHints.contains("galaxy") {
            return AnyView(GalaxyView(e: driveEntry))
        } else if textHints.contains("orbit date") {
            return AnyView(OrbitDateWidgetView(entry: orbitEntry))
        } else if textHints.contains("noir gold") {
            return AnyView(NoirGoldWidgetView(entry: orbitEntry))
        } else if textHints.contains("7-segment hud") || textHints.contains("segments") {
            return AnyView(SegmentsWidgetView(entry: orbitEntry))
        } else if textHints.contains("aurora") {
            return AnyView(AuroraRingWidgetView(entry: orbitEntry))
        } else if textHints.contains("battery pie") {
            return AnyView(BatteryPieWidgetView(entry: orbitEntry))
        } else if textHints.contains("minimal date") {
            return AnyView(MinimalDateWidgetView(entry: orbitEntry))
        } else {
            return nil
        }
    }
}
