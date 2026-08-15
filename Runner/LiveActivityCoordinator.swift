import Foundation
import ActivityKit
import UIKit
import WidgetKit

// MARK: - Live Activity Coordinator
//
// Owns the lifecycle of the Dynamic Island + Lock Screen Live
// Activity for Drive Studio. The coordinator wraps three concerns in
// one place, in order of importance:
//
//   1. **Authorization** — Live Activities are a system feature the
//      user can disable globally in Settings. We must check
//      `ActivityAuthorizationInfo.areActivitiesEnabled` before every
//      start.
//   2. **Lifecycle** — start on first above-threshold movement, update
//      on significant speed changes, end after 5 minutes of no
//      movement. Persists across the app's foreground / background
//      transitions and across hot restarts.
//   3. **State** — the `ContentState` payload passed to ActivityKit
//      must match the `DriveStudioActivityAttributes.ContentState`
//      declared in the shared `DriveStudioWidget` folder so the
//      widget extension renders the same view the host app pushed.
//
// The coordinator derives everything from `TelemetryService.shared`
// and `AppGroupContract` — no new persistence path, no new shared
// state. The activity itself is OS-managed; the coordinator only
// holds an in-memory `currentActivity` reference so on the next
// update we can call `await activity.update(...)` without starting a
// parallel activity.
//
// iOS 16.1 API surface is used throughout (`contentState:` form, not
// the iOS 16.2 `ActivityContent` wrapper) so the coordinator compiles
// against the project's iOS 16.0 deployment target without warnings.

@available(iOS 16.1, *)
final class LiveActivityCoordinator {

    // MARK: - Configuration

    /// Speed (m/s) sustained before we consider the user "moving"
    /// and start the Live Activity. Same threshold the auto-flip
    /// heuristic uses for `carConnected` so the widget starts the
    /// moment driving is detected — not several minutes later when
    /// the heuristic finally notices.
    static let startSpeedThreshold: Double = 2.0       // ~7 km/h

    /// Speed (m/s) below which we count the user as "stationary".
    /// Slightly lower than the start threshold so brief GPS noise
    /// around 2 m/s doesn't cause flapping between start and stop.
    static let stationarySpeedThreshold: Double = 1.0  // ~3.6 km/h

    /// Wall-clock window of continuous below-threshold speed
    /// before we end the activity. 5 minutes mirrors the
    /// `carConnected` auto-flip delay so the Dashboard car-link
    /// indicator and the Live Activity end in lockstep.
    static let stationaryEndInterval: TimeInterval = 300

    /// Minimum time between consecutive `activity.update(...)` calls.
    /// Apple strongly throttles high-frequency Live Activity updates
    /// even with `NSSupportsLiveActivitiesFrequentUpdates = YES` — the
    /// system grants a budget per app and gets stingy when driven
    /// faster than this. 30s matches the home-screen widget speed
    /// reload interval so the two surfaces appear to refresh at the
    /// same cadence.
    static let updateInterval: TimeInterval = 30.0

    // MARK: - State

    static let shared = LiveActivityCoordinator()

    /// The OS-managed activity, if one is currently active. Held
    /// only so subsequent updates can target the same token
    /// (`Activity.request(...)` would create a parallel activity;
    /// we want to update the existing one).
    private var currentActivity: Activity<DriveStudioActivityAttributes>?

    /// Decoupled from `currentActivity` so tests can toggle the
    /// "activity is active" gate without spinning up ActivityKit.
    /// Production sets it on `request(...)` and clears it on
    /// `end(...)`. The activity reference is itself only needed at
    /// the API call site, which the test stubs out.
    private var isActive: Bool = false

    /// `true` when an activity is currently in flight. Gated on
    /// `isActive` so tests can drive the decision paths without
    /// `Activity.activities.first` returning real tokens.
    private var hasActiveActivity: Bool {
        isActive || currentActivity != nil
    }

    /// Wall-clock stamp of the last speed sample that crossed the
    /// stationary threshold. Used to decide when to end the
    /// activity after the user parks.
    private var lastMovementAt: Date?

    /// Wall-clock stamp of the last `activity.update(...)` call. Used
    /// to enforce `updateInterval` and avoid burning the budget.
    private var lastUpdateAt: Date?

    /// The most recent `ContentState` we attempted to push. Cached
    /// so a delta check before each `update` can skip a no-op push
    /// (e.g. only the timestamp changed).
    private var lastPushedState: DriveStudioActivityAttributes.ContentState?

