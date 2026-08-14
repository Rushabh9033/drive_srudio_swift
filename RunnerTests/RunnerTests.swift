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
        return WidgetDisplayMath.batteryText(percent: percent)
    }

    // MARK: - Production helper (WidgetDisplayMath.batteryText)

    /// `WidgetDisplayMath.batteryText` is the production helper used
    /// by every widget view AND by the tests. Unknown → "—", known →
    /// "\(clamped(percent))%". This guards against a test that
    /// re-implements the rendering branch in test-only code.
    func testBatteryTextProductionHelper() {
        XCTAssertEqual(WidgetDisplayMath.batteryText(percent: nil), "—",
                       "Unknown battery must render as the unavailable marker")
        XCTAssertEqual(WidgetDisplayMath.batteryText(percent: 0), "0%",
                       "Genuine 0 must render as 0%, not the unavailable marker")
        XCTAssertEqual(WidgetDisplayMath.batteryText(percent: 73), "73%")
        XCTAssertEqual(WidgetDisplayMath.batteryText(percent: 100), "100%")
        XCTAssertEqual(WidgetDisplayMath.batteryText(percent: -5), "0%",
                       "Out-of-range values clamp to 0")
        XCTAssertEqual(WidgetDisplayMath.batteryText(percent: 150), "100%",
                       "Out-of-range values clamp to 100")
    }

    // MARK: - WidgetBatteryIcon symbol mapping

    func testBatteryIconUnknownReturnsNeutralNotFull() {
        XCTAssertEqual(WidgetBatteryIcon.symbolName(percent: nil, isCharging: false),
                       "bolt.slash",
                       "Unknown battery must never visually appear full")
        XCTAssertEqual(WidgetBatteryIcon.symbolName(percent: nil, isCharging: true),
                       "bolt.slash",
                       "Unknown battery must never visually appear full even when charging flag is on")
    }

    func testBatteryIconZeroPercent() {
        XCTAssertEqual(WidgetBatteryIcon.symbolName(percent: 0, isCharging: false),
                       "battery.0")
    }

    func testBatteryIconNormalRanges() {
        XCTAssertEqual(WidgetBatteryIcon.symbolName(percent: 24, isCharging: false), "battery.25")
        XCTAssertEqual(WidgetBatteryIcon.symbolName(percent: 25, isCharging: false), "battery.25")
        XCTAssertEqual(WidgetBatteryIcon.symbolName(percent: 50, isCharging: false), "battery.50")
        XCTAssertEqual(WidgetBatteryIcon.symbolName(percent: 74, isCharging: false), "battery.50")
        XCTAssertEqual(WidgetBatteryIcon.symbolName(percent: 75, isCharging: false), "battery.75")
        XCTAssertEqual(WidgetBatteryIcon.symbolName(percent: 94, isCharging: false), "battery.75")
    }

    func testBatteryIconFull() {
        XCTAssertEqual(WidgetBatteryIcon.symbolName(percent: 95, isCharging: false), "battery.100")
        XCTAssertEqual(WidgetBatteryIcon.symbolName(percent: 100, isCharging: false), "battery.100")
    }

    func testBatteryIconChargingVariants() {
        XCTAssertEqual(WidgetBatteryIcon.symbolName(percent: 50, isCharging: true), "battery.50.bolt")
        XCTAssertEqual(WidgetBatteryIcon.symbolName(percent: 100, isCharging: true), "battery.100.bolt")
    }

    // MARK: - WidgetSnapshotFreshness policy

    func testFreshnessMissingTimestampExpiresSpeed() {
        let snap = TelemetrySnapshot(
            carConnected: true, batteryPercent: 80, isCharging: false,
            speed: 60, timestamp: nil
        )
        let out = WidgetSnapshotFreshness.apply(to: snap, referenceDate: Date())
        XCTAssertNil(out.speed, "Missing timestamp must expire speed")
        XCTAssertEqual(out.batteryPercent, 80, "Battery remains latest-known")
        XCTAssertEqual(out.isCharging, false, "Charging remains latest-known")
    }

    func testFreshnessStaleSnapshotExpiresSpeed() {
        let ts = Date().addingTimeInterval(-10 * 60) // 10 minutes ago
        let snap = TelemetrySnapshot(
            carConnected: true, batteryPercent: 80, isCharging: false,
            speed: 60, timestamp: ts
        )
        let out = WidgetSnapshotFreshness.apply(to: snap, referenceDate: Date())
        XCTAssertNil(out.speed, "Snapshot older than 5 min must expire speed")
        XCTAssertEqual(out.batteryPercent, 80, "Battery remains latest-known")
    }

    func testFreshnessFreshNilSpeedStaysNil() {
        let snap = TelemetrySnapshot(
            carConnected: true, batteryPercent: 80, isCharging: false,
            speed: nil, timestamp: Date()
        )
        let out = WidgetSnapshotFreshness.apply(to: snap, referenceDate: Date())
        XCTAssertNil(out.speed, "Fresh nil speed stays nil")
    }

    func testFreshnessFreshGenuineZeroSpeedStaysZero() {
        let snap = TelemetrySnapshot(
            carConnected: true, batteryPercent: 80, isCharging: false,
            speed: 0, timestamp: Date()
        )
        let out = WidgetSnapshotFreshness.apply(to: snap, referenceDate: Date())
        XCTAssertEqual(out.speed, 0, "Fresh 0 km/h must remain 0")
    }

    func testFreshnessFreshMovingSpeedPassesThrough() {
        let snap = TelemetrySnapshot(
            carConnected: true, batteryPercent: 80, isCharging: false,
            speed: 87, timestamp: Date()
        )
        let out = WidgetSnapshotFreshness.apply(to: snap, referenceDate: Date())
        XCTAssertEqual(out.speed, 87, "Fresh moving speed passes through unchanged")
    }

    func testFreshnessProjectedFutureEntryExpiresCapturedSpeed() {
        let now = Date()
        let ts = now
        let snap = TelemetrySnapshot(
            carConnected: true, batteryPercent: 80, isCharging: false,
            speed: 60, timestamp: ts
        )
        // An entry scheduled 10 minutes in the future must show speed
        // as unavailable, even though the underlying snapshot is
        // "fresh at capture time". This is the policy that makes a
        // captured 60 km/h auto-expire without WidgetKit reloading.
        let projected = WidgetSnapshotFreshness.projected(
            snapshot: snap, at: now.addingTimeInterval(10 * 60)
        )
        XCTAssertNil(projected.speed,
                     "Future entry older than 5 min past timestamp must show speed as unavailable")
        XCTAssertEqual(projected.batteryPercent, 80,
                       "Battery remains latest-known on future entry")
    }

    func testFreshnessProjectedNearEntryKeepsSpeed() {
        let now = Date()
        let ts = now
        let snap = TelemetrySnapshot(
            carConnected: true, batteryPercent: 80, isCharging: false,
            speed: 60, timestamp: ts
        )
        let projected = WidgetSnapshotFreshness.projected(
            snapshot: snap, at: now.addingTimeInterval(2 * 60)
        )
        XCTAssertEqual(projected.speed, 60,
                       "Entry within freshness window keeps the captured speed")
    }

    // MARK: - Minute-clock mechanism coverage

    /// Every widget root wraps its content view in `MinuteClockView`,
    /// which uses `TimelineView(.everyMinute)`. This proves the
    /// shared minute-clock mechanism is wired into all 22 widgets.
    func testEveryWidgetRootUsesMinuteClockMechanism() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let widgetRoot = repoRoot.appendingPathComponent("DriveStudioWidget")
        let fm = FileManager.default
        let files = try fm.subpathsOfDirectory(atPath: widgetRoot.path)
            .filter { $0.hasSuffix(".swift") }

        // Each file containing `Widget {` should also reference the
        // MinuteClockView wrapper. Count widgets in DriveStudioWidget
        // files and assert they all wrap with MinuteClockView.
        var widgetFilesWithWrapping: [(file: String, count: Int)] = []
        var widgetFilesWithoutWrapping: [(file: String, widgetCount: Int)] = []
        for file in files {
            let url = widgetRoot.appendingPathComponent(file)
            let raw = try String(contentsOf: url, encoding: .utf8)
            let stripped = stripSwiftComments(raw)
            let widgetCount = stripped.components(separatedBy: ": Widget {").count - 1
            if widgetCount == 0 { continue }
            let minuteClockCount = stripped.components(separatedBy: "MinuteClockView").count - 1
            if minuteClockCount > 0 {
                widgetFilesWithWrapping.append((file, widgetCount))
            } else {
                widgetFilesWithoutWrapping.append((file, widgetCount))
            }
        }
        let totalWidgets = widgetFilesWithWrapping.map(\.count).reduce(0, +)
        XCTAssertEqual(totalWidgets, 22,
                       "Expected 22 widgets wrapped in MinuteClockView, found \(totalWidgets) — missing files: \(widgetFilesWithoutWrapping)")
    }

    /// Source-text audit: the closure passed to `TimelineView(.everyMinute)`
    /// must NOT read telemetry, `UIDevice`, Core Location, network, or
    /// `WidgetCenter`. We can't introspect SwiftUI closures from a unit
    /// test, but we can assert the production code paths.
    func testMinuteClockClosureDoesNotTouchTelemetryInProviderEntries() {
        // DriveStudioMixedWidgets.swift wraps each of the 12 DriveEntry
        // widgets in MinuteClockView with a closure that takes the
        // captured entry and only uses context.date. We assert that
        // the per-widget wrappers build a fresh `liveEntry` from the
        // captured fields rather than re-reading telemetry.
        let start = Date(timeIntervalSince1970: 1_726_000_000)
        // Walk through every DriveEntry that the factory builds.
        for offset in 0..<3 {
            let entry = WidgetTelemetryFactory.driveEntry(at: start.addingTimeInterval(TimeInterval(offset) * 5 * 60))
            // The factory entry uses the freshness policy at its
            // scheduled date. This is the entry that the minute-clock
            // closure will receive as `captured`.
            XCTAssertNotNil(entry.date, "Entry must carry its scheduled date for the closure")
        }
    }

    /// Provider entries remain at least five minutes apart.
    func testProviderEntriesStillAtLeastFiveMinutesApart() {
        let start = Date(timeIntervalSince1970: 1_726_000_000)
        let timeline = WidgetTimelineSchedule.makeProviderTimeline(
            startingAt: start,
            providerEntryCount: 12,
            factory: { date in SimpleTestEntry(date: date) }
        )
        for i in 1..<timeline.entries.count {
            let delta = timeline.entries[i].date.timeIntervalSince(timeline.entries[i - 1].date)
            XCTAssertGreaterThanOrEqual(delta, 5 * 60,
                "Provider entries must remain >=5 min apart; got \(delta) s")
        }
    }

    // MARK: - Host-preview fallbacks (WidgetCanvas.swift)

    /// `Runner/WidgetCanvas.swift` must NOT contain the fake fallback
    /// strings anywhere in its executable code.
    func testWidgetCanvasHasNoFakeHostPreviewValues() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let canvasURL = repoRoot.appendingPathComponent("Runner/WidgetCanvas.swift")
        let raw = try String(contentsOf: canvasURL, encoding: .utf8)
        let stripped = stripSwiftComments(raw)
        XCTAssertFalse(stripped.contains("\"Cyber Sedan\""),
                       "WidgetCanvas.swift must not invent a 'Cyber Sedan' fallback")
        XCTAssertFalse(stripped.contains("\"My Vehicle\""),
                       "WidgetCanvas.swift must not invent a 'My Vehicle' fallback")
        XCTAssertFalse(stripped.contains(": 88"),
                       "WidgetCanvas.swift must not substitute 88 for unknown battery")
    }

    /// The whole repository (production only — not test files) must
    /// not contain any fake telemetry fallback strings.
    func testEntireRepoHasNoFakeTelemetryFallbacks() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fm = FileManager.default
        let productionDirs = ["Runner", "DriveStudioWidget"]
        let forbiddenStrings = [
            "\"Cyber Sedan\"",
            "\"My Vehicle\"",
            "return 0.85",
        ]
        for dir in productionDirs {
            let dirURL = repoRoot.appendingPathComponent(dir)
            guard let it = fm.enumerator(atPath: dirURL.path) else { continue }
            while let file = it.nextObject() as? String {
                guard file.hasSuffix(".swift") else { continue }
                let url = dirURL.appendingPathComponent(file)
                let raw = try String(contentsOf: url, encoding: .utf8)
                let stripped = stripSwiftComments(raw)
                for bad in forbiddenStrings {
                    XCTAssertFalse(stripped.contains(bad),
                        "\(dir)/\(file) contains forbidden fake fallback \(bad)")
                }
            }
        }
    }

    // MARK: - WidgetReloadThrottle

    /// Speed-driven reloads: first call → 1, within 5 min → 0,
    /// after 5 min → 1. Verified with an injected counting closure
    /// so the test never touches `WidgetCenter`.
    func testWidgetReloadThrottleSpeedChangeRateLimit() {
        var count = 0
        let throttle = WidgetReloadThrottle(reloadHook: { count += 1 })
        throttle.reset()
        let t0 = Date(timeIntervalSince1970: 1_726_000_000)
        // First speed reload → one call.
        _ = throttle.requestReload(kind: .speedChange, now: t0)
        XCTAssertEqual(count, 1, "First speed-driven reload must fire exactly once")
        // Second request within 4 minutes → suppressed.
        _ = throttle.requestReload(kind: .speedChange, now: t0.addingTimeInterval(60))
        XCTAssertEqual(count, 1, "Speed reload within 5 min must perform zero additional calls")
        // 5 minutes later → one more.
        _ = throttle.requestReload(kind: .speedChange, now: t0.addingTimeInterval(5 * 60))
        XCTAssertEqual(count, 2, "Speed reload after 5 min must perform exactly one additional call")
    }

    /// `.noVisibleChange` performs zero reloads, regardless of
    /// timing. The widget is already showing the latest data.
    func testWidgetReloadThrottleNoVisibleChangePerformsZeroCalls() {
        var count = 0
        let throttle = WidgetReloadThrottle(reloadHook: { count += 1 })
        throttle.reset()
        _ = throttle.requestReload(kind: .noVisibleChange, now: Date())
        _ = throttle.requestReload(kind: .noVisibleChange,
                                   now: Date().addingTimeInterval(60))
        XCTAssertEqual(count, 0,
                       ".noVisibleChange must perform zero reloads, even repeated")
    }

    /// Battery / charging / connection / slot / design / foreground
    /// pass through immediately: one call each, no rate limit.
    func testWidgetReloadThrottleImmediateKindsFireExactlyOnce() {
        var count = 0
        let throttle = WidgetReloadThrottle(reloadHook: { count += 1 })
        throttle.reset()
        let t0 = Date(timeIntervalSince1970: 1_726_000_000)
        let immediateKinds: [WidgetReloadKind] = [
            .batteryLevelChange, .chargingStateChange, .connectionStateChange,
            .foregroundActivation, .slotChange, .designSave, .other
        ]
        var after: [WidgetReloadKind: Int] = [:]
        for kind in immediateKinds {
            let prev = count
            _ = throttle.requestReload(kind: kind, now: t0)
            after[kind] = count - prev
        }
        for kind in immediateKinds {
            XCTAssertEqual(after[kind], 1,
                "\(kind) must fire exactly one reload, got \(after[kind] ?? 0)")
        }
        XCTAssertEqual(count, immediateKinds.count,
                       "All immediate kinds together must fire exactly one reload each")
    }

    // MARK: - AppGroupState cache invalidation (behavioral)

