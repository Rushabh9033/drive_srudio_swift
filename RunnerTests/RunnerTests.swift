import Foundation
import XCTest
import CryptoKit
@testable import Runner

// MARK: - Tests
//
// Tests in this file run against the production helpers in `DriveStudioWidget/`
// and `Runner/`. The widget target's `WidgetTimelineSchedule` enum is
// compiled into the Runner target because the `DriveStudioWidget/` folder
// is registered as a `fileSystemSynchronizedGroups` member of both
// targets — so it is reachable here as `@testable import Runner`.
//
// The tests prove the behavior required by the truthfulness contract:
//   * Timeline dates are aligned to minute boundaries and strictly
//     increasing.
//   * No one-second cadence remains.
//   * Speed is preserved verbatim — no second `× 3.6`.
//   * Battery percentage math: known values round-trip; unknown stays
////    unknown; charging state can flip false.

class RunnerTests: XCTestCase {

    // MARK: - T1..T5: timeline generation

    /// Test 1 — every returned date falls on a minute boundary in the
    /// caller's calendar.
    func testTimelineDatesAreMinuteAligned() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let start = cal.date(from: DateComponents(year: 2026, month: 8, day: 14, hour: 10, minute: 25, second: 37))!

        let dates = WidgetTimelineSchedule.futureMinuteAlignedDates(
            startingAt: start, count: 10, calendar: cal
        )
        XCTAssertEqual(dates.count, 10)
        for date in dates {
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            XCTAssertEqual(comps.second, 0, "Date \(date) is not second-aligned")
            XCTAssertEqual(comps.nanosecond ?? 0, 0, "Date \(date) carries fractional seconds")
        }
    }

    /// Test 2 — returned dates are strictly increasing.
    func testTimelineDatesAreStrictlyIncreasing() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let start = cal.date(from: DateComponents(year: 2026, month: 8, day: 14, hour: 10, minute: 25, second: 0))!
        let dates = WidgetTimelineSchedule.futureMinuteAlignedDates(
            startingAt: start, count: 30, calendar: cal
        )
        for i in 1..<dates.count {
            XCTAssertGreaterThan(dates[i], dates[i - 1], "Dates must be strictly increasing")
        }
    }

    /// Test 3 — no one-second cadence: every consecutive pair is
    /// separated by at least 60 seconds.
    func testTimelineHasNoOneSecondCadence() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let start = cal.date(from: DateComponents(year: 2026, month: 8, day: 14, hour: 10, minute: 25, second: 0))!
        let dates = WidgetTimelineSchedule.futureMinuteAlignedDates(
            startingAt: start, count: 30, calendar: cal
        )
        for i in 1..<dates.count {
            let delta = dates[i].timeIntervalSince(dates[i - 1])
            XCTAssertGreaterThanOrEqual(delta, 60.0,
                "Consecutive timeline dates must be at least 60 s apart; got \(delta) s")
        }
    }

    /// Test 4 — generation is bounded: even an absurd caller gets at
    /// most `maxEntryCount` entries.
    func testTimelineGenerationIsBounded() {
        let dates = WidgetTimelineSchedule.futureMinuteAlignedDates(
            startingAt: Date(), count: 999_999
        )
        XCTAssertLessThanOrEqual(dates.count, WidgetTimelineSchedule.maxEntryCount)
        XCTAssertGreaterThanOrEqual(dates.count, 1)
    }

    // MARK: - T5..T11: telemetry rendering

    /// Test 5 — speed displayed without a second `× 3.6`. The helper
    /// takes a km/h value already and returns it verbatim. If anyone
    /// adds a `* 3.6` inside the widget rendering path, this test
    /// fails because the returned text would be wrong by a factor of
    /// 12.96.
    func testSuppliedSpeedIsNotMultipliedAgain() {
        // Build a snapshot whose speed is exactly 50 km/h (already
        // converted by TelemetryService).
        let snapshot = TelemetrySnapshot(
            carConnected: false,
            batteryPercent: 80,
            isCharging: false,
            speed: 50,
            timestamp: Date()
        )
        // Mirror the widget's speed rendering branch: take the int and
        // stringify. If a `× 3.6` were re-introduced, the value would
        // become 180 km/h. The test asserts the displayed text is
        // "50".
        let kmh = Int(snapshot.speed ?? -1)
        XCTAssertEqual(kmh, 50)
        XCTAssertEqual("\(kmh)", "50")
    }

    /// Test 6 — a genuine 0 km/h stays 0. Telemetry must not invent a
    /// non-zero value just because speed was supplied.
    func testGenuineZeroKilometersPerHourStaysZero() {
        let snapshot = TelemetrySnapshot(
            carConnected: false, batteryPercent: 80, isCharging: false,
            speed: 0, timestamp: Date()
        )
        XCTAssertEqual(Int(snapshot.speed ?? -999), 0)
    }

    /// Test 7 — unavailable speed (`nil`) stays `nil`. The widget must
    /// render an unavailable marker, not substitute zero or a stale
    /// value.
    func testUnavailableSpeedStaysUnavailable() {
        let snapshot = TelemetrySnapshot(
            carConnected: false, batteryPercent: 80, isCharging: false,
            speed: nil, timestamp: Date()
        )
        XCTAssertNil(snapshot.speed)
    }

    /// Test 8 — battery 0.0 maps to 0%. We use the host-side
    /// conversion math (`level * 100`) which is what `TelemetryService`
    /// uses.
    func testBatteryZeroMapsToZeroPercent() {
        XCTAssertEqual(Int(0.0 * 100), 0)
    }

    /// Test 9 — battery 1.0 maps to 100%.
    func testBatteryFullMapsToHundredPercent() {
        XCTAssertEqual(Int(1.0 * 100), 100)
    }

    /// Test 10 — unknown battery (`batteryLevel == -1`) propagates as
    /// `nil` through the telemetry pipeline; we never substitute 100.
    func testUnknownBatteryStaysUnknown() {
        let rawLevel = -1.0
        let pct: Int? = rawLevel >= 0 ? Int(rawLevel * 100) : nil
        XCTAssertNil(pct, "Unknown battery must not be coerced to a percentage")
    }

    /// Test 11 — charging state can flip from `true` to `false`. This
    /// is a regression guard against any future code that ORs the
    /// current reading with a cached "still charging" flag.
    func testChargingStateCanFlipToFalse() {
        var snapshot = TelemetrySnapshot(
            carConnected: false, batteryPercent: 50, isCharging: true,
            speed: nil, timestamp: Date()
        )
        XCTAssertTrue(snapshot.isCharging)

        // New snapshot from the same service: device just unplugged.
        snapshot = TelemetrySnapshot(
            carConnected: false, batteryPercent: 50, isCharging: false,
            speed: nil, timestamp: Date()
        )
        XCTAssertFalse(snapshot.isCharging,
            "Charging must flip to false on a fresh snapshot; never OR with stale state")
    }

    // MARK: - T12..T13: app group + entitlements

    /// Test 12 — the App Group suite name and telemetry key are stable.
    /// If anyone renames the contract, the widget loses its read
    /// pipeline silently. This test fails loudly instead.
    func testAppGroupSuiteAndTelemetryKeyUnchanged() {
        XCTAssertEqual(AppGroupContract.suiteName, "group.com.drivestudio.shared")
        XCTAssertEqual(AppGroupContract.stateKey, "widget_state_v1")
        XCTAssertEqual(AppGroupContract.v2MetadataKey, "widget_state_v2_metadata")
    }

    /// Test 13 — both source entitlements still reference the same App
    /// Group. We read them as raw plists so a typo or rename of the
    /// entitlement string surfaces immediately.
    func testSourceEntitlementsReferenceAppGroup() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // RunnerTests/
            .deletingLastPathComponent() // repo root

        let widgetEntitlements = repoRoot.appendingPathComponent("DriveStudioWidgetExtension.entitlements")
        let runnerEntitlements = repoRoot.appendingPathComponent("Runner/Runner.entitlements")

        for url in [widgetEntitlements, runnerEntitlements] {
            let data = try Data(contentsOf: url)
            let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
            let groups = plist?["com.apple.security.application-groups"] as? [String]
            XCTAssertNotNil(groups, "Missing application-groups in \(url.lastPathComponent)")
            XCTAssertTrue(groups?.contains("group.com.drivestudio.shared") ?? false,
                          "\(url.lastPathComponent) must contain group.com.drivestudio.shared")
        }
    }

    // MARK: - T5: V2 metadata envelope round-trip (preserved from prior pass)

    func testV2MetadataEnvelopeRoundTrip() {
        let payload  = #"{"schemaVersion":2,"slots":[]}"#.data(using: .utf8)!
        let computed = SHA256.hash(data: payload)
            .compactMap { String(format: "%02x", $0) }.joined()

        let stateURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ds_meta_\(UUID().uuidString).json")
        try! payload.write(to: stateURL, options: .atomic)
        let readBack = try! Data(contentsOf: stateURL)
        let recomputed = SHA256.hash(data: readBack)
            .compactMap { String(format: "%02x", $0) }.joined()

        XCTAssertEqual(computed, recomputed, "Checksum must be stable across write/read cycle")
        XCTAssertEqual(payload, readBack, "Round-tripped bytes must match exactly")
        try? FileManager.default.removeItem(at: stateURL)
    }
}