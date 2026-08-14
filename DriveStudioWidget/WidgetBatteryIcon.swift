import Foundation

/// Shared battery-symbol helper used by production views (the
/// widget-extension `ScaledLayerView` and the host-app status row)
/// and by tests. Centralized so a known percentage always maps to
/// the same SF Symbol and so unknown battery never visually appears
/// full.
///
/// The host `DashboardView` "battery reporting" status row and the
/// widget-extension `ScaledLayerView` battery/battery_text layer
/// both call this helper. Tests assert the mapping for unknown,
/// 0%, normal ranges, 100%, and charging variants.
enum WidgetBatteryIcon {

    /// SF Symbol name for the battery at `percent`. `nil` means the
    /// widget never received a battery reading — render the neutral
    /// unavailable symbol instead of pretending the battery is full.
    /// This is the rule: unknown battery MUST NOT visually appear
    /// full.
    static func symbolName(percent: Int?, isCharging: Bool) -> String {
        let base: String
        if let p = percent {
            switch p {
            case ...0: base = "battery.0"
            case 1...24: base = "battery.25"
            case 25...49: base = "battery.25"
            case 50...74: base = "battery.50"
            case 75...94: base = "battery.75"
            default: base = "battery.100" // 95…100
            }
        } else {
            // Neutral unavailable symbol. Never `battery.100` — that
            // would lie about the battery being full.
            base = "bolt.slash"
        }
        return isCharging && base != "bolt.slash" ? "\(base).bolt" : base
    }

    /// Convenience for callers that pass an optional fraction (0…1)
    /// instead of a percentage. Returns the unavailable symbol for
    /// `nil`.
    static func symbolName(fraction: Double?, isCharging: Bool) -> String {
        guard let f = fraction else {
            return symbolName(percent: nil, isCharging: isCharging)
        }
        let pct = Int((max(0.0, min(1.0, f)) * 100.0).rounded())
        return symbolName(percent: pct, isCharging: isCharging)
    }
}
