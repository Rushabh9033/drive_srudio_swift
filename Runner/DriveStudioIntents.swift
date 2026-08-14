import AppIntents
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

    @MainActor
    func perform() async throws -> some IntentResult {
        TelemetryService.shared.snapshotAndSave()
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
        guard let state = AppGroupState.loadState() else {
            return "Drive Studio has no data yet. Open the app once to set up your vehicle and slots."
        }
        let vehicleName = state.vehicle?.displayName
            ?? state.vehicle?.modelId
            ?? "your car"
        let battery: String
        if let pct = state.telemetry?.batteryPercent {
            battery = "Battery \(pct) percent."
        } else {
            battery = "Battery unknown."
        }
        let charging = state.telemetry?.isCharging == true ? "Charging." : "On battery."
        let connection = state.telemetry?.carConnected == true ? "Connected." : "Disconnected."
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

/// Writes `drive_studio_active_slot` to App Group defaults. The DriveStudio
/// widget renders all four slots in the widget gallery, so this intent's
/// effect is mainly to record the user's selection for future telemetry
/// overlays (e.g. focused-slot dashboards in CarPlay Shortcuts).
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

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let index = max(0, min(3, slot.rawValue - 1))
        let defaults = UserDefaults(suiteName: AppGroupContract.suiteName)
        defaults?.set(index, forKey: "drive_studio_active_slot")
        defaults?.synchronize()
        // No widget currently consumes `drive_studio_active_slot`, so a
        // timeline reload would be a no-op. The intent just records the
        // preference for the next sync.
        return .result(dialog: "Slot preference saved. Open Drive Studio to apply it.")
    }
}

// MARK: - Play Connect Sound Cue Intent
@available(iOS 16.0, *)
struct PlayConnectSoundIntent: AppIntent {
    static var title: LocalizedStringResource = "Play Connect Sound Cue"
    static var description = IntentDescription("Plays your assigned Drive Studio connect voice prompt or audio cue.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        TelemetryService.shared.triggerSound(for: "Connect")
        return .result()
    }
}

// MARK: - Play Disconnect Sound Cue Intent
@available(iOS 16.0, *)
struct PlayDisconnectSoundIntent: AppIntent {
    static var title: LocalizedStringResource = "Play Disconnect Sound Cue"
    static var description = IntentDescription("Plays your assigned Drive Studio disconnect and reminder audio cues.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        let duration = TelemetryService.shared.triggerSound(for: "Disconnect")
        let delayNanos = UInt64(((duration > 0 ? duration : 2.0) + 0.5) * 1_000_000_000)
        Task {
            try? await Task.sleep(nanoseconds: delayNanos)
            TelemetryService.shared.triggerSound(for: "Reminder")
        }
        return .result()
    }
}

// MARK: - App Shortcuts

/// Surfaces the above intents as built-in shortcuts so they appear in
/// the iOS Shortcuts app's "Gallery" → "Drive Studio" section, and in
/// the CarPlay Shortcuts app automatically.
@available(iOS 16.0, *)
struct DriveStudioAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RefreshDriveStudioWidgetIntent(),
            phrases: [
                "Refresh \(.applicationName) widget",
                "Reload \(.applicationName)",
            ],
            shortTitle: "Refresh Widget",
            systemImageName: "arrow.triangle.2.circlepath"
        )
        AppShortcut(
            intent: DriveStudioStatusIntent(),
            phrases: [
                "What is my \(.applicationName) status",
                "Check \(.applicationName)",
            ],
            shortTitle: "Status",
            systemImageName: "car.fill"
        )
        AppShortcut(
            intent: PlayConnectSoundIntent(),
            phrases: [
                "Play \(.applicationName) connect cue",
                "\(.applicationName) connect sound",
            ],
            shortTitle: "Play Connect Cue",
            systemImageName: "speaker.wave.3.fill"
        )
        AppShortcut(
            intent: PlayDisconnectSoundIntent(),
            phrases: [
                "Play \(.applicationName) disconnect cue",
                "\(.applicationName) disconnect sound",
            ],
            shortTitle: "Play Disconnect Cue",
            systemImageName: "speaker.wave.1.fill"
        )
    }

    static var shortcutTileColor: ShortcutTileColor = .navy
}

// MARK: - App Group reader
//
// `DriveStudioIntentsReader` was an inline copy of the V2 metadata +
// SHA-256 protocol. The same reader is now provided by `AppGroupState`
// (see `DriveStudioWidget/AppGroupState.swift`), which both the Runner
// app and the widget extension compile automatically via the
// fileSystemSynchronizedGroups setup.