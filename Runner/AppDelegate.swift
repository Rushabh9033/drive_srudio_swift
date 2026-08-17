import UIKit
import SwiftUI
import WidgetKit
import CoreLocation
import BackgroundTasks

final class AppDelegate: NSObject, UIApplicationDelegate {

    /// Identifier registered in Info.plist's
    /// `BGTaskSchedulerPermittedIdentifiers`. iOS will only invoke
    /// the handler if the identifier appears in both the plist and
    /// the registration call.
    static let refreshTaskIdentifier = "com.drivestudio.app.refresh"

    /// Earliest wall-clock delay before iOS will fire the next
    /// refresh. iOS is free to defer further; this is just a hint.
    /// 1 hour matches the app's natural "is the widget stale?"
    /// tolerance — battery headlines shift on the scale of minutes,
    /// not seconds — and stays inside Apple's typical battery-budget
    /// for third-party BGAppRefreshTask apps.
    static let refreshIntervalSeconds: TimeInterval = 60 * 60

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Register the BGAppRefreshTask handler BEFORE the app
        // finishes launching. iOS will only deliver the task to a
        // matching identifier that was registered in this window.
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.refreshTaskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Self.handleAppRefresh(refreshTask)
        }
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Eagerly schedule the next refresh the moment we go into
        // the background. iOS will queue the request and fire it
        // whenever conditions are right.
        Self.scheduleNextRefresh()
    }

    // MARK: - Background refresh handler

    /// Refreshes the App Group telemetry snapshot and reloads all
    /// widget timelines. Runs in ~30 s windows, so we keep the work
    /// to the smallest possible footprint: snapshot, save, reload,
    /// done. The widget extension then reads the new snapshot on
    /// its next render.
    static func handleAppRefresh(_ task: BGAppRefreshTask) {
        // Always re-queue the next refresh before doing any work.
        // If the work itself crashes or takes too long, we still
        // want the schedule continued.
        scheduleNextRefresh()

        // Capture the expiration handler up front so a slow run
        // still cancels cleanly even if it's mid-flight.
        let expirationWork = DispatchWorkItem {
            task.setTaskCompleted(success: false)
        }
        task.expirationHandler = {
            expirationWork.perform()
        }

        // Snapshot current telemetry + reload widgets. Both calls
        // are in-process and complete in well under a second.
        TelemetryService.shared.snapshotAndSave()
        WidgetCenter.shared.reloadAllTimelines()

        // Give the system hook a beat to settle, then mark success.
        DispatchQueue.main.async {
            task.setTaskCompleted(success: true)
        }
    }

    /// Asks iOS to schedule the next refresh. iOS may decide to
    /// delay further (Low Power Mode, thermal state, system load),
    /// but a successful submit at least registers our intent.
    static func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(
            identifier: Self.refreshTaskIdentifier
        )
        request.earliestBeginDate = Date(
            timeIntervalSinceNow: refreshIntervalSeconds
        )
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Common in the simulator: BGTaskScheduler is not
            // available. Production devices log and continue.
            #if DEBUG
            print("[BGTaskScheduler] submit failed: \(error.localizedDescription)")
            #endif
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
            case .active:
                // Returning to foreground — let the widget see the
                // most recent foreground-collected telemetry.
                WidgetReloadThrottle.shared.requestReload(kind: .foregroundActivation)
            default:
                break
            }
        }
    }
}
