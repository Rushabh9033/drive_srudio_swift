import SwiftUI

// MARK: - Premium Widget Gallery (Studio Tab)
struct PremiumWidgetGalleryView: View {
    @EnvironmentObject var store: AppStore
    var onOpenEditor: (String) -> Void
    
    @State private var selectedChip: String = "My Drafts"
    @State private var searchText = ""
    @State private var selectedWidget: StockWidgetDefinition?
    @State private var selectedDraft: Draft? = nil

    private let chipOptions = ["My Drafts", "Night & Time", "Phone Battery", "Driving", "Vehicle"]
    
    var filteredStockWidgets: [StockWidgetDefinition] {
        guard let cat = categoryForChip(selectedChip) else { return [] }
        var list = StockWidgetCatalog.shared.widgets.filter { $0.category == cat }
        if !searchText.isEmpty {
            list = list.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return list
    }
    
    private func categoryForChip(_ chip: String) -> StockWidgetCategory? {
        switch chip {
        case "Night & Time": return .nightTime
        case "Phone Battery": return .phoneBattery
        case "Driving": return .driving
        case "Vehicle": return .vehicle
        default: return nil
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                // Ambient radial glow
                Circle()
                    .fill(DriveColors.primary.opacity(0.15))
                    .frame(width: UIScreen.main.bounds.width, height: 400)
                    .blur(radius: 100)
                    .offset(y: -200)
                    .allowsHitTesting(false)
                
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 24) {
                        
                        // Header
                        HStack {
                            Text(selectedChip == "My Drafts" ? "My Custom Drafts" : "Stock Widgets")
                                .font(.system(size: 34, weight: .bold))
                                .tracking(-0.5)
                                .foregroundColor(.white)
                            Spacer()
                            
                            if selectedChip == "My Drafts" {
                                Button(action: { onOpenEditor("new") }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 14, weight: .bold))
                                        Text("New Widget")
                                            .font(.system(size: 13, weight: .bold))
                                    }
                                    .foregroundColor(DriveColors.primaryFg)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(DriveColors.primary)
                                    .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        
                        // Category Chips (Horizontally Scrollable)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(chipOptions, id: \.self) { chip in
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedChip = chip
                                        }
                                    }) {
                                        HStack(spacing: 6) {
                                            if chip == "My Drafts" {
                                                Image(systemName: "folder.fill")
                                                    .font(.system(size: 12))
                                            }
                                            Text(chip)
                                                .font(.system(size: 14, weight: selectedChip == chip ? .bold : .medium))
                                        }
                                        .foregroundColor(selectedChip == chip ? .black : .white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(selectedChip == chip ? Color.white : Color.clear)
                                        .cornerRadius(20)
                                        .overlay(
                                            Capsule()
                                                .stroke(selectedChip == chip ? Color.clear : Color.white.opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                        
                        // Content Section
                        if selectedChip == "My Drafts" {
                            // ── MY DRAFTS SECTION ─────────────────────────
                            if store.drafts.isEmpty {
                                VStack(spacing: 18) {
                                    ZStack {
                                        Circle()
                                            .fill(DriveColors.primary.opacity(0.12))
                                            .frame(width: 80, height: 80)
                                        Image(systemName: "paintpalette.fill")
                                            .font(.system(size: 36))
                                            .foregroundColor(DriveColors.primary)
                                    }
                                    
                                    Text("No Custom Drafts Yet")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text("Tap '+ Custom' in the tab bar or button below to design your own custom widget from scratch!")
                                        .font(.system(size: 14))
                                        .foregroundColor(DriveColors.mutedFg)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 36)
                                    
                                    Button(action: { onOpenEditor("new") }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "plus.circle.fill")
                                            Text("Create Custom Widget")
                                        }
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(DriveColors.primaryFg)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                        .background(DriveColors.primary)
                                        .cornerRadius(20)
                                        .shadow(color: DriveColors.primary.opacity(0.3), radius: 12)
                                    }
                                }
                                .padding(.vertical, 50)
                            } else {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                                    ForEach(store.drafts) { draft in
                                        Button(action: {
                                            selectedDraft = draft
                                        }) {
                                            VStack(alignment: .leading, spacing: 8) {
                                                ZStack(alignment: .topTrailing) {
                                                    RoundedRectangle(cornerRadius: 24)
                                                        .fill(Color(hex: "1C1C1E"))
                                                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(DriveColors.border, lineWidth: 1))
                                                    
                                                    // Widget Renderer
                                                    WidgetCanvas(
                                                        spec: .constant(draft.spec),
                                                        selectedLayerIndex: .constant(nil)
                                                    )
                                                    .clipShape(RoundedRectangle(cornerRadius: 24))
                                                    .allowsHitTesting(false)
                                                }
                                                .frame(height: 160)
                                                .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                                                
                                                HStack {
                                                    let displayName = (draft.name.isEmpty || draft.name == "Untitled Widget" || draft.name == "Untitled") ? "Custom Design" : draft.name
                                                    Text(displayName)
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundColor(.white)
                                                        .lineLimit(1)
                                                    Spacer()
                                                    Image(systemName: "ellipsis.circle")
                                                        .font(.system(size: 16))
                                                        .foregroundColor(DriveColors.mutedFg)
                                                }
                                                .padding(.horizontal, 4)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        } else {
                            // ── STOCK WIDGETS SECTION ──────────────────────
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                                ForEach(filteredStockWidgets) { widget in
                                    Button(action: {
                                        selectedWidget = widget
                                    }) {
                                        VStack {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 24)
                                                    .fill(Color(hex: "1C1C1E"))
                                                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(DriveColors.border, lineWidth: 1))
                                                
                                                WidgetCanvas(
                                                    spec: .constant(widget.document),
                                                    selectedLayerIndex: .constant(nil)
                                                )
                                                .clipShape(RoundedRectangle(cornerRadius: 24))
                                                .allowsHitTesting(false)
                                            }
                                            .frame(height: 160)
                                            .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                                            
                                            Text(widget.name)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.white)
                                                .padding(.top, 4)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        Spacer().frame(height: 100) // Bottom safe area for floating tab bar
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(item: $selectedWidget) { widget in
            StockWidgetDetailSheet(widget: widget, onOpenEditor: onOpenEditor)
                .environmentObject(store)
        }
        .sheet(item: $selectedDraft) { draft in
            DraftDetailSheet(draft: draft, onOpenEditor: onOpenEditor)
                .environmentObject(store)
        }
    }
}

// MARK: - Custom Draft Detail Sheet
struct DraftDetailSheet: View {
    let draft: Draft
    var onOpenEditor: (String) -> Void
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    @State private var showSlotPicker = false
    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack {
            Color(hex: "111111").ignoresSafeArea()

            VStack(spacing: 20) {
                Text(draft.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 20)

                // Large Canvas Preview
                WidgetCanvas(spec: .constant(draft.spec), selectedLayerIndex: .constant(nil))
                    .frame(width: 220, height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(DriveColors.border, lineWidth: 1))
                    .shadow(color: DriveColors.primary.opacity(0.25), radius: 20)

                VStack(spacing: 12) {
                    // Edit Button
                    Button(action: {
                        let idToEdit = draft.id
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onOpenEditor(idToEdit)
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "pencil")
                            Text("Edit in Custom Studio")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .cornerRadius(14)
                    }

                    // Assign Button
                    Button(action: { showSlotPicker = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.grid.2x2")
                            Text("Assign to Widget Slot")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(DriveColors.primaryFg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(DriveColors.primary)
                        .cornerRadius(14)
                    }

                    // Delete Button
                    Button(action: { showDeleteConfirm = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "trash")
                            Text("Delete Draft")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(DriveColors.destructive)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(DriveColors.destructive.opacity(0.15))
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(DriveColors.destructive.opacity(0.3), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .presentationDetents([.fraction(0.72), .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showSlotPicker) {
            SlotPickerSheet(selectedWidgetId: draft.id)
                .environmentObject(store)
        }
        .confirmationDialog("Delete Draft", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete '\(draft.name)'", role: .destructive) {
                store.deleteDraft(draft.id)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - CarPlay Preview Sheet
struct CarPlayPreviewSheet: View {
    let spec: WidgetSpec
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color(hex: "111111").ignoresSafeArea()
            VStack(spacing: 20) {
                Text("CarPlay Preview")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 20)

                // Mock CarPlay display
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: "1A1A1A"))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))

                    HStack(spacing: 0) {
                        // Left dock
                        VStack(spacing: 20) {
                            ForEach(["map", "music.note", "message", "square.grid.2x2"], id: \.self) { icon in
                                Image(systemName: icon)
                                    .font(.system(size: 20))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .frame(width: 60)
                        .frame(maxHeight: .infinity)
                        .background(Color.black.opacity(0.6))

                        Spacer()

                        // Widget preview spot
                        WidgetCanvas(spec: .constant(spec), selectedLayerIndex: .constant(nil))
                            .frame(width: 140, height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(DriveColors.border, lineWidth: 1))
                            .allowsHitTesting(false)
                        
                        Spacer().frame(width: 20)
                    }
                }
                .frame(height: 200)
                .padding(.horizontal, 20)

                Button("Done") { dismiss() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DriveColors.primaryFg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(DriveColors.primary)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
        .presentationDetents([.fraction(0.55), .medium])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Slot Picker Sheet
struct SlotPickerSheet: View {
    let selectedWidgetId: String
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color(hex: "18181A").ignoresSafeArea()
            
            VStack(spacing: 0) {
                Text("Assign Slot")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 20)

                Text("Choose which home screen slot to use")
                    .font(.system(size: 14))
                    .foregroundColor(DriveColors.mutedFg)
                    .padding(.top, 4)
                    .padding(.bottom, 20)

                VStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { i in
                        HStack(spacing: 16) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.3))
                                .frame(width: 44, height: 44)
                                .overlay(Image(systemName: "square.grid.2x2").foregroundColor(DriveColors.mutedFg))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Slot \(i + 1)")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                Text(slotName(for: i))
                                    .font(.system(size: 13))
                                    .foregroundColor(store.slots[i] != nil ? DriveColors.primary : .white.opacity(0.35))
                            }

                            Spacer()

                            Button(action: {
                                store.assignSlot(i, draftId: selectedWidgetId)
                                dismiss()
                            }) {
                                Text(store.slots[i] != nil ? "Replace" : "Assign")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(store.slots[i] != nil ? DriveColors.foreground : DriveColors.primaryFg)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(store.slots[i] != nil ? Color.white.opacity(0.1) : DriveColors.primary)
                                    .cornerRadius(12)
                                    .contentShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .presentationDetents([.fraction(0.65), .medium])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }

    private func slotName(for index: Int) -> String {
        guard let id = store.slots[index] else { return "Empty" }
        if let custom = store.drafts.first(where: { $0.id == id }) {
            return custom.name
        } else if let stock = StockWidgetCatalog.shared.widgets.first(where: { $0.stockWidgetId == id }) {
            return stock.name
        }
        return "Empty"
    }
}

// MARK: - Stock Widget Detail Sheet
struct StockWidgetDetailSheet: View {
    let widget: StockWidgetDefinition
    var onOpenEditor: (String) -> Void
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    @State private var showSlotPicker = false

    var body: some View {
        ZStack {
            Color(hex: "111111").ignoresSafeArea()

            VStack(spacing: 20) {
                Text(widget.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 20)

                // Large Canvas Preview
                WidgetCanvas(spec: .constant(widget.document), selectedLayerIndex: .constant(nil))
                    .frame(width: 220, height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(DriveColors.border, lineWidth: 1))
                    .shadow(color: DriveColors.primary.opacity(0.25), radius: 20)

                VStack(spacing: 12) {
                    // Assign to Slot
                    Button(action: { showSlotPicker = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.grid.2x2")
                            Text("Assign to Widget Slot")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(DriveColors.primaryFg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(DriveColors.primary)
                        .cornerRadius(14)
                    }

                    // Customize Copy
                    Button(action: {
                        let newDraft = Draft(id: UUID().uuidString, name: "\(widget.name) Custom", spec: widget.document, updatedAt: Date().timeIntervalSince1970)
                        store.saveDraft(newDraft)
                        let idToEdit = newDraft.id
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onOpenEditor(idToEdit)
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "paintpalette")
                            Text("Customize in Custom Studio")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.25), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .presentationDetents([.fraction(0.68), .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showSlotPicker) {
            SlotPickerSheet(selectedWidgetId: widget.stockWidgetId)
                .environmentObject(store)
        }
        .preferredColorScheme(.dark)
    }
}
