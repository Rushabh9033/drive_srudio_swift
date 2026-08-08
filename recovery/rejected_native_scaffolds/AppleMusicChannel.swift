import Flutter
import UIKit
import StoreKit
import MediaPlayer

class AppleMusicChannel: NSObject {
    static let channelName = "drive_studio/apple_music"
    
    static func register(with messenger: FlutterBinaryMessenger) {
        let instance = AppleMusicChannel()
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
        channel.setMethodCallHandler(instance.handle)
    }
    
    private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "checkAuthorization":
            let status = SKCloudServiceController.authorizationStatus()
            result(status.rawValue)
        case "requestAuthorization":
            SKCloudServiceController.requestAuthorization { status in
                result(status.rawValue)
            }
        case "play":
            MPMusicPlayerController.systemMusicPlayer.play()
            result(nil)
        case "pause":
            MPMusicPlayerController.systemMusicPlayer.pause()
            result(nil)
        case "skipToNext":
            MPMusicPlayerController.systemMusicPlayer.skipToNextItem()
            result(nil)
        case "skipToPrevious":
            MPMusicPlayerController.systemMusicPlayer.skipToPreviousItem()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
