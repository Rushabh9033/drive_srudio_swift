import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/drive_colors.dart';
import '../../data/models/models.dart';

enum ResizeHandle { nw, n, ne, e, se, s, sw, w }

/// Extra hit padding around the canvas so off-frame handles stay tappable.
/// Must match the [Positioned] inset applied in [WidgetCanvas].
const double kEditorEdgeOutset = 36;

/// Design-tool interaction for Drive Studio.
///
/// Architecture (keep this simple — do not reintroduce pointerRouter):
/// - Full-canvas [GestureDetector] owns select + body drag
/// - Each of 8 handles owns its own [GestureDetector] for stretch-resize
/// - Drag geometry lives in this [State]; parent paint updates via preview
///   callbacks that must NOT [State.setState] the editor (see EditorScreen)
/// - Painted layers under [WidgetCanvas] use [IgnorePointer] so only this
///   overlay receives gestures
/// - Background is never a layer and is never movable
class LayerEditorOverlay extends StatefulWidget {
  const LayerEditorOverlay({
    super.key,
    required this.spec,
    required this.selectedId,
    required this.onSelect,
    required this.onGeometryCommit,
    required this.onGeometryPreview,
    this.onInspect,
    this.snapThresholdPct = 2.5,
  });

  final WidgetSpec spec;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final ValueChanged<String>? onInspect;
  final void Function(String id, double x, double y, double w, double h)
      onGeometryPreview;
  final void Function(String id, double x, double y, double w, double h)
      onGeometryCommit;
  final double snapThresholdPct;

  @override
  State<LayerEditorOverlay> createState() => _LayerEditorOverlayState();
}

class _LayerEditorOverlayState extends State<LayerEditorOverlay> {
  Size _frame = Size.zero;

  /// Active gesture (move or resize). Independent of [widget.selectedId] so
  /// select+drag in one stroke works before the parent rebuilds selection.
  String? _dragId;
  ResizeHandle? _dragHandle;
  double _ox = 0, _oy = 0, _ow = 0, _oh = 0;
  double _cx = 0, _cy = 0, _cw = 0, _ch = 0;
  double _accDx = 0;
  double _accDy = 0;
  bool _dragging = false;
  bool _showGuides = false;

  /// Selection chosen during pan — flushed to parent on pan end / tap so the
  /// editor never [setState]s mid-gesture.
  String? _pendingSelectId;

  DateTime? _lastTapAt;
  String? _lastTapId;
  Offset? _lastTapGlobal;

  static const Duration _doubleTapTimeout = Duration(milliseconds: 320);
  static const double _doubleTapSlopPx = 28;
  static const double _minHitPx = 28;
  static const double _handleVisual = 14;
  static const double _handleHit = 28;

  static const double _posMin = -100;
  static const double _posMax = 200;
  static const double _sizeMinW = 4;
  static const double _sizeMaxW = 250;
  static const double _sizeMinH = 2;
  static const double _sizeMaxH = 250;

  Layer? _layerById(String? id) {
    if (id == null) return null;
    for (final l in widget.spec.layers) {
      if (l.id == id) return l;
    }
    return null;
  }

  List<Layer> get _visibleLayers => [
        for (final l in widget.spec.layers)
          if (!l.hidden) l,
      ];

  /// Layers that participate in tap/drag hit-testing.
  /// Empty full-canvas draw layers are skipped so they never look like
  /// "one big selection" over the whole widget.
  List<Layer> get _hittableLayers => [
        for (final l in _visibleLayers)
          if (!l.isEmptyDraw) l,
      ];

  /// Bounds used for selection chrome / handles during an active drag.
  (double, double, double, double) _displayGeom(Layer layer) {
    if (_dragging && _dragId == layer.id) {
      return (_cx, _cy, _cw, _ch);
    }
    return (layer.x, layer.y, layer.w, layer.h);
  }

  Rect _hitRect(Size canvas, Layer layer) {
    final g = _displayGeom(layer);
    final left = canvas.width * g.$1 / 100;
    final top = canvas.height * g.$2 / 100;
    var w = canvas.width * g.$3 / 100;
    var h = canvas.height * g.$4 / 100;
    if (w < _minHitPx) {
      final pad = (_minHitPx - w) / 2;
      return Rect.fromLTWH(
        left - pad,
        top,
        _minHitPx,
        h < _minHitPx ? _minHitPx : h,
      );
    }
    if (h < _minHitPx) {
      final pad = (_minHitPx - h) / 2;
      return Rect.fromLTWH(left, top - pad, w, _minHitPx);
    }
    return Rect.fromLTWH(left, top, w, h);
  }

