import Foundation
import CoreLocation
import UIKit
import WidgetKit
import AVFoundation

extension Notification.Name {
    /// Posted by `TelemetryService` on every CLLocation fix whose speed
    /// differs from the last one. View code subscribes to this and bumps
    /// a `@State` int so SwiftUI re-reads `currentSpeed` synchronously —
    /// the editor canvas then feels like Google Maps: every GPS sample
    /// triggers a redraw, no 60-second timer gating.
    static let telemetrySpeedUpdated = Notification.Name("telemetrySpeedUpdated")

    /// Posted whenever CL authorization status changes (initial prompt
    /// result, Settings round-trip, restriction flips). Dashboard view
    /// re-reads `CLLocationManager.authorizationStatus()` in response.
    static let locationAuthorizationChanged = Notification.Name("locationAuthorizationChanged")
}

@objc class TelemetryService: NSObject, CLLocationManagerDelegate, AVAudioPlayerDelegate {
    static let shared = TelemetryService()

    /// Heartbeat interval for telemetry persistence writes that are
    /// driven by "nothing visibly changed". Keeps the App Group
    /// blob's `timestamp` fresh without writing several times per
    /// second while the device is stationary.
    static let heartbeatPersistenceInterval: TimeInterval = 30.0

    /// Smallest speed delta (km/h) that justifies an immediate
    /// persistence write. Sub-threshold deltas ride the heartbeat
    /// instead so a parked phone with GPS jitter doesn't burn
    /// through `defaults.set` calls.
    static let significantSpeedDelta: Double = 1.0

    /// Speed (m/s) above which the user is considered "actually
    /// moving" for the `carConnected` auto-detect heuristic. ~7 km/h.
    /// Above walking pace and well above stationary GPS noise, so
    /// a phone sitting on a desk (or drifting at <2 m/s) doesn't
    /// continually refresh `lastNonNilSpeedAt` and starve the 5-min
    /// auto-flip-off countdown.
    static let movementSpeedThreshold: Double = 2.0

    /// Pure decision output. Decoupled from `WidgetCenter` so the
    /// policy can be unit-tested without ever touching real
    /// WidgetKit. The `reloadKind` is `nil` when no reload should
    /// be requested at all (e.g. an unchanged reading within the
    /// heartbeat window where persistence is also being skipped).
    struct PersistenceDecision: Equatable {
        let shouldPersist: Bool
        let reloadKind: WidgetReloadKind?
        let timestamp: Date

        static func == (lhs: PersistenceDecision,
                        rhs: PersistenceDecision) -> Bool {
            return lhs.shouldPersist == rhs.shouldPersist
                && lhs.reloadKind == rhs.reloadKind
                && lhs.timestamp == rhs.timestamp
        }
    }

    /// Pure telemetry persistence policy. No I/O, no shared state,
    /// no `WidgetCenter`. The production code calls this from
    /// `persistTelemetryIfMeaningful(...)` after gathering device
    /// readings; tests call it directly with synthetic inputs to
    /// verify exact reload-kind selection without spinning up a
    /// real `TelemetryService`.
    ///
    /// Reload-kind selection (priority order):
    /// 1. `chargingStateChange` if `isCharging` flipped.
    /// 2. `connectionStateChange` if `carConnected` flipped.
    /// 3. `batteryLevelChange` if `batteryPercent` flipped.
    /// 4. `speedChange` if speed is available (non-nil) AND either
    ///    (a) availability flipped (nil ↔ non-nil) or (b) speed
    ///    drifted ≥ `significantSpeedDelta` from baseline or (c) the
    ///    trigger was a heartbeat (which means the persisted
    ///    timestamp is freshening and the widget needs to know the
    ///    speed is still valid — otherwise the freshness policy
    ///    would expire the speed after five minutes of GPS activity
    ///    while the foreground app continues to heartbeat).
    /// 5. `noVisibleChange` for heartbeat with unavailable speed
    ///    and no other visible change (e.g. the device is
    ///    stationary and the GPS fix has not arrived yet).
    /// 6. `nil` for the "do not persist and do not reload" case.
    enum TelemetryPersistencePolicy {
        struct SnapshotShape: Equatable {
            let carConnected: Bool
            let batteryPercent: Int?
            let isCharging: Bool
            let speed: Double?
        }

