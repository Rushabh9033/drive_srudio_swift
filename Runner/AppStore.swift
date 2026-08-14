import SwiftUI
import UIKit
import WidgetKit
import CryptoKit

@MainActor
class AppStore: ObservableObject {
    static let shared = AppStore()

    @Published var slots: [String?] = [nil, nil, nil, nil]
    @Published var vehicleImage: UIImage? = nil
    @Published var drafts: [Draft] = []

    @Published var liveBatteryPercent: Int? = nil
    @Published var liveIsCharging: Bool = false
    @Published var liveTimeString: String = ""

    /// Currently focused slot (0–3). Set by the App Intents
    /// "SwitchDriveStudioSlotIntent" via the App Group key
    /// `drive_studio_active_slot` and consumed by the host app on
    /// launch and on every foreground transition. Persisted in
    /// App Group defaults so the value survives process restarts.
    @Published var activeSlotIndex: Int = 0

    /// App Group key that the Switch Slot Shortcut writes and that
    /// the host app reads to apply the user's slot preference.
    static let activeSlotKey = "drive_studio_active_slot"

    private let suiteName = "group.com.drivestudio.shared"
    /// Same string as `suiteName` but exposed as `static` so
    /// `nonisolated static` helpers (e.g. asset staging) can reach
    /// it without going through an instance.
    nonisolated static let appGroupSuite = "group.com.drivestudio.shared"
    private let draftsKey = "drive_studio_drafts"

    private init() {
        // TelemetryService.init() already enables UIDevice battery
        // monitoring — don't duplicate it here.
        loadState()
        // Apply any slot preference the user saved via the
        // "Switch Drive Studio Slot" Shortcut. The intent can only
        // write to App Group defaults from its own process; the
        // host app is the one that turns the persisted integer
        // into an applied slot.
        applyPersistedActiveSlot()
        setupAutoRefresh()
    }

