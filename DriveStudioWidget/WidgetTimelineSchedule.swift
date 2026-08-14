import Foundation
import WidgetKit

/// Builds a normal WidgetKit timeline for the custom-slot DriveStudio
/// widgets. This is the single source of truth for timeline date
/// generation so the production provider and the test target can both
/// verify the same behavior.
///
/// Design contract — this helper is intentionally conservative:
///
/// - Each entry's `date` is aligned to a real wall-clock minute
///   boundary (`Calendar.current` with the user's time zone), starting
///   at the next minute boundary strictly after `start`. Per-minute
///   alignment is the coarsest granularity at which clock/date text
///   actually changes; any finer alignment is wasted budget because
///   WidgetKit only renders entries when it decides the timeline
///   needs to advance.
/// - Entries are strictly increasing. There are no duplicates and no
///   out-of-order dates.
/// - The output is bounded. `count` is clamped to `1...240` so a
///   misconfigured caller cannot emit a runaway timeline.
/// - The provider still controls refresh pacing. WidgetKit decides
///   when to actually swap to the next entry; the `.atEnd` policy
///   only asks the system to call `getTimeline` again after the last
///   entry is consumed. This helper does not and cannot promise that
///     the widget will update every minute.
///
/// The helper is a pure function. It does not call `Date()`,
/// `WidgetCenter`, or any side-effecting API — tests can pass a fixed
/// calendar and a fixed `start` and assert on the exact returned array.
enum WidgetTimelineSchedule {

    /// Default number of entries a normal home-screen widget should
    /// ship ahead of time. 60 minutes gives a wide refresh window
    /// without spending the system timeline budget on entries that
    /// will never be rendered.
    static let defaultEntryCount = 60

    /// Maximum number of entries the helper will emit, regardless of
    /// what the caller asks for. WidgetKit itself caps how many
    /// pre-rendered entries it keeps, but a runaway caller should
    /// fail here first.
    static let maxEntryCount = 240

    /// Generate `count` future dates aligned to minute boundaries,
    /// starting at the first minute strictly after `start` in the
    /// supplied `calendar`. Returns an array of unique, strictly
    /// increasing dates of length `clamp(count, 1...maxEntryCount)`.
    static func futureMinuteAlignedDates(
        startingAt start: Date,
        count: Int,
        calendar: Calendar = .current
    ) -> [Date] {
        let boundedCount = max(1, min(maxEntryCount, count))

        // Truncate to the start of the current minute, then step to
        // the next boundary so every returned date is strictly
        // greater than `start` and aligned on a minute.
        let cal = calendar
        let startMinute = cal.dateInterval(of: .minute, for: start)?.start ?? start
        let firstMinute = cal.date(byAdding: .minute, value: 1, to: startMinute) ?? startMinute

        var dates: [Date] = []
        dates.reserveCapacity(boundedCount)
        dates.append(firstMinute)
        for offset in 1..<boundedCount {
            // `.minute` arithmetic is calendar-aware: it correctly
            // handles DST transitions and varying month lengths.
            if let next = cal.date(byAdding: .minute, value: offset, to: firstMinute) {
                dates.append(next)
            } else {
                // Calendar arithmetic failed (extremely rare — leap-
                // second tables, etc.). Stop rather than emit a
                // malformed entry.
                break
            }
        }
        return dates
    }

    /// Build a Timeline whose entries are spaced one minute apart,
    /// starting at the next minute boundary after `start`. Uses
    /// `.atEnd` because that is the documented policy for asking
    /// WidgetKit to call `getTimeline` again once the last entry is
    /// consumed. WidgetKit is still free to throttle, skip, or refuse
    /// individual entries.
    ///
    /// `factory` produces each entry, given its scheduled date.
    /// Returning an empty array yields an empty timeline — the system
    /// will then call `getTimeline` again according to the policy.
    static func makeMinuteAlignedTimeline<Entry: TimelineEntry>(
        count: Int,
        start: Date = Date(),
        calendar: Calendar = .current,
        factory: (Date) -> Entry
    ) -> Timeline<Entry> {
        let boundedCount = max(1, min(maxEntryCount, count))
        let dates = futureMinuteAlignedDates(startingAt: start, count: boundedCount, calendar: calendar)
        let entries = dates.map(factory)
        return Timeline(entries: entries, policy: .atEnd)
    }
}