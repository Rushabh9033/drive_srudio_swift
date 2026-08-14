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
        // Foreground-only GPS for this milestone. We use
        // When-In-Use authorization because there is no verified
        // background-location feature today — background speed
        // collection would require Always + UIBackgroundModes "location"
        // and a working background-update path. This milestone keeps
        // the app foreground-only and lets the user grant the broader
        // permission later if and when a real background feature
        // exists.
        locationManager.requestWhenInUseAuthorization()
    }

    func startMonitoring() {
        // Battery monitoring is already enabled in init — no need to
        // re-enable here. Calling the setter from a view body was the
        // side-effect we are removing.
        // Snapshots are written on every GPS fix (didUpdateLocations) and
        // on battery-level / state / foreground observers in AppStore —
        // no polling timer needed.
        locationManager.startUpdatingLocation()
    }

    func stopMonitoring() {
        locationManager.stopUpdatingLocation()
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

        // 1. Search App Group & Documents directory for Custom / Mic / TTS sound files
        for dir in searchDirectories {
            if let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                for file in files {
                    let ext = file.pathExtension.lowercased()
                    guard ["wav", "mp3", "m4a", "caf"].contains(ext) else { continue }

                    let fname = file.deletingPathExtension().lastPathComponent.lowercased()
                    let cleanFname = fname.replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "-", with: "_")

                    if fname == name.lowercased() || cleanFname == targetNameClean || cleanFname.contains(targetNameClean) || targetNameClean.contains(cleanFname) {
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
                    if fname == targetNameClean || fname.contains(targetNameClean) || targetNameClean.contains(fname) {
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
            return duration
        } catch {
            print("[TelemetryService] ❌ AVAudioPlayer failed (\(error)), falling back to SystemSound")
            var soundID: SystemSoundID = 0
            AudioServicesCreateSystemSoundID(soundURL as CFURL, &soundID)
            AudioServicesPlaySystemSound(soundID)
            return 2.0
        }
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

        if let defaults = UserDefaults(suiteName: suiteName),
           let data = try? JSONEncoder().encode(telemetry) {
            let prevBattery = defaults.data(forKey: AppGroupContract.liveTelemetryKey)
            let prevIsCharging = (try? JSONDecoder().decode(Snapshot.self, from: prevBattery ?? Data()))?.isCharging
            let prevSpeed = (try? JSONDecoder().decode(Snapshot.self, from: prevBattery ?? Data()))?.speed

            defaults.set(data, forKey: AppGroupContract.liveTelemetryKey)
            defaults.set(data, forKey: AppGroupContract.legacyTelemetryKey)

            // Decide reload kind based on what actually changed. The
            // throttle rate-limits speed-driven reloads to once per 5
            // min; battery / charging / foreground changes request
            // immediate reloads because they reflect user-meaningful
            // signal transitions.
            let kind: WidgetReloadThrottle.ReloadKind
            if prevIsCharging != isCharging {
                kind = .chargingStateChange
            } else if prevBattery == nil || batteryPercent != (try? JSONDecoder().decode(Snapshot.self, from: prevBattery ?? Data()))?.batteryPercent {
                kind = .batteryLevelChange
            } else if prevSpeed != currentSpeed {
                kind = .speedChange
            } else {
                kind = .other
            }
            if #available(iOS 14.0, *) {
                WidgetReloadThrottle.shared.requestReload(kind: kind)
            }
        }
    }
}
