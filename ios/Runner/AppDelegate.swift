import Flutter
import UIKit
import SwiftUI
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
    DesignerChannel.register(with: controller.binaryMessenger)
    DeviceStatusChannel.register(with: controller.binaryMessenger)
    AppleMusicChannel.register(with: controller.binaryMessenger)
    MapsLauncherChannel.register(with: controller.binaryMessenger)
    CalendarChannel.register(with: controller.binaryMessenger)
    WeatherChannel.register(with: controller.binaryMessenger)
    MapKitSearchChannel.register(with: controller.binaryMessenger)
    DriveActivityChannel.register(with: controller.binaryMessenger)

    let registrar = controller.registrar(forPlugin: "NativeTabBarPlugin")
    registrar?.register(
      NativeTabBarFactory(messenger: controller.binaryMessenger),
      withId: "drivestudio/native_tab_bar"
    )
  }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        if hexSanitized.count == 6 {
            self.init(
                red: Double((rgb & 0xFF0000) >> 16) / 255.0,
                green: Double((rgb & 0x00FF00) >> 8) / 255.0,
                blue: Double(rgb & 0x0000FF) / 255.0
            )
        } else if hexSanitized.count == 8 {
            self.init(
                red: Double((rgb & 0x00FF0000) >> 16) / 255.0,
                green: Double((rgb & 0x0000FF00) >> 8) / 255.0,
                blue: Double(rgb & 0x000000FF) / 255.0,
                opacity: Double((rgb & 0xFF000000) >> 24) / 255.0
            )
        } else {
            return nil
        }
    }
}

// MARK: - Shared Swift Models & Store

struct SlotConfig: Codable {
    var templateId: String
    var accentHex: String
    var title: String
    var subtitle: String
    var updatedAt: Date

    static func defaultFor(slot: Int) -> SlotConfig {
        switch slot {
        case 1:
            return SlotConfig(
                templateId: "battery_glow",
                accentHex: "#00FF88",
                title: "Battery Glow",
                subtitle: "Phone SOC",
                updatedAt: .distantPast
            )
        case 2:
            return SlotConfig(
                templateId: "car_status",
                accentHex: "#34C759",
                title: "Car Status",
                subtitle: "Drive Link",
                updatedAt: .distantPast
            )
        case 3:
            return SlotConfig(
                templateId: "neon",
                accentHex: "#AF52DE",
                title: "Neon HUD",
                subtitle: "Performance",
                updatedAt: .distantPast
            )
        default: // Slot 0
            return SlotConfig(
                templateId: "dark_clock",
                accentHex: "#00D4FF",
                title: "Dark Clock",
                subtitle: "My Car",
                updatedAt: .distantPast
            )
        }
    }

    static let empty = defaultFor(slot: 0)

    var isEmpty: Bool { updatedAt == .distantPast }
}

enum WidgetStore {
    static let suiteName = "group.com.drivestudio.shared"
    private static func key(slot: Int) -> String { "swift_slot_\(slot)" }

    static func save(_ config: SlotConfig, forSlot slot: Int) {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = try? JSONEncoder().encode(config) else { return }
        defaults.set(data, forKey: key(slot: slot))
        defaults.synchronize()
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    static func load(slot: Int) -> SlotConfig {
        guard
            let defaults = UserDefaults(suiteName: suiteName),
            let data = defaults.data(forKey: key(slot: slot)),
            let config = try? JSONDecoder().decode(SlotConfig.self, from: data)
        else { return SlotConfig.defaultFor(slot: slot) }
        return config
    }
}

struct NativeTelemetry {
    let batteryPercent: Int
    let isCharging: Bool
    let carConnected: Bool
}

func loadNativeTelemetry() -> NativeTelemetry? {
    guard
        let defaults = UserDefaults(suiteName: WidgetStore.suiteName),
        let json = defaults.string(forKey: "widget_state_v1"),
        let data = json.data(using: .utf8),
        let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let tele = obj["telemetry"] as? [String: Any]
    else { return nil }

    return NativeTelemetry(
        batteryPercent: tele["batteryPercent"] as? Int ?? 0,
        isCharging: tele["isCharging"] as? Bool ?? false,
        carConnected: tele["carConnected"] as? Bool ?? false
    )
}

struct WidgetTemplate: Identifiable {
    let id: String
    let name: String
    let preview: AnyView
    let render: (_ config: SlotConfig, _ telemetry: NativeTelemetry?) -> AnyView
}

let darkClockTemplate = WidgetTemplate(
    id: "dark_clock",
    name: "Dark Clock",
    preview: AnyView(DarkClockView(config: .empty, telemetry: nil, isPreview: true)),
    render: { config, tele in AnyView(DarkClockView(config: config, telemetry: tele, isPreview: false)) }
)

struct DarkClockView: View {
    let config: SlotConfig
    let telemetry: NativeTelemetry?
    let isPreview: Bool

