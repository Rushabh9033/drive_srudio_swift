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

    private var lastWasConnected: Bool = false

    /// Whether the phone currently considers itself connected to a car
    /// (CarPlay, Bluetooth, or USB). Surfaced honestly to widgets via
    /// `snapshotAndSave`. Mutable so the Settings screen toggle and the
    /// App Intents "Switch Slot" intent can affect what widgets show.
    var carConnected: Bool = false

    private let suiteName = AppGroupContract.suiteName

    private override init() {
        self.clock = { Date() }
        super.init()
        Self.configureShared(self)
    }

    /// Designated test initializer. Pass a fixed-clock closure (or a
    /// mutable-reference closure) to drive the heartbeat policy
    /// deterministically. Production code uses `TelemetryService.shared`,
    /// which is constructed with the real-clock initializer.
    internal init(clock: @escaping () -> Date) {
        self.clock = clock
        super.init()
        Self.configureShared(self)
    }

    /// Reset persistence state. Test-only — production code never
    /// resets `lastPersistenceDate` outside the heartbeat cadence.
    func resetPersistenceState() {
        lastPersistenceDate = nil
        currentSpeed = nil
    }

    private static func configureShared(_ service: TelemetryService) {
        UIDevice.current.isBatteryMonitoringEnabled = true

        service.locationManager.delegate = service
        service.locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        service.locationManager.activityType = .automotiveNavigation
        service.locationManager.distanceFilter = kCLDistanceFilterNone
        service.locationManager.pausesLocationUpdatesAutomatically = false
        // **No automatic permission request at init.**
        // iOS permission prompts are only shown in response to an
        // explicit user action. `beginLocationIfAuthorized()` is the
        // production entry point — it inspects the current
        // authorization, requests When-In-Use if undetermined, and
        // either begins monitoring (when granted) or surfaces a
        // "denied" state that the Dashboard renders with a Settings
        // shortcut. We never request Always authorization.
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
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
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
        // **Foreground UI keeps feeling live.** Every real speed
        // change triggers a notification so SwiftUI re-renders. This
        // is independent of persistence — the App Group blob is
        // NOT written here. `persistTelemetryIfMeaningful` is what
        // decides whether the on-disk defaults change.
        if prevSpeed != currentSpeed {
            NotificationCenter.default.post(name: .telemetrySpeedUpdated, object: self)
        }
        persistTelemetryIfMeaningful(previousSpeed: prevSpeed)
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
        let resolvedCarConnected = connectionOverride ?? carConnected

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

        let firstSnapshot = (prev == nil)

        let batteryChanged = prev?.batteryPercent != batteryPercent
        let chargingChanged = prev?.isCharging != isCharging
        let connectionChanged = prev?.carConnected != resolvedCarConnected
        let availabilityChanged = (prev?.speed == nil) != (currentSpeed == nil)

        // Compare against the LAST PERSISTED speed so accumulated
        // sub-threshold drift eventually trips the meaningful-speed
        // boundary and a fresh snapshot is published.
        let speedDeltaAgainstBaseline: Double = {
            guard let baseline = prev?.speed, let current = currentSpeed else {
                return 0
            }
            return abs(current - baseline)
        }()
        let speedMeaningful = speedDeltaAgainstBaseline >= Self.significantSpeedDelta

        let heartbeatDue: Bool = {
            guard let last = lastPersistenceDate else { return true }
            return now.timeIntervalSince(last) >= Self.heartbeatPersistenceInterval
        }()

        let shouldPersist = firstSnapshot
            || batteryChanged || chargingChanged
            || connectionChanged || availabilityChanged
            || speedMeaningful || heartbeatDue
        guard shouldPersist else { return }

        let telemetry = Snapshot(
            carConnected: resolvedCarConnected,
            batteryPercent: batteryPercent,
            isCharging: isCharging,
            speed: currentSpeed,
            // Use the injected clock value as the snapshot timestamp
            // so tests can assert exact equality without depending
            // on the system clock.
            timestamp: now
        )
        guard let data = try? JSONEncoder().encode(telemetry) else { return }

        defaults.set(data, forKey: AppGroupContract.liveTelemetryKey)
        defaults.set(data, forKey: AppGroupContract.legacyTelemetryKey)
        lastPersistenceDate = now

        // Decide reload kind based on what actually changed. The
        // throttle rate-limits speed-driven reloads to once per 5
        // min; battery / charging / connection changes request
        // immediate reloads because they reflect user-meaningful
        // signal transitions. **An identical snapshot performs zero
        // WidgetCenter reloads** — no `.other` bypass.
        let kind: WidgetReloadKind
        if chargingChanged {
            kind = .chargingStateChange
        } else if connectionChanged {
            kind = .connectionStateChange
        } else if batteryChanged {
            kind = .batteryLevelChange
        } else if speedMeaningful {
            kind = .speedChange
        } else {
            kind = .noVisibleChange
        }
        if #available(iOS 14.0, *) {
            WidgetReloadThrottle.shared.requestReload(kind: kind, now: now)
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
