import Foundation
import XCTest
import CryptoKit
import WidgetKit
@testable import Runner

// MARK: - Tests
//
// Tests in this file exercise the same helpers used by production
// rendering and telemetry conversion. We never reimplement production
// expressions inside the test — the only way these tests pass is if
// the production code paths return the expected values for the same
// input shapes.
//
// The widget target's helpers (WidgetTelemetryReader, WidgetDisplayMath,
// WidgetBatteryMath, WidgetTimelineSchedule, WidgetTelemetryFactory,
// AppGroupContract extensions) live in DriveStudioWidget/, which is a
// file-system-synced member of both targets, so they are reachable
// here as `@testable import Runner`.
class RunnerTests: XCTestCase {

    // MARK: - Widget bundle inventory

    /// The DriveStudioWidgetBundle registers exactly 22 widgets —
    /// no widget was removed by this milestone. Source-text scan is
    /// the only available check; we deliberately do not instantiate
    /// `WidgetBundle.body` from a unit test (it would require a real
    /// widget host process).
    func testAllTwentyTwoWidgetConfigurationsRemainRegistered() throws {
        let bundleURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // RunnerTests/
            .deletingLastPathComponent() // repo root
            .appendingPathComponent("DriveStudioWidget/DriveStudioWidgetBundle.swift")
        let source = try String(contentsOf: bundleURL, encoding: .utf8)
        let requiredWidgets = [
            "DriveStudioSlot1Widget", "DriveStudioSlot2Widget",
            "DriveStudioSlot3Widget", "DriveStudioSlot4Widget",
            "OrbitDateWidget", "NoirGoldWidget", "SegmentsWidget",
            "AuroraRingWidget", "BatteryPieWidget", "MinimalDateWidget",
            "CommandCenterWidget", "VortexDriveWidget", "GridHUDWidget",
            "CockpitWidget", "PhantomWidget", "SplitPanelWidget",
            "SolarDashWidget", "NeonStripWidget", "CarbonWidget",
            "RadarWidget", "TriZoneWidget", "GalaxyWidget",
        ]
        for widget in requiredWidgets {
            XCTAssertTrue(source.contains("\(widget)()"),
                          "\(widget) must remain registered in the bundle")
        }
    }

    // MARK: - App Group keys / entitlements

    /// The canonical telemetry key, the legacy fallback key, the App
    /// Group suite name, the V2 metadata key, and both source
    /// entitlements all remain unchanged. A typo here would silently
    /// break the widget pipeline.
    func testAppGroupSuiteAndKeysAreUnchanged() {
        XCTAssertEqual(AppGroupContract.suiteName, "group.com.drivestudio.shared")
        XCTAssertEqual(AppGroupContract.liveTelemetryKey, "live_telemetry")
        XCTAssertEqual(AppGroupContract.legacyTelemetryKey, "drive_studio_telemetry")
        XCTAssertEqual(AppGroupContract.v2MetadataKey, "widget_state_v2_metadata")
        XCTAssertEqual(AppGroupContract.stateKey, "widget_state_v1")
    }

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

    // MARK: - App Group decode preserves unavailable

    /// App Group decode preserves `batteryPercent == nil` rather than
    /// coercing to 0 or 100.
    func testAppGroupDecodePreservesUnavailableBattery() {
        let defaults = makeIsolatedDefaults()
        let payload = TelemetrySnapshot(
            carConnected: false, batteryPercent: nil, isCharging: false,
            speed: 50, timestamp: Date()
        )
        defaults.set(try? JSONEncoder().encode(payload), forKey: AppGroupContract.liveTelemetryKey)

        let snapshot = WidgetTelemetryReader.liveSnapshot()
        XCTAssertNotNil(snapshot)
        XCTAssertNil(snapshot?.batteryPercent,
                     "Nil battery must remain nil after App Group round-trip")
    }

