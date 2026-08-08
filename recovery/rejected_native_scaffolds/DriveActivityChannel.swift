import Flutter
import CoreLocation
import CoreMotion

class DriveActivityChannel: NSObject, FlutterStreamHandler, CLLocationManagerDelegate {
    static let channelName = "drive_studio/drive_activity"
    static let eventChannelName = "drive_studio/drive_activity_events"
    
    private let locationManager = CLLocationManager()
    private let motionActivityManager = CMMotionActivityManager()
    
    private var eventSink: FlutterEventSink?
    private var isDriving = false
    private var currentSpeedKph: Double = 0.0
    private var tripDistanceKm: Double = 0.0
    private var lastLocation: CLLocation?
    
    static func register(with messenger: FlutterBinaryMessenger) {
        let instance = DriveActivityChannel()
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
        channel.setMethodCallHandler(instance.handle)
        
        let eventChannel = FlutterEventChannel(name: eventChannelName, binaryMessenger: messenger)
        eventChannel.setStreamHandler(instance)
    }
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 10
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
    }
    
    private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startTracking":
            locationManager.requestAlwaysAuthorization()
            locationManager.startUpdatingLocation()
            
            if CMMotionActivityManager.isActivityAvailable() {
                motionActivityManager.startActivityUpdates(to: OperationQueue.main) { [weak self] activity in
                    guard let self = self, let activity = activity else { return }
                    self.isDriving = activity.automotive
                    self.broadcastState()
                }
            }
            result(nil)
        case "stopTracking":
            locationManager.stopUpdatingLocation()
            motionActivityManager.stopActivityUpdates()
            isDriving = false
            currentSpeedKph = 0.0
            broadcastState()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        if let last = lastLocation {
            let distance = location.distance(from: last)
            if distance > 0 {
                tripDistanceKm += distance / 1000.0
            }
        }
        lastLocation = location
        
        if location.speed >= 0 {
            currentSpeedKph = location.speed * 3.6
        } else {
            currentSpeedKph = 0.0
        }
        
        broadcastState()
    }
    
    private func broadcastState() {
        guard let sink = eventSink else { return }
        let state: [String: Any] = [
            "isDriving": isDriving,
            "currentSpeedKph": currentSpeedKph,
            "tripDistanceKm": tripDistanceKm
        ]
        sink(state)
    }
}