  Rect _visualRect(Size canvas, Layer layer) {
    final g = _displayGeom(layer);
    return Rect.fromLTWH(
      canvas.width * g.$1 / 100,
      canvas.height * g.$2 / 100,
      canvas.width * g.$3 / 100,
      canvas.height * g.$4 / 100,
    );
  }

  /// Topmost hittable layer under [local] (canvas coords).
  Layer? _hitTestTopmost(Offset local) {
    final layers = _hittableLayers;
    for (var i = layers.length - 1; i >= 0; i--) {
      if (_hitRect(_frame, layers[i]).contains(local)) return layers[i];
    }
    return null;
  }

  /// Convert overlay-local coords (includes [kEditorEdgeOutset] pad) → canvas.
  Offset _toCanvas(Offset local) =>
      local - const Offset(kEditorEdgeOutset, kEditorEdgeOutset);

  Offset _handleCenter(Size canvas, Layer layer, ResizeHandle handle) {
    final g = _displayGeom(layer);
    final left = canvas.width * g.$1 / 100;
    final top = canvas.height * g.$2 / 100;
    final w = canvas.width * g.$3 / 100;
    final h = canvas.height * g.$4 / 100;
    return switch (handle) {
      ResizeHandle.nw => Offset(left, top),
      ResizeHandle.n => Offset(left + w / 2, top),
      ResizeHandle.ne => Offset(left + w, top),
      ResizeHandle.e => Offset(left + w, top + h / 2),
      ResizeHandle.se => Offset(left + w, top + h),
      ResizeHandle.s => Offset(left + w / 2, top + h),
      ResizeHandle.sw => Offset(left, top + h),
      ResizeHandle.w => Offset(left, top + h / 2),
    };
  }

  (double, double, double, double) _snap(
    double x,
    double y,
    double w,
    double h,
  ) {
    var nx = x, ny = y;
    final t = widget.snapThresholdPct;
    if (((x + w / 2) - 50).abs() <= t) {
      nx = 50 - w / 2;
    }
    if (((y + h / 2) - 50).abs() <= t) {
      ny = 50 - h / 2;
    }
    return (
      nx.clamp(_posMin, _posMax),
      ny.clamp(_posMin, _posMax),
      w.clamp(_sizeMinW, _sizeMaxW),
      h.clamp(_sizeMinH, _sizeMaxH),
    );
  }

  void _beginDrag(Layer layer, {ResizeHandle? handle}) {
    _dragId = layer.id;
    _dragHandle = handle;
    _ox = layer.x;
    _oy = layer.y;
    _ow = layer.w;
    _oh = layer.h;
    _cx = layer.x;
    _cy = layer.y;
    _cw = layer.w;
    _ch = layer.h;
    _accDx = 0;
    _accDy = 0;
    _dragging = true;
    _showGuides = true;
  }

  void _applyDelta(double dxPct, double dyPct) {
    final id = _dragId;
    if (id == null || _frame == Size.zero) return;

    double x = _ox, y = _oy, w = _ow, h = _oh;
    final handle = _dragHandle;
    if (handle == null) {
      x = _ox + dxPct;
      y = _oy + dyPct;
    } else {
      switch (handle) {
        case ResizeHandle.nw:
          x = _ox + dxPct;
          y = _oy + dyPct;
          w = _ow - dxPct;
          h = _oh - dyPct;
        case ResizeHandle.n:
          y = _oy + dyPct;
          h = _oh - dyPct;
        case ResizeHandle.ne:
          y = _oy + dyPct;
          w = _ow + dxPct;
          h = _oh - dyPct;
        case ResizeHandle.e:
          w = _ow + dxPct;
        case ResizeHandle.se:
          w = _ow + dxPct;
          h = _oh + dyPct;
        case ResizeHandle.s:
          h = _oh + dyPct;
        case ResizeHandle.sw:
          x = _ox + dxPct;
          w = _ow - dxPct;
          h = _oh + dyPct;
        case ResizeHandle.w:
          x = _ox + dxPct;
          w = _ow - dxPct;
      }
      if (w < _sizeMinW) {
        if (handle == ResizeHandle.w ||
            handle == ResizeHandle.nw ||
            handle == ResizeHandle.sw) {
          x = _ox + _ow - _sizeMinW;
        }
        w = _sizeMinW;
      }
      if (h < _sizeMinH) {
        if (handle == ResizeHandle.n ||
            handle == ResizeHandle.nw ||
            handle == ResizeHandle.ne) {
          y = _oy + _oh - _sizeMinH;
        }
        h = _sizeMinH;
      }
    }

    final snapped = _snap(x, y, w, h);
    final guides = ((snapped.$1 + snapped.$3 / 2) - 50).abs() <=
            widget.snapThresholdPct ||
        ((snapped.$2 + snapped.$4 / 2) - 50).abs() <= widget.snapThresholdPct;

    setState(() {
      _cx = snapped.$1;
      _cy = snapped.$2;
      _cw = snapped.$3;
      _ch = snapped.$4;
      _showGuides = guides;
    });
    widget.onGeometryPreview(id, _cx, _cy, _cw, _ch);
  }