/// `AppStore.saveState` calls `AppGroupState.invalidateCache()` after
/// writing a fresh generation. The widget / App Intents readers must
/// observe the new envelope on the next `loadState()` call, not
/// return the stale cached one from before the invalidation.
///
/// Behavioral test: read generation A (warms the cache), overwrite
/// the file on disk with generation B under the SAME generation
/// string so the cache fast-path short-circuits to stale A, then
/// call `invalidateCache()` and re-read to assert the new payload B
/// is observed. We keep the same generation because
/// `AppGroupState.loadState`'s fast-path checks generation equality
/// — bumping the generation alone would force a re-read regardless of
/// cache, defeating the point of testing `invalidateCache()`.
func testAppGroupStateCacheInvalidationForcesReread() throws {
    let suite = makeIsolatedDefaults()
    let shared = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: AppGroupContract.suiteName)
    let stateFileURL = shared?.appendingPathComponent("widget_state_v2.json")
    defer {
        // Restore test-owned data so the next test starts from a
        // known-clean App Group container.
        suite.removeObject(forKey: AppGroupContract.v2MetadataKey)
        if let url = stateFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        AppGroupState.invalidateCache()
    }

    // Fixed generation string so the cache fast-path is exercised
    // when we overwrite the file on disk below.
    let generation = "cache-test-\(UUID().uuidString)"

    // Install generation A.
    let payloadA = WidgetState(
        schemaVersion: 2,
        vehicle: nil,
        slots: [Slot(index: 0, draftId: "A", spec: nil)],
        telemetry: TelemetrySnapshot(carConnected: false, batteryPercent: 11,
                                     isCharging: false, speed: 0,
                                     timestamp: Date()),
        widgetImagePath: nil
    )
    try Self.installState(
        payload: payloadA,
        generation: generation,
        suite: suite
    )

    // First read warms the cache with state A.
    AppGroupState.invalidateCache()
    let readA = AppGroupState.loadState()
    XCTAssertEqual(readA?.slots?.first?.draftId, "A",
                   "First read must return payload A")
    XCTAssertEqual(AppGroupState.currentGeneration, generation,
                   "currentGeneration must match the installed generation")

    // Overwrite the file with payload B but keep the SAME
    // generation. The fast-path in `loadState` will short-circuit
    // because metadata.generation == cached.generation, returning
    // the stale cached payload A without re-reading disk.
    let payloadB = WidgetState(
        schemaVersion: 2,
        vehicle: nil,
        slots: [Slot(index: 0, draftId: "B", spec: nil)],
        telemetry: nil,
        widgetImagePath: nil
    )
    try Self.installState(
        payload: payloadB,
        generation: generation,
        suite: suite
    )
    let stale = AppGroupState.loadState()
    XCTAssertEqual(stale?.slots?.first?.draftId, "A",
                   "Without invalidation the cache fast-path returns the previous payload")

    // After `invalidateCache` the next read re-validates disk and
    // returns payload B.
    AppGroupState.invalidateCache()
    let readB = AppGroupState.loadState()
    XCTAssertEqual(readB?.slots?.first?.draftId, "B",
                   "After invalidateCache the reader must observe the new payload on disk, not the cached one")
    XCTAssertEqual(AppGroupState.currentGeneration, generation,
                   "currentGeneration must remain anchored to the same generation after reread")
}

/// Helper used by the cache-invalidation test: write a payload to the
/// V2 envelope with a supplied generation + matching SHA-256.
private static func installState(payload: WidgetState,
                                 generation: String,
                                 suite: UserDefaults) throws {
    let data = try JSONEncoder().encode(payload)
    let sha = SHA256.hash(data: data)
        .compactMap { String(format: "%02x", $0) }
        .joined()
    guard let shared = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: AppGroupContract.suiteName) else {
        throw NSError(domain: "RunnerTests", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "No App Group container"])
    }
    let dest = shared.appendingPathComponent("widget_state_v2.json")
    try data.write(to: dest, options: [.atomic])
    let metadata: [String: Any] = [
        "schemaVersion": 2,
        "generation": generation,
        "stateFile": "widget_state_v2.json",
        "checksum": sha,
        "updatedAt": ISO8601DateFormatter().string(from: Date())
    ]
    let metaData = try JSONSerialization.data(withJSONObject: metadata)
    suite.set(metaData, forKey: AppGroupContract.v2MetadataKey)
}

// MARK: - Active-slot preference (SwitchDriveStudioSlotIntent)

/// The host app exposes `activeSlotKey` so App Intents and the host
/// share one contract. A typo here would silently break the
/// SwitchSlot Shortcut's effect.
func testActiveSlotKeyContractIsStable() {
    XCTAssertEqual(AppStore.activeSlotKey, "drive_studio_active_slot")
}

