import SwiftUI

/// Editor panel that lists every layer in the current draft, top of
/// stack first. The user can tap any row — including ones hidden
/// behind another layer — to make that layer the active selection.
/// Tapping a row sets `selectedLayerIndex` and dismisses the sheet
/// so the user can immediately drag, edit, or delete the layer via
/// the existing layer context toolbar.
struct LayersPanelSheet: View {
    @Binding var spec: WidgetSpec
    @Binding var selectedLayerIndex: Int?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                DriveColors.background.ignoresSafeArea()

                if let layers = spec.layers, !layers.isEmpty {
                    List {
                        Section(
                            header: Text("Top of stack first — tap any row to select, even if hidden behind another layer")
                                .foregroundColor(DriveColors.mutedFg)
                                .font(.system(size: 11, weight: .regular, design: .monospaced))
                        ) {
                            // Iterate reversed so the user sees the
                            // topmost layer first (matching the
                            // on-canvas visual order). `indices`
                            // preserves the real `spec.layers` index
                            // so `selectedLayerIndex` still points at
                            // the same layer the renderer uses.
                            ForEach(layers.indices.reversed(), id: \.self) { idx in
                                let layer = layers[idx]
                                Button(action: {
                                    selectedLayerIndex = idx
                                    dismiss()
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: iconName(for: layer.kind))
                                            .foregroundColor(.white)
                                            .frame(width: 24)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(labelFor(layer: layer))
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                            Text("Layer \(idx + 1) of \(layers.count)")
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundColor(DriveColors.mutedFg)
                                        }
                                        Spacer()
                                        if selectedLayerIndex == idx {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(DriveColors.primary)
                                                .font(.system(size: 18))
                                        }
                                        if layer.hidden == true {
                                            Image(systemName: "eye.slash")
                                                .foregroundColor(DriveColors.mutedFg)
                                                .font(.system(size: 13))
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "square.3.stack.3d")
                            .font(.system(size: 36, weight: .light))
                            .foregroundColor(.white.opacity(0.35))
                        Text("No layers yet")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Use the dock to add a vehicle, text, drawing, or stock widget.")
                            .font(.system(size: 12))
                            .foregroundColor(DriveColors.mutedFg)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
            }
            .navigationTitle("Layers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(DriveColors.primary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    /// SF Symbol matching the layer's `kind`. Falls back to a square
    /// for unknown kinds so new layer types are still navigable.
    private func iconName(for kind: String) -> String {
        switch kind {
        case "text":           return "textformat"
        case "image":          return "photo"
        case "draw":           return "pencil.tip.crop.circle"
        case "shape":          return "square.on.circle"
        case "clock":          return "clock"
        case "date":           return "calendar"
        case "speed":          return "speedometer"
        case "battery", "battery_text": return "battery.50"
        case "battery_bar":    return "battery.100"
        case "vehicle_name":   return "car"
        case "analog":         return "clock.fill"
        case "divider":        return "minus"
        default:               return "square"
        }
    }

    /// Human-readable label for the layer row. Includes the actual
    /// content when relevant (text body, image filename) so the user
    /// can distinguish two layers of the same kind.
    private func labelFor(layer: WidgetLayer) -> String {
        switch layer.kind {
        case "text":
            let txt = layer.text ?? ""
            return txt.isEmpty ? "Text" : "Text: \"\(txt)\""
        case "image":
            if let src = layer.src, !src.isEmpty { return "Image: \(src)" }
            return "Image"
        case "draw":
            return "Drawing"
        case "shape":
            return "Shape"
        case "clock":
            return "Clock"
        case "date":
            return "Date"
        case "speed":
            return "Speed"
        case "battery", "battery_text":
            return "Battery"
        case "battery_bar":
            return "Battery Bar"
        case "vehicle_name":
            return "Vehicle Name"
        case "analog":
            return "Analog Clock"
        case "divider":
            return "Divider"
        default:
            return layer.kind.capitalized
        }
    }
}
