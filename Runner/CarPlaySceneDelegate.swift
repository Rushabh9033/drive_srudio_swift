import CarPlay
import UIKit

// NOTE: This file is intentionally NOT registered in project.pbxproj and
// does NOT compile. It is kept here for reference and as a starting point
// for when Apple grants the com.apple.developer.carplay-driving-task
// entitlement. To activate:
//   1. Add `CPTemplateApplicationSceneSessionRoleApplication` to Info.plist
//   2. Uncomment the entitlement in Runner.entitlements
//   3. Add this file to Runner's Sources phase
// Until then, the App Intents + CarPlay Shortcuts path is the active
// CarPlay integration surface.

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
/// Slot summaries are loaded via the shared `AppGroupState` reader
/// (see `DriveStudioWidget/AppGroupState.swift`).
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

    /// Pull a short summary (vehicle name + battery) for each of the four
    /// slots from the same App Group JSON the widget reads.
    private static func loadSlotSummaries() -> [String?] {
        guard let state = AppGroupState.loadState() else {
            return Array(repeating: nil, count: 4)
        }
        let vehicleName = state.vehicle?.displayName
            ?? state.vehicle?.modelId
            ?? "Drive Studio"
        let battery: String
        if let pct = state.telemetry?.batteryPercent {
            battery = "\(pct)%"
        } else {
            battery = "—"
        }
        let connected = state.telemetry?.carConnected == true ? "Connected" : "Disconnected"
        let line = "\(vehicleName) · \(battery) · \(connected)"

        let slots = state.slots ?? []
        return (0..<4).map { idx in
            guard idx < slots.count else { return "Not assigned" }
            let slot = slots[idx]
            if slot.draftId == nil || slot.draftId?.isEmpty == true { return "Not assigned" }
            return line
        }
    }
}