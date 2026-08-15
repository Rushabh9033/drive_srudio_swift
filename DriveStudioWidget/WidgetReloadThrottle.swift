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
///     (battery-level change, charging-state change, connection-state
///     change, foreground activation, slot/design save).
///   * Performs **zero** WidgetCenter calls when nothing visible
///     changed (`.noVisibleChange`).
///
/// The throttle does NOT add background timers or polling. The
/// 5-minute minimum is enforced only when a caller asks; if no
/// caller asks for a reload, nothing fires.
///
/// All state lives in memory. `reset()` is for tests.
///
/// **Injectable for tests.** Production code uses `WidgetReloadThrottle.shared`
/// which calls the real `WidgetCenter`. Tests construct a
/// `WidgetReloadThrottle(reloadHook: { count += 1 })` so the test never
/// touches `WidgetCenter` and never crashes on simulator runs without a
/// widget host.
final class WidgetReloadThrottle {

    static let shared = WidgetReloadThrottle()

    /// Minimum interval between speed-driven widget reload requests.
    ///
    /// Speed is the one telemetry field the user notices when it's
    /// stale — a moving user opening the home-screen widget will not
    /// tolerate seeing `0 km/h` for 5 minutes after they started
    /// driving. We therefore throttle speed reloads much more tightly
    /// than other categories: one reload per 30 s. That is still well
    /// under WidgetKit's per-app budget (~40 reloads/day per app) and
    /// gives the moving user a near-real-time feel without burning
    /// the budget on a stationary device (no speed changes → no
    /// reload requests → zero cost).
    static let minSpeedReloadInterval: TimeInterval = 30

    private var lastSpeedReload: Date? = nil
    private let lock = NSLock()

    /// Closure invoked whenever the throttle forwards a reload to
    /// WidgetCenter. Production code points this at
    /// `WidgetCenter.shared.reloadAllTimelines`. Tests supply a
    /// counting closure so the assertion side can verify the throttle
    /// without touching WidgetCenter (which is unsafe to call from
    /// unit tests).
    private let reloadHook: () -> Void

    init(reloadHook: @escaping () -> Void = { WidgetCenter.shared.reloadAllTimelines() }) {
        self.reloadHook = reloadHook
    }

    /// Request a reload. The caller specifies `kind`; only
    /// `.speedChange` is rate-limited. Battery / charging /
    /// connection / foreground / slot / design save pass through
    /// immediately. `.noVisibleChange` performs zero reloads.
    ///
    /// Returns `true` when a reload was actually requested from
    /// WidgetKit, `false` when it was suppressed (by the throttle
    /// or by `.noVisibleChange`).
    @discardableResult
    func requestReload(kind: WidgetReloadKind = .other,
                       now: Date = Date()) -> Bool {
        switch kind {
        case .speedChange:
            return requestSpeedReload(now: now)
        case .batteryLevelChange,
             .chargingStateChange,
             .connectionStateChange,
             .foregroundActivation,
             .slotChange,
             .designSave,
             .other:
            // Immediate. The throttle does not gate these.
            reloadHook()
            return true
        case .noVisibleChange:
            // Identical telemetry — perform zero reloads.
            return false
        }
    }

    /// Force a reload, bypassing the throttle. Use sparingly — e.g.,
    /// when a user explicitly hits a refresh button. Does NOT update
    /// `lastSpeedReload`, so a subsequent speed-driven request is
    /// still governed by the 5-minute minimum.
    func forceReload() {
        reloadHook()
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
        reloadHook()
        return true
    }
}

/// Categorizes why a reload is being requested. The throttle uses
/// this to decide whether to apply the speed-rate-limit. Lives at
/// the top level (not nested in the throttle class) so both Runner
/// and the widget extension compile cleanly when they reference the
/// enum from their respective targets.
enum WidgetReloadKind {
    /// GPS speed reading changed. Rate-limited.
    case speedChange
    /// Battery percentage reading crossed a boundary. Immediate.
    case batteryLevelChange
    /// Charging-state reading flipped. Immediate.
    case chargingStateChange
    /// Car-link state (carConnected) flipped. Immediate.
    case connectionStateChange
    /// App became active. Immediate.
    case foregroundActivation
    /// User assigned a slot to a draft. Immediate.
    case slotChange
    /// User saved a design. Immediate.
    case designSave
    /// Anything else not enumerated. Immediate.
    case other
    /// Nothing visible changed. Performs zero reloads.
    case noVisibleChange
}
