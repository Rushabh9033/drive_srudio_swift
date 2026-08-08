import Flutter
import UIKit
import MapKit

class MapsLauncherChannel: NSObject {
    static let channelName = "drive_studio/maps_launcher"
    
    static func register(with messenger: FlutterBinaryMessenger) {
        let instance = MapsLauncherChannel()
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
        channel.setMethodCallHandler(instance.handle)
    }
    
    private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let lat = args["latitude"] as? Double,
              let lng = args["longitude"] as? Double else {
            result(FlutterError(code: "INVALID_ARGS", message: "Latitude and longitude are required", details: nil))
            return
        }
        
        let label = args["label"] as? String ?? "Destination"
        
        switch call.method {
        case "launchAppleMaps":
            let coordinate = CLLocationCoordinate2DMake(lat, lng)
            let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate, addressDictionary: nil))
            mapItem.name = label
            mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
            result(nil)
            
        case "launchGoogleMaps":
            let urlStr = "comgooglemaps://?daddr=\(lat),\(lng)&directionsmode=driving"
            if let url = URL(string: urlStr), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else {
                // Fallback to web
                let webUrlStr = "https://maps.google.com/?daddr=\(lat),\(lng)&directionsmode=driving"
                if let webUrl = URL(string: webUrlStr) {
                    UIApplication.shared.open(webUrl, options: [:], completionHandler: nil)
                }
            }
            result(nil)
            
        case "launchWaze":
            let urlStr = "waze://?ll=\(lat),\(lng)&navigate=yes"
            if let url = URL(string: urlStr), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else {
                result(FlutterError(code: "NOT_INSTALLED", message: "Waze is not installed", details: nil))
            }
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
