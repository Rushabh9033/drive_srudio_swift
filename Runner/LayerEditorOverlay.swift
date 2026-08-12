import SwiftUI

enum ResizeHandle: CaseIterable {
    case nw, n, ne, e, se, s, sw, w
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - LayerEditorOverlay
// ─────────────────────────────────────────────────────────────────────────────
struct LayerEditorOverlay: View {
    @Binding var spec: WidgetSpec
    @Binding var selectedLayerIndex: Int?
    var onInspect: ((Int) -> Void)? = nil

    let canvasSide: CGFloat

    /// Natural text sizes measured by WidgetCanvas (index → CGSize)
    var naturalTextSizes: [Int: CGSize] = [:]

    // ── Move state ────────────────────────────────────────────────────────────
    @State private var dragStartX: Double = 0
    @State private var dragStartY: Double = 0
    @State private var isDragging = false

    // ── Resize state — captured ONCE at drag start, never recaptured ──────────
    @State private var resizeStartFrame: CGRect? = nil

    var body: some View {
        ZStack(alignment: .topLeading) {

            // ── Background tap-to-deselect ────────────────────────────────────
            Color.black.opacity(0.001)
                .onTapGesture { selectedLayerIndex = nil }

            // ── Unselected hit zones ──────────────────────────────────────────
            if let layers = spec.layers {
                ForEach(layers.indices, id: \.self) { i in
                    if selectedLayerIndex != i {
                        let fr = chromeFr(for: layers[i], index: i)
                        Color.clear
                            .frame(width: max(fr.width, 44), height: max(fr.height, 44))
                            .contentShape(Rectangle())
                            .position(x: fr.midX, y: fr.midY)
                            .onTapGesture(count: 2) {
                                selectedLayerIndex = i
                                onInspect?(i)
                            }
                            .onTapGesture(count: 1) {
                                selectedLayerIndex = i
                            }
                            .gesture(
                                DragGesture(minimumDistance: 12, coordinateSpace: .local)
                                    .onChanged { val in
                                        if !isDragging {
                                            isDragging = true
                                            selectedLayerIndex = i
                                            dragStartX = layers[i].x ?? 0
                                            dragStartY = layers[i].y ?? 0
                                        }
                                        let dx = (val.translation.width  / canvasSide) * 100.0
                                        let dy = (val.translation.height / canvasSide) * 100.0
                                        moveLayer(index: i, layer: layers[i],
                                                  toX: dragStartX + dx, toY: dragStartY + dy)
                                    }
                                    .onEnded { _ in isDragging = false }
                            )
                    }
                }
            }

            // ── Selected chrome + drag + handles ─────────────────────────────
            if let i = selectedLayerIndex, let layers = spec.layers, i < layers.count {
                let layer = layers[i]
                // Tight chrome rect (natural text size for text, full rect for others)
                let fr = chromeFr(for: layer, index: i)

                // Exact-size outline — same rect as handles
                Rectangle()
                    .strokeBorder(DriveColors.primary.opacity(0.95), lineWidth: 1.5)
                    .background(Color.black.opacity(0.001))
                    .frame(width: fr.width, height: fr.height)
                    .contentShape(Rectangle())
                    .position(x: fr.midX, y: fr.midY)
                    .gesture(
                        DragGesture(minimumDistance: 12, coordinateSpace: .local)
                            .onChanged { val in
                                if !isDragging {
                                    isDragging = true
                                    dragStartX = layer.x ?? 0
                                    dragStartY = layer.y ?? 0
                                }
                                let dx = (val.translation.width  / canvasSide) * 100.0
                                let dy = (val.translation.height / canvasSide) * 100.0
                                moveLayer(index: i, layer: layer,
                                          toX: dragStartX + dx, toY: dragStartY + dy)
                            }
                            .onEnded { _ in isDragging = false }
                    )
                    .onTapGesture(count: 2) { onInspect?(i) }

                // Handles — positioned at corners of the SAME tight chrome rect
                ForEach(ResizeHandle.allCases, id: \.self) { handle in
                    HandleKnob(handle: handle)
                        .position(handleCenter(handle, fr: fr))
                        .gesture(
                            DragGesture(minimumDistance: 4, coordinateSpace: .local)
                                .onChanged { val in
                                    if !isDragging {
                                        isDragging = true
                                        // Capture the start frame ONCE — never re-read during drag
                                        resizeStartFrame = fr
                                    }
                                    // Always resize from the frozen start frame
                                    if let start = resizeStartFrame {
                                        resizeLayer(index: i, layer: layer,
                                                    handle: handle,
                                                    translation: val.translation,
                                                    startFrame: start)
                                    }
                                }
                                .onEnded { _ in
                                    isDragging = false
                                    resizeStartFrame = nil
                                }
                        )
                }
            }
        }
        .frame(width: canvasSide, height: canvasSide)
    }

    // ── Frame calculations ────────────────────────────────────────────────────

    /// Full allocated frame from stored x/y/w/h percentages
    private func allocFrame(for layer: WidgetLayer) -> CGRect {
        let x = (CGFloat(layer.x ?? 0)  / 100.0) * canvasSide
        let y = (CGFloat(layer.y ?? 0)  / 100.0) * canvasSide
        let w = max((CGFloat(layer.w ?? 20) / 100.0) * canvasSide, 20)
        let h = max((CGFloat(layer.h ?? 10) / 100.0) * canvasSide, 20)
        return CGRect(x: x, y: y, width: w, height: h)
    }

