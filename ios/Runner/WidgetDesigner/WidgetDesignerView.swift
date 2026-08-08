import SwiftUI

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
                        // Slot picker
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

                        // Widget Preview Canvas
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
                                .shadow(color: Color(hex: accentHex).opacity(0.3), radius: 15)
                        }
                        .padding(.vertical, 8)

                        // Templates horizontal carousel
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
                                                            .stroke(selectedTemplateId == template.id ? Color(hex: accentHex) : Color.white.opacity(0.1), lineWidth: selectedTemplateId == template.id ? 2 : 1)
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

                        // Accent Color picker
                        VStack(alignment: .leading, spacing: 12) {
                            Text("ACCENT COLOR")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                                .padding(.horizontal)

                            HStack(spacing: 16) {
                                ForEach(colors, id: \.self) { hex in
                                    Circle()
                                        .fill(Color(hex: hex))
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

                        // Save Button
                        Button(action: saveAndClose) {
                            Text("Save to Slot \(selectedSlot + 1)")
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(hex: accentHex))
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