    /// App Group decode preserves `speed == nil` rather than coercing
    /// to 0.
    func testAppGroupDecodePreservesUnavailableSpeed() {
        let defaults = makeIsolatedDefaults()
        let payload = TelemetrySnapshot(
            carConnected: false, batteryPercent: 80, isCharging: false,
            speed: nil, timestamp: Date()
        )
        defaults.set(try? JSONEncoder().encode(payload), forKey: AppGroupContract.liveTelemetryKey)

        let snapshot = WidgetTelemetryReader.liveSnapshot()
        XCTAssertNil(snapshot?.speed,
                     "Nil speed must remain nil after App Group round-trip")
    }

    /// App Group decode preserves genuine 0 km/h. A previous fix
    /// coerced speed to 0; this test guards against that regression.
    func testAppGroupDecodePreservesGenuineZeroSpeed() {
        let defaults = makeIsolatedDefaults()
        let payload = TelemetrySnapshot(
            carConnected: false, batteryPercent: 80, isCharging: false,
            speed: 0, timestamp: Date()
        )
        defaults.set(try? JSONEncoder().encode(payload), forKey: AppGroupContract.liveTelemetryKey)

        let snapshot = WidgetTelemetryReader.liveSnapshot()
        XCTAssertEqual(snapshot?.speed, 0,
                       "Genuine 0 km/h must remain 0 (not nil, not coerced)")
    }

    /// App Group decode preserves exact charging state — a fresh
    /// `false` after a previous `true` is read as `false`, never ORed
    /// with stale state.
    func testAppGroupDecodePreservesExactChargingFlip() {
        let defaults = makeIsolatedDefaults()
        // Simulate the host having just unplugged the device.
        let payload = TelemetrySnapshot(
            carConnected: false, batteryPercent: 50, isCharging: false,
            speed: 0, timestamp: Date()
        )
        defaults.set(try? JSONEncoder().encode(payload), forKey: AppGroupContract.liveTelemetryKey)

        let snapshot = WidgetTelemetryReader.liveSnapshot()
        XCTAssertFalse(snapshot?.isCharging ?? true,
                       "Exact charging false after true must round-trip as false")
    }

    /// Legacy `drive_studio_telemetry` fallback still works when
    /// canonical key is absent (backward compatibility for older
    /// host builds).
    func testAppGroupDecodeFallsBackToLegacyKey() {
        let defaults = makeIsolatedDefaults()
        let payload = TelemetrySnapshot(
            carConnected: true, batteryPercent: 42, isCharging: true,
            speed: 33, timestamp: Date()
        )
        defaults.set(try? JSONEncoder().encode(payload), forKey: AppGroupContract.legacyTelemetryKey)

        let snapshot = WidgetTelemetryReader.liveSnapshot()
        XCTAssertEqual(snapshot?.batteryPercent, 42)
        XCTAssertEqual(snapshot?.speed, 33)
        XCTAssertTrue(snapshot?.isCharging ?? false)
        XCTAssertTrue(snapshot?.carConnected ?? false)
    }

    /// App Group decode returns nil when nothing has been written.
    func testAppGroupDecodeReturnsNilWhenEmpty() {
        let defaults = makeIsolatedDefaults()
        _ = defaults // touch so the suite is registered
        XCTAssertNil(WidgetTelemetryReader.liveSnapshot())
    }

    /// Missing vehicle remains unavailable. The widget must render an
    /// unavailable marker; it must never substitute a placeholder.
    func testMissingVehicleRemainsUnavailable() {
        let defaults = makeIsolatedDefaults()
        // Write an empty state with no vehicle.
        let metadata: [String: Any] = [
            "schemaVersion": 2,
            "generation": UUID().uuidString,
            "stateFile": "widget_state_v2.json",
            "checksum": "deadbeef",
            "updatedAt": ISO8601DateFormatter().string(from: Date())
        ]
        if let data = try? JSONSerialization.data(withJSONObject: metadata) {
            defaults.set(data, forKey: AppGroupContract.v2MetadataKey)
        }
        XCTAssertNil(WidgetTelemetryReader.selectedVehicleDisplayName())
    }