    /// Tight chrome rect — uses measured natural text size for text layers,
    /// full allocated rect for everything else (images/shapes fill their box).
    private func chromeFr(for layer: WidgetLayer, index: Int) -> CGRect {
        let alloc = allocFrame(for: layer)
        let isText = ["text", "speed", "vehicle_name", "battery_text", "clock"].contains(layer.kind)

        guard isText, let natural = naturalTextSizes[index] else {
            return alloc
        }

        let tw = min(natural.width,  alloc.width)
        let th = min(natural.height, alloc.height)

        // Vertically center within allocation
        let ty = alloc.minY + (alloc.height - th) / 2

        // Respect text alignment horizontally
        let tx: CGFloat
        switch (layer.align ?? "center").lowercased() {
        case "left", "leading":
            tx = alloc.minX
        case "right", "trailing":
            tx = alloc.maxX - tw
        default:
            tx = alloc.minX + (alloc.width - tw) / 2
        }

        return CGRect(x: tx, y: ty, width: max(tw, 24), height: max(th, 16))
    }

    // ── Move ─────────────────────────────────────────────────────────────────

    private func moveLayer(index: Int, layer: WidgetLayer, toX: Double, toY: Double) {
        guard var layers = spec.layers, index < layers.count else { return }
        let w = layer.w ?? 20
        let h = layer.h ?? 10
        if layer.kind == "image" {
            layers[index].x = toX
            layers[index].y = toY
        } else {
            layers[index].x = max(0, min(100.0 - w, toX))
            layers[index].y = max(0, min(100.0 - h, toY))
        }
        spec.layers = layers
    }

    // ── Resize ────────────────────────────────────────────────────────────────

    private func resizeLayer(index: Int, layer: WidgetLayer, handle: ResizeHandle,
                             translation: CGSize, startFrame: CGRect) {
        guard var layers = spec.layers, index < layers.count else { return }
        var fr = startFrame          // always the frozen-at-drag-start frame
        let minPx: CGFloat = 16
        let isImage = (layer.kind == "image")

        switch handle {
        case .nw:
            fr.origin.x += translation.width;  fr.size.width  -= translation.width
            fr.origin.y += translation.height; fr.size.height -= translation.height
        case .n:
            fr.origin.y += translation.height; fr.size.height -= translation.height
        case .ne:
            fr.size.width  += translation.width
            fr.origin.y    += translation.height; fr.size.height -= translation.height
        case .e:
            fr.size.width  += translation.width
        case .se:
            fr.size.width  += translation.width; fr.size.height += translation.height
        case .s:
            fr.size.height += translation.height
        case .sw:
            fr.origin.x += translation.width; fr.size.width  -= translation.width
            fr.size.height += translation.height
        case .w:
            fr.origin.x += translation.width; fr.size.width -= translation.width
        }

        if fr.size.width  < minPx { fr.size.width  = minPx }
        if fr.size.height < minPx { fr.size.height = minPx }

        if !isImage {
            fr.origin.x = max(0, min(canvasSide - fr.size.width,  fr.origin.x))
            fr.origin.y = max(0, min(canvasSide - fr.size.height, fr.origin.y))
            fr.size.width  = min(fr.size.width,  canvasSide)
            fr.size.height = min(fr.size.height, canvasSide)
        }

        layers[index].x = Double(fr.origin.x    / canvasSide * 100)
        layers[index].y = Double(fr.origin.y    / canvasSide * 100)
        layers[index].w = Double(fr.size.width  / canvasSide * 100)
        layers[index].h = Double(fr.size.height / canvasSide * 100)
        spec.layers = layers
    }

    private func handleCenter(_ handle: ResizeHandle, fr: CGRect) -> CGPoint {
        switch handle {
        case .nw: return CGPoint(x: fr.minX, y: fr.minY)
        case .n:  return CGPoint(x: fr.midX, y: fr.minY)
        case .ne: return CGPoint(x: fr.maxX, y: fr.minY)
        case .e:  return CGPoint(x: fr.maxX, y: fr.midY)
        case .se: return CGPoint(x: fr.maxX, y: fr.maxY)
        case .s:  return CGPoint(x: fr.midX, y: fr.maxY)
        case .sw: return CGPoint(x: fr.minX, y: fr.maxY)
        case .w:  return CGPoint(x: fr.minX, y: fr.midY)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - HandleKnob
// ─────────────────────────────────────────────────────────────────────────────
struct HandleKnob: View {
    let handle: ResizeHandle

    var body: some View {
        let isCorner = (handle == .nw || handle == .ne || handle == .se || handle == .sw)
        ZStack {
            Color.black.opacity(0.001).frame(width: 36, height: 36)
            if isCorner {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.black)
                    .frame(width: 10, height: 10)
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(DriveColors.primary, lineWidth: 1.5))
                    .rotationEffect(.degrees(45))
                    .shadow(color: DriveColors.primary.opacity(0.6), radius: 6)
            } else {
                Circle()
                    .fill(Color.black)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(DriveColors.primary, lineWidth: 1.5))
                    .shadow(color: DriveColors.primary.opacity(0.4), radius: 5)
            }
        }
    }
}