        static func evaluate(
            now: Date,
            currentSpeed: Double?,
            batteryPercent: Int?,
            isCharging: Bool,
            carConnected: Bool,
            previousSnapshot: SnapshotShape?,
            lastPersistenceDate: Date?,
            heartbeatInterval: TimeInterval,
            significantSpeedDelta: Double
        ) -> PersistenceDecision {
            let firstSnapshot = (previousSnapshot == nil)

            let batteryChanged = previousSnapshot?.batteryPercent != batteryPercent
            let chargingChanged = previousSnapshot?.isCharging != isCharging
            let connectionChanged = previousSnapshot?.carConnected != carConnected
            let availabilityChanged = (previousSnapshot?.speed == nil)
                != (currentSpeed == nil)

            let speedDeltaAgainstBaseline: Double = {
                guard let baseline = previousSnapshot?.speed,
                      let current = currentSpeed else { return 0 }
                return abs(current - baseline)
            }()
            let speedMeaningful = speedDeltaAgainstBaseline >= significantSpeedDelta

            let heartbeatDue: Bool = {
                guard let last = lastPersistenceDate else { return true }
                return now.timeIntervalSince(last) >= heartbeatInterval
            }()

            let shouldPersist = firstSnapshot
                || batteryChanged || chargingChanged
                || connectionChanged || availabilityChanged
                || speedMeaningful || heartbeatDue

            // No persist → no reload. Avoids burning WidgetKit
            // budget for telemetry that did not actually change.
            guard shouldPersist else {
                return PersistenceDecision(
                    shouldPersist: false,
                    reloadKind: nil,
                    timestamp: now
                )
            }

            let reloadKind: WidgetReloadKind?
            if chargingChanged {
                reloadKind = .chargingStateChange
            } else if connectionChanged {
                reloadKind = .connectionStateChange
            } else if batteryChanged {
                reloadKind = .batteryLevelChange
            } else if speedMeaningful || availabilityChanged {
                reloadKind = .speedChange
            } else if currentSpeed != nil {
                // Heartbeat with valid speed: keep the widget's
                // freshness timer alive by going through the
                // `.speedChange` rate-limited path. Without this,
                // `WidgetSnapshotFreshness` would expire the speed
                // after five minutes of GPS activity even though the
                // foreground keeps publishing heartbeat snapshots.
                reloadKind = .speedChange
            } else {
                // Heartbeat with unavailable speed and no other
                // visible change: nothing for the widget to render
                // differently. Throttle performs zero reloads.
                reloadKind = .noVisibleChange
            }

            return PersistenceDecision(
                shouldPersist: true,
                reloadKind: reloadKind,
                timestamp: now
            )
        }
    }

    private let locationManager = CLLocationManager()
    /// Latest GPS speed in km/h, exactly as Core Location reported it.
    /// `nil` means there is no valid fix yet. A genuine `0` means the
    /// phone is stationary with a valid fix — it is NOT the same as
    /// "unknown". Widgets must distinguish the two cases.
    var currentSpeed: Double? = nil
    private var audioPlayer: AVAudioPlayer?
    private var audioDelegate: TelemetryAudioDelegate?

    /// Test seam. Production code uses `Date()`; tests inject a
    /// mutable closure so they can drive the heartbeat policy
    /// deterministically.
    private let clock: () -> Date
    /// Timestamp of the most recent persistence write to App Group
    /// defaults. Cleared by `resetPersistenceState()` between tests.
    private var lastPersistenceDate: Date? = nil

    /// Test seam. Production code calls
    /// `WidgetReloadThrottle.shared.requestReload(kind:now:)`; tests
    /// inject a counting closure so they can assert exact
    /// `WidgetCenter` call counts without ever touching real
    /// WidgetKit. The closure receives the same `(kind, now)`
    /// tuple that production would feed to the throttle.
    var reloadRequester: ((WidgetReloadKind, Date) -> Void)?

    private var lastWasConnected: Bool = false

    /// Wall-clock instant of the most recent GPS fix whose speed
    /// passed the "actually moving" threshold
    /// (`Self.movementSpeedThreshold`). The auto-detect heuristic uses
    /// this to decide whether the user has been stationary long
    /// enough that the "Car link" status should auto-flip to false —
    /// see `snapshotAndSave`.
    ///
    /// Crucially this is NOT updated on every valid speed sample —
    /// CLLocation reports small positive speeds (≤1 m/s) due to GPS
    /// noise even when the phone is genuinely stationary on a desk,
    /// which would otherwise keep refreshing this timestamp and
    /// starve the 5-min auto-flip-off countdown.
    ///
    /// `nil` means "we haven't seen above-threshold movement yet this
    /// session." Internal (not `private`) so tests using
    /// `@testable import Runner` can drive the heuristic
    /// deterministically.
    var lastNonNilSpeedAt: Date? = nil