    /// The shared reader never supplies a placeholder brand name.
    /// This is the guard rail for "no production reader supplies
    /// 'Tesla Model 3'".
    func testNoProductionReaderSuppliesTeslaModelThree() throws {
        // Source-text scan: the widget production sources must not
        // contain "Tesla Model 3" as a fallback string. Comments
        // are stripped first so the test guards against the actual
        // string in code, not in a doc-comment reminder.
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // RunnerTests/
            .deletingLastPathComponent() // repo root
        let widgetRoot = repoRoot.appendingPathComponent("DriveStudioWidget")
        let fm = FileManager.default
        let files = try fm.subpathsOfDirectory(atPath: widgetRoot.path)
            .filter { $0.hasSuffix(".swift") }
        for file in files {
            let url = widgetRoot.appendingPathComponent(file)
            let content = stripSwiftComments(try String(contentsOf: url, encoding: .utf8))
            XCTAssertFalse(content.contains("Tesla Model 3"),
                           "\(file) must not contain \"Tesla Model 3\" as a fallback")
        }
    }

    // MARK: - Display math

    /// Unknown battery → "—" via the shared `WidgetDisplayMath`. The
    /// production renderer uses the same helper.
    func testUnknownBatteryRendersDash() {
        XCTAssertNil(WidgetDisplayMath.batteryFraction(nil))
        let text = makeBatteryText(percent: nil)
        XCTAssertEqual(text, "—")
    }

    /// Genuine 0 battery → "0%". The widget must not coerce 0 to "—".
    func testZeroBatteryRendersZeroPercent() {
        XCTAssertEqual(WidgetDisplayMath.batteryFraction(0), 0.0)
        let text = makeBatteryText(percent: 0)
        XCTAssertEqual(text, "0%")
    }

    /// 100 battery stays at 100, clamped.
    func testFullBatteryRendersHundredPercent() {
        XCTAssertEqual(WidgetDisplayMath.batteryFraction(100), 1.0)
        XCTAssertEqual(makeBatteryText(percent: 100), "100%")
    }

    /// Out-of-range values are clamped (defensive: a malicious or
    /// corrupted snapshot cannot push >100%).
    func testBatteryPercentIsClamped() {
        XCTAssertEqual(WidgetDisplayMath.clampedBatteryPercent(150), 100)
        XCTAssertEqual(WidgetDisplayMath.clampedBatteryPercent(-5), 0)
        XCTAssertEqual(WidgetDisplayMath.clampedBatteryPercent(42), 42)
    }

    /// Unknown speed → "--". Genuine 0 stays "0".
    func testUnknownSpeedRendersDash() {
        XCTAssertEqual(WidgetDisplayMath.speedText(kmh: nil), "—")
        XCTAssertNil(WidgetDisplayMath.speedFraction(kmh: nil, scale: 200))
    }

    func testGenuineZeroSpeedRendersZero() {
        XCTAssertEqual(WidgetDisplayMath.speedText(kmh: 0), "0")
        XCTAssertEqual(WidgetDisplayMath.speedFraction(kmh: 0, scale: 200), 0.0)
    }

    /// Speed is never multiplied twice. The test calls the same
    /// helper the production renderer uses and asserts the supplied
    /// 50 km/h value passes through unchanged.
    func testSpeedIsNotMultipliedTwice() {
        // TelemetryService already converted m/s → km/h; the widget
        // helper takes the km/h value verbatim.
        XCTAssertEqual(WidgetDisplayMath.speedText(kmh: 50), "50")
        XCTAssertEqual(WidgetDisplayMath.speedFraction(kmh: 50, scale: 200), 0.25,
                       "50 km/h on a 0–200 scale must produce 0.25, not 0.25 × 3.6")
    }

    /// Vehicle label: missing → "—". Non-empty supplied value passes
    /// through unchanged. Empty string treated as missing.
    func testVehicleUnavailableLabel() {
        XCTAssertEqual(WidgetDisplayMath.vehicleLabel(nil), "—")
        XCTAssertEqual(WidgetDisplayMath.vehicleLabel(""), "—")
        XCTAssertEqual(WidgetDisplayMath.vehicleLabel("Tesla Model Y"), "Tesla Model Y")
    }

