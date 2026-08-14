import UIKit
import SwiftUI
import WidgetKit
import BackgroundTasks
import CoreLocation

/// Background task identifier — must match the entry in Info.plist
/// `BGTaskSchedulerPermittedIdentifiers`. Used to schedule a periodic
/// "wake the app, refresh the widget timeline" job so the home-screen
/// widget shows current time/battery/speed even when the user hasn't
/// opened the app for hours.
let widgetRefreshTaskID = "com.drivestudio.app.driveStudio.refresh"

final class AppDelegate: NSObject, UIApplicationDelegate {
    /// Register the background-task handler as early as possible —
    /// `BGTaskScheduler.shared.register` MUST be called before the app
    /// finishes launching, otherwise iOS will silently drop the next
    /// scheduled refresh.
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: widgetRefreshTaskID, using: nil) { task in
            // Off the main thread — do the widget reload, then schedule
            // the next refresh so the cycle continues. Marking the task
            // `.succeeded` before `setTaskCompleted` causes iOS to call
            // the completion handler immediately.
            self.handleWidgetRefresh(task: task as! BGAppRefreshTask)
        }
        return true
    }

    /// Called when iOS wakes our app for the scheduled refresh.
    /// We refresh telemetry (writes a fresh `live_telemetry` to the App
    /// Group), poke the widget timeline, then schedule the next refresh.
    private func handleWidgetRefresh(task: BGAppRefreshTask) {
        // Reschedule first so the chain doesn't break if the body throws.
        scheduleNextWidgetRefresh()

        task.expirationHandler = {
            // iOS is about to suspend us; nothing to clean up here.
            task.setTaskCompleted(success: false)
        }

        // Refresh telemetry on the main actor (TelemetryService writes
        // to the App Group + calls reloadAllTimelines). Then mirror the
        // reload here so the widget refresh happens even if telemetry
        // hasn't changed.
        Task { @MainActor in
            AppStore.shared.refreshDeviceTelemetry()
            WidgetCenter.shared.reloadAllTimelines()
            task.setTaskCompleted(success: true)
        }
    }

    /// Schedule another refresh ~15 minutes from now. iOS will run it
    /// opportunistically — exact timing depends on usage, charge state,
    /// and Low Power Mode. Asking for less than 15 min is silently
    /// clamped by the system.
    func scheduleNextWidgetRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: widgetRefreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Common causes: identifier not in Info.plist, low-power mode,
            // background refresh disabled in Settings. Log and bail.
            print("[AppDelegate] ⚠️ Could not schedule widget refresh: \(error)")
        }
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
            case .background:
                // Background fires when the user leaves the app — schedule
                // a widget refresh so the timeline gets reloaded by the
                // system within ~15 min while we're suspended.
                appDelegate.scheduleNextWidgetRefresh()
            case .active:
                // Returning to foreground — make sure the widget reflects
                // any pending state immediately.
                WidgetCenter.shared.reloadAllTimelines()
            default:
                break
            }
        }
    }
}
