import Foundation
import WidgetKit

/// Testable rate-limit policy for `WidgetCenter.reloadAllTimelines()`
/// calls. The host used to call reload from every GPS fix, which
/// would request dozens of reloads per second on a moving device and
/// burn WidgetKit's budget. This throttle:
///
///   * Lets GPS continue to update `TelemetryService.currentSpeed`
///     immediately (in-app UI keeps feeling live).
///   * Persists only meaningful widget telemetry changes.
///   * Rate-limits speed-driven reload requests to once every
///     `minSpeedReloadInterval` (5 minutes by default).
///   * Allows immediate reloads for events that genuinely matter
///     (battery-level change, charging-state change, foreground
///     activation, slot/design save). These are signals the user
///     acted on, so an immediate WidgetKit prompt is appropriate.
///
/// The throttle does NOT add background timers or polling. The
/// 5-minute minimum is enforced only when a caller asks; if no
/// caller asks for a reload, nothing fires.
///
/// All state lives in memory. `reset()` is for tests.
final class WidgetReloadThrottle {

    static let shared = WidgetReloadThrottle()

    /// Minimum interval between speed-driven widget reload requests.
    /// Five minutes matches Apple's documented provider cadence and
    /// keeps WidgetKit budget sane.
    static let minSpeedReloadInterval: TimeInterval = 5 * 60

    private var lastSpeedReload: Date? = nil
    private let lock = NSLock()

    init() {}

    /// Request a reload. The caller specifies `kind`; only
    /// `.speedChange` is rate-limited. All other kinds (battery,
    /// charging, foreground, slot save, design save) pass through
    /// immediately.
    ///
    /// Returns `true` when the reload was actually requested from
    /// WidgetKit, `false` when it was suppressed by the throttle.
    @discardableResult
    func requestReload(kind: ReloadKind = .other,
                       now: Date = Date()) -> Bool {
        switch kind {
        case .speedChange:
            return requestSpeedReload(now: now)
        case .batteryLevelChange,
             .chargingStateChange,
             .foregroundActivation,
             .slotChange,
             .designSave,
             .other:
            // Immediate. The throttle does not gate these.
            WidgetCenter.shared.reloadAllTimelines()
            return true
        }
    }

    /// Force a reload, bypassing the throttle. Use sparingly — e.g.,
    /// when a user explicitly hits a refresh button. Does NOT update
    /// `lastSpeedReload`, so a subsequent speed-driven request is
    /// still governed by the 5-minute minimum.
    func forceReload() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Reset internal state. Test-only.
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        lastSpeedReload = nil
    }

    /// Inspect the most recent speed-driven reload time. Test-only.
    func lastSpeedReloadTime() -> Date? {
        lock.lock()
        defer { lock.unlock() }
        return lastSpeedReload
    }

    private func requestSpeedReload(now: Date) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if let last = lastSpeedReload,
           now.timeIntervalSince(last) < Self.minSpeedReloadInterval {
            return false
        }
        lastSpeedReload = now
        WidgetCenter.shared.reloadAllTimelines()
        return true
    }

    /// Categorizes why a reload is being requested. The throttle uses
    /// this to decide whether to apply the speed-rate-limit.
    enum ReloadKind {
        /// GPS speed reading changed. Rate-limited.
        case speedChange
        /// Battery percentage reading crossed a boundary. Immediate.
        case batteryLevelChange
        /// Charging-state reading flipped. Immediate.
        case chargingStateChange
        /// App became active. Immediate.
        case foregroundActivation
        /// User assigned a slot to a draft. Immediate.
        case slotChange
        /// User saved a design. Immediate.
        case designSave
        /// Anything else not enumerated. Immediate.
        case other
    }
}
