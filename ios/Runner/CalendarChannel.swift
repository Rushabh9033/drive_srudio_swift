import Flutter
import EventKit

class CalendarChannel: NSObject {
    static let channelName = "drive_studio/calendar"
    private let eventStore = EKEventStore()
    
    static func register(with messenger: FlutterBinaryMessenger) {
        let instance = CalendarChannel()
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
        channel.setMethodCallHandler(instance.handle)
    }
    
    private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "requestAccess":
            if #available(iOS 17.0, *) {
                eventStore.requestFullAccessToEvents { granted, error in
                    DispatchQueue.main.async { result(granted) }
                }
            } else {
                eventStore.requestAccess(to: .event) { granted, error in
                    DispatchQueue.main.async { result(granted) }
                }
            }
        case "fetchUpcomingEvents":
            let status = EKEventStore.authorizationStatus(for: .event)
            guard status == .authorized || status == .fullAccess else {
                result([])
                return
            }
            
            let startDate = Date()
            let endDate = Date().addingTimeInterval(24 * 3600 * 7) // next 7 days
            let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
            let events = eventStore.events(matching: predicate).prefix(10)
            
            let mapped = events.map { event -> [String: Any] in
                return [
                    "id": event.eventIdentifier ?? "",
                    "title": event.title ?? "Event",
                    "location": event.location ?? "",
                    "startDate": event.startDate.timeIntervalSince1970,
                    "endDate": event.endDate.timeIntervalSince1970
                ]
            }
            result(Array(mapped))
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