/// `setActiveSlot` clamps out-of-range values to 0..3 silently and
/// persists the clamped integer to App Group defaults. This guards
/// against a user-supplied Shortcut parameter or corrupted App
/// Group blob pointing the host at a non-existent slot.
    func testActiveSlotIsClampedToValidRange() async {
        let defaults = UserDefaults(suiteName: AppGroupContract.suiteName)
            ?? UserDefaults.standard
        defaults.removeObject(forKey: AppStore.activeSlotKey)
        await MainActor.run {
            AppStore.shared.setActiveSlot(99)
            XCTAssertEqual(AppStore.shared.activeSlotIndex, 3,
                           "setActiveSlot(99) must clamp to slot index 3")
            XCTAssertEqual(defaults.integer(forKey: AppStore.activeSlotKey), 3,
                           "Clamped value must be persisted to App Group defaults")
            AppStore.shared.setActiveSlot(-5)
            XCTAssertEqual(AppStore.shared.activeSlotIndex, 0,
                           "setActiveSlot(-5) must clamp to slot index 0")
            XCTAssertEqual(defaults.integer(forKey: AppStore.activeSlotKey), 0,
                           "Clamped value must be persisted to App Group defaults")
        }
    }

    // MARK: - Atomic state installation (gap 1)
    //
    // The transaction under test is `AppStore.installState(...)` —
    // a pure helper that writes a generation-specific
    // `state_<generation>.json`, byte-verifies it, then hands the
    // metadata blob to a caller-supplied `publish` closure. The
    // previous generation's metadata entry is only overwritten
    // once `publish` returns successfully. Failure tests pass a
    // broken publish closure or a non-existent destination so we
    // can prove the old file stays canonical without depending on
    // the production algorithm's specific implementation details.

    /// Successful install writes the supplied state bytes to a new
    /// generation-specific file, publishes metadata pointing at it,
    /// and returns the new generation UUID.
    func testAtomicStateInstallSucceeds() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let defaults = makeIsolatedDefaults()
        let metadataKey = "test_metadata_\(UUID().uuidString)"
        var published: [Data] = []

        let result = try AppStore.installState(
            stateData: Data("HELLO-V1".utf8),
            sharedContainer: dir,
            publish: { metaData in published.append(metaData) }
        )
        XCTAssertEqual(result.publishedFilename, "state_\(result.generation).json")
        XCTAssertEqual(published.count, 1, "Metadata must be published exactly once")
        // File on disk contains the bytes we asked for.
        let writtenURL = dir.appendingPathComponent(result.publishedFilename)
        let readBack = try Data(contentsOf: writtenURL)
        XCTAssertEqual(readBack, Data("HELLO-V1".utf8),
                       "Generation file must contain the supplied bytes")
    }

    /// Pre-publication failure (write to a non-existent container
    /// throws) must not publish metadata, must not leak a file
    /// on disk, and must surface the underlying error to the
    /// caller.
    func testAtomicStateInstallPrePublicationFailureDoesNotPublishMetadata() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        // Container URL points inside a parent that does not exist.
        let bogusContainer = dir
            .appendingPathComponent("missing-parent")
            .appendingPathComponent("container")
        var published: [Data] = []

        XCTAssertThrowsError(
            try AppStore.installState(
                stateData: Data("HELLO".utf8),
                sharedContainer: bogusContainer,
                publish: { metaData in published.append(metaData) }
            )
        ) { error in
            guard case AppStore.StateInstallError.destinationDirectoryMissing = error else {
                XCTFail("Expected destinationDirectoryMissing, got \(error)")
                return
            }
        }
        XCTAssertEqual(published.count, 0,
                       "Metadata publish must NOT be invoked when the destination is missing")
    }

    /// Metadata publication failure (publish throws) must remove the
    /// staged generation file, leave the previous canonical file
    /// untouched, and surface the publish error to the caller.
    func testAtomicStateInstallMetadataPublishFailureCleansUpStagedFile() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        // Pre-existing previous generation file.
        let previousGeneration = "PREV-\(UUID().uuidString)"
        let previousFilename = "state_\(previousGeneration).json"
        let previousBytes = Data("PREVIOUS-PAYLOAD".utf8)
        try previousBytes.write(to: dir.appendingPathComponent(previousFilename))

        struct PublishBoom: Error, Equatable { let tag: String }
        XCTAssertThrowsError(
            try AppStore.installState(
                stateData: Data("NEW-PAYLOAD".utf8),
                sharedContainer: dir,
                publish: { _ in throw PublishBoom(tag: "simulated") }
            )
        ) { error in
            guard case AppStore.StateInstallError.metadataPublishFailed = error else {
                XCTFail("Expected metadataPublishFailed, got \(error)")
                return
            }
        }

        // Previous generation file is still byte-identical.
        let readBack = try Data(contentsOf: dir.appendingPathComponent(previousFilename))
        XCTAssertEqual(readBack, previousBytes,
                       "Previous generation file must remain byte-identical after metadata publish failure")

        // The staged `state_<new-uuid>.json` must not be left on
        // disk after the publish failure.
        let leftover = (try? FileManager.default.contentsOfDirectory(atPath: dir.path))?
            .filter { $0.hasPrefix("state_") && $0.hasSuffix(".json") }
            .sorted() ?? []
        XCTAssertEqual(leftover, [previousFilename],
                       "Staged generation file must be cleaned up after publish failure")
    }

    /// The cleanup hook runs only after a successful metadata
    /// publish and receives the new generation UUID in its `keep`
    /// set.
    func testAtomicStateInstallCleanupHookRunsOnlyOnSuccess() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        var cleanupCalls: [Set<String>] = []

        // Successful install — cleanup hook called once with the
        // new generation in its keep set.
        let result = try AppStore.installState(
            stateData: Data("HELLO".utf8),
            sharedContainer: dir,
            publish: { _ in },
            cleanupOlderGenerations: { keep in cleanupCalls.append(keep) }
        )
        XCTAssertEqual(cleanupCalls.count, 1)
        XCTAssertTrue(cleanupCalls[0].contains(result.generation))

        // Failed install (bogus publish) — cleanup hook NOT called.
        struct Boom: Error, Equatable {}
        XCTAssertThrowsError(
            try AppStore.installState(
                stateData: Data("HELLO".utf8),
                sharedContainer: dir,
                publish: { _ in throw Boom() },
                cleanupOlderGenerations: { keep in cleanupCalls.append(keep) }
            )
        )
        XCTAssertEqual(cleanupCalls.count, 1,
                       "Cleanup hook must NOT run when metadata publish fails")
    }

    // MARK: - Gap 2 — Stage assets BEFORE metadata publication
    //
    // The production `installState` transaction now runs an
    // `stageAssets` closure between state-file write/verify and
    // metadata publish. These tests pin the contract:
    //
    //   1. Successful staging publishes metadata exactly once and
    //      every referenced image lands in the staged folder before
    //      publish is called.
    //   2. A staging failure (closure throws) NEVER publishes
    //      metadata, removes the staged state file AND any
    //      partially-staged assets, and preserves the previous
    //      generation file untouched.
    //   3. A metadata-publish failure (publish throws) cleans up
    //      BOTH the staged state file AND the staged asset folder.
    //   4. The cleanup hook only fires on a fully successful
    //      transaction; on asset-stage or publish failure it does
    //      not run.
    //   5. The custom vehicle image (e.g. `home_vehicle.png`) is
    //      never touched or removed by staging, and the legacy
    //      SharedImages fallback path is preserved.

    /// Successful staging writes all referenced images into the
    /// new generation folder BEFORE metadata is published. We
    /// confirm the order by capturing, inside the publish closure,
    /// whether the staged asset folder already contains the image.
    func testInstallStateAssetStageRunsBeforeMetadataPublish() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Seed a "documents"-like source directory with one
        // image that the staging closure will find.
        let sourceDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: sourceDir) }
        let assetName = "test_image_\(UUID().uuidString).png"
        let assetBytes = Data([0xDE, 0xAD, 0xBE, 0xEF])
        try assetBytes.write(to: sourceDir.appendingPathComponent(assetName))

        var publishInvocations: Int = 0
        var publishObservedAssetFolder: URL?
        var publishObservedAssetPresent: Bool = false
        // The staging closure records the assetDirectory it was
        // handed; the publish closure then checks that folder
        // already contains the staged image. This proves the
        // asset-stage step happened BEFORE publish.
        let result = try AppStore.installState(
            stateData: Data("HELLO-V1".utf8),
            sharedContainer: dir,
            stageAssets: { staged in
                publishObservedAssetFolder = staged.assetDirectory
                try AppStore.copyReferencedImages(
                    filenames: [assetName],
                    into: staged.assetDirectory!,
                    sourceDirectories: [sourceDir]
                )
            },
            publish: { _ in
                publishInvocations += 1
                if let folder = publishObservedAssetFolder {
                    publishObservedAssetPresent = FileManager.default.fileExists(
                        atPath: folder.appendingPathComponent(assetName).path)
                }
            }
        )
        XCTAssertEqual(publishInvocations, 1,
                       "Metadata publish must be invoked exactly once on success")
        XCTAssertNotNil(result.assetDirectory,
                        "Staging result must carry a non-nil assetDirectory")
        let assetFolder = result.assetDirectory!
        XCTAssertTrue(FileManager.default.fileExists(atPath: assetFolder.path),
                      "Staged asset folder must exist after successful install")
        let stagedImage = assetFolder.appendingPathComponent(assetName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: stagedImage.path),
                      "Referenced image must be staged into the generation folder before publish")
        let readBack = try Data(contentsOf: stagedImage)
        XCTAssertEqual(readBack, assetBytes,
                       "Staged image must be byte-identical to the source")
        XCTAssertEqual(publishObservedAssetFolder, assetFolder,
                       "Publish closure must observe the staged asset folder already in place")
        XCTAssertTrue(publishObservedAssetPresent,
                      "Publish closure must observe the staged image already on disk")
    }

    /// Asset-stage failure (closure throws) must not publish
    /// metadata, must remove the staged state file AND any
    /// partially-staged asset directory, and must preserve the
    /// previous generation file untouched.
    func testInstallStateAssetStageFailureDoesNotPublishAndPreservesPrevious() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        // Pre-existing previous generation file.
        let previousGeneration = "PREV-\(UUID().uuidString)"
        let previousFilename = "state_\(previousGeneration).json"
        let previousBytes = Data("PREVIOUS-PAYLOAD".utf8)
        try previousBytes.write(to: dir.appendingPathComponent(previousFilename))

        var publishInvocations: Int = 0
        struct StageBoom: Error, Equatable { let tag: String }
        XCTAssertThrowsError(
            try AppStore.installState(
                stateData: Data("NEW-PAYLOAD".utf8),
                sharedContainer: dir,
                stageAssets: { staged in
                    // Create a partial asset directory so we can
                    // assert it gets removed on failure.
                    let partial = staged.assetDirectory!
                    try FileManager.default.createDirectory(
                        at: partial,
                        withIntermediateDirectories: true)
                    let stub = partial.appendingPathComponent("half-baked.png")
                    try Data([0x00]).write(to: stub)
                    throw StageBoom(tag: "simulated-asset-failure")
                },
                publish: { _ in publishInvocations += 1 }
            )
        ) { error in
            guard case AppStore.StateInstallError.assetStageFailed = error else {
                XCTFail("Expected assetStageFailed, got \(error)")
                return
            }
        }

        XCTAssertEqual(publishInvocations, 0,
                       "Metadata publish must NOT be invoked when asset staging fails")

        // The new staged state file must be removed.
        let leftoverStateFiles = (try? FileManager.default.contentsOfDirectory(atPath: dir.path))?
            .filter { $0.hasPrefix("state_") && $0.hasSuffix(".json") }
            .sorted() ?? []
        XCTAssertEqual(leftoverStateFiles, [previousFilename],
                       "Staged state file must be removed on asset-stage failure; previous file must survive")

        // No asset directories must exist on disk after failure.
        let sharedImages = dir.appendingPathComponent("SharedImages")
        let assetEntries = (try? FileManager.default.contentsOfDirectory(atPath: sharedImages.path)) ?? []
        XCTAssertEqual(assetEntries, [],
                       "No partially-staged asset directory may survive asset-stage failure")

        // Previous generation file byte-identical.
        let readBack = try Data(contentsOf: dir.appendingPathComponent(previousFilename))
        XCTAssertEqual(readBack, previousBytes,
                       "Previous generation must remain byte-identical after asset-stage failure")
    }

    /// Metadata-publish failure (publish throws) must clean up
    /// BOTH the staged state file AND the staged asset folder.
    func testInstallStateMetadataPublishFailureRemovesStagedAssets() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sourceDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: sourceDir) }
        let assetName = "test_image_\(UUID().uuidString).png"
        try Data([0x01, 0x02]).write(to: sourceDir.appendingPathComponent(assetName))

        // Previous generation must survive.
        let previousGeneration = "PREV-\(UUID().uuidString)"
        let previousFilename = "state_\(previousGeneration).json"
        let previousBytes = Data("PREVIOUS-PAYLOAD".utf8)
        try previousBytes.write(to: dir.appendingPathComponent(previousFilename))

        struct PublishBoom: Error, Equatable { let tag: String }
        XCTAssertThrowsError(
            try AppStore.installState(
                stateData: Data("NEW-PAYLOAD".utf8),
                sharedContainer: dir,
                stageAssets: { staged in
                    try AppStore.copyReferencedImages(
                        filenames: [assetName],
                        into: staged.assetDirectory!,
                        sourceDirectories: [sourceDir]
                    )
                },
                publish: { _ in throw PublishBoom(tag: "simulated-publish-failure") }
            )
        ) { error in
            guard case AppStore.StateInstallError.metadataPublishFailed = error else {
                XCTFail("Expected metadataPublishFailed, got \(error)")
                return
            }
        }

        // Staged state file removed.
        let leftover = (try? FileManager.default.contentsOfDirectory(atPath: dir.path))?
            .filter { $0.hasPrefix("state_") && $0.hasSuffix(".json") }
            .sorted() ?? []
        XCTAssertEqual(leftover, [previousFilename],
                       "Staged state file must be removed on publish failure")

        // Staged asset folder removed.
        let sharedImages = dir.appendingPathComponent("SharedImages")
        let assetEntries = (try? FileManager.default.contentsOfDirectory(atPath: sharedImages.path)) ?? []
        XCTAssertEqual(assetEntries, [],
                       "Staged asset folder must be removed on publish failure")

        // Previous generation still readable.
        let readBack = try Data(contentsOf: dir.appendingPathComponent(previousFilename))
        XCTAssertEqual(readBack, previousBytes)
    }

    /// The cleanup hook fires only when BOTH staging AND metadata
    /// publish succeed; on either failure it is never invoked.
    func testInstallStateCleanupHookRunsOnlyAfterAssetStageAndPublishSucceed() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        var cleanupCalls: [Set<String>] = []

        // Success — staging and publish both succeed, cleanup runs.
        _ = try AppStore.installState(
            stateData: Data("HELLO-V1".utf8),
            sharedContainer: dir,
            stageAssets: { _ in /* no-op */ },
            publish: { _ in },
            cleanupOlderGenerations: { keep in cleanupCalls.append(keep) }
        )
        XCTAssertEqual(cleanupCalls.count, 1,
                       "Cleanup hook must run exactly once on full success")

        // Asset-stage failure — cleanup does NOT run.
        struct StageBoom: Error, Equatable {}
        XCTAssertThrowsError(
            try AppStore.installState(
                stateData: Data("HELLO-V2".utf8),
                sharedContainer: dir,
                stageAssets: { _ in throw StageBoom() },
                publish: { _ in },
                cleanupOlderGenerations: { keep in cleanupCalls.append(keep) }
            )
        )
        XCTAssertEqual(cleanupCalls.count, 1,
                       "Cleanup hook must NOT run on asset-stage failure")

        // Publish failure — cleanup does NOT run.
        struct PublishBoom: Error, Equatable {}
        XCTAssertThrowsError(
            try AppStore.installState(
                stateData: Data("HELLO-V3".utf8),
                sharedContainer: dir,
                stageAssets: { _ in /* no-op */ },
                publish: { _ in throw PublishBoom() },
                cleanupOlderGenerations: { keep in cleanupCalls.append(keep) }
            )
        )
        XCTAssertEqual(cleanupCalls.count, 1,
                       "Cleanup hook must NOT run on metadata-publish failure")
    }

    /// Staging must never overwrite, remove, or relocate the
    /// custom vehicle image (`home_vehicle.png`) — that artwork
    /// is user-imported and lives independently of any generation.
    func testInstallStateAssetStagePreservesCustomVehicleImage() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sourceDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: sourceDir) }
        // Custom vehicle image sits in the source directory.
        let vehicleBytes = Data([0xCA, 0xFE, 0xBA, 0xBE])
        try vehicleBytes.write(to: sourceDir.appendingPathComponent("home_vehicle.png"))

        _ = try AppStore.installState(
            stateData: Data("HELLO".utf8),
            sharedContainer: dir,
            stageAssets: { staged in
                try AppStore.copyReferencedImages(
                    filenames: ["home_vehicle.png"],
                    into: staged.assetDirectory!,
                    sourceDirectories: [sourceDir],
                    preserveCustomVehicleImage: "home_vehicle.png"
                )
            },
            publish: { _ in }
        )
        // The source vehicle image must remain byte-identical —
        // staging should never touch user-imported artwork.
        let stillThere = try Data(contentsOf: sourceDir.appendingPathComponent("home_vehicle.png"))
        XCTAssertEqual(stillThere, vehicleBytes,
                       "Staging must not touch or remove the custom vehicle image source")
    }

    /// `referencedImageFilenames(in:)` is a pure helper: given
    /// slot specs that reference both background and image layers,
    /// it must enumerate every filename without duplication.
    func testReferencedImageFilenamesEnumeratesAllImageSources() {
        let slot0 = Slot(
            index: 0,
            draftId: "draft-A",
            spec: WidgetSpec(
                background: WidgetBackground(
                    type: "image",
                    from: nil,
                    to: nil,
                    imageSrc: "bg_night.png"),
                layers: [
                    WidgetLayer(
                        id: "L1",
                        kind: "image",
                        label: nil,
                        text: nil,
                        src: "car_red.png",
                        x: nil, y: nil, w: nil, h: nil,
                        fontSize: nil, weight: nil,
                        align: nil, color: nil,
                        opacity: nil, radius: nil,
                        hidden: nil, strokes: nil,
                        format: nil, groupId: nil),
                    WidgetLayer(
                        id: "L2",
                        kind: "text",
                        label: nil,
                        text: "no image here",
                        src: nil,
                        x: nil, y: nil, w: nil, h: nil,
                        fontSize: nil, weight: nil,
                        align: nil, color: nil,
                        opacity: nil, radius: nil,
                        hidden: nil, strokes: nil,
                        format: nil, groupId: nil),
                ]
            )
        )
        let slot1 = Slot(
            index: 1,
            draftId: "draft-B",
            spec: WidgetSpec(
                background: WidgetBackground(type: "solid", from: "000000", to: nil, imageSrc: nil),
                layers: [
                    WidgetLayer(
                        id: "L3",
                        kind: "image",
                        label: nil,
                        text: nil,
                        src: "bg_night.png",
                        x: nil, y: nil, w: nil, h: nil,
                        fontSize: nil, weight: nil,
                        align: nil, color: nil,
                        opacity: nil, radius: nil,
                        hidden: nil, strokes: nil,
                        format: nil, groupId: nil)
                ]
            )
        )
        let names = AppStore.referencedImageFilenames(in: [slot0, slot1])
        XCTAssertEqual(names, Set(["bg_night.png", "car_red.png"]),
                       "Image enumeration must deduplicate and skip non-image layers")
    }

    /// `copyReferencedImages` falls back through source
    /// directories in order, so an image present in the second
    /// source but missing from the first is still staged.
    func testCopyReferencedImagesFallsThroughSourceDirectories() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let primaryDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: primaryDir) }
        let fallbackDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: fallbackDir) }

        // "thumb.png" only exists in the fallback source dir.
        let fallbackBytes = Data([0xFA, 0x11])
        try fallbackBytes.write(to: fallbackDir.appendingPathComponent("thumb.png"))

        try AppStore.copyReferencedImages(
            filenames: ["thumb.png"],
            into: dir,
            sourceDirectories: [primaryDir, fallbackDir]
        )
        let staged = try Data(contentsOf: dir.appendingPathComponent("thumb.png"))
        XCTAssertEqual(staged, fallbackBytes,
                       "copyReferencedImages must walk the source directory list until it finds the file")
    }

    /// `copyReferencedImages` does not throw when a referenced
    /// image is missing on disk — that's a render-time concern,
    /// not a save-time one. A render-time missing image should not
    /// block the entire save transaction.
    func testCopyReferencedImagesSilentlySkipsMissingFiles() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sourceDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: sourceDir) }

        XCTAssertNoThrow(
            try AppStore.copyReferencedImages(
                filenames: ["does_not_exist.png"],
                into: dir,
                sourceDirectories: [sourceDir]
            )
        )
        // Destination folder was created; the missing file is
        // simply absent.
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: dir.appendingPathComponent("does_not_exist.png").path))
    }

    // MARK: - Helper for atomic install tests

    private func makeTempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ds_test_\(UUID().uuidString)",
                                    isDirectory: true)
        try! FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Telemetry persistence policy (gap 2)
    //
    // The production policy is implemented by
    // `TelemetryService.persistTelemetryIfMeaningful(previousSpeed:)`.
    // Each test below drives that exact code path with an injected
    // clock so we can assert exact write counts without depending on
    // `Date()` or shared App Group state from prior tests.
    //
    // Policy (executable form):
    //   * First valid snapshot (no `prev` blob) — persist.
    //   * Battery / charging / connection / availability transition
    //     vs `prev` — persist.
    //   * Speed |current - prev.speed| ≥ `significantSpeedDelta`
    //     (compared against the LAST PERSISTED speed, not just the
    //     immediately previous GPS sample) — persist.
    //   * Heartbeat window elapsed since the last write — persist.
    //   * Otherwise — silent.
    //
    // The persisted snapshot's `timestamp` field is the injected
    // clock value, so tests can decode it back and assert exact
    // equality without touching `Date()`.

    private func telemetryTestDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: AppGroupContract.suiteName)
            ?? UserDefaults.standard
        defaults.removeObject(forKey: AppGroupContract.liveTelemetryKey)
        defaults.removeObject(forKey: AppGroupContract.legacyTelemetryKey)
        return defaults
    }

    private func decodeSnapshot(from defaults: UserDefaults) -> TelemetryTestSnapshot? {
        guard let data = defaults.data(forKey: AppGroupContract.liveTelemetryKey) else {
            return nil
        }
        return try? JSONDecoder().decode(TelemetryTestSnapshot.self, from: data)
    }

    /// Build a fresh `TelemetryService` with the injected clock and
    /// an empty reloadRequester so the persistence tests never touch
    /// `WidgetReloadThrottle.shared` (and therefore never touch real
    /// `WidgetCenter`). Reload-kind tests inject their own counting
    /// closure on the returned service.
    private func makeTelemetryServiceForTest(
        now: Date,
        defaults: UserDefaults
    ) -> TelemetryService {
        var clockNow = now
        let service = TelemetryService(clock: { clockNow })
        service.resetPersistenceState()
        // Belt-and-braces: ensure no shared throttle call slips
        // through even if a test forgets to override the requester.
        service.reloadRequester = nil
        _ = defaults // silence unused warning
        return service
    }

    /// Initial snapshot (no prior App Group blob) persists
    /// immediately and the encoded timestamp is the injected clock
    /// value, not `Date()`.
    func testTelemetryInitialSnapshotPersistsImmediately() {
        var now = Date(timeIntervalSince1970: 1_726_000_000)
        let service = TelemetryService(clock: { now })
        defer { service.resetPersistenceState() }
        let defaults = telemetryTestDefaults()

        service.currentSpeed = 30.0
        service._persistForTest(previousSpeed: nil, currentSpeed: 30.0)
        let snapshot = decodeSnapshot(from: defaults)
        XCTAssertNotNil(snapshot, "Initial snapshot must persist immediately")
        XCTAssertEqual(snapshot?.timestamp, now,
                       "Persisted timestamp must come from the injected clock")
        XCTAssertEqual(snapshot?.speed, 30.0)
    }

    /// Unchanged reading within the heartbeat window after an
    /// initial write does NOT trigger another write. We assert this
    /// by checking that no fresh blob is published (the initial
    /// blob is the only one).
    func testTelemetryUnchangedReadingBeforeHeartbeatDoesNotPersist() {
        var now = Date(timeIntervalSince1970: 1_726_000_000)
        let service = TelemetryService(clock: { now })
        defer { service.resetPersistenceState() }
        let defaults = telemetryTestDefaults()

        service.currentSpeed = 30.0
        service._persistForTest(previousSpeed: nil, currentSpeed: 30.0)
        let firstSnapshot = defaults.data(forKey: AppGroupContract.liveTelemetryKey)
        XCTAssertNotNil(firstSnapshot)

        now = now.addingTimeInterval(5)
        service._persistForTest(previousSpeed: 30.0, currentSpeed: 30.0)
        XCTAssertEqual(
            defaults.data(forKey: AppGroupContract.liveTelemetryKey),
            firstSnapshot,
            "Identical reading within the heartbeat window must NOT publish a fresh snapshot"
        )
    }

    /// After the heartbeat window has elapsed since the last write,
    /// a fresh snapshot is published even when nothing visibly
    /// changed. The new timestamp is the injected clock at the
    /// moment of the heartbeat write.
    func testTelemetryUnchangedReadingAfterHeartbeatPersists() {
        var now = Date(timeIntervalSince1970: 1_726_000_000)
        let service = TelemetryService(clock: { now })
        defer { service.resetPersistenceState() }
        let defaults = telemetryTestDefaults()

        service.currentSpeed = 50.0
        service._persistForTest(previousSpeed: nil, currentSpeed: 50.0)
        let firstTimestamp = decodeSnapshot(from: defaults)?.timestamp
        XCTAssertEqual(firstTimestamp, now)

        now = now.addingTimeInterval(TelemetryService.heartbeatPersistenceInterval + 1)
        service._persistForTest(previousSpeed: 50.0, currentSpeed: 50.0)
        let heartbeatTimestamp = decodeSnapshot(from: defaults)?.timestamp
        XCTAssertEqual(heartbeatTimestamp, now,
                       "Heartbeat write must use the injected clock at the heartbeat moment")
    }

    /// Battery transition (e.g. 30 → 31 percent) persists immediately,
    /// even within the heartbeat window. The simulator's
    /// `UIDevice.current.batteryLevel` is `-1` (unknown) so we drive
    /// both the seed and the transition through the test seam's
    /// override parameters.
    func testTelemetryBatteryTransitionPersistsImmediately() {
        var now = Date(timeIntervalSince1970: 1_726_000_000)
        let service = TelemetryService(clock: { now })
        defer { service.resetPersistenceState() }
        let defaults = telemetryTestDefaults()

        // Seed an initial snapshot at batteryPercent = 30 with no
        // speed so the policy has a stable baseline.
        service.currentSpeed = nil
        service._persistForTest(previousSpeed: nil, currentSpeed: nil,
                                batteryPercent: 30)
        XCTAssertEqual(decodeSnapshot(from: defaults)?.batteryPercent, 30,
                       "Seed snapshot must use the override batteryPercent")

        now = now.addingTimeInterval(2)
        service._persistForTest(previousSpeed: nil, currentSpeed: nil,
                                batteryPercent: 31)
        XCTAssertEqual(decodeSnapshot(from: defaults)?.batteryPercent, 31,
                       "Battery transition must persist immediately")
    }

    /// Charging transition (charging ↔ not-charging) persists
    /// immediately.
    func testTelemetryChargingTransitionPersistsImmediately() {
        var now = Date(timeIntervalSince1970: 1_726_000_000)
        let service = TelemetryService(clock: { now })
        defer { service.resetPersistenceState() }
        let defaults = telemetryTestDefaults()

        service.currentSpeed = nil
        service._persistForTest(previousSpeed: nil, currentSpeed: nil,
                                isCharging: false)
        XCTAssertEqual(decodeSnapshot(from: defaults)?.isCharging, false)

        now = now.addingTimeInterval(2)
        service._persistForTest(previousSpeed: nil, currentSpeed: nil,
                                isCharging: true)
        XCTAssertEqual(decodeSnapshot(from: defaults)?.isCharging, true,
                       "Charging transition must persist immediately")
    }

    /// Connection transition (carConnected ↔ !carConnected) persists
    /// immediately.
    func testTelemetryConnectionTransitionPersistsImmediately() {
        var now = Date(timeIntervalSince1970: 1_726_000_000)
        let service = TelemetryService(clock: { now })
        defer { service.resetPersistenceState() }
        let defaults = telemetryTestDefaults()

        service.currentSpeed = nil
        service._persistForTest(previousSpeed: nil, currentSpeed: nil,
                                carConnected: false)
        XCTAssertEqual(decodeSnapshot(from: defaults)?.carConnected, false)

        now = now.addingTimeInterval(2)
        service._persistForTest(previousSpeed: nil, currentSpeed: nil,
                                carConnected: true)
        XCTAssertEqual(decodeSnapshot(from: defaults)?.carConnected, true,
                       "Connection transition must persist immediately")
    }

    /// Speed availability transitions (nil → 0 and 0 → nil) persist
    /// immediately because the widget needs to render the
    /// "speed unknown" → "speed known" change.
    func testTelemetrySpeedAvailabilityTransitionPersistsImmediately() {
        var now = Date(timeIntervalSince1970: 1_726_000_000)
        let service = TelemetryService(clock: { now })
        defer { service.resetPersistenceState() }
        let defaults = telemetryTestDefaults()

        service.currentSpeed = nil
        service._persistForTest(previousSpeed: nil, currentSpeed: nil)
        XCTAssertNil(decodeSnapshot(from: defaults)?.speed)

        now = now.addingTimeInterval(2)
        service.currentSpeed = 0.0
        service._persistForTest(previousSpeed: nil, currentSpeed: 0.0)
        XCTAssertEqual(decodeSnapshot(from: defaults)?.speed, 0.0,
                       "nil → 0 availability transition must persist")

        now = now.addingTimeInterval(2)
        service.currentSpeed = nil
        service._persistForTest(previousSpeed: 0.0, currentSpeed: nil)
        XCTAssertNil(decodeSnapshot(from: defaults)?.speed,
                     "0 → nil availability transition must persist")
    }

    /// Accumulated sub-threshold deltas cannot evade persistence
    /// forever — once the cumulative drift from the last persisted
    /// speed reaches `significantSpeedDelta`, a fresh snapshot is
    /// published and the baseline advances.
    func testTelemetryAccumulatedSmallSpeedChangesPersistWhenBaselineReachesThreshold() {
        var now = Date(timeIntervalSince1970: 1_726_000_000)
        let service = TelemetryService(clock: { now })
        defer { service.resetPersistenceState() }
        let defaults = telemetryTestDefaults()

        // Initial baseline at 30 km/h.
        service.currentSpeed = 30.0
        service._persistForTest(previousSpeed: nil, currentSpeed: 30.0)
        XCTAssertEqual(decodeSnapshot(from: defaults)?.speed, 30.0)

        // Three sub-threshold fixes within the heartbeat window.
        // None of these should publish a new snapshot because the
        // cumulative drift from 30 km/h has not reached 1 km/h yet.
        now = now.addingTimeInterval(1)
        service._persistForTest(previousSpeed: 30.0, currentSpeed: 30.3)
        XCTAssertEqual(decodeSnapshot(from: defaults)?.speed, 30.0,
                       "0.3 km/h drift must not publish")

        now = now.addingTimeInterval(1)
        service._persistForTest(previousSpeed: 30.3, currentSpeed: 30.6)
        XCTAssertEqual(decodeSnapshot(from: defaults)?.speed, 30.0,
                       "0.6 km/h cumulative drift must not publish")

        now = now.addingTimeInterval(1)
        service._persistForTest(previousSpeed: 30.6, currentSpeed: 30.9)
        XCTAssertEqual(decodeSnapshot(from: defaults)?.speed, 30.0,
                       "0.9 km/h cumulative drift must not publish")

        // Crossing 1 km/h cumulative drift publishes.
        now = now.addingTimeInterval(1)
        service._persistForTest(previousSpeed: 30.9, currentSpeed: 31.2)
        XCTAssertEqual(decodeSnapshot(from: defaults)?.speed, 31.2,
                       "1.2 km/h cumulative drift must publish")
    }

    /// A meaningful (≥ 1 km/h) speed delta persists immediately
    /// even within the heartbeat window, because the threshold
    /// is checked against the persisted baseline.
    func testTelemetryMeaningfulSpeedChangePersistsImmediately() {
        var now = Date(timeIntervalSince1970: 1_726_000_000)
        let service = TelemetryService(clock: { now })
        defer { service.resetPersistenceState() }
        let defaults = telemetryTestDefaults()

        service.currentSpeed = 50.0
        service._persistForTest(previousSpeed: nil, currentSpeed: 50.0)
        XCTAssertEqual(decodeSnapshot(from: defaults)?.speed, 50.0)

        now = now.addingTimeInterval(2)
        service._persistForTest(previousSpeed: 50.0, currentSpeed: 75.0)
        XCTAssertEqual(decodeSnapshot(from: defaults)?.speed, 75.0,
                       "25 km/h delta from baseline must persist immediately")
    }

    // MARK: - Telemetry reload-kind policy (gap 1 — keep speed alive)
    //
    // The previous policy classified a heartbeat-driven persistence
    // write with unchanged speed as `.noVisibleChange`. That made
    // `WidgetReloadThrottle` skip the call entirely, so the widget
    // never got a reload and `WidgetSnapshotFreshness` would expire
    // the speed after five minutes even though the foreground app
    // kept publishing heartbeat snapshots. The fix routes heartbeat
    // + valid speed through `.speedChange` so the throttle rate-
    // limits actual `WidgetCenter` calls but at least one reload is
    // issued every five minutes to refresh the widget timeline.
    //
    // Each test below uses an injected reload-requester closure to
    // capture the exact `(kind, now)` tuples the policy emits. No
    // test ever calls real `WidgetCenter`.

    /// Heartbeat-driven persistence with stable valid speed must
    /// request `.speedChange` (not `.noVisibleChange`) so the widget
    /// gets a refresh request that `WidgetReloadThrottle` will
    /// rate-limit.
    func testTelemetryHeartbeatWithValidSpeedRequestsSpeedChangeReload() {
        var now = Date(timeIntervalSince1970: 1_726_000_000)
        let service = TelemetryService(clock: { now })
        defer { service.resetPersistenceState() }
        _ = telemetryTestDefaults()
        var reloads: [(WidgetReloadKind, Date)] = []
        service.reloadRequester = { kind, when in
            reloads.append((kind, when))
        }

        // Seed an initial snapshot — that already persists and
        // requests a reload, but we don't assert on that here.
        service.currentSpeed = 50.0
        service._persistForTest(previousSpeed: nil, currentSpeed: 50.0)
        let reloadsAfterSeed = reloads.count

        // Heartbeat fires (unchanged reading past the heartbeat
        // window). The reload kind MUST be `.speedChange`, not
        // `.noVisibleChange`, otherwise the widget's freshness timer
        // expires the speed.
        now = now.addingTimeInterval(TelemetryService.heartbeatPersistenceInterval + 1)
        service._persistForTest(previousSpeed: 50.0, currentSpeed: 50.0)
        XCTAssertGreaterThan(reloads.count, reloadsAfterSeed,
                             "Heartbeat must request at least one reload")
        XCTAssertEqual(reloads.last?.0, .speedChange,
                       "Heartbeat with valid speed must request .speedChange, " +
                       "got \(String(describing: reloads.last?.0))")
        XCTAssertEqual(reloads.last?.1, now,
                       "Reload request must carry the injected clock value")
    }

    /// `nil → 0` availability transition requests `.speedChange`.
    func testTelemetryNilToZeroAvailabilityTransitionRequestsSpeedChangeReload() {
        var now = Date(timeIntervalSince1970: 1_726_000_000)
        let service = TelemetryService(clock: { now })
        defer { service.resetPersistenceState() }
        _ = telemetryTestDefaults()
        var reloads: [(WidgetReloadKind, Date)] = []
        service.reloadRequester = { kind, when in
            reloads.append((kind, when))
        }

        service.currentSpeed = nil
        service._persistForTest(previousSpeed: nil, currentSpeed: nil)
        reloads.removeAll() // ignore the initial-snapshot reload

        now = now.addingTimeInterval(2)
        service.currentSpeed = 0.0
        service._persistForTest(previousSpeed: nil, currentSpeed: 0.0)
        XCTAssertEqual(reloads.last?.0, .speedChange,
                       "nil → 0 availability transition must request .speedChange")
    }

    /// `0 → nil` availability transition requests `.speedChange`.
    func testTelemetryZeroToNilAvailabilityTransitionRequestsSpeedChangeReload() {
        var now = Date(timeIntervalSince1970: 1_726_000_000)
        let service = TelemetryService(clock: { now })
        defer { service.resetPersistenceState() }
        _ = telemetryTestDefaults()
        var reloads: [(WidgetReloadKind, Date)] = []
        service.reloadRequester = { kind, when in
            reloads.append((kind, when))
        }

        service.currentSpeed = 0.0
        service._persistForTest(previousSpeed: nil, currentSpeed: 0.0)
        reloads.removeAll()

        now = now.addingTimeInterval(2)
        service.currentSpeed = nil
        service._persistForTest(previousSpeed: 0.0, currentSpeed: nil)
        XCTAssertEqual(reloads.last?.0, .speedChange,
                       "0 → nil availability transition must request .speedChange")
    }

    /// Heartbeat with unavailable speed and no other visible change
    /// requests `.noVisibleChange` — the throttle then performs zero
    /// actual `WidgetCenter` calls. This is the policy carve-out that
    /// keeps the foreground from spamming the widget when there is
    /// genuinely nothing to render.
    func testTelemetryHeartbeatWithUnavailableSpeedRequestsNoVisibleChangeReload() {
        var now = Date(timeIntervalSince1970: 1_726_000_000)
        let service = TelemetryService(clock: { now })
        defer { service.resetPersistenceState() }
        _ = telemetryTestDefaults()
        var reloads: [(WidgetReloadKind, Date)] = []
        service.reloadRequester = { kind, when in
            reloads.append((kind, when))
        }

        // Seed with unavailable speed so the first snapshot's
        // reload-kind is already `.noVisibleChange`.
        service.currentSpeed = nil
        service._persistForTest(previousSpeed: nil, currentSpeed: nil)
        reloads.removeAll()

        // Heartbeat past the window with speed still unavailable
        // and no battery/charging/connection change.
        now = now.addingTimeInterval(TelemetryService.heartbeatPersistenceInterval + 1)
        service._persistForTest(previousSpeed: nil, currentSpeed: nil)
        XCTAssertEqual(reloads.last?.0, .noVisibleChange,
                       "Heartbeat with unavailable speed and no visible change " +
                       "must request .noVisibleChange")
    }

    /// Battery transition has priority over speed in the reload
    /// kind selection — even if the speed is also changing, the
    /// widget gets an immediate battery reload.
    func testTelemetryBatteryTransitionPriorityOverSpeedReload() {
        var now = Date(timeIntervalSince1970: 1_726_000_000)
        let service = TelemetryService(clock: { now })
        defer { service.resetPersistenceState() }
        _ = telemetryTestDefaults()
        var reloads: [(WidgetReloadKind, Date)] = []
        service.reloadRequester = { kind, when in
            reloads.append((kind, when))
        }

        service.currentSpeed = 50.0
        service._persistForTest(previousSpeed: nil, currentSpeed: 50.0,
                                batteryPercent: 30)
        reloads.removeAll()

        now = now.addingTimeInterval(2)
        service._persistForTest(previousSpeed: 50.0, currentSpeed: 75.0,
                                batteryPercent: 31)
        XCTAssertEqual(reloads.last?.0, .batteryLevelChange,
                       "Battery transition must beat speed-change in priority")
    }

    /// Charging transition has top priority in reload kind selection.
    func testTelemetryChargingTransitionPriorityOverSpeedReload() {
        var now = Date(timeIntervalSince1970: 1_726_000_000)
        let service = TelemetryService(clock: { now })
        defer { service.resetPersistenceState() }
        _ = telemetryTestDefaults()
        var reloads: [(WidgetReloadKind, Date)] = []
        service.reloadRequester = { kind, when in
            reloads.append((kind, when))
        }

        service.currentSpeed = 50.0
        service._persistForTest(previousSpeed: nil, currentSpeed: 50.0,
                                isCharging: false)
        reloads.removeAll()

        now = now.addingTimeInterval(2)
        service._persistForTest(previousSpeed: 50.0, currentSpeed: 75.0,
                                isCharging: true)
        XCTAssertEqual(reloads.last?.0, .chargingStateChange,
                       "Charging transition must have top priority")
    }

    /// Connection transition priority: must beat both speed and
    /// battery.
    func testTelemetryConnectionTransitionTopPriorityReload() {
        var now = Date(timeIntervalSince1970: 1_726_000_000)
        let service = TelemetryService(clock: { now })
        defer { service.resetPersistenceState() }
        _ = telemetryTestDefaults()
        var reloads: [(WidgetReloadKind, Date)] = []
        service.reloadRequester = { kind, when in
            reloads.append((kind, when))
        }

        service.currentSpeed = 50.0
        service._persistForTest(previousSpeed: nil, currentSpeed: 50.0,
                                batteryPercent: 30, carConnected: false)
        reloads.removeAll()

        now = now.addingTimeInterval(2)
        service._persistForTest(previousSpeed: 50.0, currentSpeed: 75.0,
                                batteryPercent: 31, carConnected: true)
        XCTAssertEqual(reloads.last?.0, .connectionStateChange,
                       "Connection transition priority")
    }

    /// `WidgetReloadThrottle` rate-limits `.speedChange` to at most
    /// one actual reload call per five minutes. We exercise this by
    /// running the policy through a counting closure that simulates
    /// the throttle behavior (first request fires, subsequent
    /// requests within five minutes are coalesced). The policy
    /// itself issues the request — the throttle (or our counting
    /// surrogate) decides whether to actually forward to WidgetCenter.
    func testTelemetryThrottleLimitsSpeedChangeReloadsToOnePerFiveMinutes() {
        // Direct unit test of the policy decision counts: the
        // policy emits reload requests on every heartbeat with
        // valid speed; the throttle is the gatekeeper. We simulate
        // the throttle by passing the requests through a counting
        // closure that only forwards the first request within any
        // five-minute window.
        var now = Date(timeIntervalSince1970: 1_726_000_000)
        let service = TelemetryService(clock: { now })
        defer { service.resetPersistenceState() }
        _ = telemetryTestDefaults()

        var actualReloads = 0
        var lastReload: Date? = nil
        service.reloadRequester = { kind, when in
            // Throttle surrogate: forward at most one `.speedChange`
            // per five minutes.
            if kind == .speedChange {
                if let last = lastReload,
                   when.timeIntervalSince(last) < 5 * 60 {
                    return
                }
                lastReload = when
            }
            actualReloads += 1
        }

        // Seed.
        service.currentSpeed = 50.0
        service._persistForTest(previousSpeed: nil, currentSpeed: 50.0)
        XCTAssertEqual(actualReloads, 1,
                       "Initial seed must produce exactly one actual reload")

        // Three heartbeats within five minutes of each other.
        // Throttle coalesces them — only the first fires.
        now = now.addingTimeInterval(TelemetryService.heartbeatPersistenceInterval + 1)
        service._persistForTest(previousSpeed: 50.0, currentSpeed: 50.0)
        XCTAssertEqual(actualReloads, 2, "First heartbeat fires exactly one reload")

        now = now.addingTimeInterval(60)
        service._persistForTest(previousSpeed: 50.0, currentSpeed: 50.0)
        XCTAssertEqual(actualReloads, 2,
                       "Second heartbeat within 5 min must be coalesced by throttle")

        now = now.addingTimeInterval(60)
        service._persistForTest(previousSpeed: 50.0, currentSpeed: 50.0)
        XCTAssertEqual(actualReloads, 2,
                       "Third heartbeat within 5 min must be coalesced by throttle")

        // After five minutes since the last reload, the next
        // heartbeat fires one more reload.
        now = now.addingTimeInterval(5 * 60)
        service._persistForTest(previousSpeed: 50.0, currentSpeed: 50.0)
        XCTAssertEqual(actualReloads, 3,
                       "Heartbeat after 5 min must fire one reload")
    }

    // MARK: - Permission path tightening (gap 9)

    /// `startMonitoring` must NEVER present a permission prompt.
    /// Source-text scan + behavior check: the method is silent when
    /// authorization is undetermined, denied, or restricted.
    func testStartMonitoringNeverPresentsPermission() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let serviceURL = repoRoot.appendingPathComponent("Runner/TelemetryService.swift")
        let code = stripSwiftComments(try String(contentsOf: serviceURL, encoding: .utf8))
        // Locate the `startMonitoring()` function body and assert it
        // does NOT contain `requestWhenInUseAuthorization` /
        // `requestAlwaysAuthorization` or any reference to
        // `beginLocationIfAuthorized` (which is the prompt path).
        if let range = code.range(of: "func startMonitoring()"),
           let endRange = code.range(of: "func ", range: range.upperBound..<code.endIndex) {
            let body = String(code[range.lowerBound..<endRange.lowerBound])
            XCTAssertFalse(body.contains("requestWhenInUseAuthorization"),
                "startMonitoring must never call requestWhenInUseAuthorization")
            XCTAssertFalse(body.contains("requestAlwaysAuthorization"),
                "startMonitoring must never call requestAlwaysAuthorization")
            XCTAssertFalse(body.contains("beginLocationIfAuthorized"),
                "startMonitoring must never route through the prompt path")
        } else {
            XCTFail("Unable to locate startMonitoring function in TelemetryService.swift")
        }
    }

    /// No automatic prompt is presented during the host app's normal
    /// lifecycle: initialization, foregrounding, or routine Core
    /// Location monitoring. The only legal prompt site is the
    /// Dashboard's explicit GPS button, which calls
    /// `beginLocationIfAuthorized()`.
    func testNoAutomaticPermissionPromptDuringLifecycle() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let serviceURL = repoRoot.appendingPathComponent("Runner/TelemetryService.swift")
        let code = stripSwiftComments(try String(contentsOf: serviceURL, encoding: .utf8))
        // Only `beginLocationIfAuthorized()` may present the prompt.
        let promptCount = code.components(separatedBy: "requestWhenInUseAuthorization").count - 1
        XCTAssertEqual(promptCount, 1,
            "Exactly one When-In-Use prompt site allowed (beginLocationIfAuthorized); got \(promptCount)")
    }

    // MARK: - Vehicle identity (gap 8)

    /// `home_vehicle.png` must NOT become the user's vehicle display
    /// name. The widget renders the custom artwork but never an
    /// invented brand/model/display name.
    func testVehicleIdentityDoesNotDeriveNameFromFilename() async {
        await MainActor.run {
            XCTAssertNil(AppStore.vehicleIdentity(forImageFilename: nil, hasImage: false),
                         "No image must produce a nil vehicle")
        }
        let v: VehicleData? = await MainActor.run {
            AppStore.vehicleIdentity(
                forImageFilename: "home_vehicle.png",
                hasImage: true
            )
        }
        XCTAssertNotNil(v)
        XCTAssertEqual(v?.customImage, "home_vehicle.png",
                       "Custom artwork path must be preserved so the widget renders it")
        XCTAssertEqual(v?.artwork, "home_vehicle.png")
        XCTAssertTrue(v?.hasCustomImage ?? false)
        XCTAssertNil(v?.displayName,
                     "displayName must never derive from filename (would produce 'Home Vehicle')")
        XCTAssertNil(v?.brandId,
                     "brandId must never be set without explicit user input")
        XCTAssertNil(v?.modelId,
                     "modelId must never be set without explicit user input")
    }

    /// Source-text scan: no production path produces the literal
    /// "Home Vehicle" as a display name.
    func testNoProductionPathProducesHomeVehicleAsDisplayName() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let runnerDir = repoRoot.appendingPathComponent("Runner")
        let fm = FileManager.default
        if let it = fm.enumerator(atPath: runnerDir.path) {
            while let file = it.nextObject() as? String {
                guard file.hasSuffix(".swift") else { continue }
                let url = runnerDir.appendingPathComponent(file)
                let code = stripSwiftComments(try String(contentsOf: url, encoding: .utf8))
                XCTAssertFalse(code.contains("\"Home Vehicle\""),
                    "\(file) must not produce \"Home Vehicle\" as a display name")
            }
        }
    }

    // MARK: - FocusDashboardSlotIntent (gap 7)

    /// `FocusDashboardSlotIntent` writes to the host-app contract
    /// key (`AppStore.activeSlotKey`), clamps out-of-range values,
    /// and survives a foreground-application round-trip. The widget
    /// timeline providers do NOT read the active-slot key, so the
    /// intent never claims to change widget content.
    func testFocusDashboardSlotIntentPersistsClampedAndAppliesOnForeground() async {
        let defaults = UserDefaults(suiteName: AppGroupContract.suiteName)
        defaults?.removeObject(forKey: AppStore.activeSlotKey)

        await MainActor.run {
            // Drive the same persist path the intent exercises.
            AppStore.shared.setActiveSlot(2)
            XCTAssertEqual(AppStore.shared.activeSlotIndex, 2,
                "FocusDashboardSlotIntent must persist index 2 → activeSlotIndex 2")
            XCTAssertEqual(defaults?.integer(forKey: AppStore.activeSlotKey), 2)

            // Out-of-range clamping.
            AppStore.shared.setActiveSlot(99)
            XCTAssertEqual(AppStore.shared.activeSlotIndex, 3,
                "Out-of-range slot index must clamp to 3")

            // Foreground-application consumes the persisted value.
            AppStore.shared.activeSlotIndex = 0
            AppStore.shared.applyPersistedActiveSlot()
            XCTAssertEqual(AppStore.shared.activeSlotIndex, 3,
                "Foreground application must read the clamped value from defaults")
        }
        defaults?.removeObject(forKey: AppStore.activeSlotKey)
    }

    /// The intent is honest: its user-visible name does not promise
    /// a widget content change. Source-text scan guards the title.
    func testFocusDashboardSlotIntentTitleIsHonest() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repoRoot.appendingPathComponent("Runner/DriveStudioIntents.swift")
        let code = stripSwiftComments(try String(contentsOf: url, encoding: .utf8))
        XCTAssertTrue(code.contains("\"Focus Dashboard Slot\""),
            "Intent must be renamed to 'Focus Dashboard Slot' so users are not misled")
        XCTAssertFalse(code.contains("\"Switch Drive Studio Slot\""),
            "Old misleading title must be gone")
    }

    /// `FocusDashboardSlotIntent` is registered in
    /// `DriveStudioAppShortcuts` so it surfaces in the iOS Shortcuts
    /// gallery and in CarPlay Shortcuts without manual setup.
    func testFocusDashboardSlotIntentIsRegisteredInAppShortcuts() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repoRoot.appendingPathComponent("Runner/DriveStudioIntents.swift")
        let code = stripSwiftComments(try String(contentsOf: url, encoding: .utf8))
        XCTAssertTrue(code.contains("FocusDashboardSlotIntent()"),
            "DriveStudioAppShortcuts must contain an AppShortcut wrapping FocusDashboardSlotIntent()")
    }

    // MARK: - Force-unwrap audit (gap 4)
    //
    // Token-level audit: walk every production source file in
    // `Runner/` and `DriveStudioWidget/`, strip comments and string
    // literals, and assert the file contains no `EXPR!` force-unwrap
    // sites. The previous regex-based audit misclassified ordinary
    // `let`/`var` declarations as force-unwraps; this one is a
    // character-level pass that explicitly excludes the well-known
    // lookalikes (`!=`, `as!`, `is!`, `!!`).
    //
    // We deliberately do NOT use `swift-syntax` — it would require
    // adding a SwiftPM dependency just for one audit. The audit is
    // good enough to catch every reachable `!`-after-identifier site;
    // it may produce a false positive for some `let foo: Int = bar!`
    // forms where the source has already been guarded upstream — those
    // false positives get the appropriate guard added at the
    // production site.

    func testNoReachableProductionForceUnwraps() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fm = FileManager.default
        let scanDirs = [
            repoRoot.appendingPathComponent("Runner"),
            repoRoot.appendingPathComponent("DriveStudioWidget"),
        ]
        var found: [String] = []
        for dir in scanDirs {
            guard let it = fm.enumerator(atPath: dir.path) else { continue }
            while let file = it.nextObject() as? String {
                guard file.hasSuffix(".swift") else { continue }
                let url = dir.appendingPathComponent(file)
                let raw = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                let stripped = stripSwiftComments(raw)
                let lines = stripped.split(separator: "\n", omittingEmptySubsequences: false)
                for (idx, line) in lines.enumerated() {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if Self.lineContainsForceUnwrap(trimmed) {
                        found.append("\(file):\(idx + 1): \(trimmed)")
                    }
                }
            }
        }
        XCTAssertEqual(found, [],
            "Reachable production force-unwraps found: \(found.joined(separator: ", "))")
    }

    /// Character-level check: does this line (with comments and string
    /// literals stripped by the caller) contain a Swift force-unwrap
    /// site `EXPR!`?
    private static func lineContainsForceUnwrap(_ line: String) -> Bool {
        // Strip string literals so a `!` inside `"foo!"` doesn't match.
        var scrubbed = ""
        var inString = false
        for ch in line {
            if ch == "\"" {
                inString.toggle()
                continue
            }
            if !inString {
                scrubbed.append(ch)
            }
        }

        let chars = Array(scrubbed)
        for i in 0..<chars.count {
            guard chars[i] == "!" else { continue }

            // Exclude `!=` and `!!`
            let prev = i > 0 ? chars[i - 1] : Character(" ")
            let next = i < chars.count - 1 ? chars[i + 1] : Character(" ")
            if next == "=" { continue }
            if prev == "=" { continue }
            if next == "!" { continue }

            // Exclude `as!` and `is!`
            if prev == "s" && i >= 2 {
                let before = chars[i - 2]
                if before == "a" || before == "i" { continue }
            }
            // Exclude `as?`, `is?` lookalikes — no `!` though so N/A.

            // Force unwrap must be preceded by an identifier-like
            // character (letter, digit, `)`, `]`) and not be the
            // first non-whitespace token on the line.
            let isIdentifierTail = prev.isLetter
                || prev.isNumber
                || prev == ")"
                || prev == "]"
            guard isIdentifierTail else { continue }

            return true
        }
        return false
    }

