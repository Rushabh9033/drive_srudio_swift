import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let didFinish = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    registerNativePluginsOnce()
    return didFinish
  }

  private var didRegisterNativePlugins = false
  private func registerNativePluginsOnce() {
    guard !didRegisterNativePlugins else { return }
    guard let controller = self.window?.rootViewController as? FlutterViewController else {
      DispatchQueue.main.async { [weak self] in
        self?.registerNativePluginsOnce()
      }
      return
    }
    didRegisterNativePlugins = true

    AppGroupChannel.register(with: controller.binaryMessenger)

    let registrar = controller.registrar(forPlugin: "NativeTabBarPlugin")
    registrar?.register(
      NativeTabBarFactory(messenger: controller.binaryMessenger),
      withId: "drivestudio/native_tab_bar"
    )
  }
}

// MARK: - Native Liquid Glass TabBar PlatformView

class NativeTabBarFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return NativeTabBarView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger
        )
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

class NativeTabBarView: NSObject, FlutterPlatformView, UITabBarDelegate {
    private var _view: UIView
    private var tabBar: UITabBar
    private var channel: FlutterMethodChannel
    private var isUpdatingFromFlutter = false

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger
    ) {
        _view = UIView(frame: frame)
        _view.backgroundColor = .clear

        tabBar = UITabBar(frame: .zero)
        tabBar.translatesAutoresizingMaskIntoConstraints = false

        // Standard Apple UITabBar system appearance for system Liquid Glass / material
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemThinMaterialDark)
        appearance.backgroundColor = UIColor(red: 0.08, green: 0.09, blue: 0.12, alpha: 0.75)

        let primaryColor = UIColor(red: 0.30, green: 0.62, blue: 1.0, alpha: 1.0)
        let normalColor = UIColor(red: 0.60, green: 0.61, blue: 0.66, alpha: 0.8)

        appearance.stackedLayoutAppearance.selected.iconColor = primaryColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: primaryColor]
        appearance.stackedLayoutAppearance.normal.iconColor = normalColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normalColor]

        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
        tabBar.tintColor = primaryColor
        tabBar.isTranslucent = true

        // Destinations: Home (0), Studio (1), Sounds (2), Settings (3)
        let homeItem = UITabBarItem(
            title: "Home",
            image: UIImage(systemName: "house"),
            selectedImage: UIImage(systemName: "house.fill")
        )
        homeItem.tag = 0

        let studioItem = UITabBarItem(
            title: "Studio",
            image: UIImage(systemName: "square.grid.2x2"),
            selectedImage: UIImage(systemName: "square.grid.2x2.fill")
        )
        studioItem.tag = 1

        let soundsItem = UITabBarItem(
            title: "Sounds",
            image: UIImage(systemName: "speaker.wave.3"),
            selectedImage: UIImage(systemName: "speaker.wave.3.fill")
        )
        soundsItem.tag = 2

        let settingsItem = UITabBarItem(
            title: "Settings",
            image: UIImage(systemName: "gearshape"),
            selectedImage: UIImage(systemName: "gearshape.fill")
        )
        settingsItem.tag = 3

        tabBar.items = [homeItem, studioItem, soundsItem, settingsItem]

        if let dict = args as? [String: Any],
           let initialIndex = dict["selectedIndex"] as? Int,
           initialIndex >= 0 && initialIndex < 4 {
            tabBar.selectedItem = tabBar.items?[initialIndex]
        } else {
            tabBar.selectedItem = homeItem
        }

        _view.addSubview(tabBar)
        NSLayoutConstraint.activate([
            tabBar.leadingAnchor.constraint(equalTo: _view.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: _view.trailingAnchor),
            tabBar.topAnchor.constraint(equalTo: _view.topAnchor),
            tabBar.bottomAnchor.constraint(equalTo: _view.bottomAnchor)
        ])

        channel = FlutterMethodChannel(
            name: "drivestudio/native_tab_bar_\(viewId)",
            binaryMessenger: messenger
        )

        super.init()

        tabBar.delegate = self

        channel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { return }
            if call.method == "setSelectedIndex" {
                if let args = call.arguments as? [String: Any], let index = args["index"] as? Int {
                    self.setSelectedIndex(index)
                    result(nil)
                } else {
                    result(FlutterError(code: "bad_args", message: "index required", details: nil))
                }
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
    }

    func view() -> UIView {
        return _view
    }

    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        guard !isUpdatingFromFlutter else { return }
        let index = item.tag
        channel.invokeMethod("onTabSelected", arguments: ["index": index])
    }

    private func setSelectedIndex(_ index: Int) {
        guard let items = tabBar.items, index >= 0 && index < items.count else { return }
        if tabBar.selectedItem?.tag != index {
            isUpdatingFromFlutter = true
            tabBar.selectedItem = items[index]
            isUpdatingFromFlutter = false
        }
    }

    deinit {
        channel.setMethodCallHandler(nil)
    }
}