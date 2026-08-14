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

    /// Natural text sizes measured by WidgetCanvas (layer.id → CGSize)
    var naturalTextSizes: [String: CGSize] = [:]

    // ── Move state ────────────────────────────────────────────────────────────
    @State private var dragStartX: Double = 0
    @State private var dragStartY: Double = 0
    @State private var isDragging = false

    // ── Resize state — captured ONCE at drag start, never recaptured ──────────
    @State private var resizeStartFrame: CGRect? = nil
    /// Group bounding box at drag start (in canvas pixels), only set when the
    /// dragged layer is part of a `groupId` group. Resize math scales every
    /// sibling layer proportionally to this bbox so the whole composite
    /// asset stretches as one.
    @State private var groupStartBBox: CGRect? = nil
    @State private var groupSiblings: [(index: Int, frame: CGRect)] = []

    var body: some View {
        ZStack(alignment: .topLeading) {

            // ── Background tap-to-deselect ────────────────────────────────────
            Color.black.opacity(0.001)
                .onTapGesture { selectedLayerIndex = nil }

            // ── Unselected hit zones ──────────────────────────────────────────
            if let layers = spec.layers {
                ForEach(layers.indices, id: \.self) { i in
                    if selectedLayerIndex != i {
                        let fr = chromeFr(for: layers[i])
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
                let fr = chromeFr(for: layer)

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
                                        // If this layer belongs to a group,
                                        // also capture the group's bbox + every
                                        // sibling's start frame for proportional
                                        // resize across the whole composite.
                                        if let gid = layer.groupId,
                                           let groupBBox = computeGroupBBox(groupId: gid) {
                                            groupStartBBox = groupBBox
                                            groupSiblings = (spec.layers ?? [])
                                                .enumerated()
                                                .filter { $0.element.groupId == gid }
                                                .map { (idx, l) in
                                                    (idx, allocFrame(for: l))
                                                }
                                        } else {
                                            groupStartBBox = nil
                                            groupSiblings = []
                                        }
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
                                    groupStartBBox = nil
                                    groupSiblings = []
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
    private func chromeFr(for layer: WidgetLayer) -> CGRect {
        let alloc = allocFrame(for: layer)
        let isText = ["text", "speed", "vehicle_name", "battery_text", "clock"].contains(layer.kind)

        guard isText, let natural = naturalTextSizes[layer.id] else {
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

        // ── Grouped layer: move every sibling by the same delta, then clamp
        // the whole group's bounding box to the canvas together.
        if let gid = layer.groupId {
            let siblings = layers.enumerated()
                .filter { $0.offset != index && $0.element.groupId == gid }
            let deltaX = (toX - (layer.x ?? 0))
            let deltaY = (toY - (layer.y ?? 0))

            // Proposed new frames for the dragged layer + every sibling
            var proposed: [(idx: Int, x: Double, y: Double, isImage: Bool)] = []
            proposed.append((index, toX, toY, layer.kind == "image"))
            for s in siblings {
                let sX = (s.element.x ?? 0) + deltaX
                let sY = (s.element.y ?? 0) + deltaY
                proposed.append((s.offset, sX, sY, s.element.kind == "image"))
            }

            // Compute group bbox in 0-100 design space, then clamp so it fits
            let xs = proposed.map { $0.x }
            let ys = proposed.map { $0.y }
            let ws = proposed.map { $0.x + ($0.isImage ? 100 : (layers[$0.idx].w ?? 20)) }
            let hs = proposed.map { $0.y + ($0.isImage ? 100 : (layers[$0.idx].h ?? 10)) }
            let groupMinX = xs.min() ?? 0
            let groupMinY = ys.min() ?? 0
            let groupMaxX = ws.max() ?? 100
            let groupMaxY = hs.max() ?? 100
            let groupW = groupMaxX - groupMinX
            let groupH = groupMaxY - groupMinY

            var clampDX: Double = 0
            var clampDY: Double = 0
            if groupMinX + clampDX < 0 { clampDX = -groupMinX }
            if groupMinY + clampDY < 0 { clampDY = -groupMinY }
            if groupMaxX + clampDX > 100 { clampDX = 100 - groupMaxX }
            if groupMaxY + clampDY > 100 { clampDY = 100 - groupMaxY }

            for p in proposed {
                layers[p.idx].x = p.x + clampDX
                layers[p.idx].y = p.y + clampDY
            }
            spec.layers = layers
            return
        }

        if layer.kind == "image" {
            // Images can extend past the canvas edge intentionally —
            // chrome just stops at the canvas border.
            layers[index].x = toX
            layers[index].y = toY
        } else {
            // `x` / `y` are the top-left of the frame in 0-100% design
            // space. Clamp to keep the entire frame inside the canvas.
            layers[index].x = max(0, min(100.0 - w, toX))
            layers[index].y = max(0, min(100.0 - h, toY))
        }
        spec.layers = layers
    }

    // ── Resize ────────────────────────────────────────────────────────────────

    private func resizeLayer(index: Int, layer: WidgetLayer, handle: ResizeHandle,
                             translation: CGSize, startFrame: CGRect) {
        guard var layers = spec.layers, index < layers.count else { return }
        let minPx: CGFloat = 16

        // ── Grouped layer: apply the same handle math to the group's
        // bounding box, then scale every sibling layer proportionally
        // inside the (possibly clamped) new bbox.
        if let gid = layer.groupId {
            guard let startGroupBBox = groupStartBBox, !groupSiblings.isEmpty else { return }

            // Apply the handle to the group's start bbox
            var grp = startGroupBBox
            switch handle {
            case .nw:
                grp.origin.x += translation.width;  grp.size.width  -= translation.width
                grp.origin.y += translation.height; grp.size.height -= translation.height
            case .n:
                grp.origin.y += translation.height; grp.size.height -= translation.height
            case .ne:
                grp.size.width  += translation.width
                grp.origin.y    += translation.height; grp.size.height -= translation.height
            case .e:
                grp.size.width  += translation.width
            case .se:
                grp.size.width  += translation.width; grp.size.height += translation.height
            case .s:
                grp.size.height += translation.height
            case .sw:
                grp.origin.x += translation.width; grp.size.width  -= translation.width
                grp.size.height += translation.height
            case .w:
                grp.origin.x += translation.width; grp.size.width -= translation.width
            }

            if grp.size.width  < minPx * 2 { grp.size.width  = minPx * 2 }
            if grp.size.height < minPx * 2 { grp.size.height = minPx * 2 }
            grp.origin.x = max(0, min(canvasSide - grp.size.width,  grp.origin.x))
            grp.origin.y = max(0, min(canvasSide - grp.size.height, grp.origin.y))
            grp.size.width  = min(grp.size.width,  canvasSide)
            grp.size.height = min(grp.size.height, canvasSide)

            let scaleX = grp.size.width  / startGroupBBox.size.width
            let scaleY = grp.size.height / startGroupBBox.size.height

            // Scale the dragged layer's frame inside the new group bbox
            if let s = groupSiblings.first(where: { $0.index == index }) {
                let newFr = scaled(s.frame, startBBox: startGroupBBox, newBBox: grp)
                layers[index].x = Double(newFr.origin.x    / canvasSide * 100)
                layers[index].y = Double(newFr.origin.y    / canvasSide * 100)
                layers[index].w = Double(newFr.size.width  / canvasSide * 100)
                layers[index].h = Double(newFr.size.height / canvasSide * 100)
                _ = s
            }

            // Scale every other sibling inside the new group bbox
            for sib in groupSiblings where sib.index != index {
                let newFr = scaled(sib.frame, startBBox: startGroupBBox, newBBox: grp)
                layers[sib.index].x = Double(newFr.origin.x    / canvasSide * 100)
                layers[sib.index].y = Double(newFr.origin.y    / canvasSide * 100)
                layers[sib.index].w = Double(newFr.size.width  / canvasSide * 100)
                layers[sib.index].h = Double(newFr.size.height / canvasSide * 100)
            }
            spec.layers = layers
            return
        }

        var fr = startFrame          // always the frozen-at-drag-start frame
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

    /// Scale a single layer's frame from `startBBox` to `newBBox`. The layer's
    /// origin/size move proportionally so it keeps the same relative position
    /// inside the group bbox.
    private func scaled(_ fr: CGRect, startBBox: CGRect, newBBox: CGRect) -> CGRect {
        let sx = (fr.minX - startBBox.minX) / startBBox.size.width
        let sy = (fr.minY - startBBox.minY) / startBBox.size.height
        let sw = fr.size.width  / startBBox.size.width
        let sh = fr.size.height / startBBox.size.height

        return CGRect(
            x: newBBox.minX + sx * newBBox.size.width,
            y: newBBox.minY + sy * newBBox.size.height,
            width:  sw * newBBox.size.width,
            height: sh * newBBox.size.height
        )
    }

    /// Compute the union of all layers' frames (in canvas pixels) that share
    /// the given groupId. Used to capture the start bbox once at drag start.
    private func computeGroupBBox(groupId: String, excludeIndex: Int? = nil) -> CGRect? {
        guard let layers = spec.layers else { return nil }
        let grouped = layers.enumerated().filter { (i, l) in
            l.groupId == groupId && i != excludeIndex
        }
        guard !grouped.isEmpty else { return nil }
        var minX: CGFloat = .greatestFiniteMagnitude
        var minY: CGFloat = .greatestFiniteMagnitude
        var maxX: CGFloat = -.greatestFiniteMagnitude
        var maxY: CGFloat = -.greatestFiniteMagnitude
        for (_, l) in grouped {
            let x = CGFloat(l.x ?? 0) / 100 * canvasSide
            let y = CGFloat(l.y ?? 0) / 100 * canvasSide
            let w = CGFloat(l.w ?? 0) / 100 * canvasSide
            let h = CGFloat(l.h ?? 0) / 100 * canvasSide
            minX = min(minX, x); minY = min(minY, y)
            maxX = max(maxX, x + w); maxY = max(maxY, y + h)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
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
