import Flutter
import CoreLocation
import WeatherKit

class WeatherChannel: NSObject {
    static let channelName = "drive_studio/weather"
    
    static func register(with messenger: FlutterBinaryMessenger) {
        let instance = WeatherChannel()
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
        channel.setMethodCallHandler(instance.handle)
    }
    
    private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let lat = args["latitude"] as? Double,
              let lng = args["longitude"] as? Double else {
            result(FlutterError(code: "INVALID_ARGS", message: "Latitude and longitude required", details: nil))
            return
        }
        
        switch call.method {
        case "fetchWeather":
            if #available(iOS 16.0, *) {
                Task {
                    do {
                        let location = CLLocation(latitude: lat, longitude: lng)
                        let weather = try await WeatherService.shared.weather(for: location)
                        let current = weather.currentWeather
                        
                        let data: [String: Any] = [
                            "temperature": current.temperature.converted(to: .celsius).value,
                            "condition": current.condition.description,
                            "symbolName": current.symbolName
                        ]
                        
                        DispatchQueue.main.async { result(data) }
                    } catch {
                        DispatchQueue.main.async { 
                            result(FlutterError(code: "WEATHER_ERROR", message: error.localizedDescription, details: nil)) 
                        }
                    }
                }
            } else {
                result(FlutterError(code: "UNSUPPORTED", message: "WeatherKit requires iOS 16.0 or newer", details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
