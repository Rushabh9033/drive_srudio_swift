import SwiftUI
import PhotosUI

// MARK: - Full Screen Custom Studio Editor
struct EditorScreen: View {
    let draftId: String
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    
    @State private var spec: WidgetSpec
    @State private var widgetName: String
    @State private var _past: [WidgetSpec] = []
    @State private var _future: [WidgetSpec] = []
    
    @State private var activeDock = "CAR"
    @State private var showUnsavedAlert = false
    @State private var selectedLayerIndex: Int? = nil
    
    // Image picker state
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var isProcessingImage = false
    @State private var showPickerSheet = false
    @State private var shouldRemoveBackground = false
    @State private var showLayerSettings = false
    @State private var showWidgetLibrary = false
    @State private var showBackgroundPicker = false
    @State private var showWidgetSettings = false
    @State private var showDrawingSheet = false

    init(draftId: String) {
        self.draftId = draftId
        
        var initialSpec: WidgetSpec = .empty
        var initialName: String = "Untitled Widget"
        
        if draftId != "new" && draftId != "new_blank" {
            if let existing = AppStore.shared.drafts.first(where: { $0.id == draftId }) {
                initialName = existing.name
                initialSpec = existing.spec
            } else if let stock = StockWidgetCatalog.shared.widgets.first(where: { $0.stockWidgetId == draftId }) {
                initialName = "\(stock.name) Custom"
                initialSpec = stock.document
            }
        }
        
        self._spec = State(initialValue: initialSpec)
        self._widgetName = State(initialValue: initialName)
    }

    private let dockItems: [(label: String, icon: String)] = [
        ("CAR",    "car.fill"),
        ("TEXT",   "textformat"),
        ("WIDGET", "square.grid.2x2"),
        ("DRAW",   "pencil"),
        ("BG",     "paintbrush"),
    ]
    
    var canUndo: Bool { !_past.isEmpty }
    var canRedo: Bool { !_future.isEmpty }

    var body: some View {
        ZStack(alignment: .bottom) {
            DriveColors.background
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { selectedLayerIndex = nil }

            VStack(spacing: 0) {
                // ── Top Nav Bar ─────────────────────────────────────
                HStack(spacing: 8) {
                    Button(action: { showUnsavedAlert = true }) {
                        ZStack {
                            Circle()
                                .fill(DriveColors.secondary)
                                .overlay(Circle().stroke(DriveColors.border, lineWidth: 1))
                                .frame(width: 36, height: 36)
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(DriveColors.foreground)
                        }
                    }

                    Spacer()

                    // Undo / Redo
                    HStack(spacing: 4) {
                        Button(action: { undo() }) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(canUndo ? DriveColors.foreground : DriveColors.mutedFg)
                                .frame(width: 34, height: 34)
                                .background(DriveColors.secondary)
                                .cornerRadius(8)
                        }
                        .disabled(!canUndo)

                        Button(action: { redo() }) {
                            Image(systemName: "arrow.uturn.forward")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(canRedo ? DriveColors.foreground : DriveColors.mutedFg)
                                .frame(width: 34, height: 34)
                                .background(DriveColors.secondary)
                                .cornerRadius(8)
                        }
                        .disabled(!canRedo)
                    }

                    // ── Sleek Save Button ────────────────────────────
                    Button(action: { saveAndExit() }) {
                        ZStack {
                            Capsule()
                                .fill(DriveColors.primary)
                                .shadow(color: DriveColors.primary.opacity(0.35), radius: 6, x: 0, y: 2)

                            HStack(spacing: 5) {
                                Image(systemName: "square.and.arrow.down.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .offset(y: -0.5)
                                Text("Save")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(DriveColors.primaryFg)
                        }
                        .frame(width: 76, height: 32)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // ── Upper Action Row (Name + Add Vehicle + Settings) ────────
                HStack(spacing: 8) {
                    TextField("Widget name", text: $widgetName)
                        .font(.system(size: 13))
                        .foregroundColor(DriveColors.foreground)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(DriveColors.carbon)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(DriveColors.border, lineWidth: 1))

                    Button(action: {
                        activeDock = "CAR"
                        showPickerSheet = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "car.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("Add Vehicle")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(color: Color.white.opacity(0.18), radius: 4, x: 0, y: 2)
                    }

                    Button(action: { showWidgetSettings = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 12))
                            Text("Settings")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(DriveColors.foreground)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(DriveColors.secondary)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(DriveColors.border, lineWidth: 1))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                // ── Canvas Area ─────────────────────────────────────
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(DriveColors.carbon)
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(DriveColors.border, lineWidth: 1))
                        .frame(width: 320, height: 320)

                    // Always show WidgetCanvas — overlay empty hint on top when no layers yet
                    WidgetCanvas(spec: $spec, selectedLayerIndex: $selectedLayerIndex, onInspect: { _ in
                        showLayerSettings = true
                    })
                    .frame(width: 320, height: 320)

                    // Empty-state hint (only visible when canvas has zero layers)
                    if spec.layers?.isEmpty ?? true {
                        VStack(spacing: 16) {
                            Image(systemName: "square.stack.3d.up")
                                .font(.system(size: 38, weight: .light))
                                .foregroundColor(.white.opacity(0.35))
                            Text("Design your widget")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            VStack(spacing: 10) {
                                Button(action: {
                                    activeDock = "CAR"
                                    showPickerSheet = true
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "car.fill")
                                        Text("Add vehicle")
                                    }
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.black)
                                    .frame(width: 180)
                                    .padding(.vertical, 10)
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .contentShape(RoundedRectangle(cornerRadius: 12))
                                }

                                Button(action: {
                                    activeDock = "WIDGET"
                                    showWidgetLibrary = true
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "square.grid.2x2")
                                        Text("Widget Library")
                                    }
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 180)
                                    .padding(.vertical, 10)
                                    .background(Color.white.opacity(0.12))
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.24), lineWidth: 1))
                                    .contentShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    }
                    
                    if isProcessingImage {
                        Color.black.opacity(0.5).cornerRadius(24)
                        ProgressView().tint(.white).scaleEffect(1.5)
                    }
                }

