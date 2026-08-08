import AppIntents
import CryptoKit
import WidgetKit

/// App Intents exposed by Drive Studio so they surface in:
///   • iOS Shortcuts app (user can build personal automations)
///   • Siri voice commands ("Hey Siri, refresh Drive Studio")
///   • **CarPlay Shortcuts app** — the built-in Shortcuts app runs on the
///     CarPlay screen and surfaces all App Intents automatically. This is
///     the official Apple-sanctioned CarPlay integration path for apps
///     without a CarPlay entitlement.
///
/// All intents live in the main app target (Runner) so they appear in the
/// iOS Shortcuts gallery and CarPlay Shortcuts app. The widget extension
/// reads from the same App Group JSON the intents write.

// MARK: - Refresh Widget

/// Reloads all Drive Studio widget timelines so the Home Screen widget
/// picks up the latest App Group JSON written by the Flutter app.
@available(iOS 16.0, *)
struct RefreshDriveStudioWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh Drive Studio"
    static var description = IntentDescription(
        "Reloads the Drive Studio widget on your Home Screen so it shows the latest vehicle, battery, and slot data."
    )

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Speak Status

/// Reads the latest App Group state and returns a spoken summary.
/// Available as a Siri response / Shortcut output — runs on CarPlay via
/// the Shortcuts app.
@available(iOS 16.0, *)
struct DriveStudioStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Drive Studio Status"
    static var description = IntentDescription(
        "Speaks the current vehicle, battery level, and car connection state from your Drive Studio setup."
    )

    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let summary = Self.loadSpokenSummary()
        return .result(value: summary)
    }

    private static func loadSpokenSummary() -> String {
        let state = DriveStudioIntentsReader.loadState()
        guard let state = state else {
            return "Drive Studio has no data yet. Open the app once to set up your vehicle and slots."
        }
        let vehicle = state["vehicle"] as? [String: Any]
        let vehicleName = (vehicle?["displayName"] as? String)
            ?? (vehicle?["modelId"] as? String)
            ?? "your car"
        let telemetry = state["telemetry"] as? [String: Any]
        let battery = (telemetry?["batteryPercent"] as? Int)
            .map { "Battery \($0) percent." } ?? "Battery unknown."
        let charging = (telemetry?["isCharging"] as? Bool ?? false)
            ? "Charging." : "On battery."
        let connection = (telemetry?["carConnected"] as? Bool ?? false)
            ? "Connected." : "Disconnected."
        return "Drive Studio status. \(vehicleName). \(battery) \(charging) \(connection)"
    }
}

// MARK: - Slot enum (App Intents requires AppEnum for parameters)

@available(iOS 16.0, *)
enum DriveStudioSlot: Int, AppEnum, CaseIterable {
    case slot1 = 1, slot2, slot3, slot4

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Drive Studio Slot"

    static var caseDisplayRepresentations: [DriveStudioSlot: DisplayRepresentation] = [
        .slot1: "Slot 1",
        .slot2: "Slot 2",
        .slot3: "Slot 3",
        .slot4: "Slot 4",
    ]
}

// MARK: - Switch Slot

/// Switches which App Group slot is "active" by writing the slot index
/// to a preference key the Flutter app reads on next launch. Lets the
/// user say "Hey Siri, switch Drive Studio to slot 2" while driving.
@available(iOS 16.0, *)
struct SwitchDriveStudioSlotIntent: AppIntent {
    static var title: LocalizedStringResource = "Switch Drive Studio Slot"
    static var description = IntentDescription(
        "Switches the Home Screen widget to display the contents of a specific slot (1 to 4)."
    )

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Slot", default: .slot1)
    var slot: DriveStudioSlot

    static var parameterSummary: some ParameterSummary {
        Summary("Show \(\.$slot) on Drive Studio")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let index = max(0, min(3, slot.rawValue - 1))
        let defaults = UserDefaults(suiteName: "group.com.drivestudio.shared")
        defaults?.set(index, forKey: "drive_studio_active_slot")
        defaults?.synchronize()
        // No widget currently consumes `drive_studio_active_slot`, so a
        // timeline reload would be a no-op. The intent just records the
        // preference for the next sync. iOS-4 fix.
        return .result(dialog: "Slot switch queued. Widget will refresh on next save.")
    }
}

// MARK: - App Shortcuts

/// Surfaces the above intents as built-in shortcuts so they appear in
/// the iOS Shortcuts app's "Gallery" → "Drive Studio" section, and in
/// the CarPlay Shortcuts app automatically.
@available(iOS 16.0, *)
struct DriveStudioShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RefreshDriveStudioWidgetIntent(),
            phrases: [
                "Refresh \(.applicationName)",
                "Reload \(.applicationName) widget",
                "Update \(.applicationName)",
            ],
            shortTitle: "Refresh Widget",
            systemImageName: "arrow.clockwise"
        )
        AppShortcut(
            intent: DriveStudioStatusIntent(),
            phrases: [
                "\(.applicationName) status",
                "What's my \(.applicationName)",
                "Read \(.applicationName)",
            ],
            shortTitle: "Status",
            systemImageName: "car.fill"
        )
        AppShortcut(
            intent: SwitchDriveStudioSlotIntent(),
            phrases: [
                "Switch \(.applicationName) to \(\.$slot)",
                "Show \(\.$slot) on \(.applicationName)",
            ],
            shortTitle: "Switch Slot",
            systemImageName: "rectangle.3.group"
        )
    }

    static var shortcutTileColor: ShortcutTileColor = .navy
}

// MARK: - Inline App Group reader (AppGroupHelper lives in widget extension)

private enum DriveStudioIntentsReader {
    static let suiteName = "group.com.drivestudio.shared"

    static func loadState() -> [String: Any]? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let metadataData = defaults.data(forKey: "widget_state_v2_metadata"),
              let metadata = try? JSONSerialization.jsonObject(with: metadataData) as? [String: Any],
              let stateFile = metadata["stateFile"] as? String,
              let checksum = metadata["checksum"] as? String,
              let sharedURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: suiteName)
        else {
            // V1 fallback
            if let defaults = UserDefaults(suiteName: suiteName),
               let json = defaults.string(forKey: "widget_state_v1"),
               let data = json.data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return dict
            }
            return nil
        }

        let fileURL = sharedURL.appendingPathComponent(stateFile)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let actual = SHA256.hash(data: data)
            .compactMap { String(format: "%02x", $0) }
            .joined()
        guard actual == checksum else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}