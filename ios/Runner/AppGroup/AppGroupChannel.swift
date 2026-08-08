import Flutter
import UIKit
import WidgetKit

/// App Group bridge — register from AppDelegate in Wave 2.
/// Channel: `drive_studio/app_group`
/// Methods: syncState({json: String}), reloadWidgets()
enum AppGroupChannel {
    static let name = "drive_studio/app_group"

    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: name, binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "syncState":
                guard
                    let args = call.arguments as? [String: Any],
                    let json = args["json"] as? String
                else {
                    result(FlutterError(code: "bad_args", message: "json required", details: nil))
                    return
                }
                guard let defaults = UserDefaults(suiteName: AppGroupContract.suiteName) else {
                    result(FlutterError(code: "no_suite", message: "App Group unavailable", details: nil))
                    return
                }
                defaults.set(json, forKey: AppGroupContract.stateKey)
                defaults.synchronize()
                result(nil)
            case "reloadWidgets":
                if #available(iOS 14.0, *) {
                    WidgetCenter.shared.reloadAllTimelines()
                }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
}
