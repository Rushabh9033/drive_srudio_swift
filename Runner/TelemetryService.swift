import Foundation
import CoreLocation
import UIKit
import WidgetKit
import AVFoundation

@objc class TelemetryService: NSObject, CLLocationManagerDelegate {
    static let shared = TelemetryService()
    
    private let locationManager = CLLocationManager()
    var currentSpeed: CLLocationSpeed = 0
    private var timer: Timer?
    private var audioPlayer: AVAudioPlayer?
    
    private var lastWasConnected: Bool = false
    private let suiteName = "group.com.drivestudio.shared"
    
    private override init() {
        super.init()
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.activityType = .automotiveNavigation
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.requestAlwaysAuthorization()
    }
    
    func startMonitoring() {
        DispatchQueue.main.async {
            UIDevice.current.isBatteryMonitoringEnabled = true
        }
        locationManager.startUpdatingLocation()
        
        // Update widget telemetry snapshots periodically
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.snapshotAndSave()
        }
    }
    
    func stopMonitoring() {
        locationManager.stopUpdatingLocation()
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Core Location Delegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentSpeed = location.speed > 0 ? (location.speed * 3.6) : 0
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
        let batteryPercent = level >= 0 ? Int(level * 100) : nil
        let isCharging = device.batteryState == .charging || device.batteryState == .full
        
        struct Snapshot: Codable {
            let carConnected: Bool
            let batteryPercent: Int?
            let isCharging: Bool
            var speed: Double?
            let timestamp: Date?
        }
        
        let telemetry = Snapshot(
            carConnected: true,
            batteryPercent: batteryPercent,
            isCharging: isCharging,
            speed: currentSpeed >= 0 ? currentSpeed : 0.0,
            timestamp: Date()
        )
        
        if let defaults = UserDefaults(suiteName: suiteName),
           let data = try? JSONEncoder().encode(telemetry) {
            defaults.set(data, forKey: "live_telemetry")
            defaults.set(data, forKey: "drive_studio_telemetry")
            if #available(iOS 14.0, *) {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
}