                Text("Drag layers to position")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(1.5)
                    .foregroundColor(DriveColors.mutedFg)
                    .padding(.top, 12)

                Spacer()

                // ── Layer Context Toolbar ─────────────────────────────────
                if let i = selectedLayerIndex, let layers = spec.layers, i < layers.count {
                    HStack(spacing: 12) {
                        Text(layers[i].kind.capitalized)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(DriveColors.primary)
                        Spacer().frame(width: 0)
                        PillIconButton(icon: "slider.horizontal.3", disabled: false) { showLayerSettings = true }
                        PillIconButton(icon: "trash", disabled: false, destructive: true) { deleteLayer(index: i) }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(DriveColors.carbon)
                    .cornerRadius(999)
                    .overlay(Capsule().stroke(DriveColors.border, lineWidth: 1))
                    .shadow(color: .black.opacity(0.2), radius: 24, y: 8)
                    .padding(.bottom, 8)
                }

                // ── Editor Dock Bar (Liquid Glass Pill Design) ─────────────────
                HStack(spacing: 0) {
                    ForEach(dockItems, id: \.label) { item in
                        Button(action: {
                            activeDock = item.label
                            handleDockTab(item.label)
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 18, weight: activeDock == item.label ? .bold : .medium))
                                Text(item.label)
                                    .font(.system(size: 9, weight: activeDock == item.label ? .bold : .medium, design: .monospaced))
                                    .tracking(1.2)
                            }
                            .foregroundColor(activeDock == item.label ? DriveColors.primary : DriveColors.mutedFg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(activeDock == item.label ? DriveColors.primary.opacity(0.18) : Color.clear)
                            .cornerRadius(18)
                        }
                    }
                }
                .padding(6)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.7), .white.opacity(0.15), Color(hex: "00FFFF").opacity(0.35)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color.black.opacity(0.4), radius: 16, x: 0, y: 8)
                .shadow(color: DriveColors.primary.opacity(0.15), radius: 10, x: 0, y: 2)
                .padding(.horizontal, 20)
                .padding(.bottom, 2)
            }
        }
        // Draft is pre-loaded in init(draftId:), no need to reload on appear
        // .onAppear { loadDraft() }
        .onChange(of: draftId) { _ in loadDraft() }
        .alert("Unsaved changes", isPresented: $showUnsavedAlert) {
            Button("Keep editing", role: .cancel) {}
            Button("Discard", role: .destructive) { dismiss() }
            Button("Save and exit") { saveAndExit() }
        }
        // Action sheet for adding a vehicle
        .confirmationDialog("Add Vehicle Image", isPresented: $showPickerSheet, titleVisibility: .visible) {
            Button("Gallery (Remove Background)") { shouldRemoveBackground = true; showPhotosPicker() }
            Button("Gallery (Original)") { shouldRemoveBackground = false; showPhotosPicker() }
            Button("Cancel", role: .cancel) {}
        }
        // Actually picking the photo
        .photosPicker(isPresented: $isShowingPhotosPicker, selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) { _ in
            if let item = selectedItem { processPickedItem(item) }
        }
        .sheet(isPresented: $showLayerSettings) {
            if let idx = selectedLayerIndex {
                LayerSettingsSheet(spec: $spec, layerIndex: idx)
            }
        }
        .sheet(isPresented: $showWidgetLibrary) {
            WidgetLibrarySheet { layers in
                commitState()
                var newLayers = spec.layers ?? []
                newLayers.append(contentsOf: layers)
                spec.layers = newLayers
                selectedLayerIndex = newLayers.count - 1
            }
        }
        .sheet(isPresented: $showBackgroundPicker) {
            BackgroundSheet { bg in
                commitState()
                spec.background = bg
            }
        }
        .sheet(isPresented: $showWidgetSettings) {
            WidgetSettingsSheet(
                widgetName: $widgetName,
                onChangeBackground: {
                    showWidgetSettings = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showBackgroundPicker = true
                    }
                }
            )
        }
        .sheet(isPresented: $showDrawingSheet) {
            DrawingCanvasSheet(onSaveDrawing: { drawnImage in
                addDrawnImageLayer(image: drawnImage)
            })
        }
        .preferredColorScheme(.dark)
    }
    
    @State private var isShowingPhotosPicker = false
    func showPhotosPicker() {
        isShowingPhotosPicker = true
    }
    
    // MARK: - Logic
    func resetCanvas() {
        commitState()
        spec = .empty
        widgetName = "Untitled Widget"
        selectedLayerIndex = nil
    }

    func commitState() {
        _past.append(spec)
        _future.removeAll()
    }
    func undo() {
        guard !_past.isEmpty else { return }
        _future.append(spec)
        spec = _past.removeLast()
    }
    func redo() {
        guard !_future.isEmpty else { return }
        _past.append(spec)
        spec = _future.removeLast()
    }
    
    func handleDockTab(_ tab: String) {
        if tab == "CAR" {
            showPickerSheet = true
        } else if tab == "TEXT" {
            commitState()
            var newLayers = spec.layers ?? []
            newLayers.append(WidgetLayer.newText())
            spec.layers = newLayers
            selectedLayerIndex = newLayers.count - 1
        } else if tab == "WIDGET" {
            showWidgetLibrary = true
        } else if tab == "DRAW" {
            showDrawingSheet = true
        } else if tab == "BG" {
            showBackgroundPicker = true
        }
    }

    private func addDrawnImageLayer(image: UIImage) {
        let filename = "draw_\(UUID().uuidString).png"
        let pngData = image.pngData()

        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = docs.appendingPathComponent(filename)
            try? pngData?.write(to: fileURL)
        }

        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.drivestudio.shared") {
            let sharedRootURL = groupURL.appendingPathComponent(filename)
            try? pngData?.write(to: sharedRootURL)

            let sharedImagesDir = groupURL.appendingPathComponent("SharedImages")
            try? FileManager.default.createDirectory(at: sharedImagesDir, withIntermediateDirectories: true)
            let sharedImagesURL = sharedImagesDir.appendingPathComponent(filename)
            try? pngData?.write(to: sharedImagesURL)
        }

        commitState()
        var newLayers = spec.layers ?? []
        let layer = WidgetLayer(
            id: UUID().uuidString,
            kind: "image",
            src: filename,
            x: 10.0,
            y: 10.0,
            w: 80.0,
            h: 80.0
        )
        newLayers.append(layer)
        spec.layers = newLayers
        selectedLayerIndex = newLayers.count - 1
    }
    
    func changeSize(by percent: Double, index: Int) {
        guard var layers = spec.layers, index < layers.count else { return }
        commitState()
        var l = layers[index]
        if l.kind == "text" {
            l.fontSize = (l.fontSize ?? 24) * (1.0 + percent)
        } else {
            l.w = (l.w ?? 100) * (1.0 + percent)
            l.h = (l.h ?? 100) * (1.0 + percent)
        }
        layers[index] = l
        spec.layers = layers
    }
    
    func deleteLayer(index: Int) {
        guard var layers = spec.layers, index < layers.count else { return }
        commitState()
        layers.remove(at: index)
        spec.layers = layers
        selectedLayerIndex = nil
    }

    func loadDraft() {
        if draftId == "new" || draftId == "new_blank" {
            spec = .empty
            widgetName = "Untitled Widget"
        } else if let existing = store.drafts.first(where: { $0.id == draftId }) {
            widgetName = existing.name
            spec = existing.spec
        } else if let stock = StockWidgetCatalog.shared.widgets.first(where: { $0.stockWidgetId == draftId }) {
            widgetName = "\(stock.name) Custom"
            spec = stock.document
        } else {
            spec = .empty
            widgetName = "Untitled Widget"
        }
        // Auto-migrate legacy hardcoded placeholder layers to live kinds
        migrateLegacyLayers()
    }

    /// Upgrades old `kind:"text"` layers that held placeholder values
    /// (e.g. "85%", "100%", "124 km/h") to the correct live-data kind
    /// so the canvas preview and home screen widget both show real data.
    private func migrateLegacyLayers() {
        guard var layers = spec.layers else { return }
        var changed = false
        let batteryPattern = #"^\d{1,3}\s*%"#   // "85%", "100 %", "72%"
        let speedPattern   = #"^\d+"#             // "124", "0"
        for i in layers.indices {
            let layer = layers[i]
            guard layer.kind == "text", let txt = layer.text else { continue }
            let trimmed = txt.trimmingCharacters(in: .whitespaces)
            if trimmed.range(of: batteryPattern, options: .regularExpression) != nil
                && trimmed.hasSuffix("%") {
                // Looks like a battery placeholder → upgrade to live battery
                layers[i].kind = "battery"
                layers[i].text = nil
                changed = true
            } else if trimmed.uppercased() == "BATTERY"
                       || trimmed.uppercased() == "BAT" {
                layers[i].kind = "battery"
                layers[i].text = nil
                changed = true
            }
        }
        if changed { spec.layers = layers }
    }

    func saveAndExit() {
        let actualId = (draftId == "new" || draftId == "new_blank") ? UUID().uuidString : draftId
        let draft = Draft(id: actualId, name: widgetName, spec: spec, updatedAt: Date().timeIntervalSince1970)
        store.saveDraft(draft)
        
        // Capture widget image and save to App Group
        captureAndSaveWidgetImage(draftId: actualId, spec: spec)
        
        dismiss()
    }
    
    @MainActor
    private func captureAndSaveWidgetImage(draftId: String, spec: WidgetSpec) {
        let renderer = ImageRenderer(content: 
            WidgetCanvas(spec: .constant(spec), selectedLayerIndex: .constant(nil))
                .frame(width: 320, height: 320)
        )
        renderer.scale = UIScreen.main.scale
        
        if let uiImage = renderer.uiImage {
            // Try to save to App Group, fallback to Documents if missing
            let fm = FileManager.default
            let dir: URL
            if let groupURL = fm.containerURL(forSecurityApplicationGroupIdentifier: "group.com.drivestudio.shared") {
                dir = groupURL
            } else {
                dir = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
            }
            let fileURL = dir.appendingPathComponent("custom_\(draftId).png")
            if let data = uiImage.pngData() {
                try? data.write(to: fileURL)
            }
        }
    }

    private func processPickedItem(_ item: PhotosPickerItem) {
        isProcessingImage = true
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    guard let rawData = data, let originalImage = UIImage(data: rawData) else {
                        isProcessingImage = false
                        return
                    }
                    
                    if shouldRemoveBackground {
                        Task {
                            let resultImg: UIImage
                            if #available(iOS 17.0, *) {
                                do {
                                    resultImg = try await BgCutoutService.removeBackground(from: originalImage)
                                } catch {
                                    print("BgCutout error: \(error), using fallback")
                                    resultImg = await withCheckedContinuation { continuation in
                                        removeBackground(from: originalImage) { img in
                                            continuation.resume(returning: img ?? originalImage)
                                        }
                                    }
                                }
                            } else {
                                resultImg = await withCheckedContinuation { continuation in
                                    removeBackground(from: originalImage) { img in
                                        continuation.resume(returning: img ?? originalImage)
                                    }
                                }
                            }
                            
                            await MainActor.run {
                                isProcessingImage = false
                                addVehicleLayer(image: resultImg)
                            }
                        }
                    } else {
                        isProcessingImage = false
                        addVehicleLayer(image: originalImage)
                    }
                case .failure(let err):
                    isProcessingImage = false
                    print("Image pick error: \(err)")
                }
            }
        }
    }

    private func addVehicleLayer(image: UIImage) {
        let filename = "vehicle_\(UUID().uuidString).png"
        let pngData = image.pngData()
        
        // 1. Save to private Documents Directory
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = docs.appendingPathComponent(filename)
            try? pngData?.write(to: fileURL)
        }
        
        // 2. Save PERMANENTLY to App Group Shared Container (so Home Screen Widget extension can access it forever!)
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.drivestudio.shared") {
            let sharedRootURL = groupURL.appendingPathComponent(filename)
            try? pngData?.write(to: sharedRootURL)
            
            let sharedImagesDir = groupURL.appendingPathComponent("SharedImages")
            try? FileManager.default.createDirectory(at: sharedImagesDir, withIntermediateDirectories: true)
            let sharedImagesURL = sharedImagesDir.appendingPathComponent(filename)
            try? pngData?.write(to: sharedImagesURL)
        }
        
        commitState()
        var newLayers = spec.layers ?? []
        let layer = WidgetLayer(
            id: UUID().uuidString,
            kind: "image",
            src: filename,
            x: 10.0,
            y: 10.0,
            w: 80.0,
            h: 80.0
        )
        newLayers.append(layer)
        spec.layers = newLayers
        selectedLayerIndex = newLayers.count - 1
    }

    private func removeBackground(from image: UIImage, completion: @escaping (UIImage?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let width = cgImage.width
            let height = cgImage.height
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            var rawData = [UInt8](repeating: 0, count: width * height * 4)
            let bytesPerPixel = 4
            let bytesPerRow = bytesPerPixel * width
            let bitsPerComponent = 8
            
            guard let context = CGContext(
                data: &rawData,
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            ) else {
                completion(nil)
                return
            }
            
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            
            // Corner samples for background color detection
            let topLeft = (0, 0)
            let topRight = (width - 1, 0)
            let bottomLeft = (0, height - 1)
            let bottomRight = (width - 1, height - 1)
            
            func getPixel(_ x: Int, _ y: Int) -> (r: UInt8, g: UInt8, b: UInt8) {
                let offset = (y * bytesPerRow) + (x * bytesPerPixel)
                return (rawData[offset], rawData[offset + 1], rawData[offset + 2])
            }
            
            let p1 = getPixel(topLeft.0, topLeft.1)
            let p2 = getPixel(topRight.0, topRight.1)
            let p3 = getPixel(bottomLeft.0, bottomLeft.1)
            let p4 = getPixel(bottomRight.0, bottomRight.1)
            
            let bgR = Int(p1.r) + Int(p2.r) + Int(p3.r) + Int(p4.r)
            let bgG = Int(p1.g) + Int(p2.g) + Int(p3.g) + Int(p4.g)
            let bgB = Int(p1.b) + Int(p2.b) + Int(p3.b) + Int(p4.b)
            
            let targetR = bgR / 4
            let targetG = bgG / 4
            let targetB = bgB / 4
            
            let tolerance = 45
            
            for y in 0..<height {
                for x in 0..<width {
                    let offset = (y * bytesPerRow) + (x * bytesPerPixel)
                    let r = Int(rawData[offset])
                    let g = Int(rawData[offset + 1])
                    let b = Int(rawData[offset + 2])
                    
                    let diffR = abs(r - targetR)
                    let diffG = abs(g - targetG)
                    let diffB = abs(b - targetB)
                    
                    if diffR < tolerance && diffG < tolerance && diffB < tolerance {
                        rawData[offset + 3] = 0 // set alpha to 0
                    }
                }
            }
            
            guard let newCgImage = context.makeImage() else {
                completion(nil)
                return
            }
            
            let resultImage = UIImage(cgImage: newCgImage, scale: image.scale, orientation: image.imageOrientation)
            completion(resultImage)
        }
    }
}

struct PillIconButton: View {
    let icon: String
    let disabled: Bool
    var destructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(destructive ? DriveColors.destructive.opacity(0.15) : DriveColors.secondary)
                    .overlay(Circle().stroke(DriveColors.border, lineWidth: 1))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(destructive ? DriveColors.destructive : (disabled ? DriveColors.mutedFg : DriveColors.foreground))
            }
        }
        .disabled(disabled)
    }
}

struct WidgetSettingsSheet: View {
    @Binding var widgetName: String
    var onChangeBackground: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Widget Title")) {
                    TextField("Widget Name", text: $widgetName)
                }
                
                Section(header: Text("Background")) {
                    Button(action: onChangeBackground) {
                        HStack {
                            Image(systemName: "paintbrush.fill")
                                .foregroundColor(DriveColors.primary)
                            Text("Change Background Style")
                                .foregroundColor(DriveColors.foreground)
                        }
                    }
                }
            }
            .navigationTitle("Widget Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
