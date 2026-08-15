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

    // ── Two-finger transform state — captured ONCE at gesture start ──────────
    /// `scale` at the moment the pinch gesture began (so the math is
    /// `start × magnification` rather than multiplicative drift).
    @State private var pinchStartScale: Double = 1.0
    /// `rotation` in degrees at the moment the rotate gesture began.
    @State private var rotationStartDegrees: Double = 0
    /// `true` once the gesture has captured its start values; reset on
    /// `.onEnded` so the next gesture re-captures.
    @State private var transformDidStart: Bool = false

    var body: some View {
        // The overlay's chrome and handles are clipped to the canvas's
        // rounded-rect shape (matching the layer-content clip in
        // `WidgetCanvas`). Without this clip, the yellow selection
        // border would extend visually AND for hit-testing past the
        // canvas edge whenever a layer is free-placed near (or
        // outside) the canvas — covering UI buttons like "Add
        // Vehicle" that sit in rows above/below the canvas and
        // making them un-tappable. Clip restricts both the visual
        // chrome and the gesture hit-region to the canvas's rounded
        // rect so off-canvas buttons stay interactive.
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
                    // Two-finger pinch + rotate on the layer body itself.
                    // Composed as `SimultaneousGesture` so two thumbs can
                    // both pinch AND rotate at the same time without one
                    // gesture cancelling the other. SwiftUI's gesture
                    // system routes single-finger drag to the gesture
                    // above (via `minimumDistance: 12`) and two-finger
                    // transforms here.
                    .simultaneousGesture(
                        SimultaneousGesture(
                            MagnificationGesture(),
                            RotationGesture()
                        )
                        .onChanged { val in
                            // `val.first` / `val.second` are optional
                            // because SimultaneousGesture delivers a
                            // value from each gesture independently —
                            // a pure pinch has no rotation (and vice
                            // versa). Use 1.0 / 0 as the identity
                            // fallback so the math stays well-defined.
                            let scaleVal = val.first ?? 1.0
                            let rotVal = val.second ?? .zero
                            if !transformDidStart {
                                transformDidStart = true
                                pinchStartScale = layer.scale ?? 1.0
                                rotationStartDegrees = layer.rotation ?? 0
                            }
                            let newScale = max(0.1, min(10.0,
                                pinchStartScale * Double(scaleVal)))
                            let newRotation = rotationStartDegrees
                                + Double(rotVal.degrees)
                            applyTransform(
                                index: i, layer: layer,
                                scale: newScale, rotation: newRotation)
                        }
                        .onEnded { _ in transformDidStart = false }
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
                        // Pinch + rotate also work on the corner knobs
                        // themselves (handy when the user wants to grab
                        // a corner and two-thumb the layer without
                        // aiming at the body). Same composition rules
                        // as the body gesture above.
                        .simultaneousGesture(
                            SimultaneousGesture(
                                MagnificationGesture(),
                                RotationGesture()
                            )
                            .onChanged { val in
                                let scaleVal = val.first ?? 1.0
                                let rotVal = val.second ?? .zero
                                if !transformDidStart {
                                    transformDidStart = true
                                    pinchStartScale = layer.scale ?? 1.0
                                    rotationStartDegrees = layer.rotation ?? 0
                                }
                                let newScale = max(0.1, min(10.0,
                                    pinchStartScale * Double(scaleVal)))
                                let newRotation = rotationStartDegrees
                                    + Double(rotVal.degrees)
                                applyTransform(
                                    index: i, layer: layer,
                                    scale: newScale, rotation: newRotation)
                            }
                            .onEnded { _ in transformDidStart = false }
                        )
                }
            }
        }
        .frame(width: canvasSide, height: canvasSide)
        // Clip the chrome + handles to the canvas's rounded rect so a
        // layer free-placed near (or past) the canvas edge doesn't
        // extend its yellow selection border over UI buttons (e.g.
        // "Add Vehicle") sitting in the row above the canvas. The
        // shape matches the layer-content clip in `WidgetCanvas` so
        // the visible chrome and the rendered asset share the same
        // outline.
        .clipShape(RoundedRectangle(cornerRadius: 24))
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

        // ── Grouped layer: move every sibling by the same delta.
        // NO clamp — the user wants full freedom to position layers
        // (and entire composites) partially off-canvas.
        if let gid = layer.groupId {
            let deltaX = (toX - (layer.x ?? 0))
            let deltaY = (toY - (layer.y ?? 0))
            layers[index].x = toX
            layers[index].y = toY
            for i in layers.indices
            where i != index && layers[i].groupId == gid {
                layers[i].x = (layers[i].x ?? 0) + deltaX
                layers[i].y = (layers[i].y ?? 0) + deltaY
            }
            spec.layers = layers
            return
        }

        // Single layer: free placement — no canvas clamp. x/y can be
        // negative or > 100 so the user can tuck an asset partially
        // behind a neighboring widget edge or off the visible canvas
        // entirely. The widget itself renders the spec as-stored, so
        // off-canvas portions simply don't appear in the home-screen
        // widget but stay available in the editor preview for
        // repositioning.
        layers[index].x = toX
        layers[index].y = toY
        spec.layers = layers
    }

    // ── Two-finger transform (scale + rotate) ────────────────────────────────

    /// Apply a pinch-derived scale and rotation to the layer at `index`.
    /// When the layer is part of a `groupId` group, the same transform
    /// is applied to every sibling so the composite asset scales and
    /// rotates as a unit. The transform is applied additively on top of
    /// the group's existing per-layer scale/rotation so the user can
    /// iterate (pinch once, pinch again — each gesture captures its own
    /// start values, never multiplies on top of in-flight ones).
    private func applyTransform(index: Int, layer: WidgetLayer,
                                scale: Double, rotation: Double) {
        guard var layers = spec.layers, index < layers.count else { return }
        if let gid = layer.groupId {
            for i in layers.indices where layers[i].groupId == gid {
                layers[i].scale = scale
                layers[i].rotation = rotation
            }
        } else {
            layers[index].scale = scale
            layers[index].rotation = rotation
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
            // NO canvas clamp — free placement. Group bbox can extend
            // past the canvas edges so the user has full creative
            // freedom over the composite asset.

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

        // NO canvas clamp — free placement. The single layer can be
        // resized past the canvas edges so the user has full freedom
        // to size assets exactly how they want. Off-canvas portions
        // are clipped by the widget's rounded-rect clip shape at
        // render time, but the spec values themselves are unlimited.

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
