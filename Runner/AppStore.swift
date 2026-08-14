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

        // **Atomic write.** Encode once, write to a temp file, then
        // rename. A crash mid-write can no longer truncate the JSON
        // half-written; the next read either sees the old (valid)
        // version or the new (complete) version.
        guard let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName),
              let stateData = try? JSONEncoder().encode(envelope) else {
            return
        }

        let stateFile = "widget_state_v2.json"
        let fileURL = sharedURL.appendingPathComponent(stateFile)
        let tempURL = sharedURL.appendingPathComponent("\(stateFile).tmp")
        do {
            try stateData.write(to: tempURL, options: [.atomic])
            _ = try? FileManager.default.removeItem(at: fileURL)
            try FileManager.default.moveItem(at: tempURL, to: fileURL)
        } catch {
            // Last-resort fallback: direct write (older filesystems).
            try? stateData.write(to: fileURL, options: [.atomic])
        }

        let sha256 = SHA256.hash(data: stateData).compactMap { String(format: "%02x", $0) }.joined()
        let generation = UUID().uuidString
        let metadata: [String: Any] = [
            "schemaVersion": 2,
            "generation": generation,
            "stateFile": stateFile,
            "checksum": sha256,
            "updatedAt": ISO8601DateFormatter().string(from: Date())
        ]

        if let metaDataJSON = try? JSONSerialization.data(withJSONObject: metadata, options: []) {
            defaults.set(metaDataJSON, forKey: "widget_state_v2_metadata")
        }

        // **Cache invalidation.** Bumping the generation also
        // invalidates the in-memory cache inside `AppGroupState` so the
        // very next read sees the new envelope instead of returning
        // the previous generation's cached value.
        AppGroupState.invalidateCache()

        // Sync referenced image files into the App Group so the widget
        // extension can render the same assets as the editor.
        let destFolder = sharedURL.appendingPathComponent("SharedImages").appendingPathComponent("generation_\(generation)")
        try? FileManager.default.createDirectory(at: destFolder, withIntermediateDirectories: true)

        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            var imagesToSync = Set<String>()
            for slot in newSlots {
                if let bgSrc = slot.spec?.background?.imageSrc { imagesToSync.insert(bgSrc) }
                for layer in slot.spec?.layers ?? [] {
                    if layer.kind == "image", let src = layer.src { imagesToSync.insert(src) }
                }
            }

            for img in imagesToSync {
                let sourceURL = docs.appendingPathComponent(img)
                let destURL = destFolder.appendingPathComponent(img)
                if FileManager.default.fileExists(atPath: sourceURL.path) {
                    try? FileManager.default.copyItem(at: sourceURL, to: destURL)
                } else if let bundleURL = Bundle.main.url(forResource: img, withExtension: nil) {
                    try? FileManager.default.copyItem(at: bundleURL, to: destURL)
                }
            }
        }

        WidgetReloadThrottle.shared.requestReload(kind: .slotChange)
    }

    /// Build the selected-vehicle `VehicleData` from the user-imported
    /// vehicle image (if any). Returns `nil` when no vehicle has been
    /// selected so the widget renders "—"; never invents a brand.
    private func currentSelectedVehicle() -> VehicleData? {
        // We currently derive the displayed vehicle name from the
        // filename of the imported image. The user picks the image —
        // we never invent the model. When the image is absent we
        // return `nil` so the widget renders the unavailable marker.
        guard let image = vehicleImage else { return nil }
        // Find the on-disk filename so the widget extension and the
        // App Intents reader all see the same identifier.
        let filename = "home_vehicle.png"
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let docsURL = docs?.appendingPathComponent(filename)
        let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName)
            .map { $0.appendingPathComponent("SharedImages").appendingPathComponent(filename) }
        let found = (docsURL.map { FileManager.default.fileExists(atPath: $0.path) } == true) ||
                    (sharedURL.map { FileManager.default.fileExists(atPath: $0.path) } == true)
        guard found else { return nil }
        // Surface the filename as the user-visible label. The image
        // exists; the user picked it; we report it honestly. No fake
        // brand strings.
        let displayName = humanReadableName(for: filename) ?? filename
        return VehicleData(
            brandId: nil,
            modelId: nil,
            artwork: filename,
            displayName: displayName,
            hasCustomImage: true,
            customImage: filename
        )
    }

    /// Convert a filename like `home_vehicle.png` into a human-readable
    /// label. Pure: no side effects, no I/O. Returns `nil` if the
    /// filename cannot be turned into a sensible label.
    private func humanReadableName(for filename: String) -> String? {
        let base = (filename as NSString).deletingPathExtension
        guard !base.isEmpty else { return nil }
        // Replace separators with spaces and Title-Case each word.
        let parts = base.replacingOccurrences(of: "_", with: " ")
                       .replacingOccurrences(of: "-", with: " ")
                       .split(separator: " ")
        let titled = parts.map { word -> String in
            guard let first = word.first else { return "" }
            return first.uppercased() + word.dropFirst()
        }
        return titled.joined(separator: " ")
    }
}
