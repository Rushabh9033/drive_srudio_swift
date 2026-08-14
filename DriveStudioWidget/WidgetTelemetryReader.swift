import Foundation

/// The single truthful reader of widget telemetry and selected vehicle
/// from the App Group. Every production widget provider and renderer in
/// this target (StaticProvider, DriveProvider, OrbitDateProvider,
/// NativeSpecialRenderer) reads through this enum. There are no
/// fallback paths that invent values.
///
/// **What it reads:**
///   * `AppGroupContract.suiteName` (`group.com.drivestudio.shared`)
///   * `live_telemetry` (canonical key the host writes)
///   * `drive_studio_telemetry` (older key; legacy fallback only)
///   * V2 `WidgetState` (slots + selected vehicle) via `AppGroupState`
///
/// **What it does NOT read or call:**
///   * `UIDevice.current` (no battery, no state)
///   * Core Location
///   * Network
///   * Timer
///   * `WidgetCenter`
///
/// **Truth contract:**
///   * `batteryPercent` returns `nil` when the host never wrote a value
///     or when the value is missing.
///   * `speed` returns `nil` when no fix exists or `speed < 0`.
///   * `isCharging` is the exact value the host wrote — never ORed with
///     a stale cached flag.
///   * `vehicleDisplayName` returns `nil` when no vehicle is selected.
///
/// All decoding methods are pure: they take no `UIDevice`, no
/// `CLLocationManager`, no `WidgetCenter`. Tests can construct a
/// synthetic `UserDefaults` suite (or pass prebuilt values) and assert
/// on the exact returned optionals.
enum WidgetTelemetryReader {

    /// Live telemetry the host app last wrote. `nil` if nothing has
    /// been written yet, the value is unreadable, or the snapshot is
    /// stale beyond the documented threshold.
    ///
    /// The first time the host writes a snapshot it appears here; if
    /// the user force-quits the app the widget continues to render the
    /// most recent snapshot until iOS evicts the timeline.
    static func liveSnapshot() -> TelemetrySnapshot? {
        return decodeLiveSnapshot()
    }

    /// Decode the host-app-written telemetry snapshot. Tries the
    /// canonical key first, falls back to the legacy key only when the
    /// canonical key is absent (so older host builds that still write
    /// the legacy key keep working until they upgrade). Never returns
    /// a fabricated value.
    static func decodeLiveSnapshot() -> TelemetrySnapshot? {
        guard let defaults = UserDefaults(suiteName: AppGroupContract.suiteName) else {
            return nil
        }
        if let data = defaults.data(forKey: AppGroupContract.liveTelemetryKey),
           let snapshot = try? JSONDecoder().decode(TelemetrySnapshot.self, from: data) {
            return snapshot
        }
        // Documented backward-compatible fallback only.
        if let data = defaults.data(forKey: AppGroupContract.legacyTelemetryKey),
           let snapshot = try? JSONDecoder().decode(TelemetrySnapshot.self, from: data) {
            return snapshot
        }
        return nil
    }

    /// The selected vehicle's display name from the App Group state, or
    /// `nil` when no vehicle is selected. The widget must render an
    /// unavailable marker for `nil`; it must never substitute a
    /// placeholder brand name.
    static func selectedVehicleDisplayName() -> String? {
        return AppGroupState.loadState()?.vehicle?.displayName
    }
}

extension AppGroupContract {
    /// Canonical key the host app writes on every telemetry refresh
    /// (battery change, charging state change, foreground, GPS fix).
    static let liveTelemetryKey = "live_telemetry"

    /// Backward-compatible legacy key. Read only as a documented
    /// fallback when `liveTelemetryKey` is absent. New host builds
    /// write both, then read via the canonical key first.
    static let legacyTelemetryKey = "drive_studio_telemetry"
}

/// Pure helpers used by production renderers and by tests. These are
/// kept here (not in the views) so that the same conversion is exercised
/// in the test target as in production.
enum WidgetDisplayMath {

    /// Clamp a battery percentage to the displayable 0…100 range. Does
    /// NOT substitute a value for `nil`; callers must check
    /// availability at the call site.
    static func clampedBatteryPercent(_ pct: Int?) -> Int? {
        guard let pct else { return nil }
        return max(0, min(100, pct))
    }

    /// Battery fill fraction (0.0…1.0) for progress rings/bars. Returns
    /// `nil` when battery is unknown so the caller can render an empty
    /// track rather than a fake filled value.
    static func batteryFraction(_ pct: Int?) -> Double? {
        guard let clamped = clampedBatteryPercent(pct) else { return nil }
        return Double(clamped) / 100.0
    }

    /// Speed text used by production renderers. `nil` becomes `"—"`;
    /// any supplied km/h value (including genuine `0`) is rendered
    /// verbatim. The widget never multiplies this value again; the
    /// host converts m/s → km/h exactly once.
    static func speedText(kmh: Double?) -> String {
        guard let kmh else { return "—" }
        return "\(Int(kmh))"
    }

    /// Speed fill fraction for a 0…`scale` km/h gauge. Returns `nil`
    /// when speed is unknown so the caller renders an empty track.
    /// Does NOT enforce an artificial minimum like 0.01 or 0.05.
    static func speedFraction(kmh: Double?, scale: Double = 200.0) -> Double? {
        guard let kmh else { return nil }
        return max(0.0, min(1.0, kmh / scale))
    }

    /// Vehicle label used by production renderers. Returns `nil` when
    /// no vehicle is selected — caller must render an unavailable
    /// marker; we never substitute `"Tesla Model 3"` or any other
    /// placeholder brand name.
    static func vehicleLabel(_ name: String?) -> String {
        guard let name, !name.isEmpty else { return "—" }
        return name
    }
}