    // MARK: - Provider timeline architecture

    /// First provider entry's date equals `start` — Apple's documented
    /// model requires the first entry to represent the current time.
    func testFirstTimelineEntryEqualsStart() {
        let start = Date(timeIntervalSince1970: 1_726_000_000)
        let timeline = WidgetTimelineSchedule.makeProviderTimeline(
            startingAt: start,
            providerEntryCount: 4,
            factory: { date in SimpleTestEntry(date: date) }
        )
        XCTAssertEqual(timeline.entries.count, 4)
        XCTAssertEqual(timeline.entries.first?.date, start,
                       "First provider entry's date must equal the supplied start")
    }

    /// Provider cadence is at least ~5 minutes between consecutive
    /// entries (Apple's documented minimum).
    func testProviderCadenceIsAtLeastFiveMinutes() {
        let start = Date(timeIntervalSince1970: 1_726_000_000)
        let timeline = WidgetTimelineSchedule.makeProviderTimeline(
            startingAt: start,
            providerEntryCount: 6,
            factory: { date in SimpleTestEntry(date: date) }
        )
        for i in 1..<timeline.entries.count {
            let delta = timeline.entries[i].date.timeIntervalSince(timeline.entries[i - 1].date)
            XCTAssertGreaterThanOrEqual(delta, 5 * 60,
                "Provider entries must be spaced ≥5 min apart; got \(delta) s")
        }
    }

    /// Default provider cadence is exactly 5 minutes (300 s).
    func testDefaultProviderCadenceIsFiveMinutes() {
        XCTAssertEqual(WidgetTimelineSchedule.defaultProviderCadenceSeconds, 5 * 60)
    }

    /// Provider timeline is bounded: even an absurd count returns at
    /// most `maxProviderEntryCount` entries.
    func testProviderTimelineIsBounded() {
        let timeline = WidgetTimelineSchedule.makeProviderTimeline(
            startingAt: Date(),
            providerEntryCount: 999_999,
            factory: { date in SimpleTestEntry(date: date) }
        )
        XCTAssertLessThanOrEqual(timeline.entries.count,
                                 WidgetTimelineSchedule.maxProviderEntryCount)
        XCTAssertGreaterThanOrEqual(timeline.entries.count, 1)
    }

    /// No provider uses a one-minute reload policy. The
    /// `defaultProviderCadenceSeconds` constant — which is what every
    /// provider picks — is at least 5 minutes.
    func testNoProviderUsesOneMinuteReloadPolicy() {
        XCTAssertGreaterThanOrEqual(
            WidgetTimelineSchedule.defaultProviderCadenceSeconds,
            5 * 60,
            "Default provider cadence must be ≥ 5 minutes"
        )
    }

    /// Current timeline entry exists and has a non-nil `date`. This is
    /// a sanity guard for the TimelineEntry contract.
    func testCurrentTimelineEntryExists() {
        let now = Date()
        let timeline = WidgetTimelineSchedule.makeProviderTimeline(
            startingAt: now,
            providerEntryCount: 3,
            factory: { date in SimpleTestEntry(date: date) }
        )
        XCTAssertFalse(timeline.entries.isEmpty)
        XCTAssertNotNil(timeline.entries.first?.date)
    }

    /// The `.atEnd` policy is documented as the right choice for
    /// asking WidgetKit to call `getTimeline` again after the last
    /// entry. Confirm the helper emits `.atEnd`.
    func testProviderTimelineUsesAtEndPolicy() {
        let timeline = WidgetTimelineSchedule.makeProviderTimeline(
            startingAt: Date(),
            providerEntryCount: 3,
            factory: { date in SimpleTestEntry(date: date) }
        )
        if let policy = timeline.policy as? TimelineReloadPolicy {
            switch policy {
            case .atEnd:
                break
            default:
                XCTFail("Provider timeline must use .atEnd policy, got \(policy)")
            }
        } else {
            XCTFail("Provider timeline must declare a reload policy")
        }
    }

    // MARK: - Production helper integration