    func setupAutoRefresh() {
        refreshDeviceTelemetry()

        // Battery observers fire at every 1% boundary (batteryLevelDidChange)
        // and on every plug/unplug (batteryStateDidChange). willEnterForeground
        // catches app-resume. These three together cover every meaningful
        // state transition without needing a polling timer.
        NotificationCenter.default.addObserver(forName: UIDevice.batteryLevelDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshDeviceTelemetry() }
        }
        NotificationCenter.default.addObserver(forName: UIDevice.batteryStateDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshDeviceTelemetry() }
        }
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.refreshDeviceTelemetry()
                // Re-apply the slot preference the user saved via
                // the Shortcut while the app was backgrounded. The
                // intent can only write App Group defaults, so the
                // host app is the one that turns the saved integer
                // into a focused slot.
                self?.applyPersistedActiveSlot()
            }
        }
    }

    func refreshDeviceTelemetry() {
        let rawLevel = UIDevice.current.batteryLevel
        // `batteryLevel` returns -1 when monitoring is disabled or the
        // reading is genuinely unavailable. We propagate that as `nil`
        // rather than substituting a fake number like 100.
        let level: Int? = rawLevel >= 0 ? Int(round(rawLevel * 100)) : nil
        let state = UIDevice.current.batteryState
        // Use the exact current state. We never OR with a previously
        // cached charging flag — if the phone just unplugged, we must
        // show "not charging" immediately.
        let charging = (state == .charging || state == .full)

        // Single change-check on battery + charging only. The minute
        // tick in `liveTimeString` is purely a UI label — it does NOT
        // trigger a write to the App Group or a widget reload. Every
        // tick would write the same telemetry JSON and burn through
        // the WidgetCenter budget for no widget-visible change.
        let prev = (liveBatteryPercent, liveIsCharging)
        let curr = (level, charging)
        guard prev != curr else {
            // No battery / charging transition. Still refresh the UI
            // label so the visible clock ticks.
            self.liveTimeString = FormatterCache.hmmFormatter.string(from: Date())
            return
        }
        (liveBatteryPercent, liveIsCharging) = curr
        self.liveTimeString = FormatterCache.hmmFormatter.string(from: Date())
        TelemetryService.shared.snapshotAndSave()
    }

    func loadState() {
        let defaults = UserDefaults(suiteName: suiteName) ?? UserDefaults.standard

        // Delegate slot recovery to the shared V2 reader so the
        // host app, widget extension, and intents all agree on the
        // same generation/checksum/cache semantics.
        if let state = AppGroupState.loadState() {
            for (i, slot) in (state.slots ?? []).enumerated() where i < 4 {
                self.slots[i] = slot.draftId
            }
        }

        if let draftsData = defaults.data(forKey: draftsKey),
           let savedDrafts = try? JSONDecoder().decode([Draft].self, from: draftsData) {
            self.drafts = savedDrafts
        }

        // Also cleanup slots that don't correspond to any draft or actual default template
        for i in 0..<4 {
            if let slot = self.slots[i] {
                let isCustomDraft = self.drafts.contains(where: { $0.id == slot })
                let isDefaultTemplate = StockWidgetCatalog.shared.widgets.contains(where: { $0.stockWidgetId == slot })

                if !isCustomDraft && !isDefaultTemplate {
                    self.slots[i] = nil // Reset corrupted slot
                }
            }
        }

        // Load vehicle image permanently from disk
        loadVehicleImage()
    }

    /// Read the slot index the user most recently saved via the
    /// "Switch Drive Studio Slot" Shortcut (App Group key
    /// `drive_studio_active_slot`) and apply it. Out-of-range or
    /// missing values fall back to slot 0 without surfacing an error
    /// — Shortcuts users should never see a crash from this path.
    /// Called once from `init()` after `loadState()` and from every
    /// foreground transition (`scenePhase == .active`) so a
    /// Shortcut fired while the host was backgrounded still takes
    /// effect when the user next opens Drive Studio.
    func applyPersistedActiveSlot() {
        let defaults = UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
        let raw = defaults.integer(forKey: Self.activeSlotKey)
        // `integer(forKey:)` returns 0 when the key is absent —
        // indistinguishable from "user picked slot 1". We accept
        // that ambiguity for the first launch (no preference saved
        // yet) and trust the value thereafter.
        let clamped = max(0, min(3, raw))
        if clamped != activeSlotIndex {
            activeSlotIndex = clamped
        }
    }

    /// Manually focus a slot. Persists the preference to App Group
    /// defaults (so a subsequent Shortcut invocation reads the same
    /// value) and triggers an immediate widget reload so the gallery
    /// reflects the new focus. Out-of-range values are clamped to
    /// 0..3 silently — the caller should not need to validate.
    func setActiveSlot(_ index: Int) {
        let clamped = max(0, min(3, index))
        activeSlotIndex = clamped
        let defaults = UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
        defaults.set(clamped, forKey: Self.activeSlotKey)
        // Persist V2 envelope so the widget reads the latest state
        // alongside the active-slot preference.
        saveState()
        WidgetReloadThrottle.shared.requestReload(kind: .slotChange)
    }

    func saveVehicleImage(_ image: UIImage) {
        self.vehicleImage = image
        let filename = "home_vehicle.png"
        let pngData = image.pngData()

        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = docs.appendingPathComponent(filename)
            try? pngData?.write(to: fileURL)
        }

        if let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName) {
            let sharedRootURL = sharedURL.appendingPathComponent(filename)
            try? pngData?.write(to: sharedRootURL)

            let sharedImagesDir = sharedURL.appendingPathComponent("SharedImages")
            try? FileManager.default.createDirectory(at: sharedImagesDir, withIntermediateDirectories: true)
            let sharedImagesURL = sharedImagesDir.appendingPathComponent(filename)
            try? pngData?.write(to: sharedImagesURL)
        }
    }

    private func loadVehicleImage() {
        let filename = "home_vehicle.png"

        if let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName) {
            let sharedImagesURL = sharedURL.appendingPathComponent("SharedImages").appendingPathComponent(filename)
            if let data = try? Data(contentsOf: sharedImagesURL), let img = UIImage(data: data) {
                self.vehicleImage = img
                return
            }
            let sharedRootURL = sharedURL.appendingPathComponent(filename)
            if let data = try? Data(contentsOf: sharedRootURL), let img = UIImage(data: data) {
                self.vehicleImage = img
                return
            }
        }

        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = docs.appendingPathComponent(filename)
            if let data = try? Data(contentsOf: fileURL), let img = UIImage(data: data) {
                self.vehicleImage = img
                return
            }
        }
    }

    func assignSlot(_ index: Int, draftId: String?) {
        guard index >= 0 && index < 4 else { return }
        slots[index] = draftId
        saveState()
    }

    func moveSlots(fromOffsets: IndexSet, toOffset: Int) {
        slots.move(fromOffsets: fromOffsets, toOffset: toOffset)
        saveState()
    }
    
    func saveDraft(_ draft: Draft) {
        if let index = drafts.firstIndex(where: { $0.id == draft.id }) {
            drafts[index] = draft
        } else {
            drafts.append(draft)
        }
        saveState()
    }

    func deleteDraft(_ id: String) {
        drafts.removeAll(where: { $0.id == id })
        for i in 0..<4 {
            if slots[i] == id {
                slots[i] = nil
            }
        }
        saveState()
    }

    func clearAllDrafts() {
        drafts.removeAll()
        slots = [nil, nil, nil, nil]
        saveState()
    }

    func clearCustomVehicleImage() {
        self.vehicleImage = nil
        let filename = "home_vehicle.png"

        if let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName) {
            let sharedImagesURL = sharedURL.appendingPathComponent("SharedImages").appendingPathComponent(filename)
            try? FileManager.default.removeItem(at: sharedImagesURL)
            let sharedRootURL = sharedURL.appendingPathComponent(filename)
            try? FileManager.default.removeItem(at: sharedRootURL)
        }

        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = docs.appendingPathComponent(filename)
            try? FileManager.default.removeItem(at: fileURL)
        }

        saveState()
    }

    func saveState() {
        let defaults = UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
        if let data = try? JSONEncoder().encode(drafts) {
            defaults.set(data, forKey: draftsKey)
        }

        // Build the V2 envelope. **Persist real selected-vehicle and
        // real telemetry values** so the widget extension, App Intents
        // reader, and any future CarPlay scene all see the same canonical
        // data. We never invent a fake vehicle and we never write a
        // stale telemetry snapshot — if no telemetry is currently
        // available, we pass through `nil` and the reader surfaces
        // "unknown" honestly.
        var newSlots: [Slot] = []
        for i in 0..<4 {
            let draftId = slots[i]
            var slotSpec: WidgetSpec? = nil
            if let dId = draftId {
                if let customDraft = drafts.first(where: { $0.id == dId }) {
                    slotSpec = customDraft.spec
                } else if let stockWidget = StockWidgetCatalog.shared.widgets.first(where: { $0.stockWidgetId == dId }) {
                    slotSpec = stockWidget.document
                }
            }
            newSlots.append(Slot(index: i, draftId: draftId, spec: slotSpec))
        }

        // **Real selected-vehicle source.** The user picks a vehicle
        // when they import a vehicle image; we never invent a brand.
        // When no image has been picked we keep `vehicle: nil` so the
        // widget renders "—".
        let selectedVehicle = currentSelectedVehicle()

        // **Real telemetry from the host.** We do NOT re-encode a fresh
        // telemetry snapshot here — that is `TelemetryService`'s job
        // and runs through its freshness policy. We pass through the
        // last `live_*` values the AppStore already tracks. Genuine 0
        // and `nil` are preserved exactly.
        let telemetry = TelemetrySnapshot(
            carConnected: TelemetryService.shared.carConnected,
            batteryPercent: liveBatteryPercent,
            isCharging: liveIsCharging,
            speed: TelemetryService.shared.currentSpeed,
            timestamp: Date()
        )

        let envelope = WidgetState(
            schemaVersion: 2,
            vehicle: selectedVehicle,
            slots: newSlots,
            telemetry: telemetry,
            widgetImagePath: nil
        )

        // **Crash-safe generation-specific replacement.** Encode
        // once, then hand off to a dedicated installer that writes
        // to a unique `state_<generation>.json`, byte-verifies it,
        // and only publishes the new metadata after the staged file
        // is durable on disk. If anything fails before metadata
        // publication, the previous generation's metadata entry
        // stays canonical and readers continue to read the previous
        // (valid) generation file unchanged.
        guard let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName),
              let stateData = try? JSONEncoder().encode(envelope) else {
            return
        }

        // Look up the previous generation so the install can
        // preserve the at-least-two-generation invariant in its
        // cleanup hook.
        let previousGeneration = Self.readCurrentGeneration(
            from: defaults,
            metadataKey: AppGroupContract.v2MetadataKey
        )

        let installResult: StateInstallResult
        do {
            // **Pure asset plan.** Compute the set of image filenames
            // that the new generation references. We resolve this
            // up-front (before any I/O happens in the installer) so
            // the staging closure itself can be a thin filesystem
            // operation and the plan is testable independently.
            let imagesToSync = Self.referencedImageFilenames(in: newSlots)

            installResult = try Self.installState(
                stateData: stateData,
                sharedContainer: sharedURL,
                stageAssets: { staged in
                    // The installer wrote a brand-new
                    // `state_<gen>.json` and verified it byte-for-byte.
                    // Now copy every referenced image into the new
                    // generation's directory BEFORE we publish the new
                    // metadata — so any reader who sees the new
                    // generation through metadata will also be able to
                    // find its assets on disk.
                    let destFolder = staged.assetDirectory
                        ?? sharedURL
                            .appendingPathComponent("SharedImages")
                            .appendingPathComponent("generation_\(staged.generation)")
                    try Self.copyReferencedImages(
                        filenames: imagesToSync,
                        into: destFolder,
                        sourceDirectories: Self.imageSourceDirectories(),
                        bundle: Bundle.main,
                        preserveCustomVehicleImage: self.vehicleImage != nil ? "home_vehicle.png" : nil
                    )
                },
                publish: { metaData in
                    defaults.set(metaData, forKey: AppGroupContract.v2MetadataKey)
                },
                cleanupOlderGenerations: { keepGenerations in
                    // Preserve at least the new generation and the
                    // previous one (when one exists) so a crash
                    // between publish and reader-consume does not
                    // orphan the previous file.
                    var preserve = keepGenerations
                    if let prev = previousGeneration { preserve.insert(prev) }
                    Self.cleanupStateFilesExcept(
                        in: sharedURL,
                        keep: preserve
                    )
                }
            )
        } catch {
            // Replacement failed — the previous valid generation
            // is still readable. Bail without invalidating the cache,
            // bail without requesting a widget reload, and bail
            // without staging any partial asset directory.
            return
        }
        _ = installResult.generation

        // **Cache invalidation.** The installer published the new
        // generation's checksum, generation, and timestamp. Now drop
        // the in-memory cache so the very next read in any process
        // — Runner, widget extension, App Intents — is forced to
        // re-fetch and re-hash instead of returning the previous
        // generation's cached value.
        AppGroupState.invalidateCache()

        // **WidgetKit reload.** Only after metadata publish + cache
        // invalidation succeeds do we tell WidgetKit to refresh.
        WidgetReloadThrottle.shared.requestReload(kind: .slotChange)
    }

    /// Build the selected-vehicle `VehicleData` from the user-imported
    /// vehicle image (if any). Returns `nil` when no vehicle has been
    /// selected so the widget renders "—"; never invents a brand,
    /// model, or display name.
    private func currentSelectedVehicle() -> VehicleData? {
        guard let image = vehicleImage else { return nil }
        // Confirm the artwork actually exists on disk in either the
        // sandboxed Documents dir or the App Group SharedImages
        // folder — the user may have cleared one of them since the
        // image was first imported.
        let filename = "home_vehicle.png"
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let docsURL = docs?.appendingPathComponent(filename)
        let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName)
            .map { $0.appendingPathComponent("SharedImages").appendingPathComponent(filename) }
        let found = (docsURL.map { FileManager.default.fileExists(atPath: $0.path) } == true) ||
                    (sharedURL.map { FileManager.default.fileExists(atPath: $0.path) } == true)
        guard found else { return nil }
        // The user uploaded custom artwork. Surface only the artwork
        // path. We deliberately do NOT derive `displayName` from the
        // filename (which would produce "Home Vehicle" from
        // `home_vehicle.png` — an invented identity we never agreed
        // to). The widget renders a generic unavailable marker for
        // `brandId == nil` and `modelId == nil` and `displayName ==
        // nil`. See `vehicleIdentity(forImageFilename:hasImage:)`
        // for the testable shape of this decision.
        return Self.vehicleIdentity(forImageFilename: filename, hasImage: true)
    }

    /// Pure, testable decision: given whether the user uploaded an
    /// image (and its on-disk filename), what `VehicleData` should
    /// the App Group envelope carry? We **never** invent brandId,
    /// modelId, or displayName — those require the user to pick or
    /// type them. We do preserve the artwork path so the widget
    /// renders the user's custom image.
    static func vehicleIdentity(forImageFilename filename: String?, hasImage: Bool) -> VehicleData? {
        guard hasImage, let filename = filename, !filename.isEmpty else { return nil }
        return VehicleData(
            brandId: nil,
            modelId: nil,
            artwork: filename,
            displayName: nil,
            hasCustomImage: true,
            customImage: filename
        )
    }

    /// Install a new V2 state file atomically and publish its
    /// metadata. Returns the new generation on success, `nil` on
    /// any failure so the caller can preserve the previous valid
    /// file and skip cache invalidation.
    ///
    /// - Writes the new payload to a unique temp file (not the
    ///   destination).
    /// - Uses `FileManager.replaceItemAt` when the destination
    ///   exists (APFS-atomic), and a plain move when it doesn't
    ///   (first-launch).
    /// - On failure, removes the orphan temp file and returns
    // MARK: - Crash-safe state installation
    //
    // The previous installer overwrote a fixed
    // `widget_state_v2.json` in place and then updated the metadata
    // blob pointing at it. That left a crash window: the new bytes
    // could land on disk while the metadata update was still in
    // flight, so a process crash between file-write and
    // metadata-publish left metadata pointing at the new bytes —
    // and any reader who verified the checksum against the old
    // metadata would either fail or (worse) trust the new bytes
    // for which the checksum had not been re-validated.
    //
    // The new transaction:
    //   1. Picks a fresh generation UUID and writes the new state
    //      to a unique `state_<generation>.json` filename inside
    //      the shared App Group container.
    //   2. Reads the file back from disk and byte-compares against
    //      the supplied `stateData` to make sure the write was
    //      durable and not truncated.
    //   3. Computes SHA-256 over the verified bytes and hands the
    //      metadata blob to the caller-supplied `publish` closure.
    //   4. If `publish` throws, the new generation file is removed
    //      so the next install can write a clean file under the
    //      same UUID. The previous generation remains canonical
    //      because its metadata entry was never overwritten.
    //   5. Only after a successful publish does the optional
    //      `cleanupOlderGenerations` hook get to remove older
    //      generation files. The new generation and (when known)
    //      the previous generation are passed to the hook so it
    //      can keep the at-least-two-generation invariant.
    //
    // **Failure semantics:**
    // - Crash before step 1: nothing on disk changed.
    // - Crash between step 1 and step 2: an orphan
    //   `state_<uuid>.json` exists on disk; metadata still points at
    //   the previous generation file, which is fully readable.
    // - Crash between step 2 and step 3: same as above, with the
    //   verification read-back guaranteeing the file is complete
    //   (not a partial write).
    // - Crash between step 3 and step 4 (publish): the previous
    //   metadata entry is still valid, the new file is on disk but
    //   invisible to readers. The next install's cleanup hook can
    //   remove orphan state_*.json files if it wants.
    // - `publish` throws: new file removed, previous metadata
    //   unchanged, callers see a thrown error and can retry.

    enum StateInstallError: Error, Equatable {
        /// The shared container URL was not a usable directory.
        case destinationDirectoryMissing(URL)
        /// Writing the staged generation file failed.
        case stageWriteFailed(URL)
        /// Verifying the staged file (re-reading and byte-comparing)
        /// did not produce the exact `stateData` we wrote.
        case verificationFailed(expectedBytes: Int, actualBytes: Int)
        /// The asset-stage closure threw. The new generation file
        /// and any partially-staged assets are removed; the previous
        /// generation's metadata is unchanged.
        case assetStageFailed(String)
        /// The metadata publish closure threw. The new generation
        /// file and any staged assets are removed; the previous
        /// generation remains canonical.
        case metadataPublishFailed(String)
    }

    struct StateInstallResult: Equatable {
        let generation: String
        let publishedFilename: String
        let assetDirectory: URL?
    }

    /// Crash-safe state installer with optional asset staging.
    /// Writes a fresh `state_<generation>.json`, verifies it, then
    /// runs an asset-stage closure BEFORE publishing metadata. The
    /// previous generation's metadata entry is only overwritten once
    /// `publish` returns successfully.
    ///
    /// Transaction order:
    ///   1. Write + verify `state_<generation>.json`.
    ///   2. Run `stageAssets(...)` so referenced generation image
    ///      assets land in
    ///      `SharedImages/generation_<generation>/` before any reader
    ///      can observe the new metadata.
    ///   3. Publish metadata as the commit point. Until this returns,
    ///      readers continue to see the previous generation.
    ///   4. Best-effort cleanup of older generations preserving at
    ///      least the new and previous ones.
    ///
    /// Failure semantics:
    /// - State write/verify failure: temp file removed, throw —
    ///   previous metadata is untouched, no asset stage ever runs.
    /// - Asset stage failure: state file AND any partially-staged
    ///   assets removed, throw — previous metadata is untouched,
    ///   `publish` is never invoked, no widget reload fires.
    /// - Metadata publish failure: state file AND any staged assets
    ///   removed, throw — previous metadata is untouched, no
    ///   cleanup hook runs.
    ///
    /// Marked `nonisolated` because the transaction is pure — it
    /// touches the filesystem and the caller-supplied closures but
    /// never reads any actor-isolated state — so tests can call it
    /// without hopping through `MainActor.run`.
    nonisolated static func installState(
        stateData: Data,
        sharedContainer: URL,
        clock: () -> Date = { Date() },
        stageAssets: ((StateInstallResult) throws -> Void)? = nil,
        publish: (Data) throws -> Void,
        cleanupOlderGenerations: (Set<String>) -> Void = { _ in }
    ) throws -> StateInstallResult {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: sharedContainer.path, isDirectory: &isDir),
              isDir.boolValue else {
            throw StateInstallError.destinationDirectoryMissing(sharedContainer)
        }

        // Step 1: pick a unique generation UUID and write the new
        // state to a generation-specific filename.
        let newGeneration = UUID().uuidString
        let newFilename = "state_\(newGeneration).json"
        let newURL = sharedContainer.appendingPathComponent(newFilename)

        do {
            try stateData.write(to: newURL, options: [.atomic])
        } catch {
            // Pre-publication failure: stage write failed. Remove
            // any partial file and bail. Previous generation's
            // metadata is untouched.
            try? fm.removeItem(at: newURL)
            throw StateInstallError.stageWriteFailed(newURL)
        }

        // Step 2: re-read the staged file and byte-compare against
        // the source data so we never advance metadata pointing at
        // a partial or corrupt write.
        let readBack: Data
        do {
            readBack = try Data(contentsOf: newURL)
        } catch {
            try? fm.removeItem(at: newURL)
            throw StateInstallError.stageWriteFailed(newURL)
        }
        guard readBack == stateData else {
            try? fm.removeItem(at: newURL)
            throw StateInstallError.verificationFailed(
                expectedBytes: stateData.count,
                actualBytes: readBack.count
            )
        }

        let assetDirectory = sharedContainer
            .appendingPathComponent("SharedImages")
            .appendingPathComponent("generation_\(newGeneration)")
        let staged = StateInstallResult(
            generation: newGeneration,
            publishedFilename: newFilename,
            assetDirectory: assetDirectory
        )

        // Step 3: stage generation assets BEFORE metadata publish.
        // If this throws, the staged state file and any partially-
        // staged assets are cleaned up; `publish` is never called.
        if let stageAssets = stageAssets {
            do {
                try stageAssets(staged)
            } catch {
                try? fm.removeItem(at: newURL)
                try? fm.removeItem(at: assetDirectory)
                throw StateInstallError.assetStageFailed(
                    "asset stage closure threw: \(error)")
            }
        }

        // Step 4: build the metadata blob. Checksum is over the
        // verified bytes, timestamp comes from the injected clock.
        let checksum = SHA256.hash(data: stateData)
            .compactMap { String(format: "%02x", $0) }
            .joined()
        let metadata: [String: Any] = [
            "schemaVersion": 2,
            "generation": newGeneration,
            "stateFile": newFilename,
            "checksum": checksum,
            "updatedAt": ISO8601DateFormatter().string(from: clock())
        ]
        let metaData: Data
        do {
            metaData = try JSONSerialization.data(withJSONObject: metadata, options: [])
        } catch {
            try? fm.removeItem(at: newURL)
            try? fm.removeItem(at: assetDirectory)
            throw StateInstallError.metadataPublishFailed(
                "metadata serialization failed: \(error)")
        }

        // Step 5: atomic metadata publication. If this throws, the
        // previous metadata entry is unchanged, the new state file
        // is removed, and any staged assets are removed.
        do {
            try publish(metaData)
        } catch {
            try? fm.removeItem(at: newURL)
            try? fm.removeItem(at: assetDirectory)
            throw StateInstallError.metadataPublishFailed(
                "publish closure threw: \(error)")
        }

        // Step 6: best-effort cleanup of older generation files,
        // preserving the at-least-two-generation invariant.
        cleanupOlderGenerations(Set([newGeneration]))

        return staged
    }

    /// Read the generation UUID currently published in the metadata
    /// blob. Returns `nil` if the metadata is missing, malformed, or
    /// was never written.
    nonisolated private static func readCurrentGeneration(
        from defaults: UserDefaults,
        metadataKey: String
    ) -> String? {
        guard let data = defaults.data(forKey: metadataKey),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let gen = json["generation"] as? String else {
            return nil
        }
        return gen
    }

    /// Remove all `state_<generation>.json` files in `container`
    /// whose generation UUID is not in `keep`. Best-effort: failures
    /// are logged and ignored so a cleanup hiccup never breaks a
    /// successful install.
    nonisolated private static func cleanupStateFilesExcept(
        in container: URL,
        keep: Set<String>
    ) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            atPath: container.path) else { return }
        for entry in entries {
            // Only act on generation-specific state files; leave any
            // legacy `widget_state_v2.json` and image folders alone.
            guard entry.hasPrefix("state_"),
                  entry.hasSuffix(".json") else { continue }
            // Entry format: state_<generation>.json
            let stripped = entry
                .replacingOccurrences(of: "state_", with: "")
                .replacingOccurrences(of: ".json", with: "")
            guard !keep.contains(stripped) else { continue }
            try? fm.removeItem(at: container.appendingPathComponent(entry))
        }
    }

    // MARK: - Asset staging (gap 2 — stage before metadata publish)

    /// Pure: enumerate the image filenames referenced by the slot
    /// specs being saved. Order-independent (returns a Set) so the
    /// caller can run it before any I/O and so the test can pin it.
    nonisolated static func referencedImageFilenames(in slots: [Slot]) -> Set<String> {
        var names: Set<String> = []
        for slot in slots {
            if let bgSrc = slot.spec?.background?.imageSrc {
                names.insert(bgSrc)
            }
            for layer in slot.spec?.layers ?? [] {
                if layer.kind == "image", let src = layer.src {
                    names.insert(src)
                }
            }
        }
        return names
    }

    /// Pure: enumerate every URL the asset-stager should look in
    /// when copying referenced images. Documents dir is the primary
    /// source for user-imported artwork; the App Group SharedImages
    /// folder is a fallback for legacy hand-copied assets. We do NOT
    /// pass `Bundle.main` as a source here so the test seam is
    /// deterministic.
    nonisolated static func imageSourceDirectories() -> [URL] {
        var sources: [URL] = []
        if let docs = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask).first {
            sources.append(docs)
        }
        if let shared = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupSuite) {
            sources.append(shared.appendingPathComponent("SharedImages"))
        }
        return sources
    }

    /// Pure-with-filesystem: copy every filename in `filenames`
    /// into `destinationFolder`, looking for the source in each of
    /// `sourceDirectories` in order. Missing files are silently
    /// skipped — a referenced image the user deleted on disk is a
    /// render-time concern, not a save-time error. Throws if the
    /// destination folder cannot be created.
    ///
    /// `bundle` is the production fallback for catalog stock images
    /// shipped in the app bundle (e.g. stock widget thumbnails that
    /// don't live in Documents). It is parameterized so the test
    /// seam does not require a real Bundle.main to function.
    ///
    /// `preserveCustomVehicleImage` is the existing `vehicleImage`
    /// filename (e.g. `home_vehicle.png`) that has been uploaded by
    /// the user. We never overwrite or remove it during staging;
    /// the user-imported artwork lives independently of any
    /// generation.
    nonisolated static func copyReferencedImages(
        filenames: Set<String>,
        into destinationFolder: URL,
        sourceDirectories: [URL],
        bundle: Bundle? = nil,
        preserveCustomVehicleImage: String? = nil
    ) throws {
        let fm = FileManager.default
        try fm.createDirectory(
            at: destinationFolder,
            withIntermediateDirectories: true)
        for name in filenames {
            // Honor the legacy fallback: the widget extension can
            // still read `SharedImages/<file>` (no generation
            // prefix) and `home_vehicle.png` is user artwork that
            // must always survive any staging pass.
            if name == preserveCustomVehicleImage { continue }
            let destURL = destinationFolder.appendingPathComponent(name)
            try? fm.removeItem(at: destURL)
            var copied = false
            for sourceDir in sourceDirectories {
                let srcURL = sourceDir.appendingPathComponent(name)
                if fm.fileExists(atPath: srcURL.path) {
                    do {
                        try fm.copyItem(at: srcURL, to: destURL)
                        copied = true
                    } catch {
                        // Try next source.
                        continue
                    }
                    break
                }
            }
            if !copied, let bundle = bundle,
               let bundleURL = bundle.url(forResource: name, withExtension: nil) {
                try? fm.copyItem(at: bundleURL, to: destURL)
            }
        }
    }
}
