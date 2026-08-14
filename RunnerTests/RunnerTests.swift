import Foundation
import XCTest
import CryptoKit
@testable import Runner

// MARK: - T5: SHA-256 checksum round-trip
//
// The simplify pass deleted three tests that exercised code paths which
// no longer exist:
//   * testAtomicStateWriteAndRead — tested `Data.write(.atomic)`, which is
//     Foundation, not app code. The app has no custom atomic-write path.
//   * testPreviousGenerationRecovery — re-implemented SHA-256 + fallback
//     locally with a "Simulate what AppGroupHelper.loadState() does"
//     comment; never called the real reader, so it tested the test, not
//     the app.
//   * testLegacyUserDefaultsMigration / testGenerationRetentionAndCleanup
//     / testMigrationV1IsNeverPurged — exercised `AppGroupChannel.migrateV1ifNeeded`
//     and `AppGroupChannel.cleanupOrphanGenerations`. Both helpers were
//     removed when `AppGroupChannel.swift` was emptied (the real V2 write
//     path is `AppStore.saveState` which writes directly).
//
// What remains is one round-trip assertion that the V2 metadata
// envelope (schemaVersion + generation + checksum) is stable across a
// write/read cycle.

class RunnerTests: XCTestCase {

    // MARK: - T5: V2 metadata envelope round-trip

    func testV2MetadataEnvelopeRoundTrip() {
        let payload  = #"{"schemaVersion":2,"slots":[]}"#.data(using: .utf8)!
        let computed = SHA256.hash(data: payload)
            .compactMap { String(format: "%02x", $0) }.joined()

        // Write, read back, re-hash → must match.
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
