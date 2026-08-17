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
///
/// **Per-entry freshness:** when an entry's scheduled date is more
/// than `WidgetSnapshotFreshness.maxAge` past the captured
/// snapshot's timestamp, the entry's speed reading is treated as
/// unavailable (the snapshot is reused via `WidgetSnapshotFreshness.projected`,
/// so a stale speed auto-expires on future entries even if WidgetKit
/// has not reloaded the timeline).
enum WidgetTimelineSchedule {

    /// Default number of entries a normal home-screen widget provider
    /// should ship ahead of time. With a 60-second cadence and 60
    /// entries this is ~1 hour of coverage — enough headroom for
    /// WidgetKit batching without spending the system timeline
    /// budget on entries that will never be rendered.
    static let defaultProviderEntryCount = 60

    /// Maximum number of entries the provider helper will emit, regardless
    /// of what the caller asks for. WidgetKit itself caps how many
    /// pre-rendered entries it keeps.
    static let maxProviderEntryCount = 60

    /// Some widgets (e.g. battery-only with no clock) want to fall
    /// back to the Apple-documented 5-minute cadence. `makeProviderTimeline`
    /// accepts any value ≥ 60 s.
    static let minProviderCadenceSeconds: TimeInterval = 60

    /// Upper bound on provider entry spacing. Beyond an hour, an entry
    /// is so stale when it renders that a single fresh `.after` request
    /// would be cheaper.
    static let maxProviderCadenceSeconds: TimeInterval = 60 * 60

    /// Default provider cadence: 60 seconds — the granularity every
    /// minute-boundary clock widget needs.
    static let defaultProviderCadenceSeconds: TimeInterval = 60

    /// Build a Timeline whose first entry's date is `start`, and whose
    /// subsequent entries are `cadenceSeconds` apart, aligned to the
    /// top of each minute. Each entry is produced by `factory`, which
    /// receives the scheduled date.
    ///
    /// **Why minute-alignment:** `Text(e.date, style: .time)` only
    /// updates when the widget is re-rendered. WidgetKit re-renders a
    /// widget at the next timeline entry's date. If the next entry's
    /// date is `11:29:37` (i.e. just `+300s` after a 11:24:37 entry),
    /// the widget will still show "11:24 AM" at 11:30 because the
    /// widget never re-rendered with the 11:29:37 entry's date in
    /// the meantime. Aligning future entries to minute boundaries
    /// (11:25:00, 11:26:00, …) guarantees iOS has a fresh entry to
    /// switch to at the top of each minute, so the clock displays the
    /// current minute without depending on `TimelineView(.everyMinute)`
    /// firing.
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

        // First entry uses the actual start time. The widget renders
        // this immediately; the current minute is captured here.
        entries.append(factory(start))

        // Subsequent entries are aligned to clean minute boundaries.
        // - start = 11:29:37 → next boundary = 11:30:00
        // - start = 11:30:00 → next boundary = 11:31:00
        // The seconds-component of `start` is subtracted to round
        // down to the top of the current minute, then `+ 60s` for
        // each subsequent entry.
        let calendar = Calendar.current
        let secondsComponent = TimeInterval(
            calendar.component(.second, from: start)
        )
        let nanosecondsComponent = TimeInterval(
            calendar.component(.nanosecond, from: start)
        ) / 1_000_000_000
        let topOfCurrentMinute = start
            .addingTimeInterval(-(secondsComponent + nanosecondsComponent))

        for offset in 1..<boundedCount {
            let scheduled = topOfCurrentMinute
                .addingTimeInterval(TimeInterval(offset) * cadence)
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
        let calendar = Calendar.current
        let secondsComponent = TimeInterval(
            calendar.component(.second, from: start)
        )
        let nanosecondsComponent = TimeInterval(
            calendar.component(.nanosecond, from: start)
        ) / 1_000_000_000
        let topOfCurrentMinute = start
            .addingTimeInterval(-(secondsComponent + nanosecondsComponent))
        let firstOffset = start == topOfCurrentMinute ? 0 : 1
        return (0..<boundedCount).map { offset in
            let idx = firstOffset + offset
            if idx == 0 {
                return start
            }
            return topOfCurrentMinute
                .addingTimeInterval(TimeInterval(idx) * cadence)
        }
    }
}

/// Centralized factory every widget provider uses to build its entry.
/// All three providers (`StaticProvider`, `DriveProvider`,
/// `OrbitDateProvider`) read App Group telemetry through
/// `WidgetTelemetryReader` here — no provider or renderer is allowed to
/// read `UIDevice`, call `CLLocation`, or invent fallback values.
///
/// Each factory entry applies `WidgetSnapshotFreshness.projected`
/// for the entry's scheduled `date`. This guarantees that an entry
/// rendering 5 minutes into the future will not display the
/// captured speed as if it were current — the policy is the single
/// source of truth, every entry goes through it, and tests assert
/// the projected behavior at known dates.
enum WidgetTelemetryFactory {

    /// Build a `DriveEntry` for `DriveProvider`. The entry's telemetry
    /// fields are populated from the App Group snapshot the host wrote;
    /// `nil` propagates as `nil`. Speed is projected for the entry's
    /// scheduled date.
    static func driveEntry(at date: Date) -> DriveEntry {
        let snapshot = WidgetTelemetryReader.liveSnapshot()
            .map { WidgetSnapshotFreshness.projected(snapshot: $0, at: date) }
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
            .map { WidgetSnapshotFreshness.projected(snapshot: $0, at: date) }
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
    /// Speed is projected for the entry's scheduled date.
    static func simpleEntry(slotIndex: Int, at date: Date, isPreview: Bool) -> SimpleEntry {
        let state = AppGroupState.loadState()
        let slot = state?.slots?.first(where: { $0.index == slotIndex })
        let liveTelemetry = WidgetTelemetryReader.liveSnapshot()
            .map { WidgetSnapshotFreshness.projected(snapshot: $0, at: date) }
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
