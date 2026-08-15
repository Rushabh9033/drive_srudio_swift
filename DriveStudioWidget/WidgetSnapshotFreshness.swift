import Foundation

/// Snapshot freshness policy used by every widget provider and the
/// `NativeSpecialRenderer`. Pure: takes a snapshot and a reference
/// `Date` (so tests can drive the clock deterministically), returns
/// a snapshot whose `speed` is `nil` when the captured reading is
/// older than `maxAge` or when the timestamp itself is missing.
///
/// **What expires:**
///   * `speed` — GPS readings go stale quickly. A 5-minute-old speed
///     must never display as "current" because the user is unlikely
///     to be moving at the recorded value anymore.
///
/// **What does NOT expire:**
///   * `batteryPercent` — the latest known battery is still useful
///     even if speed has expired; the widget should show "— speed ·
///     73% battery", not "— speed · — battery".
///   * `isCharging` — same reasoning; charging state moves slowly.
///   * `carConnected` — the manual toggle persists regardless of
///     how stale the snapshot is.
///
/// The policy is intentionally asymmetric: only the time-sensitive
/// field is reaped, the rest remain "latest known". This matches the
/// reality of what stale data is and isn't safe to display.
enum WidgetSnapshotFreshness {

    /// Maximum age of a snapshot before its speed reading is
    /// considered expired.
    ///
    /// Speed is the time-sensitive telemetry field — a 5-min-old
    /// speed almost never reflects the user's actual current speed.
    /// Ninety seconds is short enough that a stationary user who
    /// starts moving sees the widget switch from `—` (no fresh fix)
    /// to a real number within one provider tick, and long enough
    /// to absorb a single missed GPS sample.
    ///
    /// The provider's entry cadence is still 5 minutes (Apple's
    /// documented minimum for normal home-screen widgets), but
    /// `projected` zeroes the speed on any entry more than
    /// `maxAge` past the captured timestamp. That means entry 1
    /// (just published) shows real speed; entries 2+ show `—`
    /// until a `speedChange` reload triggers a new snapshot.
    static let maxAge: TimeInterval = 90

    /// Apply the freshness policy to `snapshot`. Returns a snapshot
    /// whose `speed` is `nil` when:
    ///   * `snapshot.timestamp == nil` (no fix recorded yet)
    ///   * `referenceDate - snapshot.timestamp > maxAge`
    ///
    /// All other fields are passed through unchanged. Genuine `0`
    /// km/h remains `0`; only `nil`/stale becomes `nil`.
    static func apply(to snapshot: TelemetrySnapshot,
                      referenceDate: Date) -> TelemetrySnapshot {
        guard isFresh(snapshot: snapshot, referenceDate: referenceDate) else {
            return TelemetrySnapshot(
                carConnected: snapshot.carConnected,
                batteryPercent: snapshot.batteryPercent,
                isCharging: snapshot.isCharging,
                speed: nil,
                timestamp: snapshot.timestamp
            )
        }
        return snapshot
    }

    /// `true` when the snapshot's speed reading is still within the
    /// freshness window relative to `referenceDate`. Used by the
    /// timeline factories to decide whether to propagate speed to a
    /// future entry, so a timeline entry that renders 7 minutes in the
    /// future automatically stops showing the captured speed.
    static func isFresh(snapshot: TelemetrySnapshot,
                        referenceDate: Date) -> Bool {
        guard let ts = snapshot.timestamp else { return false }
        let age = referenceDate.timeIntervalSince(ts)
        // A negative age means the host clock is behind ours (or the
        // user manually set their clock back). Treat as fresh rather
        // than expiring valid data.
        return age <= maxAge
    }

    /// Per-entry freshness for a future timeline entry. If the entry's
    /// scheduled date is older than `maxAge` past the snapshot's
    /// timestamp, the speed must read as unavailable.
    ///
    /// This is the policy that makes a captured 60 km/h speed
    /// automatically disappear 5 minutes into the future — even if
    /// WidgetKit has not yet reloaded the timeline.
    static func projected(snapshot: TelemetrySnapshot,
                          at entryDate: Date) -> TelemetrySnapshot {
        guard let ts = snapshot.timestamp else {
            return TelemetrySnapshot(
                carConnected: snapshot.carConnected,
                batteryPercent: snapshot.batteryPercent,
                isCharging: snapshot.isCharging,
                speed: nil,
                timestamp: snapshot.timestamp
            )
        }
        let age = entryDate.timeIntervalSince(ts)
        if age > maxAge {
            return TelemetrySnapshot(
                carConnected: snapshot.carConnected,
                batteryPercent: snapshot.batteryPercent,
                isCharging: snapshot.isCharging,
                speed: nil,
                timestamp: snapshot.timestamp
            )
        }
        return snapshot
    }
}
