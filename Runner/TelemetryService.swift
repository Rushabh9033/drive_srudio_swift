import Foundation
import CoreLocation
import UIKit
import WidgetKit
import AVFoundation

@objc class TelemetryService: NSObject, CLLocationManagerDelegate {
    static let shared = TelemetryService()
    
    private let locationManager = CLLocationManager()
    private var currentSpeed: CLLocationSpeed = 0
    private var timer: Timer?
    private var audioPlayer: AVAudioPlayer?
    
    private var lastWasConnected: Bool = false
    private let suiteName = "group.com.drivestudio.shared"
    
    private override init() {
        super.init()
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.requestWhenInUseAuthorization()
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
        
        // 1. Check App Group / Documents Directory for Custom/Mic/TTS sound
        if let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            do {
                let files = try fm.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil)
                for file in files {
                    if file.deletingPathExtension().lastPathComponent.lowercased() == name.lowercased() {
                        targetURL = file
                        break
                    }
                }
            } catch {}
        }
        
        // 2. Check Bundle Resources for Stock Sounds
        if targetURL == nil {
            let searchKey = name.lowercased().replacingOccurrences(of: " ", with: "_")
            if let urls = Bundle.main.urls(forResourcesWithExtension: "wav", subdirectory: nil) {
                for u in urls {
                    if u.lastPathComponent.lowercased().contains(searchKey) {
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
            
            // Category .playback with mixWithOthers (NO ducking) so system volume is NOT decreased on unplug
            try? session.setCategory(.playback, mode: .default, options: [.allowBluetoothA2DP, .mixWithOthers])
            try? session.overrideOutputAudioPort(.none)
            try? session.setActive(true)
            
            let player = try AVAudioPlayer(contentsOf: soundURL)
            player.volume = 0.8 // Set playback volume to 80%
            player.prepareToPlay()
            player.play()
            audioPlayer = player
            let duration = player.duration
            print("[TelemetryService] 🔊 Playing sound at 80% volume (\(duration)s): \(soundURL.lastPathComponent)")
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
    private func snapshotAndSave() {
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