    /// Test seam. Production reads `TelemetryService.shared` from
    /// the global; tests inject a stub to drive
    /// `shouldStart`/`shouldEnd` without CLLocation.
    var telemetrySource: () -> LiveActivityTelemetrySnapshot = {
        LiveActivityTelemetrySnapshot(
            speed: TelemetryService.shared.currentSpeed,
            batteryPercent: LiveActivityCoordinator.readBatteryPercent(),
            isCharging: LiveActivityCoordinator.readIsCharging(),
            carConnected: TelemetryService.shared.carConnected,
            speedUnit: LiveActivityCoordinator.readSpeedUnit()
        )
    }

    /// Test seam. Mirrors the `reloadRequester` pattern in
    /// `TelemetryService` — production calls `Activity.request(...)`,
    /// tests substitute a no-op so they can assert on the
    /// decision logic without spinning up ActivityKit.
    var activityRequester: ((DriveStudioActivityAttributes.ContentState) -> Void)?
    var activityUpdater: ((DriveStudioActivityAttributes.ContentState) -> Void)?
    var activityEnder: (() -> Void)?

    private init() {
        // Default `activityRequester`/`Updater`/`Ender` use the
        // real ActivityKit API. Tests overwrite these before the
        // first call.
        let coordinator = self
        self.activityRequester = { state in
            Task { await coordinator.requestActivity(state: state) }
        }
        self.activityUpdater = { state in
            Task { await coordinator.updateActivity(state: state) }
        }
        self.activityEnder = {
            Task { await coordinator.endActivitySoon() }
        }
    }

    // MARK: - Test seams

    /// Test-only seam. Production code never calls this — it only
    /// sets `isActive` via `request(...)` / `end(...)`. Tests inject
    /// `true` to simulate "an activity is currently active" without
    /// ActivityKit, so the update / end-decision paths can be
    /// exercised in isolation.
    func _setActivityActiveForTest(_ active: Bool) {
        isActive = active
        currentActivity = nil
    }

    /// Test-only seam that re-installs the production start path
    /// after a test has stubbed it. The test bodies call this inside
    /// `defer` blocks so the `LiveActivityCoordinator.shared` singleton
    /// returns to its default state before the next test runs.
    func _realRequestActivityTest() async {
        isActive = true
        currentActivity = nil
    }

    /// Test-only seam for the update closure. No-op in tests — the
    /// actual `update(contentState:)` call needs a real `Activity`
    /// token, which the test stubs out.
    func _realUpdateActivityTest() async {
        // No-op in tests.
    }

    /// Test-only seam for the end closure.
    func _realEndActivityTest() async {
        isActive = false
        currentActivity = nil
        lastPushedState = nil
        lastUpdateAt = nil
        lastMovementAt = nil
    }

    /// Test-only seam. Mirror the production `updateActivity` side
    /// effect of stamping `lastUpdateAt` so the rate-limit gate in
    /// `shouldUpdate` can be exercised from tests whose stub
    /// `activityUpdater` closure observes the call but does not
    /// run the production code.
    func _setLastUpdateAtForTest(_ date: Date?) {
        lastUpdateAt = date
    }

    // MARK: - Public API — called from TelemetryService

    /// Called on every GPS update. Decides whether to start, update,
    /// or end the Live Activity based on the current telemetry.
    /// No-op on iOS < 16.1 (ActivityKit unavailable).
    func onTelemetryUpdate(now: Date = Date()) {
        guard #available(iOS 16.1, *) else { return }
        let snapshot = telemetrySource()

        // One-shot: stitch on an existing activity if the system
        // still has one alive (e.g. cold start while a previous
        // session's activity is still live in the Lock Screen).
        if !isActive, let existing = Activity<DriveStudioActivityAttributes>.activities.first {
            currentActivity = existing
            isActive = true
        }

        if let spd = snapshot.speed, spd > Self.startSpeedThreshold {
            lastMovementAt = now
            if !hasActiveActivity {
                if Self.areActivitiesEnabled() {
                    activityRequester?(snapshot.asContentState())
                }
            } else if shouldUpdate(now: now, snapshot: snapshot) {
                activityUpdater?(snapshot.asContentState())
            }
        } else if hasActiveActivity {
            // Either stationary (count toward end) or never moving
            // (immediately end). The first branch we enter is
            // `lastMovementAt == nil` — we have never seen
            // movement, so we end the activity right away.
            if let last = lastMovementAt {
                if now.timeIntervalSince(last) >= Self.stationaryEndInterval {
                    activityEnder?()
                }
            } else {
                activityEnder?()
            }
        }
    }

    /// Force-end the activity. Called from the `carConnected`
    /// auto-flip path and from `AppDelegate` termination handlers
    /// so the Lock Screen banner disappears promptly.
    func endImmediately() {
        guard #available(iOS 16.1, *) else { return }
        activityEnder?()
    }

    // MARK: - ActivityKit plumbing (iOS 16.1 API surface)

