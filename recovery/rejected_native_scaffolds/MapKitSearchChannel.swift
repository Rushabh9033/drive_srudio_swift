import Flutter
import MapKit

class MapKitSearchChannel: NSObject {
    static let channelName = "drive_studio/mapkit_search"
    
    static func register(with messenger: FlutterBinaryMessenger) {
        let instance = MapKitSearchChannel()
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
        channel.setMethodCallHandler(instance.handle)
    }
    
    private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let query = args["query"] as? String,
              let lat = args["latitude"] as? Double,
              let lng = args["longitude"] as? Double else {
            result(FlutterError(code: "INVALID_ARGS", message: "Query, latitude and longitude required", details: nil))
            return
        }
        
        switch call.method {
        case "searchNearby":
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            let center = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            request.region = MKCoordinateRegion(center: center, latitudinalMeters: 5000, longitudinalMeters: 5000)
            
            let search = MKLocalSearch(request: request)
            search.start { response, error in
                if let error = error {
                    result(FlutterError(code: "SEARCH_ERROR", message: error.localizedDescription, details: nil))
                    return
                }
                
                guard let response = response else {
                    result([])
                    return
                }
                
                let mapped = response.mapItems.map { item -> [String: Any] in
                    return [
                        "name": item.name ?? "Unknown Place",
                        "latitude": item.placemark.coordinate.latitude,
                        "longitude": item.placemark.coordinate.longitude,
                        "address": item.placemark.title ?? ""
                    ]
                }
                
                result(Array(mapped))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
