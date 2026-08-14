import UIKit
import SwiftUI
import WidgetKit
import BackgroundTasks
import CoreLocation

/// Background refresh task identifier. Must match the value declared in
/// `Runner/Info.plist` under `BGTaskSchedulerPermittedIdentifiers`.
///
/// IMPORTANT — what this task is and is not:
///   * It is an *opportunistic* aid, not a real-time refresh
///     mechanism. iOS controls when (and whether) the task actually
///     runs. `earliestBeginDate` is a *hint*; the system may delay it
///     indefinitely or skip it entirely (low-power mode, background
///     app refresh disabled, system pressure, etc.).
///   * It does not collect GPS while the app is suspended. It only
///     calls `WidgetCenter.reloadAllTimelines` so the widget reads the
///     most recent telemetry the host app already wrote.
///   * It does not update speed while suspended. Speed updates only
///     happen while the host app is running in the foreground (or in
///     a future explicit Drive Mode, which is reserved for a later
///     milestone).
let widgetRefreshTaskID = "com.drivestudio.app.driveStudio.refresh"

final class AppDelegate: NSObject, UIApplicationDelegate {

    /// Set when a `BGAppRefreshTaskRequest` has been submitted but the
    /// system hasn't run it yet. Prevents piling up duplicate pending
    /// requests for the same identifier (each duplicate is a wasted
    /// scheduling slot).
    private var hasPendingRefreshRequest = false
    private let refreshLock = NSLock()

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // `BGTaskScheduler.shared.register` MUST be called before the
        // app finishes launching — otherwise iOS silently drops every
        // subsequent request for this identifier.
        BGTaskScheduler.shared.register(forTaskWithIdentifier: widgetRefreshTaskID, using: nil) { task in
            self.handleWidgetRefresh(task: task as! BGAppRefreshTask)
        }
        return true
    }

    /// Called by iOS when it decides to wake us up. We do not collect
    /// GPS, start a sound, or do anything that requires sustained
    /// background execution — the system budget for a BGAppRefreshTask
    /// is short and unpredictable.
    private func handleWidgetRefresh(task: BGAppRefreshTask) {
        // The pending flag must clear here regardless of whether we
        // successfully reschedule, otherwise we would never submit a
        // fresh request again.
        clearPendingRequest()

        // Reschedule first so the chain doesn't break if the body of
        // the task errors out before the system suspends us.
        scheduleNextWidgetRefresh()

        var didComplete = false
        let complete: (Bool) -> Void = { success in
            // Ensure the task is completed exactly once, even if both
            // the expiration handler and the body race for it.
            guard !didComplete else { return }
            didComplete = true
            task.setTaskCompleted(success: success)
        }

        task.expirationHandler = {
            // iOS is about to suspend us. Mark the task unsuccessful
            // but do not start any new work — the budget is gone.
            complete(false)
        }

        Task { @MainActor in
            AppStore.shared.refreshDeviceTelemetry()
            WidgetCenter.shared.reloadAllTimelines()
            complete(true)
        }
    }

    /// Schedule another refresh ~15 minutes from now. iOS may delay
    /// this arbitrarily. We dedupe so we never have more than one
    /// outstanding request for this identifier.
    func scheduleNextWidgetRefresh() {
        refreshLock.lock()
        if hasPendingRefreshRequest {
            refreshLock.unlock()
            return
        }
        hasPendingRefreshRequest = true
        refreshLock.unlock()

        let request = BGAppRefreshTaskRequest(identifier: widgetRefreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Common causes: identifier not in Info.plist, low-power
            // mode, background refresh disabled in Settings. Clear the
            // pending flag so we can try again on the next scenePhase
            // transition.
            clearPendingRequest()
            print("[AppDelegate] ⚠️ Could not schedule widget refresh: \(error)")
        }
    }

    private func clearPendingRequest() {
        refreshLock.lock()
        hasPendingRefreshRequest = false
        refreshLock.unlock()
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
                // Background fires when the user leaves the app. We ask
                // the system to schedule an opportunistic refresh; iOS
                // decides whether and when to actually run it.
                appDelegate.scheduleNextWidgetRefresh()
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