  void _flushPendingSelect() {
    final id = _pendingSelectId;
    _pendingSelectId = null;
    if (id != null && id != widget.selectedId) {
      widget.onSelect(id);
    }
  }

  void _endDrag({required bool commit}) {
    final id = _dragId;
    final x = _cx, y = _cy, w = _cw, h = _ch;
    final didDrag = _dragging && id != null;

    setState(() {
      _dragging = false;
      _dragId = null;
      _dragHandle = null;
      _showGuides = false;
      _accDx = 0;
      _accDy = 0;
    });

    if (didDrag && commit) {
      widget.onGeometryCommit(id, x, y, w, h);
      HapticFeedback.selectionClick();
    }
    _flushPendingSelect();
  }

  void _onBodyPanStart(DragStartDetails details) {
    if (_frame == Size.zero) return;
    final local = _toCanvas(details.localPosition);
    final selected = _layerById(widget.selectedId);
    final topmost = _hitTestTopmost(local);

    // Already-selected layer under pointer (incl. buried) → move it.
    if (selected != null &&
        !selected.locked &&
        !selected.hidden &&
        _hitRect(_frame, selected).contains(local)) {
      _pendingSelectId = selected.id;
      _beginDrag(selected);
      setState(() {});
      return;
    }

    // Empty canvas + selection → keep moving the selected layer.
    if (selected != null && !selected.locked && topmost == null) {
      _beginDrag(selected);
      setState(() {});
      return;
    }

    // Different / new layer → select and move (parent notified on pan end).
    if (topmost != null) {
      _pendingSelectId = topmost.id;
      if (!topmost.locked) _beginDrag(topmost);
      setState(() {});
    }
  }

  void _onBodyPanUpdate(DragUpdateDetails details) {
    if (!_dragging || _dragHandle != null) return;
    if (_frame.width <= 0 || _frame.height <= 0) return;
    _accDx += details.delta.dx / _frame.width * 100;
    _accDy += details.delta.dy / _frame.height * 100;
    _applyDelta(_accDx, _accDy);
  }

  void _onBodyPanEnd(DragEndDetails details) {
    if (_dragging && _dragHandle == null) {
      _endDrag(commit: true);
    }
  }

  void _onBodyPanCancel() {
    if (_dragging && _dragHandle == null) {
      _endDrag(commit: true);
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (_dragging) return;
    if (_frame == Size.zero) return;
    final local = _toCanvas(details.localPosition);
    final topmost = _hitTestTopmost(local);
    _pendingSelectId = null;
    widget.onSelect(topmost?.id);

    if (topmost != null) {
      final global = details.globalPosition;
      if (_isDoubleTap(topmost.id, global)) {
        widget.onInspect?.call(topmost.id);
        _lastTapAt = null;
        _lastTapId = null;
        _lastTapGlobal = null;
      } else {
        _lastTapAt = DateTime.now();
        _lastTapId = topmost.id;
        _lastTapGlobal = global;
      }
    } else {
      _lastTapAt = null;
      _lastTapId = null;
      _lastTapGlobal = null;
    }
  }

  bool _isDoubleTap(String id, Offset global) {
    final lastAt = _lastTapAt;
    final lastId = _lastTapId;
    final lastGlobal = _lastTapGlobal;
    if (lastAt == null || lastId != id || lastGlobal == null) return false;
    if (DateTime.now().difference(lastAt) > _doubleTapTimeout) return false;
    if ((global - lastGlobal).distance > _doubleTapSlopPx) return false;
    return true;
  }

  void _onHandlePanStart(ResizeHandle handle, DragStartDetails details) {
    final selected = _layerById(widget.selectedId);
    if (selected == null || selected.locked) return;
    _pendingSelectId = selected.id;
    _beginDrag(selected, handle: handle);
    setState(() {});
  }

  void _onHandlePanUpdate(DragUpdateDetails details) {
    if (!_dragging || _dragHandle == null) return;
    if (_frame.width <= 0 || _frame.height <= 0) return;
    _accDx += details.delta.dx / _frame.width * 100;
    _accDy += details.delta.dy / _frame.height * 100;
    _applyDelta(_accDx, _accDy);
  }

  void _onHandlePanEnd(DragEndDetails details) {
    if (_dragging && _dragHandle != null) {
      _endDrag(commit: true);
    }
  }

  void _onHandlePanCancel() {
    if (_dragging && _dragHandle != null) {
      _endDrag(commit: true);
    }
  }

  Layer? get _chromeLayer {
    if (_dragging && _dragId != null) return _layerById(_dragId);
    if (_pendingSelectId != null) return _layerById(_pendingSelectId);
    return _layerById(widget.selectedId);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        // Parent pads by [kEditorEdgeOutset] on each side.
        _frame = Size(
          math.max(0, c.maxWidth - kEditorEdgeOutset * 2),
          math.max(0, c.maxHeight - kEditorEdgeOutset * 2),
        );
        final selected = _chromeLayer;
        final origin = const Offset(kEditorEdgeOutset, kEditorEdgeOutset);

        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            // Full padded surface — select + move (incl. off-canvas fringe).
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: _onTapUp,
                onPanStart: _onBodyPanStart,
                onPanUpdate: _onBodyPanUpdate,
                onPanEnd: _onBodyPanEnd,
                onPanCancel: _onBodyPanCancel,
                child: const SizedBox.expand(),
              ),
            ),