    var accent: Color { Color(hex: config.accentHex) ?? .blue }

    var body: some View {
        ZStack {
            Color.black
            LinearGradient(
                colors: [accent.opacity(0.18), Color.black],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(config.subtitle.isEmpty ? "Drive Studio" : config.subtitle)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(accent)
                    .tracking(1.5)
                    .textCase(.uppercase)
                Spacer()
                Text(Date(), style: .time)
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(Date(), style: .date)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

let batteryGlowTemplate = WidgetTemplate(
    id: "battery_glow",
    name: "Battery Glow",
    preview: AnyView(BatteryGlowView(config: .empty, telemetry: nil, isPreview: true)),
    render: { config, tele in AnyView(BatteryGlowView(config: config, telemetry: tele, isPreview: false)) }
)

struct BatteryGlowView: View {
    let config: SlotConfig
    let telemetry: NativeTelemetry?
    let isPreview: Bool

    var accent: Color { Color(hex: config.accentHex) ?? .cyan }
    var level: Int { isPreview ? 87 : (telemetry?.batteryPercent ?? 0) }
    var charging: Bool { isPreview ? true : (telemetry?.isCharging ?? false) }
    var fraction: Double { Double(level) / 100.0 }

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.08)
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(
                            AngularGradient(colors: [accent.opacity(0.6), accent], center: .center),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Image(systemName: charging ? "bolt.fill" : "battery.100")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(accent)
                        Text("\(level)%")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 90, height: 90)
                .shadow(color: accent.opacity(0.5), radius: 16)
                Text(charging ? "Charging" : "On Battery")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(accent)
                    .tracking(1)
                    .textCase(.uppercase)
            }
        }
    }
}

let carStatusTemplate = WidgetTemplate(
    id: "car_status",
    name: "Car Status",
    preview: AnyView(CarStatusView(config: .empty, telemetry: nil, isPreview: true)),
    render: { config, tele in AnyView(CarStatusView(config: config, telemetry: tele, isPreview: false)) }
)

struct CarStatusView: View {
    let config: SlotConfig
    let telemetry: NativeTelemetry?
    let isPreview: Bool

    var accent: Color { Color(hex: config.accentHex) ?? .blue }
    var connected: Bool { isPreview ? true : (telemetry?.carConnected ?? false) }
    var battery: Int { isPreview ? 100 : (telemetry?.batteryPercent ?? 0) }
    var charging: Bool { isPreview ? true : (telemetry?.isCharging ?? false) }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.08, blue: 0.14), Color.black],
                startPoint: .top, endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "car.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(connected ? accent : .gray)
                    Text(connected ? "Connected" : "Disconnected")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(connected ? accent : .gray)
                    Spacer()
                }
                Spacer()
                Text(Date(), style: .time)
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: charging ? "battery.100.bolt" : "battery.75")
                        .foregroundColor(charging ? .green : .white.opacity(0.7))
                    Text(battery > 0 ? "\(battery)%" : "—")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                    Spacer()
                    Circle()
                        .fill(connected ? accent : Color.gray)
                        .frame(width: 7, height: 7)
                        .shadow(color: connected ? accent : .clear, radius: 4)
                }
            }
            .padding(14)
        }
    }
}

let minimalTemplate = WidgetTemplate(
    id: "minimal",
    name: "Minimal",
    preview: AnyView(MinimalView(config: .empty, telemetry: nil, isPreview: true)),
    render: { config, tele in AnyView(MinimalView(config: config, telemetry: tele, isPreview: false)) }
)

struct MinimalView: View {
    let config: SlotConfig
    let telemetry: NativeTelemetry?
    let isPreview: Bool

    var accent: Color { Color(hex: config.accentHex) ?? .white }

    var body: some View {
        ZStack {
            Color(white: 0.06)
            VStack(spacing: 0) {
                Rectangle()
                    .fill(accent)
                    .frame(height: 3)
                    .frame(maxWidth: .infinity)
                Spacer()
                VStack(spacing: 6) {
                    Text(Date(), style: .time)
                        .font(.system(size: 42, weight: .ultraLight, design: .default))
                        .foregroundColor(.white)
                        .monospacedDigit()
                    Text(Date(), style: .date)
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(0.5)
                }
                Spacer()
            }
        }
    }
}

let neonTemplate = WidgetTemplate(
    id: "neon",
    name: "Neon",
    preview: AnyView(NeonView(config: .empty, telemetry: nil, isPreview: true)),
    render: { config, tele in AnyView(NeonView(config: config, telemetry: tele, isPreview: false)) }
)

