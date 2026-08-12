import CarPlay
import UIKit
import CryptoKit

/// CarPlay scene delegate.
///
/// CarPlay Dashboard widgets surface in
/// `Settings → General → CarPlay → [My Car] → Customize → Widgets`
/// only after Apple grants a CarPlay entitlement (one of
/// `com.apple.developer.carplay-*`) AND the app declares
/// `CPTemplateApplicationSceneSessionRoleApplication` in its Info.plist.
///
/// This delegate renders a minimal `CPListTemplate` so the CarPlay scene
/// has a valid root template when (and if) Apple activates CarPlay Dashboard
/// widgets for this bundle id. Without a root template the CarPlay scene
/// fails to attach and the widget won't appear in the Customize list.
///
/// The widget the user sees on CarPlay Dashboard is the existing
/// `DriveStudioSlot1Widget`/`…Slot4Widget` definitions — this delegate
/// is only the scene host, not the widget renderer.
///
/// AppGroupHelper lives in the widget extension target, so this file
/// inlines a minimal V2/V1 reader to pull the slot summaries it needs.
@available(iOS 16.0, *)
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController

        let slots = Self.loadSlotSummaries()
        let items = slots.enumerated().map { idx, summary in
            let row = CPListItem(
                text: "Drive Studio - Slot \(idx + 1)",
                detailText: summary ?? "Not assigned"
            )
            row.handler = { _, completion in
                // Hand control back to the system so the widget picker
                // can highlight the matching widget.
                completion()
            }
            return row
        }

        let section = CPListSection(items: items)
        let template = CPListTemplate(
            title: "Drive Studio",
            sections: [section]
        )
        template.tabImage = UIImage(systemName: "car.fill")
        interfaceController.setRootTemplate(template, animated: false)
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
    }

    // MARK: - Inline App Group reader

    private struct AppGroupReader {
        static let suiteName = "group.com.drivestudio.shared"

        static func loadState() -> [String: Any]? {
            guard let defaults = UserDefaults(suiteName: suiteName),
                  let metadataData = defaults.data(forKey: "widget_state_v2_metadata"),
                  let metadata = try? JSONSerialization.jsonObject(with: metadataData) as? [String: Any],
                  let stateFile = metadata["stateFile"] as? String,
                  let checksum = metadata["checksum"] as? String,
                  let sharedURL = FileManager.default.containerURL(
                    forSecurityApplicationGroupIdentifier: suiteName)
            else {
                // V1 fallback
                if let defaults = UserDefaults(suiteName: suiteName),
                   let json = defaults.string(forKey: "widget_state_v1"),
                   let data = json.data(using: .utf8),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    return dict
                }
                return nil
            }

            let fileURL = sharedURL.appendingPathComponent(stateFile)
            guard let data = try? Data(contentsOf: fileURL) else { return nil }
            let actual = SHA256.hash(data: data)
                .compactMap { String(format: "%02x", $0) }
                .joined()
            guard actual == checksum else { return nil }
            return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        }
    }

    /// Pull a short summary (vehicle name + battery) for each of the four
    /// slots from the same App Group JSON the widget reads.
    private static func loadSlotSummaries() -> [String?] {
        guard let state = AppGroupReader.loadState() else {
            return Array(repeating: nil, count: 4)
        }
        let vehicle = state["vehicle"] as? [String: Any]
        let vehicleName = (vehicle?["displayName"] as? String)
            ?? (vehicle?["modelId"] as? String)
            ?? "Drive Studio"
        let telemetry = state["telemetry"] as? [String: Any]
        let battery = (telemetry?["batteryPercent"] as? Int)
            .map { "\($0)%" } ?? "—"
        let connected = ((telemetry?["carConnected"] as? Bool) ?? false)
            ? "Connected" : "Disconnected"
        let line = "\(vehicleName) · \(battery) · \(connected)"

        let slots = state["slots"] as? [[String: Any]] ?? []
        return (0..<4).map { idx in
            guard idx < slots.count else { return "Not assigned" }
            let slot = slots[idx]
            let draftId = slot["draftId"] as? String
            if draftId == nil || draftId?.isEmpty == true { return "Not assigned" }
            return line
        }
    }
}