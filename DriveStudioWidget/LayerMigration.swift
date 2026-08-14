import Foundation

/// Single source of truth for upgrading legacy hardcoded placeholder layers
/// (e.g. `"85%"`, `"124"`, `"12:00"`) into the corresponding live-data
/// layer kind (battery / speed / clock / date / vehicle_name).
///
/// Prior to this enum the same regex chain lived in three places:
///   * `Runner/WidgetCanvas.swift` `liveSpec`
///   * `Runner/EditorScreen.swift` `migrateLegacyLayers` (now inline)
///   * `DriveStudioWidget/DriveStudioWidget.swift` `migrateLayers` (now inline)
///
/// This enum is the one place to add a new placeholder pattern. The other
/// three call sites now delegate to it.
///
/// The file lives in the `DriveStudioWidget/` synchronized folder so it is
/// automatically compiled into both the Runner app and the
/// DriveStudioWidgetExtension target — the widget cannot render live
/// values without going through the same upgrade path the editor uses.
enum LayerMigration {

    /// Returns a new array with any legacy `kind:"text"` placeholder layers
    /// replaced by their live-data equivalent. Pure function — input is
    /// not mutated. Layers that don't match a placeholder pattern are
    /// returned unchanged (Equatable field-by-field equality on `WidgetLayer`
    /// means unchanged layers are still `==` to the input).
    static func upgrade(_ layers: [WidgetLayer]) -> [WidgetLayer] {
        var out = layers
        for i in out.indices {
            let layer = out[i]
            guard layer.kind == "text", let txt = layer.text else { continue }
            let t = txt.trimmingCharacters(in: .whitespaces)
            if let upgraded = upgradePlaceholder(t, current: layer) {
                out[i] = upgraded
            }
        }
        return out
    }

    /// Convenience for the `spec.layers` upgrade path used by callers that
    /// operate on a full `WidgetSpec`. Always returns a fresh spec — the
    /// only caller is a computed property (`liveSpec`) where identity is
    /// invisible.
    static func upgrade(_ spec: WidgetSpec) -> WidgetSpec {
        guard let layers = spec.layers else { return spec }
        var s = spec
        s.layers = upgrade(layers)
        return s
    }

    // MARK: - Pattern rules

    /// Matches an old placeholder text against all known rules and returns
    /// a new layer with the appropriate live-data `kind`. Returns `nil`
    /// when the text does not look like a placeholder (i.e. keep it).
    private static func upgradePlaceholder(_ t: String, current: WidgetLayer) -> WidgetLayer? {
        // ── Battery: "85%", "100 %", "72%" ───────────────────────────────
        if t.hasSuffix("%") {
            let digits = t.dropLast().trimmingCharacters(in: .whitespaces)
            if !digits.isEmpty && digits.allSatisfy({ $0.isNumber }) {
                var l = current
                l.kind = "battery"
                l.text = nil
                return l
            }
        }

        // ── Battery: bare "BATTERY" / "BAT" labels ────────────────────────
        let upper = t.uppercased()
        if upper == "BATTERY" || upper == "BAT" {
            var l = current
            l.kind = "battery"
            l.text = nil
            return l
        }

        // ── Clock: "12:00", "6:12 PM", "23:59", "12:00:00" ────────────────
        let clockRx = #"^\d{1,2}:\d{2}(:\d{2})?(\s*(AM|PM|am|pm))?$"#
        if t.range(of: clockRx, options: .regularExpression) != nil {
            var l = current
            l.kind = "clock"
            l.text = nil
            return l
        }

        // ── Date: weekday or month names ─────────────────────────────────
        let dateRx = #"(?i)^(mon|tue|wed|thu|fri|sat|sun|monday|tuesday|wednesday|thursday|friday|saturday|sunday)"#
        let monthRx = #"(?i)^(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)"#
        if t.range(of: dateRx, options: .regularExpression) != nil
            || t.range(of: monthRx, options: .regularExpression) != nil {
            var l = current
            l.kind = "date"
            l.text = nil
            return l
        }

        // ── Speed: pure 1–3 digit integer "0" – "999" ────────────────────
        // Only upgrade if text is ONLY digits — avoids touching labels like "SLOT 1"
        if t.count <= 3 && !t.isEmpty && t.allSatisfy({ $0.isNumber }) {
            var l = current
            l.kind = "speed"
            l.text = nil
            return l
        }

        // ── Vehicle name placeholders ─────────────────────────────────────
        let vehicleHints = ["cyber sedan", "my vehicle", "select vehicle",
                            "vehicle name", "car name", "vehicle"]
        if vehicleHints.contains(t.lowercased()) {
            var l = current
            l.kind = "vehicle_name"
            l.text = nil
            return l
        }

        return nil
    }
}