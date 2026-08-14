import Foundation
import WidgetKit

/// Builds normal WidgetKit timelines for the DriveStudio widgets.
///
/// Apple-documented provider model:
///   - The **first** entry's `date` represents the current time.
///   - Subsequent entries should be spaced **at least ~5 minutes apart**
///     so WidgetKit does not waste its budget on near-duplicate frames.
///   - Provider entries should not be one minute apart.
///   - `.atEnd` asks the system to call `getTimeline` again once the
///     last entry is consumed. `.after(date)` requests a single
///     re-evaluation at a future date.
///
/// This helper is intentionally conservative:
///   - First entry = the supplied `start` (no skipping of "now").
///   - Cadence = `providerCadenceSeconds` (default 5 min), clamped to
///     `minProviderCadenceSeconds…maxProviderCadenceSeconds`.
///   - Output is bounded: `providerEntryCount` is clamped to
///     `1...maxProviderEntryCount`.
///
/// The helper is a pure function. It does not call `Date()` (caller
/// supplies `start`), `WidgetCenter`, or any side-effecting API, so
/// tests can pass a fixed start and assert on the exact returned array.
enum WidgetTimelineSchedule {

    /// Default number of entries a normal home-screen widget provider
    /// should ship ahead of time. With a 5-minute cadence this is
    /// ~5 hours of coverage — enough headroom for WidgetKit batching
    /// without spending the system timeline budget on entries that
    /// will never be rendered.
    static let defaultProviderEntryCount = 12

    /// Maximum number of entries the provider helper will emit, regardless
    /// of what the caller asks for. WidgetKit itself caps how many
    /// pre-rendered entries it keeps.
    static let maxProviderEntryCount = 24

    /// Apple-recommended minimum spacing between provider entries for
    /// normal home-screen widgets. Five minutes is the documented
    /// threshold; tighter spacing is wasted budget.
    static let minProviderCadenceSeconds: TimeInterval = 5 * 60

    /// Upper bound on provider entry spacing. Beyond an hour, an entry
    /// is so stale when it renders that a single fresh `.after` request
    /// would be cheaper.
    static let maxProviderCadenceSeconds: TimeInterval = 60 * 60

    /// Default provider cadence: 5 minutes — the Apple-documented
    /// minimum for normal widgets.
    static let defaultProviderCadenceSeconds: TimeInterval = 5 * 60

    /// Build a Timeline whose first entry's date is `start`, and whose
    /// subsequent entries are `cadenceSeconds` apart. Each entry is
    /// produced by `factory`, which receives the scheduled date.
    ///
    /// First entry is always `start`. There are no entries between `start`
    /// and `start + cadenceSeconds`. Output is bounded to
    /// `providerEntryCount` (clamped to `1...maxProviderEntryCount`).
    static func makeProviderTimeline<Entry: TimelineEntry>(
        startingAt start: Date,
        providerEntryCount: Int,
        cadenceSeconds: TimeInterval = defaultProviderCadenceSeconds,
        factory: (Date) -> Entry
    ) -> Timeline<Entry> {
        let boundedCount = max(1, min(maxProviderEntryCount, providerEntryCount))
        let cadence = max(minProviderCadenceSeconds,
                          min(maxProviderCadenceSeconds, cadenceSeconds))
        var entries: [Entry] = []
        entries.reserveCapacity(boundedCount)
        for offset in 0..<boundedCount {
            let scheduled = start.addingTimeInterval(TimeInterval(offset) * cadence)
            entries.append(factory(scheduled))
        }
        return Timeline(entries: entries, policy: .atEnd)
    }

    /// Generate `count` dates starting at `start`, spaced
    /// `cadenceSeconds` apart. Pure; no `Date()` call inside.
    static func providerScheduleDates(
        startingAt start: Date,
        count: Int,
        cadenceSeconds: TimeInterval = defaultProviderCadenceSeconds
    ) -> [Date] {
        let boundedCount = max(1, min(maxProviderEntryCount, count))
        let cadence = max(minProviderCadenceSeconds,
                          min(maxProviderCadenceSeconds, cadenceSeconds))
        return (0..<boundedCount).map { offset in
            start.addingTimeInterval(TimeInterval(offset) * cadence)
        }
    }
}

/// Centralized factory every widget provider uses to build its entry.
/// All three providers (`StaticProvider`, `DriveProvider`,
/// `OrbitDateProvider`) read App Group telemetry through
/// `WidgetTelemetryReader` here — no provider or renderer is allowed to
/// read `UIDevice`, call `CLLocation`, or invent fallback values.
enum WidgetTelemetryFactory {

    /// Build a `DriveEntry` for `DriveProvider`. The entry's telemetry
    /// fields are populated from the App Group snapshot the host wrote;
    /// `nil` propagates as `nil`.
    static func driveEntry(at date: Date) -> DriveEntry {
        let snapshot = WidgetTelemetryReader.liveSnapshot()
        return DriveEntry(
            date: date,
            speed: snapshot?.speed,
            batteryLevel: snapshot?.batteryPercent
                .map { Double(WidgetBatteryMath.clamp($0)) / 100.0 },
            isCharging: snapshot?.isCharging ?? false,
            vehicleName: WidgetTelemetryReader.selectedVehicleDisplayName()
        )
    }

    /// Build an `OrbitDateEntry` for `OrbitDateProvider`. Same truth
    /// contract as `driveEntry`.
    static func orbitEntry(at date: Date) -> OrbitDateEntry {
        let snapshot = WidgetTelemetryReader.liveSnapshot()
        return OrbitDateEntry(
            date: date,
            batteryLevel: snapshot?.batteryPercent
                .map { Double(WidgetBatteryMath.clamp($0)) / 100.0 },
            isCharging: snapshot?.isCharging ?? false,
            vehicleName: WidgetTelemetryReader.selectedVehicleDisplayName()
        )
    }

    /// Build a `SimpleEntry` for `StaticProvider`. Reads the slot spec
    /// for `slotIndex` from the App Group state. The widget canvas
    /// applies the spec; telemetry flows through the same reader.
    static func simpleEntry(slotIndex: Int, at date: Date, isPreview: Bool) -> SimpleEntry {
        let state = AppGroupState.loadState()
        let slot = state?.slots?.first(where: { $0.index == slotIndex })
        let liveTelemetry = WidgetTelemetryReader.liveSnapshot()
        return SimpleEntry(
            date: date,
            slotIndex: slotIndex,
            slot: slot,
            vehicle: state?.vehicle,
            telemetry: liveTelemetry,
            widgetImagePath: state?.widgetImagePath,
            generation: AppGroupState.currentGeneration,
            isPreview: isPreview
        )
    }
}