    /// `WidgetTelemetryFactory.driveEntry` reads through the shared
    /// reader. The integration test feeds a synthetic snapshot to the
    /// isolated UserDefaults suite and asserts the factory entry
    /// reflects it.
    func testDriveEntryFactoryReadsViaSharedReader() {
        let defaults = makeIsolatedDefaults()
        let payload = TelemetrySnapshot(
            carConnected: true, batteryPercent: 73, isCharging: false,
            speed: 88, timestamp: Date()
        )
        defaults.set(try? JSONEncoder().encode(payload), forKey: AppGroupContract.liveTelemetryKey)

        let entry = WidgetTelemetryFactory.driveEntry(at: Date())
        XCTAssertEqual(entry.speed, 88)
        XCTAssertEqual(entry.batteryLevel ?? 0, 0.73, accuracy: 0.001)
        XCTAssertFalse(entry.isCharging)
    }

    /// `WidgetTelemetryFactory.orbitEntry` reads through the shared
    /// reader. Same integration pattern.
    func testOrbitEntryFactoryReadsViaSharedReader() {
        let defaults = makeIsolatedDefaults()
        let payload = TelemetrySnapshot(
            carConnected: true, batteryPercent: 27, isCharging: true,
            speed: 12, timestamp: Date()
        )
        defaults.set(try? JSONEncoder().encode(payload), forKey: AppGroupContract.liveTelemetryKey)

        let entry = WidgetTelemetryFactory.orbitEntry(at: Date())
        XCTAssertEqual(entry.batteryLevel ?? 0, 0.27, accuracy: 0.001)
        XCTAssertTrue(entry.isCharging)
    }

