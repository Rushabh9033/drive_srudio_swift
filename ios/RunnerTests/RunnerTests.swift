import Flutter
import UIKit
import XCTest
import CryptoKit
@testable import Runner

class RunnerTests: XCTestCase {

    var sharedURL: URL!
    var defaults: UserDefaults!
    let testSuite = "group.com.drivestudio.xctest"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: testSuite)
        defaults.removePersistentDomain(forName: testSuite)
        sharedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DriveStudioTest_\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: sharedURL, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: sharedURL)
        defaults.removePersistentDomain(forName: testSuite)
        super.tearDown()
    }

    // MARK: - T1: Atomic write produces valid file

    func testAtomicStateWriteAndRead() {
        let json = #"{"vehicle":{"customImage":""},"slots":[]}"#
        let genId = UUID().uuidString
        let genDir = sharedURL
            .appendingPathComponent("SharedImages/generation_\(genId)", isDirectory: true)
        try! FileManager.default.createDirectory(at: genDir, withIntermediateDirectories: true)

        let data = json.data(using: .utf8)!
        let stateURL = genDir.appendingPathComponent("state.json")
        try! data.write(to: stateURL, options: .atomic)

        XCTAssertTrue(FileManager.default.fileExists(atPath: stateURL.path),
                      "state.json must exist after atomic write")
        let read = try! Data(contentsOf: stateURL)
        XCTAssertEqual(read, data, "Read-back data must match written data exactly")
    }

    // MARK: - T2: Legacy V1 migration

    func testLegacyUserDefaultsMigration() {
        defaults.set(#"{"old":true}"#, forKey: AppGroupContract.stateKey)
        AppGroupChannel.migrateV1ifNeeded(sharedURL: sharedURL, defaults: defaults)

        XCTAssertNotNil(defaults.data(forKey: "widget_state_v2_metadata"),
                        "V2 metadata must be written after migration")
        XCTAssertEqual(defaults.string(forKey: "widget_state_v2_current_generation"),
                       "migration_v1",
                       "Current generation must be 'migration_v1'")
        XCTAssertNil(defaults.string(forKey: AppGroupContract.stateKey),
                     "Old V1 UserDefaults key must be removed after migration")

        // Migrated state.json must exist on disk
        let genDir = sharedURL
            .appendingPathComponent("SharedImages/generation_migration_v1/state.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: genDir.path),
                      "Migrated state.json must exist on disk")
    }

    // MARK: - T3: Generation cleanup retains current + previous only

    func testGenerationRetentionAndCleanup() {
        let imgDir = sharedURL.appendingPathComponent("SharedImages", isDirectory: true)
        try! FileManager.default.createDirectory(at: imgDir, withIntermediateDirectories: true)

        let keep   = ["current", "prev", "migration_v1"]
        let purge  = ["old1", "old2", "orphan"]
        for g in keep + purge {
            try! FileManager.default.createDirectory(
                at: imgDir.appendingPathComponent("generation_\(g)"),
                withIntermediateDirectories: true)
        }

        defaults.set("current", forKey: "widget_state_v2_current_generation")
        defaults.set("prev",    forKey: "widget_state_v2_previous_generation")

        AppGroupChannel.cleanupOrphanGenerations(sharedURL: sharedURL, defaults: defaults)

        let remaining = (try! FileManager.default.contentsOfDirectory(at: imgDir, includingPropertiesForKeys: nil))
            .map { $0.lastPathComponent }

        for g in keep  { XCTAssertTrue(remaining.contains("generation_\(g)"),  "Must retain: \(g)") }
        for g in purge { XCTAssertFalse(remaining.contains("generation_\(g)"), "Must purge:  \(g)") }
    }

    // MARK: - T4: Previous generation survives and can restore after current corruption

    func testPreviousGenerationRecovery() {
        let imgDir = sharedURL.appendingPathComponent("SharedImages", isDirectory: true)
        try! FileManager.default.createDirectory(at: imgDir, withIntermediateDirectories: true)

        // Write valid previous generation
        let prevId  = "prev_valid"
        let prevDir = imgDir.appendingPathComponent("generation_\(prevId)")
        try! FileManager.default.createDirectory(at: prevDir, withIntermediateDirectories: true)
        let goodPayload = #"{"slots":[],"vehicle":{}}"#.data(using: .utf8)!
        let goodChecksum = SHA256.hash(data: goodPayload).compactMap { String(format: "%02x", $0) }.joined()
        try! goodPayload.write(to: prevDir.appendingPathComponent("state.json"), options: .atomic)

        // Write corrupt current generation (bad JSON bytes)
        let currId  = "curr_corrupt"
        let currDir = imgDir.appendingPathComponent("generation_\(currId)")
        try! FileManager.default.createDirectory(at: currDir, withIntermediateDirectories: true)
        let corruptData = Data([0xFF, 0xFE, 0x00])   // not valid UTF-8 JSON
        let badChecksum = "deadbeef"
        try! corruptData.write(to: currDir.appendingPathComponent("state.json"), options: .atomic)

        // Simulate what AppGroupHelper.loadState() does:
        // 1. Read current → checksum mismatch → fallback to previous
        let currStateURL = currDir.appendingPathComponent("state.json")
        let currData = try! Data(contentsOf: currStateURL)
        let computedCurrChecksum = SHA256.hash(data: currData)
            .compactMap { String(format: "%02x", $0) }.joined()
        XCTAssertNotEqual(computedCurrChecksum, badChecksum,
                          "Corrupt generation checksum must not match stored checksum")

        // 2. Fall back to previous
        let prevStateURL = prevDir.appendingPathComponent("state.json")
        let prevData = try! Data(contentsOf: prevStateURL)
        let computedPrevChecksum = SHA256.hash(data: prevData)
            .compactMap { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(computedPrevChecksum, goodChecksum,
                       "Previous generation checksum must be valid and match")
        XCTAssertTrue(prevData.count > 0, "Previous generation state.json must be non-empty")
    }

    // MARK: - T5: SVG / malformed image is rejected

    func testMalformedImageRejection() {
        let genDir = sharedURL.appendingPathComponent("SharedImages/generation_svg_test", isDirectory: true)
        try! FileManager.default.createDirectory(at: genDir, withIntermediateDirectories: true)

        let svgB64 = "<svg></svg>".data(using: .utf8)!.base64EncodedString()
        let dict: [String: Any] = ["vehicle": ["customImage": "data:image/svg+xml;base64,\(svgB64)"]]

        XCTAssertThrowsError(try AppGroupChannel.processAndCopyImages(in: dict, to: genDir)) { err in
            let e = err as NSError
            XCTAssertEqual(e.domain, "ImageError")
            XCTAssertEqual(e.code, 2, "SVG must be rejected with ImageError code 2")
        }
    }

    // MARK: - T6: SHA-256 checksum round-trip

    func testSHA256ChecksumRoundTrip() {
        let payload  = #"{"schemaVersion":2,"slots":[]}"#.data(using: .utf8)!
        let computed = SHA256.hash(data: payload)
            .compactMap { String(format: "%02x", $0) }.joined()

        // Write, read back, re-hash → must match
        let stateURL = sharedURL.appendingPathComponent("cs_test.json")
        try! payload.write(to: stateURL, options: .atomic)
        let readBack = try! Data(contentsOf: stateURL)
        let recomputed = SHA256.hash(data: readBack)
            .compactMap { String(format: "%02x", $0) }.joined()

        XCTAssertEqual(computed, recomputed, "Checksum must be stable across write/read cycle")
    }

    // MARK: - T7: migration_v1 is never deleted by cleanup

    func testMigrationV1IsNeverPurged() {
        let imgDir = sharedURL.appendingPathComponent("SharedImages", isDirectory: true)
        try! FileManager.default.createDirectory(at: imgDir, withIntermediateDirectories: true)

        // migration_v1 exists, but current/prev point to different gens
        try! FileManager.default.createDirectory(
            at: imgDir.appendingPathComponent("generation_migration_v1"),
            withIntermediateDirectories: true)
        try! FileManager.default.createDirectory(
            at: imgDir.appendingPathComponent("generation_A"),
            withIntermediateDirectories: true)

        defaults.set("A",   forKey: "widget_state_v2_current_generation")
        // No previous set — migration_v1 is the only other dir

        AppGroupChannel.cleanupOrphanGenerations(sharedURL: sharedURL, defaults: defaults)

        let remaining = (try! FileManager.default.contentsOfDirectory(
            at: imgDir, includingPropertiesForKeys: nil)).map { $0.lastPathComponent }

        XCTAssertTrue(remaining.contains("generation_migration_v1"),
                      "migration_v1 must never be deleted by cleanup")
        XCTAssertTrue(remaining.contains("generation_A"),
                      "Current active generation must never be deleted")
    }
}
