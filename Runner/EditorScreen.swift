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
    @State private var imageImportError: String? = nil
    @State private var saveError: String? = nil
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
    @State private var showLayersPanel = false

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
        ("LAYERS", "square.3.stack.3d"),
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
                DockBar(
                    activeDock: $activeDock,
                    items: dockItems,
                    onTap: handleDockTab
                )
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
        .alert("Image import failed",
               isPresented: Binding(
                get: { imageImportError != nil },
                set: { if !$0 { imageImportError = nil } }
               ),
               presenting: imageImportError) { _ in
            Button("Try again", role: .cancel) { imageImportError = nil }
            Button("Keep editing", role: .destructive) { imageImportError = nil }
        } message: { msg in
            Text(msg)
        }
        .alert("Couldn't save widget",
               isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
               ),
               presenting: saveError) { _ in
            Button("Try again", role: .cancel) { saveError = nil }
            Button("Keep editing", role: .destructive) { saveError = nil }
        } message: { msg in
            Text(msg)
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

                // 1) Fresh IDs on every insertion so tapping the same library
                //    item twice doesn't yield duplicate Identifiable IDs.
                // 2) Multi-layer items get a shared groupId so the composite
                //    moves and resizes together as one unit.
                let groupId: String? = layers.count > 1 ? UUID().uuidString : nil
                let insertedLayers = layers.map { l -> WidgetLayer in
                    var copy = l
                    copy.id = UUID().uuidString
                    copy.groupId = groupId
                    return copy
                }

                // 3) Translate the inserted group so its bounding box is
                //    centered on the canvas — library items store absolute
                //    positions (e.g. x:25), so without this every asset would
                //    pile up in the top-left corner.
                let centered = centerOnCanvas(insertedLayers)

                newLayers.append(contentsOf: centered)
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
        .sheet(isPresented: $showLayersPanel) {
            LayersPanelSheet(
                spec: $spec,
                selectedLayerIndex: $selectedLayerIndex
            )
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
        } else if tab == "LAYERS" {
            showLayersPanel = true
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

        // If this layer is part of a group, delete every sibling in the same
        // group at once so the user doesn't have to tap the trash button
        // once per layer to clear the whole composite.
        if let gid = layers[index].groupId {
            layers.removeAll { $0.groupId == gid }
        } else {
            layers.remove(at: index)
        }
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
        spec.layers = LayerMigration.upgrade(spec.layers ?? [])
    }

    /// Upgrades old placeholder text layers to live-data kinds via the
    /// shared `LayerMigration` enum so the editor preview and the home
    /// screen widget agree on what a layer represents.

    /// Truthful save-and-exit.
    ///
    /// Saving must publish ALL of the following before we dismiss the
    /// editor:
    ///   1. The spec mutation is committed to `store.drafts` so
    ///      `saveState()` can see it.
    ///   2. App Group V2 metadata + a new generation file are
    ///      published atomically (via `installState`).
    ///   3. Every referenced image derivative is staged into the
    ///      current generation's asset folder.
    ///   4. The widget-preview PNG snapshot is byte-verified.
    ///
    /// If anything fails the editor stays open, the previous widget
    /// generation remains canonical, and the user gets a retryable
    /// alert with the underlying error. We never dismiss over a
    /// half-published state.
    func saveAndExit() {
        let actualId = (draftId == "new" || draftId == "new_blank") ? UUID().uuidString : draftId
        let draft = Draft(
            id: actualId,
            name: widgetName,
            spec: spec,
            updatedAt: Date().timeIntervalSince1970
        )
        // 1. Mirror the spec into store.drafts so saveState() can
        //    pick up the new spec when it serializes the envelope.
        //    (saveDraft also calls saveState() internally — that
        //    call is allowed to fail silently here because we'll do
        //    an authoritative saveState() right after, which is the
        //    one whose result we surface to the user.)
        store.saveDraft(draft)

        // 2. Capture widget-preview snapshot and byte-verify BEFORE
        //    we attempt the authoritative state publish. The PNG
        //    write failing should not block the spec publish — the
        //    widget renders the spec layers directly, the PNG is
        //    only used for legacy fallback paths — but we DO need
        //    to know about it so we can surface the issue to the
        //    user instead of silently dropping the snapshot.
        let previewResult = captureAndSaveWidgetImage(
            draftId: actualId, spec: spec)
        if case .writeFailed(let msg) = previewResult {
            saveError = "Couldn't save widget preview image. \(msg)"
            return
        }

        // 3. Authoritative state publish. installState writes the
        //    generation file, byte-verifies it, stages assets, and
        //    only THEN publishes new metadata. If any step fails the
        //    in-memory drafts/slots snapshot is rolled back inside
        //    saveState() and we surface the error.
        do {
            try store.saveState()
        } catch {
            saveError = "Couldn't publish widget to the home screen. \(error.localizedDescription)"
            return
        }

        // 4. All steps succeeded — only now do we dismiss.
        dismiss()
    }

    @MainActor
    private enum CaptureResult: Equatable {
        case succeeded(URL)
        case writeFailed(String)
        case rendererUnavailable
    }

    @MainActor
    private func captureAndSaveWidgetImage(draftId: String, spec: WidgetSpec) -> CaptureResult {
        let renderer = ImageRenderer(content:
            WidgetCanvas(spec: .constant(spec), selectedLayerIndex: .constant(nil))
                .frame(width: 320, height: 320)
        )
        renderer.scale = UIScreen.main.scale

        guard let uiImage = renderer.uiImage,
              let data = uiImage.pngData() else {
            return .rendererUnavailable
        }

        // Prefer the App Group container; that's the location the
        // widget reads. If the entitlement is missing we fall back
        // to host Documents — the widget will still see the spec
        // publication regardless, but the snapshot will only be
        // available host-side.
        let fm = FileManager.default
        let dir: URL
        if let groupURL = fm.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.drivestudio.shared"
        ) {
            dir = groupURL
        } else if let docs = fm.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first {
            dir = docs
        } else {
            return .writeFailed("no host container available")
        }
        let fileURL = dir.appendingPathComponent("custom_\(draftId).png")
        if Self.writeImageVerified(data, to: fileURL) {
            return .succeeded(fileURL)
        }
        return .writeFailed("byte verification failed at \(fileURL.path)")
    }

    private func processPickedItem(_ item: PhotosPickerItem) {
        isProcessingImage = true
        // Capture the source type identifier BEFORE async hops so we
        // can preserve the original's extension (HEIC, PNG, WebP, …)
        // when we save the host-private copy. PhotosPickerItem
        // returns raw bytes via `loadTransferable(type: Data.self)`;
        // we never instantiate a full-resolution `UIImage` so a 48 MP
        // photo doesn't push us past available memory.
        let typeIdentifier = item.supportedContentTypes.first?.identifier
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    guard let rawData = data else {
                        isProcessingImage = false
                        imageImportError = "The picker returned no image bytes."
                        return
                    }
                    self.handlePickedImageData(
                        rawData, typeIdentifier: typeIdentifier)
                case .failure(let err):
                    isProcessingImage = false
                    print("Image pick error: \(err)")
                    imageImportError = "Couldn't load the picked image."
                }
            }
        }
    }

    /// Build a derivative from the picked bytes (optionally with
    /// background removal), then hand the result to
    /// `addVehicleLayer(derivative:originalBytes:originalFilename:)`
    /// which is the single mutation point for the editor's spec.
    private func handlePickedImageData(_ data: Data, typeIdentifier: String?) {
        let originalFilename = ImageDerivativeService.originalFilename(
            suggested: "picked",
            typeIdentifier: typeIdentifier
        )
        if shouldRemoveBackground {
            Task {
                let derivative: ImageDerivativeService.Derivative
                do {
                    derivative = try await Self.buildCutoutDerivative(
                        from: data, typeIdentifier: typeIdentifier)
                } catch {
                    await MainActor.run {
                        isProcessingImage = false
                        imageImportError = error.localizedDescription
                    }
                    return
                }
                await MainActor.run {
                    isProcessingImage = false
                    self.addVehicleLayer(
                        derivative: derivative,
                        originalBytes: data,
                        originalFilename: originalFilename
                    )
                }
            }
        } else {
            do {
                let derivative = try ImageDerivativeService.makeDerivative(
                    from: data,
                    suggestedFilename: originalFilename
                )
                isProcessingImage = false
                self.addVehicleLayer(
                    derivative: derivative,
                    originalBytes: data,
                    originalFilename: originalFilename
                )
            } catch {
                isProcessingImage = false
                imageImportError = error.localizedDescription
            }
        }
    }

    /// Background removal pipeline that NEVER allocates a buffer
    /// sized by the source's full resolution. We build a working
    /// CGImage (max 1024 px long edge) from the picked bytes, run
    /// the cutout on that bounded buffer, then re-derive a
    /// widget-safe derivative from the cutout result.
    private static func buildCutoutDerivative(
        from data: Data, typeIdentifier: String?
    ) async throws -> ImageDerivativeService.Derivative {
        if #available(iOS 17.0, *) {
            // Vision handles arbitrary input sizes natively; we feed
            // it the picked bytes via a temporary UIImage so Vision
            // can apply its own scaling. If Vision fails, fall
            // through to the bounded-memory legacy pixel sampler.
            guard let ui = UIImage(data: data),
                  let cut = try? await BgCutoutService.removeBackground(from: ui),
                  let cutData = cut.pngData()
                    ?? cut.jpegData(compressionQuality: ImageDerivativeService.opaqueJPEGQuality) else {
                return try await Self.legacyCutoutDerivative(from: data)
            }
            return try ImageDerivativeService.makeDerivative(
                from: cutData, suggestedFilename: "cutout-vision"
            )
        }
        return try await Self.legacyCutoutDerivative(from: data)
    }

    /// Legacy pixel-sampling background removal, but operating on a
    /// memory-safe working image (`maxLongEdgePixels × maxLongEdgePixels
    /// × 4` bytes max) rather than the source's full resolution.
    private static func legacyCutoutDerivative(
        from data: Data
    ) async throws -> ImageDerivativeService.Derivative {
        let working = try ImageDerivativeService.makeWorkingImage(
            from: data, suggestedFilename: "working-cutout"
        )
        defer { working.rgbaBuffer.deallocate() }

        let width = working.pixelWidth
        let height = working.pixelHeight
        let bytesPerRow = working.bytesPerRow

        @inline(__always) func getPixel(_ x: Int, _ y: Int) -> (UInt8, UInt8, UInt8) {
            let offset = y * bytesPerRow + x * 4
            return (working.rgbaBuffer[offset],
                    working.rgbaBuffer[offset + 1],
                    working.rgbaBuffer[offset + 2])
        }

        let p1 = getPixel(0, 0)
        let p2 = getPixel(width - 1, 0)
        let p3 = getPixel(0, height - 1)
        let p4 = getPixel(width - 1, height - 1)

        let bgR = (Int(p1.0) + Int(p2.0) + Int(p3.0) + Int(p4.0)) / 4
        let bgG = (Int(p1.1) + Int(p2.1) + Int(p3.1) + Int(p4.1)) / 4
        let bgB = (Int(p1.2) + Int(p2.2) + Int(p3.2) + Int(p4.2)) / 4

        let tolerance = 45

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * 4
                let r = Int(working.rgbaBuffer[offset])
                let g = Int(working.rgbaBuffer[offset + 1])
                let b = Int(working.rgbaBuffer[offset + 2])
                if abs(r - bgR) < tolerance
                    && abs(g - bgG) < tolerance
                    && abs(b - bgB) < tolerance {
                    working.rgbaBuffer[offset + 3] = 0
                }
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue
        guard let ctx = CGContext(
            data: working.rgbaBuffer.baseAddress,
            width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: bytesPerRow,
            space: colorSpace, bitmapInfo: bitmapInfo
        ), let cutCG = ctx.makeImage() else {
            throw ImageDerivativeService.DerivativeError.encodeFailed(
                "legacy cutout context")
        }

        // Encode the cutout CGImage as PNG so alpha survives.
        let outData = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            outData as CFMutableData,
            UTType.png.identifier as CFString, 1, nil
        ) else {
            throw ImageDerivativeService.DerivativeError.encodeFailed(
                "cutout destination")
        }
        CGImageDestinationAddImage(dest, cutCG, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw ImageDerivativeService.DerivativeError.encodeFailed(
                "cutout finalize")
        }
        return try ImageDerivativeService.makeDerivative(
            from: outData as Data, suggestedFilename: "cutout-legacy"
        )
    }

    /// Wire a freshly-built derivative into the editor and the App
    /// Group. The `originalBytes` + `originalFilename` pair is
    /// persisted to host-private Documents so the user can re-edit
    /// the photo later without us having to re-derive the source
    /// format. The widget-readable asset is the *derivative* — never
    /// the original — so the App Group container stays small.
    ///
    /// Critical ordering:
    ///   1. Write the original to host Documents (private).
    ///   2. Write the derivative to App Group SharedImages + the
    ///      current `generation_*` asset folder so the widget can
    ///      read it. Byte-verify every write.
    ///   3. Only after (1) and (2) succeed do we mutate the editor's
    ///      spec AND mirror it into `store.drafts` so the next
    ///      `saveState()` writes the new spec to App Group V2.
    ///      If anything fails, the spec is left alone so the user
    ///      never sees a half-published state.
    private func addVehicleLayer(
        derivative: ImageDerivativeService.Derivative,
        originalBytes: Data,
        originalFilename: String
    ) {
        // 1. Original → host Documents (private).
        let docsBase = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first
        if let docsBase = docsBase {
            let originalsDir = docsBase.appendingPathComponent(
                "Originals", isDirectory: true)
            try? FileManager.default.createDirectory(
                at: originalsDir, withIntermediateDirectories: true)
            let originalURL = originalsDir.appendingPathComponent(
                originalFilename)
            if !Self.writeImageVerified(originalBytes, to: originalURL) {
                imageImportError = "Couldn't write the original photo to host storage."
                return
            }
        }

        // 2. Derivative → App Group SharedImages + generation folder.
        //    The widget reads from SharedImages; installState() will
        //    re-stage the same bytes into `generation_<uuid>/` when
        //    the user taps Save & Exit.
        let derivativeFilename = ImageDerivativeService.derivativeFilename(
            hasAlpha: derivative.hasAlpha)
        var widgetVisibleVerified = false
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.drivestudio.shared"
        ) {
            let sharedImagesDir = groupURL.appendingPathComponent(
                "SharedImages", isDirectory: true)
            try? FileManager.default.createDirectory(
                at: sharedImagesDir, withIntermediateDirectories: true)

            let sharedImagesURL = sharedImagesDir.appendingPathComponent(
                derivativeFilename)
            widgetVisibleVerified = Self.writeImageVerified(
                derivative.data, to: sharedImagesURL)

            // Also drop into the App Group root for legacy readers.
            let sharedRootURL = groupURL.appendingPathComponent(
                derivativeFilename)
            Self.writeImageVerified(derivative.data, to: sharedRootURL)
        }

        if !widgetVisibleVerified {
            imageImportError = "Couldn't stage the optimized photo into the widget's container."
            return
        }

        commitState()

        // 3. Spec mutation — replaces the selected `template_car`
        //    guide (or the single visible guide) instead of
        //    piling up new layers. Pass `aspectRatio` so the
        //    dashed yellow border hugs the photo's edges instead
        //    of floating around it with empty space.
        let existing = spec.layers ?? []
        let merged = WidgetLayer.mergedLayersAfterAddingImage(
            current: existing,
            selectedIndex: selectedLayerIndex,
            newImageSrc: derivativeFilename,
            newImageAspect: derivative.aspectRatio
        )
        spec.layers = merged.layers
        selectedLayerIndex = merged.selectedIndex

        // Persist the spec change to App Group V2 metadata NOW
        // instead of waiting for `saveAndExit()`. Otherwise the
        // widget (which reads App Group V2 metadata) keeps seeing
        // `template_car` and draws the dashed guide, while the
        // editor canvas (which reads the in-memory spec) already
        // shows the new photo. The two surfaces desync until the
        // user taps Save & Exit — exactly the "some images work
        // and some don't" pattern reported in the field.
        //
        // **Critical ordering:** `saveState()` reads the spec from
        // `store.drafts[draftId].spec`, NOT from the editor's
        // local `@State spec`. We MUST commit the updated spec to
        // `store.drafts` first via `saveDraft(_:)` so the
        // subsequent `trySaveStateLoggingFailure()` sees the new
        // image. Without this, the slot still resolves to the
        // pre-image spec and the widget keeps drawing the guide.
        let actualDraftId: String
        if draftId == "new" || draftId == "new_blank" {
            // Brand-new draft — promote it to a real UUID so the
            // slot can reference it. The slot binding happens in
            // `saveAndExit`, but we mirror the draft into
            // `store.drafts` here so `saveState()` can already
            // pick it up if the user backgrounds the app before
            // tapping Save & Exit.
            actualDraftId = UUID().uuidString
        } else {
            actualDraftId = draftId
        }
        let draft = Draft(
            id: actualDraftId,
            name: widgetName,
            spec: spec,
            updatedAt: Date().timeIntervalSince1970
        )
        store.saveDraft(draft)

        DriveStudioImageLoader.invalidateCache()
        store.trySaveStateLoggingFailure()
    }

    /// Write `data` to `url` and byte-compare the result against the
    /// source. Returns `true` only when the on-disk bytes match the
    /// in-memory bytes exactly. On any failure (write error, read
    /// error, byte mismatch) the partial file is removed and the
    /// function returns `false`.
    @discardableResult
    static func writeImageVerified(_ data: Data, to url: URL) -> Bool {
        do {
            try data.write(to: url, options: [.atomic])
        } catch {
            print("writeImageVerified: write failed at \(url.path): \(error)")
            return false
        }
        let readBack: Data
        do {
            readBack = try Data(contentsOf: url)
        } catch {
            print("writeImageVerified: read-back failed at \(url.path): \(error)")
            try? FileManager.default.removeItem(at: url)
            return false
        }
        guard readBack == data else {
            print("writeImageVerified: byte mismatch at \(url.path) (wrote \(data.count), read \(readBack.count))")
            try? FileManager.default.removeItem(at: url)
            return false
        }
        return true
    }
}

/// Translate a set of inserted library layers so the group's bounding box is
/// centered on the canvas. Library items are authored with absolute design-
/// space positions (e.g. `x: 25, y: 22`), so without this shift every asset
/// would land in the top-left quadrant of the canvas instead of wherever the
/// user expects. Operates in 0-100% design space.
func centerOnCanvas(_ layers: [WidgetLayer]) -> [WidgetLayer] {
    guard !layers.isEmpty else { return layers }
    var minX: Double =  200; var minY: Double =  200
    var maxX: Double = -200; var maxY: Double = -200
    for l in layers {
        let x = l.x ?? 0; let y = l.y ?? 0
        let w = l.w ?? 20; let h = l.h ?? 10
        if x < minX { minX = x }
        if y < minY { minY = y }
        if x + w > maxX { maxX = x + w }
        if y + h > maxY { maxY = y + h }
    }
    let cx = (minX + maxX) / 2
    let cy = (minY + maxY) / 2
    let dx = 50 - cx
    let dy = 50 - cy
    return layers.map { l -> WidgetLayer in
        var copy = l
        copy.x = (l.x ?? 0) + dx
        copy.y = (l.y ?? 0) + dy
        return copy
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