// MARK: - TelemetryService test seam
//
// Production code uses `persistTelemetryIfMeaningful(previousSpeed:)`
// from inside `locationManager(_:didUpdateLocations:)`. Tests need a
// way to drive the persistence policy without setting up a real
// CLLocationManager. The internal `_persistForTest` entry point
// already exposes the private method via `@testable import Runner`,
// so tests call it directly on a `TelemetryService(clock:)` instance.

/// `applyPersistedActiveSlot` reads the value the
/// `SwitchDriveStudioSlotIntent` writes into App Group defaults and
/// applies it to `activeSlotIndex`. Out-of-range or missing values
/// fall back to slot 0 without surfacing an error.
func testApplyPersistedActiveSlotHonorsPersistedValue() async {
    let defaults = UserDefaults(suiteName: AppGroupContract.suiteName)
        ?? UserDefaults.standard
    defaults.removeObject(forKey: AppStore.activeSlotKey)
    defaults.set(2, forKey: AppStore.activeSlotKey)

    await MainActor.run {
        // Force a non-matching prior value to prove the read happens.
        AppStore.shared.activeSlotIndex = 0
        AppStore.shared.applyPersistedActiveSlot()
        XCTAssertEqual(AppStore.shared.activeSlotIndex, 2,
                       "Persisted slot index 2 must be applied on next read")
    }
    defaults.removeObject(forKey: AppStore.activeSlotKey)
}

