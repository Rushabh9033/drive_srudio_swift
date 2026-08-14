import Foundation

/// Cached DateFormatter instances. DateFormatter allocation is expensive
/// (parses locale, builds calendar) and was previously happening inside
/// SwiftUI view bodies. Reusing one shared instance per format keeps
/// the canvas and widget rendering cheap.
///
/// This file lives in the `DriveStudioWidget/` synchronized folder so it
/// is automatically compiled into both the Runner app and the
/// DriveStudioWidgetExtension target.
enum FormatterCache {
    /// `h:mm a` — used for live clock face strings on the home screen.
    static let hmmFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    /// `DateFormatter.Style.short` for time-of-day, e.g. `8:42 AM`.
    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    /// `DateFormatter.Style.medium` for date-only display.
    static let mediumDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}