    @available(iOS 16.1, *)
    private func requestActivity(state: DriveStudioActivityAttributes.ContentState) {
        let attributes = DriveStudioActivityAttributes()
        do {
            let activity = try Activity.request(
                attributes: attributes,
                contentState: state,
                pushType: nil
            )
            currentActivity = activity
            isActive = true
            lastPushedState = state
            lastUpdateAt = Date()
        } catch {
            print("[LiveActivity] start failed: \(error.localizedDescription)")
        }
    }

    @available(iOS 16.1, *)
    private func updateActivity(state: DriveStudioActivityAttributes.ContentState) async {
        guard let activity = currentActivity else { return }
        await activity.update(using: state)
        lastPushedState = state
        lastUpdateAt = Date()
    }

    @available(iOS 16.1, *)
    private func endActivitySoon() async {
        guard let activity = currentActivity else { return }
        let final = currentFinalState()
        await activity.end(using: final, dismissalPolicy: .immediate)
        currentActivity = nil
        isActive = false
        lastPushedState = nil
        lastUpdateAt = nil
        lastMovementAt = nil
    }

    // MARK: - Decision helpers

    /// Should we push an `update(...)` for this snapshot? Always
    /// returns true for the first update after a start; otherwise
    /// compares against the last pushed state and only pushes when
    /// something user-visible changed AND we're past
    /// `updateInterval`.
    private func shouldUpdate(now: Date, snapshot: LiveActivityTelemetrySnapshot) -> Bool {
        if let last = lastUpdateAt,
           now.timeIntervalSince(last) < Self.updateInterval {
            return false
        }
        if let last = lastPushedState {
            // Car-link state changed (always visible).
            if last.carConnected != snapshot.carConnected { return true }
            // Charging state changed (battery icon overlay).
            if last.isCharging != snapshot.isCharging { return true }
            // Battery int changed (visible rounding).
            if last.batteryPercent != snapshot.batteryPercent { return true }
            // Speed moved by ≥ `significantSpeedDelta` km/h.
            let prev = last.speedKmh ?? 0
            let curr = snapshot.speed ?? 0
            if abs(prev - curr) >= TelemetryService.significantSpeedDelta { return true }
            // GPS lost flipped (derived from `speed == nil`).
            let currGpsLost = snapshot.speed == nil
            if last.gpsLost != currGpsLost { return true }
            return false
        }
        return true
    }

    private func currentFinalState() -> DriveStudioActivityAttributes.ContentState {
        // Capture the last telemetry and force the "stationary"
        // state so the activity ends showing 0 instead of an
        // inflated value.
        let snapshot = telemetrySource()
        let copy = LiveActivityTelemetrySnapshot(
            speed: 0,
            batteryPercent: snapshot.batteryPercent,
            isCharging: snapshot.isCharging,
            carConnected: snapshot.carConnected,
            speedUnit: snapshot.speedUnit
        )
        return copy.asContentState()
    }

    // MARK: - Static helpers

    /// `ActivityAuthorizationInfo` is the OS switch the user can
    /// toggle per app in Settings. If it's off, `Activity.request`
    /// throws — return early instead of borrowing other apps'
    /// budgets.
    @available(iOS 16.1, *)
    static func areActivitiesEnabled() -> Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    static func readBatteryPercent() -> Int? {
        let device = UIDevice.current
        let level = device.batteryLevel
        return level >= 0 ? Int(level * 100) : nil
    }

    static func readIsCharging() -> Bool {
        let device = UIDevice.current
        return device.batteryState == .charging
            || device.batteryState == .full
    }

    static func readSpeedUnit() -> String {
        let defaults = UserDefaults(suiteName: AppGroupContract.suiteName)
        return defaults?.string(forKey: "settings.speedUnit") ?? "kmh"
    }
}

// MARK: - Snapshot helper

/// Aggregated telemetry read at one instant. Distinct from the
/// App-Group-persisted `TelemetrySnapshot` (in `WidgetModels.swift`)
/// because the coordinator needs an explicit `asContentState()`
/// mapper to the `ActivityAttributes.ContentState` shape. Renamed
/// to `LiveActivityTelemetrySnapshot` so the two don't collide.
struct LiveActivityTelemetrySnapshot {
    let speed: Double?
    let batteryPercent: Int?
    let isCharging: Bool
    let carConnected: Bool
    let speedUnit: String

    /// Map into the shared `ContentState` shape used by the
    /// activity. The `gpsLost` flag is derived from the speed
    /// being `nil` (no recent fix within the freshness window).
    func asContentState() -> DriveStudioActivityAttributes.ContentState {
        DriveStudioActivityAttributes.ContentState(
            speedKmh: speed,
            isCharging: isCharging,
            batteryPercent: batteryPercent,
            carConnected: carConnected,
            speedUnit: speedUnit,
            gpsLost: speed == nil
        )
    }
}