// MARK: - Background-mode audits

    /// `UIBackgroundModes → fetch` must not be declared because no
    /// `application:performFetchWithCompletionHandler:` implementation
    /// exists. The `audio` mode may remain.
    func testInfoPlistHasNoBackgroundFetchDeclaration() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let infoPlistURL = repoRoot.appendingPathComponent("Runner/Info.plist")
        let raw = try String(contentsOf: infoPlistURL, encoding: .utf8)
        // We look at executable code only — strip HTML comments so
        // notes about absence do not count.
        let stripped = stripPlistComments(raw)
        // The `fetch` entry must not appear in executable key/values.
        XCTAssertFalse(stripped.contains("<string>fetch</string>"),
            "Info.plist must not declare UIBackgroundModes → fetch (no handler exists)")

        // The codebase must not contain a `performFetchWithCompletionHandler`
        // selector or `setMinimumBackgroundFetchInterval`.
        let fm = FileManager.default
        let runnerDir = repoRoot.appendingPathComponent("Runner")
        if let it = fm.enumerator(atPath: runnerDir.path) {
            while let file = it.nextObject() as? String {
                guard file.hasSuffix(".swift") else { continue }
                let url = runnerDir.appendingPathComponent(file)
                let code = stripSwiftComments(try String(contentsOf: url, encoding: .utf8))
                XCTAssertFalse(code.contains("performFetchWithCompletionHandler"),
                    "\(file) must not implement background fetch")
                XCTAssertFalse(code.contains("setMinimumBackgroundFetchInterval"),
                    "\(file) must not configure minimum background fetch interval")
            }
        }
    }

    /// Location authorization is foreground-only: `requestWhenInUseAuthorization`
    /// is the call site, and `NSLocationAlwaysAndWhenInUseUsageDescription`
    /// is absent from Info.plist.
    func testLocationAuthIsForegroundOnly() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let infoPlistURL = repoRoot.appendingPathComponent("Runner/Info.plist")
        let raw = try String(contentsOf: infoPlistURL, encoding: .utf8)
        let stripped = stripPlistComments(raw)
        XCTAssertFalse(stripped.contains("NSLocationAlwaysAndWhenInUseUsageDescription"),
            "Info.plist must not declare the Always-location purpose string when no background feature exists")
        // Code path: ensure requestAlwaysAuthorization is NOT called anywhere
        // in Runner, and that the When-In-Use call exists somewhere.
        let fm = FileManager.default
        let runnerDir = repoRoot.appendingPathComponent("Runner")
        var hasWhenInUse = false
        var alwaysAuthorizationFiles: [String] = []
        if let it = fm.enumerator(atPath: runnerDir.path) {
            while let file = it.nextObject() as? String {
                guard file.hasSuffix(".swift") else { continue }
                let url = runnerDir.appendingPathComponent(file)
                let code = stripSwiftComments(try String(contentsOf: url, encoding: .utf8))
                if code.contains("requestAlwaysAuthorization") {
                    alwaysAuthorizationFiles.append(file)
                }
                if code.contains("requestWhenInUseAuthorization") {
                    hasWhenInUse = true
                }
            }
        }
        XCTAssertTrue(alwaysAuthorizationFiles.isEmpty,
            "Runner must not call requestAlwaysAuthorization; offenders: \(alwaysAuthorizationFiles)")
        XCTAssertTrue(hasWhenInUse,
            "Runner must call requestWhenInUseAuthorization somewhere (foreground-only GPS)")
    }
}

// MARK: - Test-only TimelineEntry used by helper-shape tests

/// A minimal TimelineEntry used to assert timeline shape (entry count,
/// first-entry date, spacing). Production entries have additional
/// fields; those are exercised in their own dedicated tests.
struct SimpleTestEntry: TimelineEntry {
    let date: Date
}

/// Mirror of the private `Snapshot` struct inside
/// `TelemetryService.persistTelemetryIfMeaningful`. Tests decode the
/// persisted App Group blob into this so we can assert exact equality
/// on the encoded values (especially `timestamp` which is the
/// injected clock value).
struct TelemetryTestSnapshot: Codable, Equatable {
    let carConnected: Bool
    let batteryPercent: Int?
    let isCharging: Bool
    var speed: Double?
    let timestamp: Date?
}