            if (selected != null)
              _SelectionChrome(
                visual: _visualRect(_frame, selected).shift(origin),
              ),

            if (_showGuides && _dragging)
              Positioned(
                left: kEditorEdgeOutset,
                top: kEditorEdgeOutset,
                width: _frame.width,
                height: _frame.height,
                child: const IgnorePointer(
                  child: CustomPaint(painter: _SnapGuidePainter()),
                ),
              ),

            // Handles sit above the body detector and own resize pans.
            if (selected != null && !selected.locked)
              for (final handle in ResizeHandle.values)
                _HandleKnob(
                  center: _handleCenter(_frame, selected, handle) + origin,
                  handle: handle,
                  hitSize: _handleHit,
                  visualSize: _handleVisual,
                  onPanStart: (d) => _onHandlePanStart(handle, d),
                  onPanUpdate: _onHandlePanUpdate,
                  onPanEnd: _onHandlePanEnd,
                  onPanCancel: _onHandlePanCancel,
                ),
          ],
        );
      },
    );
  }
}

class _SelectionChrome extends StatelessWidget {
  const _SelectionChrome({required this.visual});

  final Rect visual;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: visual.left,
      top: visual.top,
      width: math.max(visual.width, 1),
      height: math.max(visual.height, 1),
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: DriveColors.primary.withValues(alpha: 0.95),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: DriveColors.primary.withValues(alpha: 0.28),
                blurRadius: 10,
              ),
            ],
            color: DriveColors.primary.withValues(alpha: 0.04),
          ),
        ),
      ),
    );
  }
}

class _HandleKnob extends StatelessWidget {
  const _HandleKnob({
    required this.center,
    required this.handle,
    required this.hitSize,
    required this.visualSize,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onPanCancel,
  });

  final Offset center;
  final ResizeHandle handle;
  final double hitSize;
  final double visualSize;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;
  final VoidCallback onPanCancel;

  @override
  Widget build(BuildContext context) {
    final isCorner = handle == ResizeHandle.nw ||
        handle == ResizeHandle.ne ||
        handle == ResizeHandle.se ||
        handle == ResizeHandle.sw;

    return Positioned(
      left: center.dx - hitSize / 2,
      top: center.dy - hitSize / 2,
      width: hitSize,
      height: hitSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: onPanStart,
        onPanUpdate: onPanUpdate,
        onPanEnd: onPanEnd,
        onPanCancel: onPanCancel,
        child: Center(
          child: isCorner
              ? Transform.rotate(
                  angle: math.pi / 4,
                  child: Container(
                    width: visualSize * 0.55,
                    height: visualSize * 0.55,
                    decoration: BoxDecoration(
                      color: DriveColors.obsidian,
                      border: Border.all(
                        color: DriveColors.primary,
                        width: 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: DriveColors.primary.withValues(alpha: 0.55),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                )
              : Container(
                  width: visualSize * 0.6,
                  height: visualSize * 0.6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: DriveColors.obsidian.withValues(alpha: 0.9),
                    border: Border.all(
                      color: DriveColors.primaryGlow,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: DriveColors.primary.withValues(alpha: 0.4),
                        blurRadius: 7,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _SnapGuidePainter extends CustomPainter {
  const _SnapGuidePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = DriveColors.primary.withValues(alpha: 0.45)
      ..strokeWidth = 0.8;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
