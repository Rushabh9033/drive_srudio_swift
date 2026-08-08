import Foundation
import WidgetKit

// MARK: - Data Model

struct SlotConfig: Codable {
    var templateId: String
    var accentHex: String
    var title: String
    var subtitle: String
    var updatedAt: Date

    static let empty = SlotConfig(
        templateId: "dark_clock",
        accentHex: "#00D4FF",
        title: "Drive Studio",
        subtitle: "My Car",
        updatedAt: .distantPast
    )

    var isEmpty: Bool { updatedAt == .distantPast }
}

// MARK: - Store

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
        else { return .empty }
        return config
    }

    static func allSlots() -> [SlotConfig] {
        (0..<4).map { load(slot: $0) }
    }
}
