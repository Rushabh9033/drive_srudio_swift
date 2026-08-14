import UIKit
import SwiftUI
import WidgetKit
import CoreLocation

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // BGAppRefreshTask registration intentionally removed.
        //
        // Background refresh cannot provide real-time speed: iOS may
        // delay the task arbitrarily, skip it in low-power mode, and
        // only call it while the app is suspended (which is exactly
        // when GPS is not collecting). Its only previous effect was
        // to call WidgetCenter.reloadAllTimelines, which the host app
        // already does on every Core Location fix, every battery
        // change, and every scene-phase transition. Removing the task
        // is the smallest safe solution: telemetry freshness now comes
        // exclusively from foreground collection plus WidgetKit's
        // normal timeline policy.
        return true
    }
}

@main
struct DriveStudioApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = AppStore.shared

    @Environment(\.scenePhase) private var scenePhase

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
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                // Returning to foreground — let the widget see the
                // most recent foreground-collected telemetry.
                WidgetCenter.shared.reloadAllTimelines()
            default:
                break
            }
        }
    }
}
