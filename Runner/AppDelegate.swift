import SwiftUI
import WidgetKit
import CoreLocation
import AppIntents

@main
struct DriveStudioApp: App {
    @StateObject private var store = AppStore.shared

    init() {
        TelemetryService.shared.startMonitoring()
        WidgetCenter.shared.reloadAllTimelines()
        if #available(iOS 16.0, *) {
            DriveStudioAppShortcuts.updateAppShortcutParameters()
        }
    }

    var body: some Scene {
        WindowGroup {
            HomeScreen()
                .environmentObject(store)
        }
    }
}