import Flutter
import UIKit
import SwiftUI

enum DesignerChannel {
    static let name = "drive_studio/widget_designer"

    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: name, binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "openDesigner":
                DispatchQueue.main.async {
                    openNativeDesigner()
                }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private static func openNativeDesigner() {
        guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }),
              let rootVC = window.rootViewController else { return }

        let designerView = WidgetDesignerView()
        let hostingVC = UIHostingController(rootView: designerView)
        hostingVC.modalPresentationStyle = .fullScreen
        rootVC.present(hostingVC, animated: true)
    }
}
