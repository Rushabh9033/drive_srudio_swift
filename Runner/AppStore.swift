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

    @Published var liveBatteryPercent: Int = 100
    @Published var liveIsCharging: Bool = false
    @Published var liveTimeString: String = ""

    private let suiteName = "group.com.drivestudio.shared"
    private let draftsKey = "drive_studio_drafts"
    private var refreshTimer: Timer? = nil

    private init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        loadState()
        setupAutoRefresh()
    }

    var batteryPercent: Int {
        return liveBatteryPercent
    }

    var isCharging: Bool {
        return liveIsCharging
    }

    func setupAutoRefresh() {
        refreshDeviceTelemetry()
        
        NotificationCenter.default.addObserver(forName: UIDevice.batteryLevelDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refreshDeviceTelemetry()
        }
        NotificationCenter.default.addObserver(forName: UIDevice.batteryStateDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refreshDeviceTelemetry()
        }
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refreshDeviceTelemetry()
        }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshDeviceTelemetry()
            }
        }
    }

    func refreshDeviceTelemetry() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let rawLevel = UIDevice.current.batteryLevel
        let level = rawLevel >= 0 ? Int(round(rawLevel * 100)) : 100
        let state = UIDevice.current.batteryState
        let charging = (state == .charging || state == .full)

        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let currentTime = formatter.string(from: Date())

        if self.liveBatteryPercent != level {
            self.liveBatteryPercent = level
        }
        if self.liveIsCharging != charging {
            self.liveIsCharging = charging
        }
        if self.liveTimeString != currentTime {
            self.liveTimeString = currentTime
        }

        TelemetryService.shared.snapshotAndSave()
    }

    let validTemplates = ["Apex", "Neon Grid", "Minimal", "Carbon", "Charge Arc", "Bolt Pill", "Power Ring", "Cell Bar", "Apex Gauge", "Dial", "Velocity", "Track"]
    
    struct Metadata: Codable {
        let schemaVersion: Int
        let generation: String
        let stateFile: String
        let checksum: String
        let updatedAt: String
    }
    
    func loadState() {
        let defaults = UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
        
        if let data = defaults.data(forKey: "widget_state_v2_metadata"),
           let metadata = try? JSONDecoder().decode(Metadata.self, from: data),
           let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName) {
            
            let fileURL = sharedURL.appendingPathComponent(metadata.stateFile)
            if let stateData = try? Data(contentsOf: fileURL),
               let state = try? JSONDecoder().decode(WidgetState.self, from: stateData) {
                for (i, slot) in (state.slots ?? []).enumerated() {
                    if i < 4 {
                        // Wipe the broken "template_x" assignments from previous build
                        if let draftId = slot.draftId, draftId.hasPrefix("template_") {
                            self.slots[i] = nil
                        } else {
                            self.slots[i] = slot.draftId
                        }
                    }
                }
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

    func saveState() {
        let defaults = UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
        if let data = try? JSONEncoder().encode(drafts) {
            defaults.set(data, forKey: draftsKey)
        }
        
        // Save the slots into widget_state_v2_metadata so extensions can read them
        var oldState = WidgetState(schemaVersion: 2, vehicle: nil, slots: [], telemetry: nil, widgetImagePath: nil)
        
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
            newSlots.append(Slot(index: i, draftId: draftId, name: draftId, summary: nil, spec: slotSpec))
        }
        oldState.slots = newSlots
        
        // Write oldState to stateFile in App Group
        if let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName),
           let stateData = try? JSONEncoder().encode(oldState) {
            let stateFile = "widget_state_v2.json"
            let fileURL = sharedURL.appendingPathComponent(stateFile)
            try? stateData.write(to: fileURL)
            
            // Calculate SHA256 (requires CryptoKit, so I'll do a simple hash or we can use CryptoKit)
            // Wait, we need to import CryptoKit at the top of AppStore.swift
            let checksum = Insecure.MD5.hash(data: stateData).map { String(format: "%02x", $0) }.joined()
            // Wait! The widget extension expects SHA256. 
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
            
            // Sync images to App Group
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
                    // If it's a local file, copy it
                    if FileManager.default.fileExists(atPath: sourceURL.path) {
                        try? FileManager.default.copyItem(at: sourceURL, to: destURL)
                    } else if let bundleURL = Bundle.main.url(forResource: img, withExtension: nil) {
                        // Or if it's a bundled asset
                        try? FileManager.default.copyItem(at: bundleURL, to: destURL)
                    }
                }
            }
        }
        
        WidgetCenter.shared.reloadAllTimelines()
    }
}
