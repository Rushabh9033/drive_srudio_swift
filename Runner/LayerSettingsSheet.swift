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
        // Safe access
        let initialLayer = (layerIndex >= 0 && layerIndex < (spec.wrappedValue.layers?.count ?? 0))
            ? spec.wrappedValue.layers![layerIndex]
            : WidgetLayer.newText() // Fallback
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