    /// Wall-clock instant this service was instantiated. Used as a
    /// fallback for the auto-flip-off countdown when there has NEVER
    /// been a movement sample — e.g. the user is testing in a
    /// simulator, or has the app open indoors with no GPS signal. In
    /// that case the @AppStorage seed would otherwise pin
    /// `carConnected = true` forever because `lastNonNilSpeedAt`
    /// stays `nil`. After 5 minutes from launch with no movement,
    /// the heuristic flips it off.
    var serviceStartedAt: Date = Date()

    /// Whether the phone currently considers itself connected to a car
    /// (CarPlay, Bluetooth, or USB). Surfaced honestly to widgets via
    /// `snapshotAndSave`. Mutable so the Settings screen toggle and the
    /// App Intents "Switch Slot" intent can affect what widgets show.
    ///
    /// The auto-detect heuristic writes this too: a fresh valid
    /// GPS speed flips it to `true` (user is moving → driving), and
    /// 5 minutes of no valid speed flips it to `false` (user stopped).
    /// The Settings toggle can override at any time; the heuristic
    /// simply re-applies on the next speed update or heartbeat.
    var carConnected: Bool = false

    private let suiteName = AppGroupContract.suiteName

    private override init() {
        self.clock = { Date() }
        super.init()
        Self.configureShared(self)
        // Production reload path goes through the shared throttle.
        // The throttle itself handles rate limiting; we only forward
        // `(kind, now)` and trust it not to call `WidgetCenter` more
        // than once per five minutes for `.speedChange`.
        self.reloadRequester = { kind, now in
            if #available(iOS 14.0, *) {
                WidgetReloadThrottle.shared.requestReload(kind: kind, now: now)
            }
        }
    }

    /// Designated test initializer. Pass a fixed-clock closure (or a
    /// mutable-reference closure) to drive the heartbeat policy
    /// deterministically. Production code uses `TelemetryService.shared`,
    /// which is constructed with the real-clock initializer.
    internal init(clock: @escaping () -> Date) {
        self.clock = clock
        super.init()
        Self.configureShared(self)
        // Tests can override `reloadRequester` directly after init.
        self.reloadRequester = nil
    }

    /// Reset persistence state. Test-only — production code never
    /// resets `lastPersistenceDate` outside the heartbeat cadence.
    func resetPersistenceState() {
        lastPersistenceDate = nil
        currentSpeed = nil
        lastNonNilSpeedAt = nil
        serviceStartedAt = Date()
    }

    private static func configureShared(_ service: TelemetryService) {
        UIDevice.current.isBatteryMonitoringEnabled = true

        service.locationManager.delegate = service
        service.locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        service.locationManager.activityType = .automotiveNavigation
        service.locationManager.distanceFilter = kCLDistanceFilterNone
        service.locationManager.pausesLocationUpdatesAutomatically = false
        // **Background GPS for real-time widget updates.** With the
        // `location` UIBackgroundModes entry declared in Info.plist
        // and a granted Always authorization, this lets CLLocationManager
        // keep delivering fixes while the app is in the background.
        // Each fix updates the App Group telemetry snapshot and
        // requests a widget reload so the home-screen speedometer
        // reflects real-time speed without the user opening the app.
        //
        // Apple REQUIRES `allowsBackgroundLocationUpdates = true` for
        // background GPS to fire. It also requires the matching
        // UIBackgroundModes entry AND a granted Always authorization;
        // if any of those three is missing, iOS silently suspends the
        // location updates within minutes of backgrounding.
        service.locationManager.allowsBackgroundLocationUpdates = true
        service.locationManager.showsBackgroundLocationIndicator = false

        // **No automatic permission request at init.**
        // iOS permission prompts are only shown in response to an
        // explicit user action. `beginLocationIfAuthorized()` is the
        // production entry point — it inspects the current
        // authorization, requests When-In-Use if undetermined, and
        // either begins monitoring (when granted) or surfaces a
        // "denied" state that the Dashboard renders with a Settings
        // shortcut. We upgrade to Always once When-In-Use is granted
        // (see `locationManagerDidChangeAuthorization`).
    }

    /// Explicit, user-driven entry point. Call from a button in
    /// DashboardView's GPS status row. Inspects the current
    /// authorization, requests When-In-Use if undetermined, and starts
    /// monitoring if granted. Returns the resulting status so the UI
    /// can reflect what actually happened.
    @discardableResult
    func beginLocationIfAuthorized() -> LocationAuthorizationOutcome {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            // Already authorized — start monitoring immediately.
            locationManager.startUpdatingLocation()
            NotificationCenter.default.post(name: .locationAuthorizationChanged, object: self)
            return .startedMonitoring
        case .notDetermined:
            // Show the system prompt on this user-driven action.
            locationManager.requestWhenInUseAuthorization()
            // The delegate callback will deliver the next state via
            // `locationManagerDidChangeAuthorization`.
            return .promptPresented
        case .denied, .restricted:
            // No silent retry, no Always fallback — caller must open
            // Settings for the user to change their mind.
            NotificationCenter.default.post(name: .locationAuthorizationChanged, object: self)
            return .denied
        @unknown default:
            return .denied
        }
    }

    /// Stop monitoring. Idempotent — safe to call from the
    /// scenePhase == .background transition.
    func stopMonitoring() {
        locationManager.stopUpdatingLocation()
    }

    /// Re-arm monitoring after a Settings round-trip or after a
    /// successful authorization prompt. Idempotent.
    ///
    /// **Never presents a permission prompt.** Only starts Core
    /// Location updates when the user has already granted When-In-Use
    /// or Always authorization. When authorization is undetermined,
    /// denied, or restricted, this method is a silent no-op — the
    /// user must tap the Dashboard's "Enable GPS speed" button (which
    /// routes through `beginLocationIfAuthorized()`) to actually
    /// surface the system permission dialog.
    func startMonitoring() {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
        case .notDetermined, .denied, .restricted:
            // No prompt, no fallback to `beginLocationIfAuthorized`.
            // The Dashboard button is the only path that may present
            // the When-In-Use dialog.
            break
        @unknown default:
            break
        }
    }

    // MARK: - CLLocationManagerDelegate
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // React to any authorization change (initial prompt result,
        // Settings round-trip, restriction flips).
        switch manager.authorizationStatus {
        case .authorizedAlways:
            // Full background-GPS authority. Start monitoring and
            // remember the upgrade so we don't re-prompt.
            manager.startUpdatingLocation()
        case .authorizedWhenInUse:
            // Foreground-only. Start monitoring so the in-app
            // dashboard and foreground widgets work, and ask the
            // user to upgrade to Always so the widget also updates
            // when the app is backgrounded. iOS shows the second-step
            // "Always Allow" prompt; the user can decline and we
            // fall back to When-In-Use (which still works while the
            // app is open).
            manager.startUpdatingLocation()
            manager.requestAlwaysAuthorization()
        case .denied, .restricted:
            manager.stopUpdatingLocation()
        case .notDetermined:
            break
        @unknown default:
            break
        }
        NotificationCenter.default.post(name: .locationAuthorizationChanged, object: self)
    }

    /// Outcome of `beginLocationIfAuthorized()`. Honest, no fake
    /// "started monitoring" claims when the prompt is still pending.
    enum LocationAuthorizationOutcome: Equatable {
        /// Authorization was already granted; monitoring is running.
        case startedMonitoring
        /// The system When-In-Use prompt was just presented; result
        /// arrives via `locationManagerDidChangeAuthorization`.
        case promptPresented
        /// Authorization is denied or restricted; UI must offer the
        /// user a route to Settings.
        case denied
    }

    // MARK: - Core Location Delegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        // Core Location reports negative `speed` when it does not yet
        // have a confident fix. We treat that as "no speed available"
        // rather than coercing to 0.
        let prevSpeed = currentSpeed
        if location.speed >= 0 {
            currentSpeed = location.speed * 3.6
        } else {
            currentSpeed = nil
        }
        // **Auto-detect "car linked" from GPS movement.** A speed
        // sample above the "actually moving" threshold means the user
        // is driving — flip `carConnected` to true so the Dashboard
        // reflects what the user is actually doing, not just whatever
        // the Settings toggle last said. Without CarPlay / Bluetooth
        // entitlements we have no way to know if a cable is plugged
        // in, but we CAN observe real motion, which is the more
        // useful signal for a driving-mode widget.
        //
        // We require > 2 m/s (~7 km/h) so GPS noise on a stationary
        // phone doesn't continually refresh `lastNonNilSpeedAt` and
        // starve the 5-min auto-flip-off countdown. Walking pace and
        // idle desk drift both fall below this.
        if let spd = currentSpeed, spd > Self.movementSpeedThreshold {
            lastNonNilSpeedAt = Date()
            if !carConnected {
                carConnected = true
            }
        }
        // **Foreground UI keeps feeling live.** Every real speed
        // change triggers a notification so SwiftUI re-renders. This
        // is independent of persistence — the App Group blob is
        // NOT written here. `persistTelemetryIfMeaningful` is what
        // decides whether the on-disk defaults change.
        if prevSpeed != currentSpeed {
            NotificationCenter.default.post(name: .telemetrySpeedUpdated, object: self)
        }
        persistTelemetryIfMeaningful(previousSpeed: prevSpeed)

        // **Live Activity (Dynamic Island + Lock Screen).** Fire on
        // every GPS update so the coordinator can decide whether to
        // start a new activity, push an update, or end. The
        // coordinator is internally rate-limited and gated on the
        // `ActivityAuthorizationInfo.areActivitiesEnabled` system
        // switch, so this is safe to call on every fix.
        if #available(iOS 16.1, *) {
            LiveActivityCoordinator.shared.onTelemetryUpdate()
        }
    }

    // MARK: - Play Sound Cues
    @discardableResult
    func triggerSound(for trigger: String) -> Double {
        let defaults = UserDefaults(suiteName: suiteName)
        // Resolve the user's assigned cue without force-unwrapping the
        // `String?` lookup result. A missing assignment falls back to
        // the bundled default for that trigger; "none" means "user
        // explicitly silenced this cue" and we return zero.
        let assigned = defaults?.string(forKey: "trigger_\(trigger)")
        let resolved: String
        if let assigned = assigned, !assigned.isEmpty, assigned != "none" {
            resolved = assigned
        } else {
            resolved = fallbackSound(for: trigger)
        }
        guard resolved != "none" else { return 0.0 }
        return playSoundByName(resolved)
    }

    private func fallbackSound(for trigger: String) -> String {
        switch trigger {
        case "Connect": return "Welcome Back"
        case "Disconnect": return "Goodbye"
        case "Reminder": return "Phone Keys Wallet"
        default: return "none"
        }
    }

    @discardableResult
    func playSoundByName(_ name: String) -> Double {
        let fm = FileManager.default
        var targetURL: URL? = nil
        let targetNameClean = name.lowercased().replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "-", with: "_")

        var searchDirectories: [URL] = []
        if let shared = fm.containerURL(forSecurityApplicationGroupIdentifier: suiteName) {
            searchDirectories.append(shared)
        }
        if let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            searchDirectories.append(docs)
        }

        // Minimum length for a substring match. Shorter than this and
        // almost any file in the directory would match (e.g. "a" matches
        // "Waze", "Phone Keys Wallet", "Welcome Back" — three unrelated
        // files). We require exact-or-substantial matches only.
        let kMinSubstringMatch = 4

        // 1. Search App Group & Documents directory for Custom / Mic / TTS sound files
        for dir in searchDirectories {
            if let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                for file in files {
                    let ext = file.pathExtension.lowercased()
                    guard ["wav", "mp3", "m4a", "caf"].contains(ext) else { continue }

                    let fname = file.deletingPathExtension().lastPathComponent.lowercased()
                    let cleanFname = fname.replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "-", with: "_")

                    if Self.soundFileMatches(
                        cleanFname: cleanFname,
                        target: targetNameClean,
                        minSubstringLength: kMinSubstringMatch
                    ) {
                        targetURL = file
                        break
                    }
                }
            }
            if targetURL != nil { break }
        }

        // 2. Search Bundle Resources for Stock Sounds
        if targetURL == nil {
            if let urls = Bundle.main.urls(forResourcesWithExtension: "wav", subdirectory: nil) {
                for u in urls {
                    let fname = u.deletingPathExtension().lastPathComponent.lowercased()
                    if Self.soundFileMatches(
                        cleanFname: fname,
                        target: targetNameClean,
                        minSubstringLength: kMinSubstringMatch
                    ) {
                        targetURL = u
                        break
                    }
                }
            }
        }

        guard let soundURL = targetURL else {
            print("[TelemetryService] ⚠️ Could not find sound URL for: \(name)")
            return 0.0
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .default, options: [.allowBluetoothA2DP, .mixWithOthers])
            try? session.overrideOutputAudioPort(.none)
            try? session.setActive(true)

            // Replace any in-flight player. Stop it first so its
            // delegate doesn't fire a stale finish callback that
            // would prematurely deactivate the session we just
            // activated for the new sound.
            audioPlayer?.stop()
            audioPlayer = nil
            audioDelegate?.invalidate()
            let delegate = TelemetryAudioDelegate(owner: self)
            self.audioDelegate = delegate

            let player = try AVAudioPlayer(contentsOf: soundURL)
            player.volume = 0.85
            player.delegate = delegate
            player.prepareToPlay()
            player.play()
            audioPlayer = player
            let duration = player.duration
            print("[TelemetryService] 🔊 Playing custom/TTS sound (\(duration)s): \(soundURL.lastPathComponent)")

            // **AVAudioSession lifecycle.** We don't deactivate the
            // session here — we let `audioPlayerDidFinishPlaying`
            // (or the player being replaced by the next call) handle
            // it. But we DO log if `setActive(true)` failed so the
            // cause of any silent playback is visible in the console.
            if session.category != .playback {
                print("[TelemetryService] ⚠️ Audio session category is \(session.category.rawValue), expected .playback")
            }
            return duration
        } catch {
            print("[TelemetryService] ❌ AVAudioPlayer failed (\(error)), falling back to SystemSound")
            // **Fallback system sound.** `AudioServicesPlaySystemSound`
            // does not use the `AVAudioSession`, so we must release
            // the `.playback` session we activated above. If we don't,
            // the session stays active until the host app is killed —
            // exactly the leak we are closing here.
            try? AVAudioSession.sharedInstance().setActive(false,
                options: [.notifyOthersOnDeactivation])
            audioPlayer = nil
            audioDelegate?.invalidate()
            var soundID: SystemSoundID = 0
            AudioServicesCreateSystemSoundID(soundURL as CFURL, &soundID)
            AudioServicesPlaySystemSound(soundID)
            return 2.0
        }
    }

    // MARK: - AVAudioPlayerDelegate
    //
    // The delegate methods are routed through `TelemetryAudioDelegate`
    // (a small NSObject proxy) so the player retains a strong
    // reference to its delegate — the player does not retain its
    // delegate, so without the proxy the delegate would be
    // deallocated immediately and the finish callback would never
    // fire. The proxy calls back into this service to deactivate the
    // session once playback actually completes (success or failure).
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        deactivatePlaybackSession(reason: "finished")
        if audioPlayer === player {
            audioPlayer = nil
        }
        audioDelegate?.invalidate()
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("[TelemetryService] ❌ AVAudioPlayer decode error: \(error?.localizedDescription ?? "unknown")")
        deactivatePlaybackSession(reason: "decode error")
        if audioPlayer === player {
            audioPlayer = nil
        }
        audioDelegate?.invalidate()
    }

    /// Deactivate the shared `AVAudioSession` after playback has
    /// ended, failed, or been replaced. Uses
    /// `.notifyOthersOnDeactivation` so any other app that was
    /// ducked under our session (Music, Maps navigation) can resume
    /// immediately. Safe to call when the session is already
    /// inactive — `setActive(false)` is a no-op in that case.
    private func deactivatePlaybackSession(reason: String) {
        let session = AVAudioSession.sharedInstance()
        // Only deactivate if we actually own a `.playback` session.
        // If a mic recording is currently active (`.playAndRecord`),
        // we MUST NOT deactivate — that would interrupt the user's
        // recording. The mic session takes precedence.
        if session.category == .playAndRecord || session.category == .record {
            return
        }
        do {
            try session.setActive(false, options: [.notifyOthersOnDeactivation])
            print("[TelemetryService] 🔇 Audio session deactivated (\(reason))")
        } catch {
            print("[TelemetryService] ⚠️ Failed to deactivate audio session (\(reason)): \(error)")
        }
    }

    /// Decide whether a candidate file (whose name, lowercased + with
    /// `_`/`-` collapsed, is `cleanFname`) matches the user's requested
    /// sound name (`target`). Exact matches always pass. Substring
    /// matches in either direction require both strings to be at least
    /// `minSubstringLength` characters — otherwise a request like
    /// `"Phone Keys Wallet"` would also match files named
    /// `"Waze"`, `"Tesla"`, etc., which is never what the user wants.
    private static func soundFileMatches(
        cleanFname: String,
        target: String,
        minSubstringLength: Int
    ) -> Bool {
        if cleanFname == target { return true }
        // Only one direction can win for very short names. Require both
        // the target and the candidate to be at least the minimum length
        // before we accept a "contains" match in either direction.
        let allowSubstring = target.count >= minSubstringLength
                        && cleanFname.count >= minSubstringLength
        guard allowSubstring else { return false }
        return cleanFname.contains(target) || target.contains(cleanFname)
    }

    // MARK: - Save Telemetry Snapshot
    /// Public entry point — preserved for callers (`AppStore` and the
    /// "Refresh Drive Studio" intent) that want a guaranteed
    /// persistence pass. Delegates to the meaningful-change policy
    /// so callers get the throttled behavior for free.
    func snapshotAndSave() {
        persistTelemetryIfMeaningful(previousSpeed: currentSpeed)
    }

    /// Write the current telemetry to App Group defaults only when:
    ///
    ///   1. **First valid snapshot** — when no previous telemetry
    ///      exists in App Group defaults, persist immediately so
    ///      the widget has something to render.
    ///   2. A widget-visible signal flipped (battery %, charging,
    ///      carConnected, speed availability nil↔non-nil).
    ///   3. Speed changed by ≥ `significantSpeedDelta` km/h from the
    ///      **last persisted** snapshot. Comparing against the
    ///      persisted baseline (not just the immediately previous
    ///      GPS sample) prevents many sub-1 km/h fixes from
    ///      forever evading persistence: once the accumulated drift
    ///      from the persisted baseline reaches the threshold we
    ///      persist and reset the baseline.
    ///   4. The heartbeat window (`heartbeatPersistenceInterval`)
    ///      has elapsed since the last write.
    ///
    /// In every other case the in-memory `currentSpeed` and the UI
    /// notification already give the foreground the latest reading;
    /// the App Group blob is left alone so a parked device with GPS
    /// jitter doesn't write defaults 5+ times per second. Widget
    /// reload throttling is handled separately by
    /// `WidgetReloadThrottle.shared.requestReload(kind:)` below.
    private func persistTelemetryIfMeaningful(
        previousSpeed: Double?,
        batteryOverride: Int? = nil,
        chargingOverride: Bool? = nil,
        connectionOverride: Bool? = nil
    ) {
        let now = clock()
        let device = UIDevice.current
        let level = device.batteryLevel
        // Unknown battery (`batteryLevel == -1`) is propagated as
        // `nil`. We never substitute a fake value. Test overrides
        // bypass the device read so simulator tests can simulate
        // transitions.
        let batteryPercent: Int? = batteryOverride
            ?? (level >= 0 ? Int(level * 100) : nil)
        // Exact current charging state. Do not OR with any previously
        // cached state — if the device just unplugged, this must
        // flip to false on the next snapshot.
        let isCharging = chargingOverride
            ?? (device.batteryState == .charging
                || device.batteryState == .full)
        // Apply the test-only override to the in-memory state BEFORE
        // the auto-flip runs. Production never passes a
        // `connectionOverride`, so this is a no-op in production.
        // Tests pass `true` to seed specific scenarios; the auto-flip
        // still runs on top of the override so an override that
        // conflicts with the elapsed-time countdown still gets
        // corrected.
        if let override = connectionOverride {
            carConnected = override
        }

        // **Auto-detect "car unlinked" from sustained no-movement.**
        // Two cases flip `carConnected` to false:
        //
        //   1. The user was moving (`lastNonNilSpeedAt` is set) but
        //      hasn't reported motion for >5 minutes. Without CarPlay
        //      entitlements we can't observe the cable unplug, but we
        //      CAN observe that the phone stopped reporting motion.
        //      The 5-min window absorbs brief stationary intervals
        //      (red lights, pull-overs).
        //
        //   2. We've NEVER seen above-threshold movement this session
        //      (simulator, indoors, no GPS signal). In that case
        //      `lastNonNilSpeedAt` is nil and case 1 would skip —
        //      falling back to `serviceStartedAt` ensures the
        //      `@AppStorage` seed doesn't pin `carConnected = true`
        //      forever on devices with no real GPS.
        //
        // The auto-flip MUST run before the policy + snapshot write
        // (see below) so the persisted snapshot reflects the new
        // value — otherwise the App Group blob stays pinned to the
        // pre-flip value and the widget renders "car linked" forever.
        if carConnected {
            let lastReference: Date = lastNonNilSpeedAt ?? serviceStartedAt
            if now.timeIntervalSince(lastReference) > 300 {
                carConnected = false
            }
        }

        struct Snapshot: Codable {
            let carConnected: Bool
            let batteryPercent: Int?
            let isCharging: Bool
            var speed: Double?
            let timestamp: Date?
        }

        guard let defaults = UserDefaults(suiteName: suiteName) else { return }

        // Decode the previous snapshot ONCE — never multiple times.
        let prev: Snapshot?
        if let prevData = defaults.data(forKey: AppGroupContract.liveTelemetryKey) {
            prev = try? JSONDecoder().decode(Snapshot.self, from: prevData)
        } else {
            prev = nil
        }

        let prevShape = prev.map {
            TelemetryPersistencePolicy.SnapshotShape(
                carConnected: $0.carConnected,
                batteryPercent: $0.batteryPercent,
                isCharging: $0.isCharging,
                speed: $0.speed
            )
        }

        // Pure decision: should we persist, which reload kind, and
        // the snapshot timestamp (injected clock value).
        // Pass the POST-auto-flip `carConnected` so the policy sees
        // the new value when deciding whether the connection state
        // changed (and therefore whether to fire
        // `.connectionStateChange` reloads and mark the snapshot
        // shape as different from the previous write).
        let decision = TelemetryPersistencePolicy.evaluate(
            now: now,
            currentSpeed: currentSpeed,
            batteryPercent: batteryPercent,
            isCharging: isCharging,
            carConnected: carConnected,
            previousSnapshot: prevShape,
            lastPersistenceDate: lastPersistenceDate,
            heartbeatInterval: Self.heartbeatPersistenceInterval,
            significantSpeedDelta: Self.significantSpeedDelta
        )
        guard decision.shouldPersist else { return }

        // Use the POST-auto-flip `carConnected` so the persisted
        // App Group snapshot reflects the new value. The previous
        // code captured `resolvedCarConnected = connectionOverride
        // ?? carConnected` BEFORE the auto-flip ran, so the snapshot
        // stayed pinned to the pre-flip value even when the in-memory
        // state had correctly flipped — and the widget kept showing
        // "car linked" after the user unplugged from CarPlay.
        let telemetry = Snapshot(
            carConnected: carConnected,
            batteryPercent: batteryPercent,
            isCharging: isCharging,
            speed: currentSpeed,
            timestamp: decision.timestamp
        )
        guard let data = try? JSONEncoder().encode(telemetry) else { return }

        defaults.set(data, forKey: AppGroupContract.liveTelemetryKey)
        defaults.set(data, forKey: AppGroupContract.legacyTelemetryKey)
        lastPersistenceDate = now

        if let kind = decision.reloadKind, let requester = reloadRequester {
            requester(kind, now)
        }
    }

    /// Test-only entry point that exposes the private
    /// `persistTelemetryIfMeaningful` to the test target via
    /// `@testable import Runner`. Production callers go through
    /// `locationManager(_:didUpdateLocations:)` which already
    /// supplies `previousSpeed` from the in-memory `currentSpeed`.
    ///
    /// Optional overrides for `batteryPercent`, `isCharging`, and
    /// `carConnected` let tests simulate transitions without having
    /// to mutate `UIDevice.current` (which the simulator does not
    /// support anyway). Pass `nil` to fall through to the real
    /// device reading.
    func _persistForTest(previousSpeed: Double?,
                         currentSpeed: Double? = nil,
                         batteryPercent: Int? = nil,
                         isCharging: Bool? = nil,
                         carConnected: Bool? = nil) {
        if let currentSpeed = currentSpeed { self.currentSpeed = currentSpeed }
        persistTelemetryIfMeaningful(
            previousSpeed: previousSpeed,
            batteryOverride: batteryPercent,
            chargingOverride: isCharging,
            connectionOverride: carConnected
        )
    }
}

// MARK: - TelemetryAudioDelegate
//
// `AVAudioPlayer` does NOT retain its delegate. Without this proxy
// the delegate would be deallocated as soon as the player's `play`
// call returned and `audioPlayerDidFinishPlaying` would never
// reach the service. The proxy keeps a weak reference back to the
// owning service so the finish / decode-error notifications actually
// fire — and so the service can invalidate the proxy after use
// without falling into a retain cycle.
private final class TelemetryAudioDelegate: NSObject, AVAudioPlayerDelegate {
    weak var owner: TelemetryService?
    private var invalidated = false

    init(owner: TelemetryService) {
        self.owner = owner
    }

    func invalidate() {
        invalidated = true
        owner = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard !invalidated else { return }
        owner?.audioPlayerDidFinishPlaying(player, successfully: flag)
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        guard !invalidated else { return }
        owner?.audioPlayerDecodeErrorDidOccur(player, error: error)
    }
}