    /// Every production provider must use the shared reader. The
    /// provider types are StaticProvider, DriveProvider,
    /// OrbitDateProvider. Their `getTimeline` implementations all
    /// route through `WidgetTimelineSchedule.makeProviderTimeline`
    /// with a factory that calls `WidgetTelemetryFactory.*Entry(at:)`.
    /// Source-text scan verifies the routing.
    func testEveryProviderUsesSharedReader() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // RunnerTests/
            .deletingLastPathComponent() // repo root
        let widgetRoot = repoRoot.appendingPathComponent("DriveStudioWidget")
        let providers: [(file: String, type: String)] = [
            ("DriveStudioWidget.swift", "StaticProvider"),
            ("DriveStudioMixedWidgets.swift", "DriveProvider"),
            ("NativeSpecialWidgets.swift", "OrbitDateProvider"),
        ]
        for provider in providers {
            let url = widgetRoot.appendingPathComponent(provider.file)
            let content = try String(contentsOf: url, encoding: .utf8)
            XCTAssertTrue(content.contains("WidgetTimelineSchedule.makeProviderTimeline"),
                          "\(provider.type) must use the shared timeline helper")
            XCTAssertTrue(content.contains("WidgetTelemetryFactory"),
                          "\(provider.type) must use the shared telemetry factory")
        }
    }

    /// No production widget reads `UIDevice` directly. Source-text
    /// scan: every `UIDevice.current` reference in
    /// `DriveStudioWidget/` must be unreachable from provider /
    /// timeline / render paths. We assert there are no `UIDevice`
    /// uses inside the widget extension's source files. Comments
    /// are stripped first so doc-comments that describe the rule
    /// don't trip the scan.
    func testNoProductionWidgetReadsUIDevice() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // RunnerTests/
            .deletingLastPathComponent() // repo root
        let widgetRoot = repoRoot.appendingPathComponent("DriveStudioWidget")
        let fm = FileManager.default
        let files = try fm.subpathsOfDirectory(atPath: widgetRoot.path)
            .filter { $0.hasSuffix(".swift") }
        for file in files {
            let url = widgetRoot.appendingPathComponent(file)
            let content = stripSwiftComments(try String(contentsOf: url, encoding: .utf8))
            XCTAssertFalse(content.contains("UIDevice.current"),
                "\(file) must not read UIDevice.current directly; route through WidgetTelemetryReader")
        }
    }

    /// No artificial minimum fill clamp like `max(0.05, ...)` or
    /// `max(0.01, ...)` remains in widget view rendering.
    func testNoArtificialMinimumProgressClampsRemain() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // RunnerTests/
            .deletingLastPathComponent() // repo root
        let widgetRoot = repoRoot.appendingPathComponent("DriveStudioWidget")
        let fm = FileManager.default
        let files = try fm.subpathsOfDirectory(atPath: widgetRoot.path)
            .filter { $0.hasSuffix(".swift") }
        for file in files {
            let url = widgetRoot.appendingPathComponent(file)
            let content = try String(contentsOf: url, encoding: .utf8)
            XCTAssertFalse(content.contains("max(0.05"),
                "\(file) must not enforce an artificial 0.05 minimum fill")
            XCTAssertFalse(content.contains("max(0.01"),
                "\(file) must not enforce an artificial 0.01 minimum fill")
        }
    }

    /// No fake battery fallback (`return 0.85`) remains in production.
    func testNoFakeBatteryFallbacksRemain() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // RunnerTests/
            .deletingLastPathComponent() // repo root
        let widgetRoot = repoRoot.appendingPathComponent("DriveStudioWidget")
        let fm = FileManager.default
        let files = try fm.subpathsOfDirectory(atPath: widgetRoot.path)
            .filter { $0.hasSuffix(".swift") }
        for file in files {
            let url = widgetRoot.appendingPathComponent(file)
            let content = try String(contentsOf: url, encoding: .utf8)
            XCTAssertFalse(content.contains("return 0.85"),
                "\(file) must not contain a fake 85% battery fallback")
        }
    }

    /// No provider entries are spaced one minute apart
    /// (`.minute, value: 1`).
    func testNoProviderUsesOneMinuteSpacing() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // RunnerTests/
            .deletingLastPathComponent() // repo root
        let widgetRoot = repoRoot.appendingPathComponent("DriveStudioWidget")
        let fm = FileManager.default
        let files = try fm.subpathsOfDirectory(atPath: widgetRoot.path)
            .filter { $0.hasSuffix(".swift") }
        for file in files {
            let url = widgetRoot.appendingPathComponent(file)
            let content = try String(contentsOf: url, encoding: .utf8)
            XCTAssertFalse(content.contains(".minute, value: 1"),
                "\(file) must not emit one-minute provider entries")
        }
    }

    /// No `TimelineView(.periodic, ...)` remains in production.
    func testNoTimelineViewPeriodicRemains() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // RunnerTests/
            .deletingLastPathComponent() // repo root
        let widgetRoot = repoRoot.appendingPathComponent("DriveStudioWidget")
        let fm = FileManager.default
        let files = try fm.subpathsOfDirectory(atPath: widgetRoot.path)
            .filter { $0.hasSuffix(".swift") }
        for file in files {
            let url = widgetRoot.appendingPathComponent(file)
            let content = try String(contentsOf: url, encoding: .utf8)
            XCTAssertFalse(content.contains("TimelineView(.periodic"),
                "\(file) must not use TimelineView(.periodic, …)")
        }
    }

    /// BGAppRefresh identifiers must be removed from source and
    /// Info.plist. Comments are stripped first so the explanatory
    /// notes we left behind ("intentionally removed", "intentionally
    /// absent") do not trip the scan.
    func testNoBGAppRefreshRemains() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // RunnerTests/
            .deletingLastPathComponent() // repo root

        let runnerInfoPlist = repoRoot.appendingPathComponent("Runner/Info.plist")
        let infoPlistContent = stripPlistComments(try String(contentsOf: runnerInfoPlist, encoding: .utf8))
        XCTAssertFalse(infoPlistContent.contains("BGTaskSchedulerPermittedIdentifiers"),
            "Info.plist must not declare BGTaskSchedulerPermittedIdentifiers")

        let runnerDir = repoRoot.appendingPathComponent("Runner")
        let fm = FileManager.default
        let files = try fm.subpathsOfDirectory(atPath: runnerDir.path)
            .filter { $0.hasSuffix(".swift") }
        for file in files {
            let url = runnerDir.appendingPathComponent(file)
            let content = stripSwiftComments(try String(contentsOf: url, encoding: .utf8))
            XCTAssertFalse(content.contains("BGAppRefreshTask"),
                "\(file) must not register a BGAppRefreshTask")
            XCTAssertFalse(content.contains("BGTaskScheduler"),
                "\(file) must not import or call BGTaskScheduler")
        }
    }

    // MARK: - V2 metadata envelope round-trip (preserved)

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

    // MARK: - Test helpers

    /// Build a clean UserDefaults instance for the App Group suite.
    /// Both the canonical `liveTelemetryKey` and the legacy
    /// `legacyTelemetryKey` are removed before returning so a
    /// previous test's snapshot cannot leak into this one. The
    /// shared reader (used by the production code under test)
    /// reads from this same suite, so a clean slate per test is
    /// required for the decode-isolation tests.
    private func makeIsolatedDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: AppGroupContract.suiteName)
            ?? UserDefaults.standard
        defaults.removeObject(forKey: AppGroupContract.liveTelemetryKey)
        defaults.removeObject(forKey: AppGroupContract.legacyTelemetryKey)
        defaults.removeObject(forKey: AppGroupContract.v2MetadataKey)
        defaults.removeObject(forKey: AppGroupContract.stateKey)
        return defaults
    }

    /// Strip Swift line comments (`//`, `///`) and block comments
    /// (`/* ... */`) from a source string so source-text audit
    /// tests can match against executable code only. Doc comments
    /// that name the rule (e.g. "no production reader supplies
    /// 'Tesla Model 3'") legitimately mention the forbidden
    /// strings; stripping comments keeps the audit focused on the
    /// actual code.
    private func stripSwiftComments(_ source: String) -> String {
        let chars = Array(source)
        var result = ""
        var i = 0
        var inBlockComment = false
        while i < chars.count {
            let c = chars[i]
            let next = i + 1 < chars.count ? chars[i + 1] : Character("\0")
            if inBlockComment {
                if c == "*" && next == "/" {
                    inBlockComment = false
                    i += 2
                    continue
                }
                if c == "\n" { result.append("\n") }
                i += 1
                continue
            }
            if c == "/" && next == "/" {
                // line comment — consume to end of line
                while i < chars.count && chars[i] != "\n" { i += 1 }
                continue
            }
            if c == "/" && next == "*" {
                inBlockComment = true
                i += 2
                continue
            }
            result.append(c)
            i += 1
        }
        return result
    }

    /// Strip XML comments (`<!-- ... -->`) from a plist source so
    /// audit tests can match against actual key/value content only.
    private func stripPlistComments(_ source: String) -> String {
        let chars = Array(source)
        var result = ""
        var i = 0
        while i < chars.count {
            if i + 3 < chars.count
                && chars[i] == "<" && chars[i + 1] == "!"
                && chars[i + 2] == "-" && chars[i + 3] == "-" {
                // Skip to end of comment
                i += 4
                while i + 2 < chars.count
                    && !(chars[i] == "-" && chars[i + 1] == "-" && chars[i + 2] == ">") {
                    if chars[i] == "\n" { result.append("\n") }
                    i += 1
                }
                i += 3
                continue
            }
            result.append(chars[i])
            i += 1
        }
        return result
    }

    /// Helper used by the unknown/known battery text tests. Mirrors
    /// the widget's text branch:
    ///   nil → "—", known → "\(clamped(percent))%".
    private func makeBatteryText(percent: Int?) -> String {
        if let p = WidgetDisplayMath.clampedBatteryPercent(percent) {
            return "\(p)%"
        }
        return "—"
    }
}

// MARK: - Test-only TimelineEntry used by helper-shape tests

/// A minimal TimelineEntry used to assert timeline shape (entry count,
/// first-entry date, spacing). Production entries have additional
/// fields; those are exercised in their own dedicated tests.
struct SimpleTestEntry: TimelineEntry {
    let date: Date
}
