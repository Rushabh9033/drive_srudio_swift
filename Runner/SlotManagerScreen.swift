import SwiftUI

struct SlotPickerTarget: Identifiable {
    let id: Int
}

struct SlotManagerScreen: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    
    @State private var targetSlot: SlotPickerTarget? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                DriveColors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Text("Drag slots to reorder. Position 1 is your Home Screen primary slot.")
                        .font(.system(size: 13))
                        .foregroundColor(DriveColors.mutedFg)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                    
                    List {
                        ForEach(0..<4, id: \.self) { i in
                            SlotManagerRow(
                                index: i,
                                draftId: store.slots[i],
                                onAssign: { targetSlot = SlotPickerTarget(id: i) }
                            )
                            .listRowBackground(DriveColors.background)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                        .onMove { indices, newOffset in
                            store.moveSlots(fromOffsets: indices, toOffset: newOffset)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Manage Slots")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                        .foregroundColor(DriveColors.primary)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(item: $targetSlot) { target in
                DraftPickerSheet(slotIndex: target.id)
                    .environmentObject(store)
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct SlotManagerRow: View {
    let index: Int
    let draftId: String?
    let onAssign: () -> Void
    
    @EnvironmentObject var store: AppStore
    
    var draftName: String {
        if let id = draftId {
            if let draft = store.drafts.first(where: { $0.id == id }) {
                return draft.name
            } else if let stock = StockWidgetCatalog.shared.widgets.first(where: { $0.stockWidgetId == id }) {
                return stock.name
            }
        }
        return "Empty"
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 60, height: 60)
                
                if draftId != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(DriveColors.primary)
                } else {
                    Image(systemName: "square.grid.2x2")
                        .foregroundColor(DriveColors.mutedFg)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Slot \(index + 1)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text(draftName)
                    .font(.system(size: 13))
                    .foregroundColor(draftId != nil ? DriveColors.primary : .white.opacity(0.35))
            }
            
            Spacer()
            
            if draftId != nil {
                Button(action: {
                    store.assignSlot(index, draftId: nil)
                }) {
                    Text("Clear")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(DriveColors.destructive)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                }
            }
            
            Button(action: onAssign) {
                Text("Assign")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DriveColors.primaryFg)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(DriveColors.primary)
                    .cornerRadius(12)
                    .contentShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .padding(.horizontal, 20)
    }
}

struct DraftPickerSheet: View {
    let slotIndex: Int
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    
    private func resolveDraftName(name: String, spec: WidgetSpec) -> String {
        if !name.isEmpty && name != "Untitled Widget" && name != "Untitled" {
            return name
        }
        guard let layers = spec.layers, !layers.isEmpty else {
            return "Custom Studio Design"
        }
        var hasCar = false
        var hasBattery = false
        var hasClock = false
        var hasSpeed = false
        
        for l in layers {
            if l.kind == "image" || l.src?.contains("car") == true || l.src?.contains("vehicle") == true {
                hasCar = true
            } else if l.kind == "battery" || l.kind == "battery_text" {
                hasBattery = true
            } else if l.kind == "clock" || l.kind == "date" {
                hasClock = true
            } else if l.kind == "speed" || l.kind == "speedometer" {
                hasSpeed = true
            }
        }
        
        if hasCar && hasSpeed { return "Custom Hyper Dash" }
        if hasCar { return "Custom Car Profile" }
        if hasBattery && hasClock { return "Power Clock Cluster" }
        if hasBattery { return "Custom Battery Meter" }
        if hasClock { return "Custom Digital Time" }
        if hasSpeed { return "Telemetry Speedometer" }
        return "Custom Graphic Design"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                DriveColors.background.ignoresSafeArea()
                
                List {
                    if !store.drafts.isEmpty {
                        Section(header: Text("My Custom Drafts").foregroundColor(DriveColors.primary)) {
                            ForEach(store.drafts) { draft in
                                Button(action: {
                                    store.assignSlot(slotIndex, draftId: draft.id)
                                    dismiss()
                                }) {
                                    HStack(spacing: 12) {
                                        // Live Thumbnail Preview
                                        WidgetCanvas(spec: .constant(draft.spec), selectedLayerIndex: .constant(nil))
                                            .frame(width: 56, height: 56)
                                            .cornerRadius(10)
                                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(DriveColors.border.opacity(0.5), lineWidth: 1))
                                            .allowsHitTesting(false)

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(resolveDraftName(name: draft.name, spec: draft.spec))
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(.white)
                                            Text("\(draft.spec.layers?.count ?? 0) Elements • Custom Design")
                                                .font(.system(size: 11))
                                                .foregroundColor(DriveColors.mutedFg)
                                        }
                                        Spacer()
                                        if store.slots[slotIndex] == draft.id {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(DriveColors.primary)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    
                    Section(header: Text("Stock Widgets").foregroundColor(DriveColors.primary)) {
                        ForEach(StockWidgetCatalog.shared.widgets) { stock in
                            Button(action: {
                                store.assignSlot(slotIndex, draftId: stock.stockWidgetId)
                                dismiss()
                            }) {
                                HStack(spacing: 12) {
                                    WidgetCanvas(spec: .constant(stock.document), selectedLayerIndex: .constant(nil))
                                        .frame(width: 56, height: 56)
                                        .cornerRadius(10)
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(DriveColors.border.opacity(0.5), lineWidth: 1))
                                        .allowsHitTesting(false)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(stock.name)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.white)
                                        Text(stock.category.rawValue)
                                            .font(.system(size: 11))
                                            .foregroundColor(DriveColors.mutedFg)
                                    }
                                    Spacer()
                                    if store.slots[slotIndex] == stock.stockWidgetId {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(DriveColors.primary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Assign Slot \(slotIndex + 1)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }
}
