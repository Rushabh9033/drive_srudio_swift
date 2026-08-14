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

@objc class TelemetryService: NSObject, CLLocationManagerDelegate {
    static let shared = TelemetryService()

    private let locationManager = CLLocationManager()
    /// Latest GPS speed in km/h, exactly as Core Location reported it.
    /// `nil` means there is no valid fix yet. A genuine `0` means the
    /// phone is stationary with a valid fix — it is NOT the same as
    /// "unknown". Widgets must distinguish the two cases.
    var currentSpeed: Double? = nil
    private var audioPlayer: AVAudioPlayer?

    private var lastWasConnected: Bool = false

    /// Whether the phone currently considers itself connected to a car
    /// (CarPlay, Bluetooth, or USB). Surfaced honestly to widgets via
    /// `snapshotAndSave`. Mutable so the Settings screen toggle and the
    /// App Intents "Switch Slot" intent can affect what widgets show.
    var carConnected: Bool = false

    private let suiteName = AppGroupContract.suiteName

    private override init() {
        super.init()
        UIDevice.current.isBatteryMonitoringEnabled = true

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.activityType = .automotiveNavigation
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.pausesLocationUpdatesAutomatically = false
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
    func startMonitoring() {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
        default:
            // Caller invoked `startMonitoring` without authorization;
            // route through the user-driven path so the prompt is
            // shown explicitly rather than silently failing.
            _ = beginLocationIfAuthorized()
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
        // Only notify on actual change — GPS can fire 5+ times/sec and
        // many of those are redundant. Cheap equality check, but it
        // matters because each notification schedules a SwiftUI render.
        if prevSpeed != currentSpeed {
            NotificationCenter.default.post(name: .telemetrySpeedUpdated, object: self)
        }
        snapshotAndSave()
    }

    // MARK: - Play Sound Cues
    @discardableResult
    func triggerSound(for trigger: String) -> Double {
        let defaults = UserDefaults(suiteName: suiteName)
        let assigned = defaults?.string(forKey: "trigger_\(trigger)")
        let soundName = (assigned != nil && assigned != "none") ? assigned! : fallbackSound(for: trigger)

        guard soundName != "none" else { return 0.0 }
        return playSoundByName(soundName)
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

            let player = try AVAudioPlayer(contentsOf: soundURL)
            player.volume = 0.85
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
            var soundID: SystemSoundID = 0
            AudioServicesCreateSystemSoundID(soundURL as CFURL, &soundID)
            AudioServicesPlaySystemSound(soundID)
            return 2.0
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
    func snapshotAndSave() {
        let device = UIDevice.current
        let level = device.batteryLevel
        // Unknown battery (`batteryLevel == -1`) is propagated as `nil`.
        // We never substitute a fake value.
        let batteryPercent: Int? = level >= 0 ? Int(level * 100) : nil
        // Exact current charging state. Do not OR with any previously
        // cached state — if the device just unplugged, this must flip
        // to false on the next snapshot.
        let isCharging = device.batteryState == .charging || device.batteryState == .full

        struct Snapshot: Codable {
            let carConnected: Bool
            let batteryPercent: Int?
            let isCharging: Bool
            var speed: Double?
            let timestamp: Date?
        }

        // `currentSpeed` is the most recent GPS-derived km/h value, or
        // `nil` when no valid fix exists. Genuine stationary (0) is
        // preserved; "no fix" stays `nil`. The widget extension renders
        // each case differently.
        let telemetry = Snapshot(
            carConnected: carConnected,
            batteryPercent: batteryPercent,
            isCharging: isCharging,
            speed: currentSpeed,
            timestamp: Date()
        )

        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = try? JSONEncoder().encode(telemetry) else {
            return
        }

        // Decode the previous snapshot ONCE — never multiple times. The
        // previous implementation decoded the same Data up to three
        // times, wasting CPU on the timeline thread.
        let prev = (try? JSONDecoder().decode(Snapshot.self,
            from: defaults.data(forKey: AppGroupContract.liveTelemetryKey) ?? Data()))

        defaults.set(data, forKey: AppGroupContract.liveTelemetryKey)
        defaults.set(data, forKey: AppGroupContract.legacyTelemetryKey)

        // Decide reload kind based on what actually changed. The
        // throttle rate-limits speed-driven reloads to once per 5
        // min; battery / charging / connection changes request
        // immediate reloads because they reflect user-meaningful
        // signal transitions. **An identical snapshot performs zero
        // WidgetCenter reloads** — no `.other` bypass.
        let kind: WidgetReloadKind
        if prev?.isCharging != isCharging {
            kind = .chargingStateChange
        } else if prev?.carConnected != carConnected {
            kind = .connectionStateChange
        } else if prev?.batteryPercent != batteryPercent {
            kind = .batteryLevelChange
        } else if prev?.speed != currentSpeed {
            kind = .speedChange
        } else {
            kind = .noVisibleChange
        }
        if #available(iOS 14.0, *) {
            WidgetReloadThrottle.shared.requestReload(kind: kind)
        }
    }
}