struct NeonView: View {
    let config: SlotConfig
    let telemetry: NativeTelemetry?
    let isPreview: Bool

    var accent: Color { Color(hex: config.accentHex) ?? .green }
    var battery: Int { isPreview ? 100 : (telemetry?.batteryPercent ?? 0) }

    var body: some View {
        ZStack {
            Color.black
            VStack(alignment: .leading, spacing: 4) {
                Text(config.title.isEmpty ? "DRIVE" : config.title.uppercased())
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundColor(accent)
                    .shadow(color: accent, radius: 6)
                    .tracking(3)
                Spacer()
                Text(Date(), style: .time)
                    .font(.system(size: 46, weight: .black, design: .monospaced))
                    .foregroundColor(accent)
                    .shadow(color: accent.opacity(0.8), radius: 12)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                Spacer()
                if battery > 0 {
                    HStack(spacing: 4) {
                        ForEach(0..<5) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Double(i) / 5.0 < Double(battery) / 100.0
                                      ? accent : Color.white.opacity(0.1))
                                .frame(width: 16, height: 6)
                        }
                        Text("\(battery)%")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(accent.opacity(0.8))
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

let allTemplates: [WidgetTemplate] = [
    darkClockTemplate,
    batteryGlowTemplate,
    carStatusTemplate,
    minimalTemplate,
    neonTemplate,
]

// MARK: - Native Designer Channel & View

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

struct WidgetDesignerView: View {
    @Environment(\.presentationMode) var presentationMode

    @State private var selectedSlot: Int = 0
    @State private var selectedTemplateId: String = "dark_clock"
    @State private var accentHex: String = "#00D4FF"
    @State private var title: String = "Drive Studio"
    @State private var subtitle: String = "My Car"

    let colors = ["#00D4FF", "#FF3B30", "#34C759", "#AF52DE", "#FF9500", "#FFCC00", "#FFFFFF"]

    var currentConfig: SlotConfig {
        SlotConfig(
            templateId: selectedTemplateId,
            accentHex: accentHex,
            title: title,
            subtitle: subtitle,
            updatedAt: Date()
        )
    }

    var currentTemplate: WidgetTemplate {
        allTemplates.first(where: { $0.id == selectedTemplateId }) ?? darkClockTemplate
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        Picker("Target Slot", selection: $selectedSlot) {
                            Text("Slot 1").tag(0)
                            Text("Slot 2").tag(1)
                            Text("Slot 3").tag(2)
                            Text("Slot 4").tag(3)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        .onChange(of: selectedSlot) { newSlot in
                            loadSlotData(newSlot)
                        }

                        VStack(spacing: 8) {
                            Text("PREVIEW")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)

                            currentTemplate.render(currentConfig, loadNativeTelemetry())
                                .frame(width: 170, height: 170)
                                .cornerRadius(24)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                                .shadow(color: (Color(hex: accentHex) ?? .blue).opacity(0.3), radius: 15)
                        }
                        .padding(.vertical, 8)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("SELECT TEMPLATE")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(allTemplates) { template in
                                        Button(action: {
                                            selectedTemplateId = template.id
                                        }) {
                                            VStack(spacing: 8) {
                                                template.preview
                                                    .frame(width: 100, height: 100)
                                                    .cornerRadius(16)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 16)
                                                            .stroke(selectedTemplateId == template.id ? (Color(hex: accentHex) ?? .blue) : Color.white.opacity(0.1), lineWidth: selectedTemplateId == template.id ? 2 : 1)
                                                    )

                                                Text(template.name)
                                                    .font(.caption2)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(selectedTemplateId == template.id ? .white : .gray)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("ACCENT COLOR")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                                .padding(.horizontal)

                            HStack(spacing: 16) {
                                ForEach(colors, id: \.self) { hex in
                                    Circle()
                                        .fill(Color(hex: hex) ?? .blue)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: accentHex == hex ? 3 : 0)
                                        )
                                        .onTapGesture {
                                            accentHex = hex
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }

                        Button(action: saveAndClose) {
                            Text("Save to Slot \(selectedSlot + 1)")
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(hex: accentHex) ?? .blue)
                                .cornerRadius(16)
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Native Widget Designer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                loadSlotData(selectedSlot)
            }
        }
    }

    private func loadSlotData(_ slot: Int) {
        let loaded = WidgetStore.load(slot: slot)
        if !loaded.isEmpty {
            selectedTemplateId = loaded.templateId
            accentHex = loaded.accentHex
            title = loaded.title
            subtitle = loaded.subtitle
        }
    }

    private func saveAndClose() {
        WidgetStore.save(currentConfig, forSlot: selectedSlot)
        presentationMode.wrappedValue.dismiss()
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


