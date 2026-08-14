import SwiftUI
import WidgetKit

/// Shared minute-clock mechanism used by every widget root.
///
/// Apple-documented: `TimelineView(.everyMinute)` re-evaluates its
/// content closure every minute WidgetKit is willing to advance the
/// clock. The closure receives a `context` whose `context.date`
/// advances independently of provider entries — so clock text, date
/// text, day-progress arcs, and analog-clock hands can refresh once
/// per minute even though provider entries are spaced five minutes
/// apart.
///
/// **Truth contract:** the closure is allowed to read `context.date`
/// ONLY. It MUST NOT read telemetry, `UIDevice`, Core Location,
/// network data, UserDefaults, or call `WidgetCenter`. The closure
/// receives no app state other than `context.date` and the data
/// passed in via `static data`. The outer widget view passes the
/// captured `entry` (telemetry, vehicle, spec) once; the closure
/// only uses that data — it does not re-fetch.
///
/// `WidgetKit` controls when the closure actually runs. We do not
/// promise per-minute execution.
@available(iOS 16.0, *)
struct MinuteClockView<StaticData, Content: View>: View {
    let staticData: StaticData
    let content: (Date, StaticData) -> Content

    init(
        data: StaticData,
        @ViewBuilder content: @escaping (Date, StaticData) -> Content
    ) {
        self.staticData = data
        self.content = content
    }

    var body: some View {
        TimelineView(.everyMinute) { context in
            // The closure body MUST NOT touch UIDevice, Core Location,
            // network, UserDefaults, or WidgetCenter. It may only use
            // `context.date` for clock/date/day-progress/analog-hand
            // rendering and the supplied `staticData` (which the outer
            // widget view has already captured from its entry).
            content(context.date, staticData)
        }
    }
}
