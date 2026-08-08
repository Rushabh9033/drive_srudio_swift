import AppIntents
import WidgetKit

@available(iOS 16.0, *)
struct RefreshWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh Drive Studio Widgets"
    static var description = IntentDescription("Forces all Drive Studio widgets to reload their content immediately.")
    
    // Suggest this intent so it appears automatically in Shortcuts
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult {
        // Trigger WidgetKit to reload all timelines
        WidgetCenter.shared.reloadAllTimelines()
        
        return .result()
    }
}

@available(iOS 16.0, *)
struct DriveStudioShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RefreshWidgetIntent(),
            phrases: [
                "Refresh \(.applicationName) widgets",
                "Reload \(.applicationName)",
                "Update \(.applicationName)"
            ],
            shortTitle: "Refresh Widgets",
            systemImageName: "arrow.clockwise"
        )
    }
}
