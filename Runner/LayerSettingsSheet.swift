import SwiftUI

struct LayerSettingsSheet: View {
    @Binding var spec: WidgetSpec
    let layerIndex: Int
    @Environment(\.dismiss) var dismiss
    
    @State private var draft: WidgetLayer
    
    @FocusState private var isTextFocused: Bool
    
    init(spec: Binding<WidgetSpec>, layerIndex: Int) {
        self._spec = spec
        self.layerIndex = layerIndex
        // Safe access — the layer at `layerIndex` may not exist (the
        // editor can pass an out-of-range index when a layer was just
        // deleted). Fall back to a fresh empty text layer instead of
        // force-unwrapping a nil array.
        let layers = spec.wrappedValue.layers ?? []
        let initialLayer: WidgetLayer
        if layerIndex >= 0 && layerIndex < layers.count {
            initialLayer = layers[layerIndex]
        } else {
            initialLayer = WidgetLayer.newText()
        }
        self._draft = State(initialValue: initialLayer)
    }
    
    var body: some View {
        NavigationView {
            Form {
                if draft.kind == "text" || draft.kind == "speed" || draft.kind == "vehicle_name" || draft.kind == "battery_text" || draft.kind == "clock" || draft.kind == "date" {
                    if draft.kind == "text" {
                        Section(header: Text("Text Content")) {
                            TextField("Text", text: Binding(
                                get: { draft.text ?? "" },
                                set: { draft.text = $0 }
                            ))
                            .focused($isTextFocused)
                        }
                    }
                    
                    Section(header: Text("Font Styling")) {
                        VStack(alignment: .leading) {
                            Text("Font Size: \(Int(draft.fontSize ?? 24))")
                            Slider(value: Binding(
                                get: { draft.fontSize ?? 24 },
                                set: { draft.fontSize = $0 }
                            ), in: 8...120, step: 1)
                        }
                        
                        Picker("Weight", selection: Binding(
                            get: { draft.weight ?? 600 },
                            set: { draft.weight = $0 }
                        )) {
                            Text("Regular").tag(400)
                            Text("Medium").tag(500)
                            Text("Semibold").tag(600)
                            Text("Bold").tag(700)
                            Text("Heavy").tag(800)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Alignment")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.secondary)
                            Picker("Alignment", selection: Binding(
                                get: { draft.align ?? "center" },
                                set: { draft.align = $0 }
                            )) {
                                Label("Left", systemImage: "text.alignleft").tag("left")
                                Label("Center", systemImage: "text.aligncenter").tag("center")
                                Label("Right", systemImage: "text.alignright").tag("right")
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                if draft.kind == "shape" {
                    Section(header: Text("Shape Settings")) {
                        VStack(alignment: .leading) {
                            Text("Corner Radius: \(Int(draft.radius ?? 0))")
                            Slider(value: Binding(
                                get: { draft.radius ?? 0 },
                                set: { draft.radius = $0 }
                            ), in: 0...100, step: 1)
                        }
                    }
                }
                
                Section(header: Text("Appearance")) {
                    ColorPicker("Primary Color", selection: Binding(
                        get: { Color(hex: draft.color ?? "FFFFFF") },
                        set: { draft.color = $0.toHex() }
                    ))
                    
                    VStack(alignment: .leading) {
                        Text("Opacity: \(String(format: "%.1f", draft.opacity ?? 1.0))")
                        Slider(value: Binding(
                            get: { draft.opacity ?? 1.0 },
                            set: { draft.opacity = $0 }
                        ), in: 0...1, step: 0.05)
                    }
                }
                
                Section(header: Text("Dimensions & Position")) {
                    HStack {
                        Text("X")
                        Spacer()
                        Text(String(format: "%.1f", draft.x ?? 0)).foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Y")
                        Spacer()
                        Text(String(format: "%.1f", draft.y ?? 0)).foregroundColor(.secondary)
                    }
                    HStack {
                        Text("W")
                        Spacer()
                        Text(String(format: "%.1f", draft.w ?? 0)).foregroundColor(.secondary)
                    }
                    HStack {
                        Text("H")
                        Spacer()
                        Text(String(format: "%.1f", draft.h ?? 0)).foregroundColor(.secondary)
                    }
                }

                // ── Group section ─────────────────────────────────────
                // Multi-layer library assets come in pre-grouped so the whole
                // composite behaves as one unit on the canvas. User can ungroup
                // to edit individual layers, or group this layer with the one
                // below it to form a new composite.
                Section(header: Text("Group")) {
                    if let gid = draft.groupId,
                       let allLayers = spec.layers {
                        let siblingCount = allLayers.filter { $0.groupId == gid }.count - 1
                        HStack {
                            Image(systemName: "square.stack.3d.up.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Grouped asset")
                                    .font(.system(size: 14, weight: .semibold))
                                Text(siblingCount > 0
                                    ? "\(siblingCount) other layer\(siblingCount == 1 ? "" : "s") move & resize together"
                                    : "Single layer group")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        Button {
                            if let layers = spec.layers {
                                var updated = layers
                                for i in updated.indices where updated[i].groupId == gid {
                                    updated[i].groupId = nil
                                }
                                spec.layers = updated
                                draft.groupId = nil
                            }
                        } label: {
                            Label("Ungroup", systemImage: "rectangle.split.3x1")
                                .foregroundColor(.red)
                        }
                    } else {
                        Button {
                            // Group this layer with the previous sibling (if any
                            // and currently ungrouped). Forms a new composite
                            // asset that the user can then drop into other
                            // widgets as one unit.
                            if let layers = spec.layers,
                               layerIndex > 0,
                               layerIndex - 1 < layers.count {
                                let prev = layers[layerIndex - 1]
                                if prev.groupId == nil {
                                    let newGid = UUID().uuidString
                                    var updated = layers
                                    updated[layerIndex - 1].groupId = newGid
                                    updated[layerIndex].groupId = newGid
                                    spec.layers = updated
                                    draft.groupId = newGid
                                }
                            }
                        } label: {
                            Label("Group with previous layer", systemImage: "rectangle.stack.fill.badge.plus")
                        }
                        .disabled(layerIndex <= 0)
                    }
                }
            }
            .navigationTitle("Edit \(draft.kind.capitalized)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        if layerIndex >= 0 && layerIndex < (spec.layers?.count ?? 0) {
                            spec.layers?[layerIndex] = draft
                        }
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .onAppear {
            if draft.kind == "text" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isTextFocused = true
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }
}

// Helper to convert Color back to hex
extension Color {
    func toHex() -> String {
        guard let components = cgColor?.components, components.count >= 3 else {
            return "FFFFFF"
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        var a = Float(1.0)
        
        if components.count >= 4 {
            a = Float(components[3])
        }
        
        if a != Float(1.0) {
            return String(format: "%02lX%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255), lroundf(a * 255))
        } else {
            return String(format: "%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        }
    }
}
