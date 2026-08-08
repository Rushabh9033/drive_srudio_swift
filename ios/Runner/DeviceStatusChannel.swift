import Flutter
import UIKit

class DeviceStatusChannel: NSObject, FlutterStreamHandler {
    static let channelName = "drive_studio/device_status"
    static let eventChannelName = "drive_studio/device_status_events"
    
    private var eventSink: FlutterEventSink?
    
    static func register(with messenger: FlutterBinaryMessenger) {
        let instance = DeviceStatusChannel()
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
        channel.setMethodCallHandler(instance.handle)
        
        let eventChannel = FlutterEventChannel(name: eventChannelName, binaryMessenger: messenger)
        eventChannel.setStreamHandler(instance)
        
        UIDevice.current.isBatteryMonitoringEnabled = true
    }
    
    private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "getInitialStatus" {
            result(currentStatus())
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func currentStatus() -> [String: Any] {
        let device = UIDevice.current
        var percent = Int(device.batteryLevel * 100)
        if percent < 0 { percent = 0 } // Simulator can return -1
        
        var state = 0
        switch device.batteryState {
        case .unplugged: state = 1
        case .charging: state = 2
        case .full: state = 3
        default: state = 0
        }
        
        return [
            "percent": percent,
            "state": state,
            "isLowPowerMode": ProcessInfo.processInfo.isLowPowerModeEnabled,
            "isAvailable": device.batteryState != .unknown
        ]
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        NotificationCenter.default.addObserver(self, selector: #selector(batteryChanged), name: UIDevice.batteryLevelDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(batteryChanged), name: UIDevice.batteryStateDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(batteryChanged), name: Notification.Name.NSProcessInfoPowerStateDidChange, object: nil)
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        NotificationCenter.default.removeObserver(self)
        return nil
    }
    
    @objc private func batteryChanged() {
        eventSink?(currentStatus())
    }
}
