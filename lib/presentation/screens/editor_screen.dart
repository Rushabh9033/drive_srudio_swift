import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/feedback/drive_haptics.dart';
import '../../core/media/bg_cutout_service.dart';
import '../../core/media/image_store.dart';
import '../../core/nav/studio_browse.dart';
import '../../core/permissions/drive_permissions.dart';
import '../../core/theme/drive_colors.dart';
import '../../core/theme/drive_theme.dart';
import '../../data/catalog/catalog.dart';
import '../../data/models/models.dart';
import '../../data/store/app_store.dart';
import '../widgets/drive_ui.dart';
import '../widgets/layer_editor_overlay.dart';
import '../widgets/layer_preset_sheet.dart';
import '../widgets/surfaces.dart';
import '../widgets/widget_canvas.dart';
import 'background_picker_sheet.dart';
import 'layer_settings_sheets.dart';
import 'studio_creation_sheets.dart';
import '../widgets/editor_dock.dart';
import '../widgets/widget_library_sheet.dart';
import '../widgets/background_sheet.dart';

enum _EditorTab { car, text, widget, draw, background }

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.id});
  final String id;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late WidgetSpec _spec;
  late TextEditingController _name;
  String? _selectedId;
  bool _dirty = false;
  final List<WidgetSpec> _past = [];
  final List<WidgetSpec> _future = [];
  bool _missing = false;
  bool _previewing = false;
  WidgetSpec? _beforeGesture;
  Layer? _clipboard;
  _EditorTab _tab = _EditorTab.car;
  bool _processing = false;
  String _processingLabel = 'Processing image…';
  bool _drawMode = false;
  List<List<List<double>>> _activeStrokes = [];
  List<List<double>>? _currentStroke;

  /// Keeps [LayerEditorOverlay] State mounted across editor rebuilds.
  final GlobalKey _layerEditorKey = GlobalKey();

  /// Live geometry / clock paint signal — updates canvas paint WITHOUT
  /// [setState], so the overlay GestureDetectors are never remounted mid-drag.
  final ValueNotifier<int> _paintTick = ValueNotifier(0);

  Layer? get _selected {
    if (_selectedId == null) return null;
    for (final l in _spec.layers) {
      if (l.id == _selectedId) return l;
    }
    return null;
  }

  Layer? get _sizeTarget {
    final sel = _selected;
    if (sel != null &&
        (sel.kind == LayerKind.image ||
            sel.isLogo ||
            sel.role == 'logo' ||
            sel.role == 'stock' ||
            sel.role == 'gallery')) {
      return sel;
    }
    for (final l in _spec.layers.reversed) {
      if (l.kind == LayerKind.image && !l.hidden) return l;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final draft = context.read<AppStore>().draftById(widget.id);
    if (draft == null) {
      _missing = true;
      _spec = WidgetSpec(
        background: const WidgetBackground(type: BgType.solid, from: '#12141A'),
        layers: [],
      );
      _name = TextEditingController(text: 'Untitled');
    } else {
      // Full multi-layer clone — never a flattened preview image.
      final cloned = draft.spec.clone();
      _spec = WidgetSpec(
        background: cloned.background,
        layers: [
          for (final l in cloned.layers)
            if (!l.isEmptyDraw) l,
        ],
      );
      _name = TextEditingController(text: draft.name);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _paintTick.dispose();
    super.dispose();
  }

  void _repaintCanvas() {
    _paintTick.value++;
  }

  void _commit(WidgetSpec next) {
    if (!_previewing) {
      _past.add(_spec.clone());
      if (_past.length > 40) _past.removeAt(0);
      _future.clear();
    }
    setState(() {
      _spec = next;
      _dirty = true;
      if (_selectedId != null && !next.layers.any((l) => l.id == _selectedId)) {
        _selectedId = null;
      }
    });
  }

  /// Live drag preview: mutate layer geometry in place + paint tick.
  /// Must NOT call [setState] — that remounts gesture arenas and freezes drag.
  void _previewGeometry(String id, double x, double y, double w, double h) {
    if (!_previewing) {
      _previewing = true;
      _beforeGesture = _spec.clone();
    }
    for (final l in _spec.layers) {
      if (l.id == id) {
        l.x = x;
        l.y = y;
        l.w = w;
        l.h = h;
        break;
      }
    }
    _dirty = true;
    _repaintCanvas();
  }

  /// Gesture end: one undo entry from the pre-drag snapshot.
  void _commitGeometry(String id, double x, double y, double w, double h) {
    for (final l in _spec.layers) {
      if (l.id == id) {
        l.x = x;
        l.y = y;
        l.w = w;
        l.h = h;
        break;
      }
    }
    final before = _beforeGesture;
    if (before != null) {
      Layer? prior;
      for (final l in before.layers) {
        if (l.id == id) {
          prior = l;
          break;
        }
      }
      final changed =
          prior == null ||
          prior.x != x ||
          prior.y != y ||
          prior.w != w ||
          prior.h != h;
      if (changed) {
        _past.add(before);
        if (_past.length > 40) _past.removeAt(0);
        _future.clear();
      }
      _beforeGesture = null;
    }
    _previewing = false;
    setState(() => _dirty = true);
    _repaintCanvas();
  }

  void _selectLayer(String? id) {
    if (_selectedId == id) return;
    DriveHaptics.selection();
    setState(() => _selectedId = id);
  }

  void _undo() {
    if (_past.isEmpty) return;
    _future.add(_spec.clone());
    setState(() {
      _spec = _past.removeLast();
      _dirty = true;
      _selectedId = null;
    });
  }

  void _redo() {
    if (_future.isEmpty) return;
    _past.add(_spec.clone());
    setState(() {
      _spec = _future.removeLast();
      _dirty = true;
      _selectedId = null;
    });
  }

  void _save() {
    context.read<AppStore>().saveDraft(
      widget.id,
      name: _name.text.trim().isEmpty ? 'Untitled widget' : _name.text.trim(),
      spec: _spec,
    );
    setState(() => _dirty = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Draft saved')));
  }

  Future<void> _exit() async {
    if (!_dirty) {
      context.go('/studio');
      return;
    }
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text('Save before leaving the editor?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'keep'),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Discard'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Save and exit'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'save') {
      _save();
      context.go('/studio');
    } else if (action == 'discard') {
      context.go('/studio');
    }
  }

  void _patchLayer(String id, Layer Function(Layer) patch) {
    final nextLayers = _spec.layers.map((l) {
      if (l.id != id) return l;
      return patch(l);
    }).toList();
    _commit(WidgetSpec(background: _spec.background, layers: nextLayers));
  }

  Future<void> _maybeHowTo() async {
    final store = context.read<AppStore>();
    if (store.howToSeen) return;
    store.markHowToSeen();
    if (!mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DriveColors.carbon,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Widget Configured!',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Would you like to open the How To Set Widget page?',
          style: GoogleFonts.manrope(color: DriveColors.mutedForeground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (go == true && mounted) context.push('/setup');
  }

  Future<void> _withProcessing(
    Future<void> Function() work, {
    String label = 'Processing image…',
  }) async {
    setState(() {
      _processing = true;
      _processingLabel = label;
    });
    try {
      await work();
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  /// Primary entry: Gallery / Camera / Remove BG (user photos only).
  Future<void> _onCarTab() async {
    final choice = await showImageSelectionSheet(context);
    if (!mounted || choice == null) return;
    switch (choice) {
      case ImageSelectionChoice.gallery:
        await _addUserCarPhoto(ImageSource.gallery);
      case ImageSelectionChoice.camera:
        await _addUserCarPhoto(ImageSource.camera);
      case ImageSelectionChoice.removeBg:
        await _addUserCarPhoto(
          ImageSource.gallery,
          cutout: BgCutoutMode.onDevice,
        );
    }
  }

  Future<void> _addUserCarPhoto(
    ImageSource source, {
    BgCutoutMode? cutout,
  }) async {
    final kind = source == ImageSource.camera
        ? DrivePermissionKind.camera
        : DrivePermissionKind.photos;
    final gate = await DrivePermissions.ensure(context, kind);
    if (!mounted) return;
    if (gate != DrivePermissionOutcome.granted) return;

    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 90,
    );
    if (file == null || !mounted) return;

    var mode = cutout;
    if (mode == null) {
      final choice = await showRemoveBackgroundPrompt(context);
      if (!mounted || choice == null) return;
      switch (choice) {
        case RemoveBgPromptChoice.keep:
          mode = null;
        case RemoveBgPromptChoice.removeBg:
          mode = BgCutoutMode.onDevice;
      }
    }

    final cutting = mode != null;

    await _withProcessing(() async {
      var bytes = await file.readAsBytes();
      var label = source == ImageSource.camera ? 'Camera' : 'Gallery';
      const role = 'gallery';

      if (mode != null) {
        final result = await BgCutoutService().cutout(bytes, mode: mode);
        if (!result.ok || result.pngBytes == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.error ?? 'Background removal failed'),
              ),
            );
          }
          return;
        }
        bytes = result.pngBytes!;
        label = 'Cutout';
        final path = await persistPickedPng(bytes, maxEdge: 1024);
        if (!mounted || path == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not save cutout')),
            );
          }
          return;
        }
        final layer = baseLayer(
          LayerKind.image,
          overrides: {
            'label': label,
            'x': 0.0,
            'y': 0.0,
            'w': 100.0,
            'h': 100.0,
          },
        ).copyWith(role: role, src: path, fit: BoxFit.cover, radius: 0);
        _commit(
          WidgetSpec(
            background: _spec.background,
            layers: [..._spec.layers, layer],
          ),
        );
        setState(() => _selectedId = layer.id);
        DriveHaptics.light();
        return;
      }

      final path = await persistPickedImage(bytes, maxEdge: 1024);
      if (!mounted || path == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not process image')),
          );
        }
        return;
      }
      final layer = baseLayer(
        LayerKind.image,
        overrides: {'label': label, 'x': 0.0, 'y': 0.0, 'w': 100.0, 'h': 100.0},
      ).copyWith(role: role, src: path, fit: BoxFit.cover, radius: 0);
      _commit(
        WidgetSpec(
          background: _spec.background,
          layers: [..._spec.layers, layer],
        ),
      );
      setState(() => _selectedId = layer.id);
      DriveHaptics.light();
    }, label: cutting ? 'Remove BG…' : 'Processing image…');
    if (mounted) await _maybeHowTo();
  }

  bool get _selectedIsRemovableImage {
    final sel = _selected;
    return sel != null &&
        sel.kind == LayerKind.image &&
        (sel.src?.isNotEmpty ?? false) &&
        sel.role != 'logo';
  }

  /// Remove BG on the selected image layer only.
  /// If another image exists but none is selected — prompt to select.
  /// If no image layers — open gallery cutout flow (Add photo → Remove BG).
  Future<void> _removeBgOnSelected() async {
    final sel = _selected;
    if (sel != null &&
        sel.kind == LayerKind.image &&
        (sel.src?.isNotEmpty ?? false) &&
        sel.role != 'logo') {
      // Apply to selected image only.
    } else {
      final hasImage = _spec.layers.any(
        (l) =>
            l.kind == LayerKind.image &&
            (l.src?.isNotEmpty ?? false) &&
            l.role != 'logo',
      );
      if (hasImage) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Select an image layer first (tap it or use Layers), then Remove BG',
            ),
          ),
        );
        _sheetLayers();
        return;
      }
      await _addUserCarPhoto(
        ImageSource.gallery,
        cutout: BgCutoutMode.onDevice,
      );
      return;
    }

    await _withProcessing(() async {
      final bytes = await loadImageBytes(sel.src);
      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Could not load image')));
        }
        return;
      }
      final result = await BgCutoutService().cutout(
        bytes,
        mode: BgCutoutMode.onDevice,
      );
      if (!result.ok || result.pngBytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Background removal failed'),
            ),
          );
        }
        return;
      }
      final path = await persistPickedPng(result.pngBytes!, maxEdge: 1024);
      if (!mounted || path == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not save cutout')),
          );
        }
        return;
      }
      _patchLayer(
        sel.id,
        (l) => l.copyWith(
          src: path,
          label: 'Cutout',
          fit: BoxFit.contain,
          radius: 0,
        ),
      );
    }, label: 'Remove BG…');
  }

  Future<void> _onTextTab() async {
    final result = await showTextEditorSheet(
      context,
      initialText: '',
      color: '#F2F5FA',
      weight: 700,
      shadow: false,
      radius: 0,
    );
    if (!mounted || result == null) return;
    final text = (result['text'] as String?)?.trim() ?? '';
    if (text.isEmpty) return;
    final layer =
        baseLayer(
          LayerKind.text,
          overrides: {
            'text': text,
            'x': 12.0,
            'y': 40.0,
            'fontSize': 18.0,
            'weight': result['weight'] as int? ?? 700,
            'color': result['color'] as String? ?? '#F2F5FA',
          },
        ).copyWith(
          shadow: result['shadow'] as bool? ?? false,
          radius: (result['radius'] as num?)?.toDouble() ?? 0,
          color2: result['color2'] as String?,
          shadowColor: result['shadowColor'] as String?,
        );
    _commit(
      WidgetSpec(
        background: _spec.background,
        layers: [..._spec.layers, layer],
      ),
    );
    setState(() => _selectedId = layer.id);
  }

  Future<void> _onWidgetTab() async {
    final layers = await WidgetLibrarySheet.show(context);
    if (!mounted || layers == null || layers.isEmpty) return;
    _commit(
      WidgetSpec(
        background: _spec.background,
        layers: [..._spec.layers, ...layers],
      ),
    );
    setState(() => _selectedId = layers.last.id);
    DriveHaptics.light();
  }

  Future<void> _showSpeedometerAddPicker() async {
    await DriveSheet.show<void>(
      context: context,
      builder: (ctx) => DriveSheet(
        title: 'Speedometer',
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Compose freely, drop a premium layout onto this canvas, or browse the full stock set.',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  height: 1.35,
                  color: DriveColors.mutedForeground,
                ),
              ),
            ),
            _WidgetAddTile(
              title: 'Compose free',
              subtitle: 'Speed + unit + GPS badge — drag each',
              icon: CupertinoIcons.plus_circle,
              onTap: () {
                Navigator.pop(ctx);
                _addSpeedometerLayer();
              },
            ),
            _WidgetAddTile(
              title: 'Arc Gauge',
              subtitle: 'Premium crescent + hero digits',
              icon: CupertinoIcons.speedometer,
              onTap: () {
                Navigator.pop(ctx);
                _dropSpeedometerPreset('speed-arc-gauge');
              },
            ),
            _WidgetAddTile(
              title: 'HUD Brackets',
              subtitle: 'Premium night HUD corners',
              icon: CupertinoIcons.square_favorites_alt,
              onTap: () {
                Navigator.pop(ctx);
                _dropSpeedometerPreset('speed-hud-brackets');
              },
            ),
            _WidgetAddTile(
              title: 'Browse all speedometers',
              subtitle: 'Studio → Speedometer',
              icon: CupertinoIcons.collections,
              onTap: () {
                Navigator.pop(ctx);
                StudioBrowse.goToCategory(context, 'Speedometer');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _addSpeedometerLayer() {
    final nest = countSpeedometerClusters(_spec.layers);
    final cluster = composeSpeedometerLayers(nestIndex: nest);
    final digits = cluster.firstWhere(
      (l) => l.format == 'gpsspeed' && l.kind == LayerKind.text,
    );
    _commit(
      WidgetSpec(
        background: _spec.background,
        layers: [..._spec.layers, ...cluster],
      ),
    );
    setState(() => _selectedId = digits.id);
  }

  /// Append reminted layers from a Speedometer stock template (keeps current BG).
  void _dropSpeedometerPreset(String templateId) {
    TemplateItem? match;
    for (final t in Catalog.templates) {
      if (t.id == templateId) {
        match = t;
        break;
      }
    }
    if (match == null) {
      _addSpeedometerLayer();
      return;
    }
    final nest = countSpeedometerClusters(_spec.layers);
    final dx = (nest % 4) * 6.0;
    final dy = (nest % 4) * 8.0;
    final cloned = match.spec.clone(remintLayerIds: true);
    final dropped = [
      for (final l in cloned.layers) l.copyWith(x: l.x + dx, y: l.y + dy),
    ];
    Layer? digits;
    for (final l in dropped) {
      if (l.kind == LayerKind.text && l.format == 'gpsspeed') {
        digits = l;
        break;
      }
    }
    _commit(
      WidgetSpec(
        background: _spec.background,
        layers: [..._spec.layers, ...dropped],
      ),
    );
    setState(() => _selectedId = digits?.id ?? dropped.last.id);
  }

  void _addSimple(LayerKind kind) {
    final layer = baseLayer(
      kind,
      overrides: {'y': 20.0 + _spec.layers.length * 4},
    );
    _commit(
      WidgetSpec(
        background: _spec.background,
        layers: [..._spec.layers, layer],
      ),
    );
    setState(() => _selectedId = layer.id);
  }

  double _composeNestY() => 20.0 + (_spec.layers.length % 6) * 6.0;

  void _showLayerPresetSheet(LayerKind kind) {
    DriveSheet.show(
      context: context,
      builder: (ctx) => LayerPresetSheet(
        kind: kind,
        onSelect: (presetLayer) {
          final layer = presetLayer.copyWith(
            id: const Uuid().v4(),
            x: 12.0 + (_spec.layers.length % 4) * 4.0,
            y: 38.0 + (_spec.layers.length % 5) * 4.0,
          );
          _commit(
            WidgetSpec(
              background: _spec.background,
              layers: [..._spec.layers, layer],
            ),
          );
          setState(() {
            _selectedId = layer.id;
          });
        },
      ),
    );
  }

  void _addDigitalClockLayer() {
    final layer = baseLayer(
      LayerKind.clock,
      overrides: {
        'x': 12.0 + (_spec.layers.length % 4) * 4.0,
        'y': 38.0 + (_spec.layers.length % 5) * 4.0,
        'fontSize': 32.0,
        'weight': 800,
        'format': '24',
      },
    );
    _commit(
      WidgetSpec(
        background: _spec.background,
        layers: [..._spec.layers, layer],
      ),
    );
    setState(() => _selectedId = layer.id);
  }

  void _addAnalogClockLayer() {
    final nest =
        (_spec.layers.where((l) => l.kind == LayerKind.analog).length % 3);
    final layer = baseLayer(
      LayerKind.analog,
      overrides: {
        'x': 18.0 + nest * 8.0,
        'y': 14.0 + nest * 6.0,
        'w': 52.0,
        'h': 52.0,
      },
    );
    _commit(
      WidgetSpec(
        background: _spec.background,
        layers: [..._spec.layers, layer],
      ),
    );
    setState(() => _selectedId = layer.id);
  }

  void _addDateLayer() {
    final layer = baseLayer(
      LayerKind.date,
      overrides: {
        'x': 12.0,
        'y': _composeNestY(),
        'fontSize': 14.0,
        'format': 'abbrev',
        'color': '#A8B6CC',
      },
    );
    _commit(
      WidgetSpec(
        background: _spec.background,
        layers: [..._spec.layers, layer],
      ),
    );
    setState(() => _selectedId = layer.id);
  }

  void _onDrawTab() {
    final leaving = _drawMode;
    if (leaving) {
      setState(() {
        _drawMode = false;
        _tab = _EditorTab.draw;
      });
      _pruneEmptyDrawLayers();
      return;
    }
    setState(() {
      _drawMode = true;
      _tab = _EditorTab.draw;
      Layer? draw;
      for (final l in _spec.layers) {
        if (l.kind == LayerKind.draw && !l.isEmptyDraw) {
          draw = l;
          break;
        }
      }
      if (draw != null) {
        _selectedId = draw.id;
        try {
          final raw =
              jsonDecode(draw.strokes.isEmpty ? '[]' : draw.strokes) as List;
          _activeStrokes = raw
              .map(
                (s) => (s as List)
                    .map(
                      (p) => (p as List)
                          .map((n) => (n as num).toDouble())
                          .toList(),
                    )
                    .toList(),
              )
              .toList();
        } catch (_) {
          _activeStrokes = [];
        }
      } else {
        // Do not insert a full-canvas empty draw layer until ink exists —
        // that layer would steal every tap as one giant selection.
        _selectedId = null;
        _activeStrokes = [];
      }
    });
  }

  /// Drop ink-less draw layers left behind by prior Draw sessions / old drafts.
  void _pruneEmptyDrawLayers() {
    final next = [
      for (final l in _spec.layers)
        if (!l.isEmptyDraw) l,
    ];
    if (next.length == _spec.layers.length) return;
    final prunedIds = {
      for (final l in _spec.layers)
        if (l.isEmptyDraw) l.id,
    };
    _commit(WidgetSpec(background: _spec.background, layers: next));
    if (_selectedId != null && prunedIds.contains(_selectedId)) {
      _selectedId = null;
    }
  }

  void _persistStrokes() {
    var id = _selectedId;
    Layer? draw;
    if (id != null) {
      for (final l in _spec.layers) {
        if (l.id == id && l.kind == LayerKind.draw) {
          draw = l;
          break;
        }
      }
    }
    if (draw == null) {
      for (final l in _spec.layers) {
        if (l.kind == LayerKind.draw) {
          draw = l;
          id = l.id;
          break;
        }
      }
    }
    if (draw == null) {
      final layer = baseLayer(
        LayerKind.draw,
      ).copyWith(strokes: jsonEncode(_activeStrokes));
      _commit(
        WidgetSpec(
          background: _spec.background,
          layers: [..._spec.layers, layer],
        ),
      );
      setState(() => _selectedId = layer.id);
      return;
    }
    _patchLayer(id!, (l) => l.copyWith(strokes: jsonEncode(_activeStrokes)));
  }

  Future<void> _onBackgroundTab() async {
    await BackgroundSheet.show(context, _spec, (WidgetSpec newSpec) {
      _commit(newSpec);
    }, _pickBackgroundImage);
  }

  Future<WidgetBackground?> _pickBackgroundImage() async {
    final gate = await DrivePermissions.ensure(
      context,
      DrivePermissionKind.photos,
    );
    if (!mounted || gate != DrivePermissionOutcome.granted) return null;

    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 90,
    );
    if (file == null || !mounted) return null;
    WidgetBackground? result;
    await _withProcessing(() async {
      final bytes = await file.readAsBytes();
      final path = await persistPickedImage(bytes, maxEdge: 1280);
      if (!mounted || path == null) return;
      result = WidgetBackground(
        type: BgType.image,
        from: '#12141A',
        to: '#1E3A5F',
        imageSrc: path,
      );
    });
    return result;
  }

  void _setImageSize(double nextW, {required bool commit}) {
    final target = _sizeTarget;
    if (target == null || target.w <= 0) return;
    final id = target.id;
    final next = nextW.clamp(10.0, 250.0);
    final scale = next / target.w;
    final nh = (target.h * scale).clamp(8.0, 250.0);
    final cx = target.x + target.w / 2;
    final cy = target.y + target.h / 2;
    final x = (cx - next / 2).clamp(-100.0, 200.0);
    final y = (cy - nh / 2).clamp(-100.0, 200.0);

    if (!commit) {
      // Live slider: mutate in place + paint tick (same contract as drag).
      // Avoid replacing layer list identity mid-gesture.
      if (!_previewing) {
        _previewing = true;
        _beforeGesture = _spec.clone();
      }
      for (final l in _spec.layers) {
        if (l.id == id) {
          l.x = x;
          l.y = y;
          l.w = next;
          l.h = nh;
          break;
        }
      }
      _dirty = true;
      _selectedId = id;
      _repaintCanvas();
      setState(() {});
      return;
    }

    for (final l in _spec.layers) {
      if (l.id == id) {
        l.x = x;
        l.y = y;
        l.w = next;
        l.h = nh;
        break;
      }
    }

    // Commit: one undo entry from pre-gesture snapshot when available.
    if (_previewing && _beforeGesture != null) {
      _past.add(_beforeGesture!);
      if (_past.length > 40) _past.removeAt(0);
      _future.clear();
      _beforeGesture = null;
      _previewing = false;
      setState(() {
        _dirty = true;
        _selectedId = id;
      });
      _repaintCanvas();
      return;
    }

    _patchLayer(id, (l) => l.copyWith(w: next, h: nh, x: x, y: y));
    setState(() => _selectedId = id);
  }

  void _nudgeSize(double delta) {
    final target = _sizeTarget;
    if (target == null) return;
    _setImageSize(target.w + delta, commit: true);
  }

  void _deleteSelected() {
    final sel = _selected;
    if (sel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a widget layer first')),
      );
      _sheetLayers();
      return;
    }
    _deleteLayerById(sel.id);
  }

  void _deleteLayerById(String id) {
    DriveHaptics.medium();
    _commit(
      WidgetSpec(
        background: _spec.background,
        layers: _spec.layers.where((l) => l.id != id).toList(),
      ),
    );
    if (_selectedId == id) {
      setState(() => _selectedId = null);
    }
  }

  void _copySelected() {
    final sel = _selected;
    if (sel == null) return;
    setState(() => _clipboard = Layer.fromJson(sel.toJson()));
  }

  void _pasteClipboard() {
    final src = _clipboard;
    if (src == null) return;
    final json = src.toJson();
    json['id'] = const Uuid().v4();
    final copy = Layer.fromJson(json).copyWith(
      x: (src.x + 4).clamp(-100.0, 200.0).toDouble(),
      y: (src.y + 4).clamp(-100.0, 200.0).toDouble(),
      label: '${src.label} copy',
    );
    _commit(
      WidgetSpec(background: _spec.background, layers: [..._spec.layers, copy]),
    );
    setState(() => _selectedId = copy.id);
  }

  void _duplicateSelected() {
    _copySelected();
    _pasteClipboard();
  }

  void _sheetLayers() {
    DriveSheet.show<void>(
      context: context,
      builder: (ctx) => DriveSheet(
        title: 'Layers',
        child: _spec.layers.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Text(
                      'No layers yet.',
                      style: GoogleFonts.manrope(
                        color: DriveColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _onCarTab();
                      },
                      icon: const Icon(CupertinoIcons.car_fill, size: 16),
                      label: const Text('Add photo'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _onWidgetTab();
                      },
                      icon: const Icon(CupertinoIcons.plus_app, size: 16),
                      label: const Text('Add widget'),
                    ),
                  ],
                ),
              )
            : ListView(
                children: [
                  for (final l in _spec.layers.reversed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: _selectedId == l.id
                            ? DriveColors.primary.withValues(alpha: 0.12)
                            : DriveColors.graphite,
                        borderRadius: BorderRadius.circular(DriveRadii.md),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(DriveRadii.md),
                          onTap: () {
                            // Select only — drag on canvas moves this layer even
                            // when buried. Double-tap canvas or Inspect for settings.
                            setState(() => _selectedId = l.id);
                            Navigator.pop(ctx);
                          },
                          onLongPress: () {
                            Navigator.pop(ctx);
                            _openLayerSettings(l.id);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l.label.isNotEmpty
                                            ? l.label
                                            : l.kind.name,
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        [
                                          l.kind.name,
                                          if (l.format.isNotEmpty) l.format,
                                          if (l.text.trim().isNotEmpty &&
                                              l.kind != LayerKind.image)
                                            '"${l.text.trim()}"',
                                        ].join(' · '),
                                        style: driveMonoLabel(size: 10),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Edit layer',
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _openLayerSettings(l.id);
                                  },
                                  icon: const Icon(
                                    CupertinoIcons.slider_horizontal_3,
                                    size: 18,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Remove widget',
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _deleteLayerById(l.id);
                                  },
                                  icon: const Icon(
                                    CupertinoIcons.trash,
                                    size: 18,
                                    color: DriveColors.destructive,
                                  ),
                                ),
                                if (l.locked)
                                  const Icon(
                                    CupertinoIcons.lock_fill,
                                    size: 14,
                                    color: DriveColors.mutedForeground,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  /// Double-tap / Inspect entry — kind-specific editor when available.
  Future<void> _openLayerSettings(String id) async {
    Layer? layer;
    for (final l in _spec.layers) {
      if (l.id == id) {
        layer = l;
        break;
      }
    }
    if (layer == null) return;
    setState(() => _selectedId = id);
    final updated = await showLayerSettingsSheet(context, layer: layer);
    if (!mounted || updated == null) return;
    _patchLayer(id, (_) => updated);
  }

  /// Bottom-right chrome — opens per-layer settings when a widget is selected.
  void _openWidgetSettings() {
    final sel = _selected;
    if (sel == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a widget first')));
      _sheetLayers();
      return;
    }
    _openLayerSettings(sel.id);
  }

  void _toggleAnimateSelected(bool value) {
    final sel = _selected;
    if (sel == null || !sel.supportsAnimation) return;
    _patchLayer(
      sel.id,
      (l) => l.copyWith(
        animate: value,
        animStyle: value && l.animStyle.isEmpty
            ? l.resolvedAnimStyle
            : l.animStyle,
      ),
    );
  }

  void _sheetInspect() {
    final sel = _selected;
    DriveSheet.show<void>(
      context: context,
      builder: (ctx) => DriveSheet(
        title: 'Inspect',
        child: sel == null
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Text(
                      'Select a layer on the canvas, or add a car first.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        color: DriveColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _onCarTab();
                      },
                      icon: const Icon(CupertinoIcons.car_fill, size: 16),
                      label: const Text('Add photo'),
                    ),
                  ],
                ),
              )
            : ListView(
                children: [
                  _InspectRow(label: 'Name', value: sel.label),
                  _InspectRow(label: 'Type', value: sel.kind.name),
                  if (sel.role.isNotEmpty)
                    _InspectRow(label: 'Role', value: sel.role),
                  _InspectRow(
                    label: 'Size',
                    value: '${sel.w.round()} × ${sel.h.round()}',
                  ),
                  _InspectRow(
                    label: 'Position',
                    value: '${sel.x.round()}, ${sel.y.round()}',
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openLayerSettings(sel.id);
                    },
                    child: const Text('Edit layer'),
                  ),
                  if (sel.supportsAnimation) ...[
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Animate',
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                      ),
                      value: sel.animate,
                      onChanged: (v) {
                        Navigator.pop(ctx);
                        _toggleAnimateSelected(v);
                      },
                    ),
                  ],
                  if (sel.kind == LayerKind.image) ...[
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: DriveColors.primary,
                        foregroundColor: DriveColors.primaryForeground,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _removeBgOnSelected();
                      },
                      icon: const Icon(Icons.auto_fix_high, size: 20),
                      label: const Text('Remove BG'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _onCarTab();
                      },
                      icon: const Icon(CupertinoIcons.car_fill, size: 16),
                      label: const Text('Replace image / car'),
                    ),
                  ],
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _deleteSelected();
                    },
                    icon: const Icon(
                      CupertinoIcons.trash,
                      size: 16,
                      color: DriveColors.destructive,
                    ),
                    label: const Text('Remove widget'),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _handleTab(_EditorTab tab) async {
    setState(() {
      _tab = tab;
      if (tab != _EditorTab.draw) _drawMode = false;
    });
    switch (tab) {
      case _EditorTab.car:
        await _onCarTab();
      case _EditorTab.text:
        await _onTextTab();
      case _EditorTab.widget:
        await _onWidgetTab();
      case _EditorTab.draw:
        _onDrawTab();
      case _EditorTab.background:
        await _onBackgroundTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_missing) {
      return Scaffold(
        backgroundColor: DriveColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Draft not found',
                    style: GoogleFonts.manrope(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.go('/studio'),
                    child: const Text('Back to Studio'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final sizeTarget = _sizeTarget;
    final sizeLabel = sizeTarget?.isLogo == true || sizeTarget?.role == 'logo'
        ? 'Logo Size'
        : 'Image Size';
    final sizeValue = sizeTarget?.w.round() ?? 0;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _undo,
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        ): _redo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
            _redo,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): _redo,
        const SingleActivator(LogicalKeyboardKey.keyC, control: true):
            _copySelected,
        const SingleActivator(LogicalKeyboardKey.keyC, meta: true):
            _copySelected,
        const SingleActivator(LogicalKeyboardKey.keyV, control: true):
            _pasteClipboard,
        const SingleActivator(LogicalKeyboardKey.keyV, meta: true):
            _pasteClipboard,
        const SingleActivator(LogicalKeyboardKey.keyD, control: true):
            _duplicateSelected,
        const SingleActivator(LogicalKeyboardKey.keyD, meta: true):
            _duplicateSelected,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _save,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: DriveColors.background,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _exit,
                        icon: const Icon(CupertinoIcons.back),
                      ),
                      Expanded(
                        child: Text(
                          'Drive Studio',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Undo',
                        onPressed: _past.isEmpty ? null : _undo,
                        icon: const Icon(
                          CupertinoIcons.arrow_uturn_left,
                          size: 20,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Save',
                        onPressed: _save,
                        icon: const Icon(CupertinoIcons.square_arrow_down),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _name,
                          onChanged: (_) => setState(() => _dirty = true),
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: DriveColors.mutedForeground,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            hintText: 'Widget name',
                          ),
                        ),
                      ),
                      _GhostTool(
                        icon: CupertinoIcons.layers_alt,
                        label: 'Layers',
                        onTap: _sheetLayers,
                      ),
                      const SizedBox(width: 8),
                      _GhostTool(
                        icon: CupertinoIcons.slider_horizontal_3,
                        label: 'Inspect',
                        onTap: _sheetInspect,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            WidgetCanvas(
                              spec: _spec,
                              tickSeconds: 30,
                              paintListenable: _paintTick,
                              child: _drawMode
                                  ? LayoutBuilder(
                                      builder: (context, constraints) {
                                        return GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onPanStart: (d) {
                                            final x =
                                                (d.localPosition.dx /
                                                    constraints.maxWidth) *
                                                100;
                                            final y =
                                                (d.localPosition.dy /
                                                    constraints.maxHeight) *
                                                100;
                                            setState(() {
                                              _currentStroke = [
                                                [x, y],
                                              ];
                                            });
                                          },
                                          onPanUpdate: (d) {
                                            final x =
                                                (d.localPosition.dx /
                                                    constraints.maxWidth) *
                                                100;
                                            final y =
                                                (d.localPosition.dy /
                                                    constraints.maxHeight) *
                                                100;
                                            setState(() {
                                              _currentStroke = [
                                                ...?_currentStroke,
                                                [x, y],
                                              ];
                                            });
                                          },
                                          onPanEnd: (_) {
                                            if (_currentStroke != null &&
                                                _currentStroke!.length > 1) {
                                              _activeStrokes = [
                                                ..._activeStrokes,
                                                _currentStroke!,
                                              ];
                                              _currentStroke = null;
                                              _persistStrokes();
                                            } else {
                                              setState(
                                                () => _currentStroke = null,
                                              );
                                            }
                                          },
                                        );
                                      },
                                    )
                                  : LayerEditorOverlay(
                                      key: _layerEditorKey,
                                      spec: _spec,
                                      selectedId: _selectedId,
                                      onSelect: _selectLayer,
                                      onInspect: _openLayerSettings,
                                      onGeometryPreview: _previewGeometry,
                                      onGeometryCommit: _commitGeometry,
                                    ),
                            ),
                            if (_spec.layers.isEmpty &&
                                !_drawMode &&
                                !_processing)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      DriveRadii.xxxl,
                                    ),
                                    color: const Color(0x6610141C),
                                  ),
                                  alignment: Alignment.center,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: DriveColors.primary
                                                .withValues(alpha: 0.18),
                                            border: Border.all(
                                              color: DriveColors.primary
                                                  .withValues(alpha: 0.55),
                                            ),
                                          ),
                                          child: const Icon(
                                            CupertinoIcons.layers_alt_fill,
                                            color: DriveColors.primary,
                                            size: 26,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Compose your widget',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.manrope(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                            color: DriveColors.foreground,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Add photo or widgets, then drag & resize',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.manrope(
                                            fontSize: 12,
                                            color: DriveColors.mutedForeground,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            ElevatedButton.icon(
                                              onPressed: _onCarTab,
                                              icon: const Icon(
                                                CupertinoIcons.photo,
                                                size: 16,
                                              ),
                                              label: const Text('Add photo'),
                                            ),
                                            const SizedBox(width: 12),
                                            OutlinedButton.icon(
                                              onPressed: _onWidgetTab,
                                              icon: const Icon(
                                                CupertinoIcons.plus_app,
                                                size: 16,
                                              ),
                                              label: const Text('Add widget'),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        TextButton(
                                          onPressed: () =>
                                              StudioBrowse.goToCategory(
                                                context,
                                                'Speedometer',
                                              ),
                                          child: Text(
                                            'Start from template',
                                            style: GoogleFonts.manrope(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  DriveColors.mutedForeground,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            if (_processing)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0x99080808),
                                    borderRadius: BorderRadius.circular(
                                      DriveRadii.xxxl,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const CircularProgressIndicator(),
                                      const SizedBox(height: 14),
                                      Text(
                                        _processingLabel,
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (!_drawMode)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                    child: Row(
                      children: [
                        if (_selected != null && _selected!.supportsAnimation)
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  CupertinoIcons.sparkles,
                                  size: 14,
                                  color: _selected!.animate
                                      ? DriveColors.primary
                                      : DriveColors.mutedForeground,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Animate',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.manrope(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Switch.adaptive(
                                  value: _selected!.animate,
                                  onChanged: _toggleAnimateSelected,
                                ),
                              ],
                            ),
                          )
                        else
                          const Spacer(),
                        const SizedBox(width: 8),
                        _WidgetSettingsChip(onTap: _openWidgetSettings),
                      ],
                    ),
                  ),
                if (sizeTarget != null && !_drawMode)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                    child: _SizeChrome(
                      label: sizeLabel,
                      value: sizeValue.toDouble(),
                      onChanged: (v) => _setImageSize(v, commit: false),
                      onChangeEnd: (v) => _setImageSize(v, commit: true),
                      onNudge: _nudgeSize,
                      onDelete: _selected == null ? null : _deleteSelected,
                    ),
                  )
                else if (_drawMode)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      'Draw mode — drag on canvas · tap Draw again to exit',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        height: 1.3,
                        color: DriveColors.mutedForeground,
                      ),
                    ),
                  ),
                EditorDock(
                  drawMode: _drawMode,
                  onImage: () => _handleTab(_EditorTab.car),
                  onText: () => _handleTab(_EditorTab.text),
                  onWidget: () => _handleTab(_EditorTab.widget),
                  onDraw: () => _handleTab(_EditorTab.draw),
                  onBackground: () => _handleTab(_EditorTab.background),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SizeChrome extends StatelessWidget {
  const _SizeChrome({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
    required this.onNudge,
    this.onDelete,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final ValueChanged<double> onNudge;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            DriveColors.carbon.withValues(alpha: 0.95),
            DriveColors.graphite.withValues(alpha: 0.72),
          ],
        ),
        border: Border.all(color: DriveColors.primary.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmMono(
                    fontSize: 10,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w500,
                    color: DriveColors.mutedForeground,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                value.round().toString(),
                style: GoogleFonts.dmMono(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: DriveColors.primaryGlow,
                ),
              ),
              const SizedBox(width: 8),
              _MiniStep(icon: CupertinoIcons.minus, onTap: () => onNudge(-5)),
              const SizedBox(width: 4),
              _MiniStep(icon: CupertinoIcons.plus, onTap: () => onNudge(5)),
              if (onDelete != null) ...[
                const SizedBox(width: 6),
                _MiniStep(
                  icon: CupertinoIcons.trash,
                  danger: true,
                  onTap: onDelete!,
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: DriveColors.primary,
              inactiveTrackColor: DriveColors.border.withValues(alpha: 0.7),
              thumbColor: DriveColors.foreground,
              overlayColor: DriveColors.primary.withValues(alpha: 0.18),
            ),
            child: Slider(
              min: 10,
              max: 250,
              value: value.clamp(10, 250),
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStep extends StatelessWidget {
  const _MiniStep({
    required this.icon,
    required this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? DriveColors.destructive : DriveColors.primary;
    return Material(
      color: accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 30,
          height: 28,
          child: Icon(icon, size: 14, color: accent),
        ),
      ),
    );
  }
}

class _TabTool extends StatelessWidget {
  const _TabTool({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.emphasize = false,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final c = selected
        ? DriveColors.primary
        : emphasize
        ? DriveColors.primaryGlow.withValues(alpha: 0.85)
        : DriveColors.mutedForeground;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: selected
                ? DriveColors.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: DriveColors.primary.withValues(alpha: 0.28),
                      blurRadius: 18,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: c, size: selected || emphasize ? 20 : 18),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    height: 1.1,
                    letterSpacing: selected ? 0.2 : 0,
                    fontWeight: selected || emphasize
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: c,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddCarPill extends StatelessWidget {
  const _AddCarPill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: DriveColors.primary,
            boxShadow: [
              BoxShadow(
                color: DriveColors.primary.withValues(alpha: 0.32),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  CupertinoIcons.car_fill,
                  color: DriveColors.primaryForeground,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Add photo',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.1,
                    color: DriveColors.primaryForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddWidgetPill extends StatelessWidget {
  const _AddWidgetPill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: DriveColors.graphite,
            border: Border.all(color: DriveColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  CupertinoIcons.plus_app,
                  color: DriveColors.primary,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'Add widget',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: DriveColors.foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RemoveWidgetPill extends StatelessWidget {
  const _RemoveWidgetPill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: DriveColors.graphite,
            border: Border.all(
              color: DriveColors.destructive.withValues(alpha: 0.85),
              width: 1.4,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  CupertinoIcons.trash,
                  color: DriveColors.destructive,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Remove widget',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.1,
                      color: DriveColors.destructive,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RemoveBgPill extends StatelessWidget {
  const _RemoveBgPill({
    required this.label,
    required this.onTap,
    required this.filled,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: filled ? DriveColors.primary : DriveColors.graphite,
            border: filled
                ? null
                : Border.all(color: DriveColors.primary, width: 1.4),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: DriveColors.primary.withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  filled ? Icons.auto_fix_high : Icons.content_cut,
                  color: filled
                      ? DriveColors.primaryForeground
                      : DriveColors.primaryGlow,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.1,
                      color: filled
                          ? DriveColors.primaryForeground
                          : DriveColors.primaryGlow,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GhostTool extends StatelessWidget {
  const _GhostTool({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: DriveColors.mutedForeground),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
                color: DriveColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom-right chrome control — Electric Blue on obsidian, not Remove BG.
class _WidgetSettingsChip extends StatelessWidget {
  const _WidgetSettingsChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: DriveColors.obsidian,
            border: Border.all(
              color: DriveColors.primary.withValues(alpha: 0.75),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: DriveColors.primary.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.gear_alt,
                  size: 14,
                  color: DriveColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Settings',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.15,
                    color: DriveColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InspectRow extends StatelessWidget {
  const _InspectRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: DriveColors.mutedForeground,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _WidgetAddTile extends StatelessWidget {
  const _WidgetAddTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: DriveColors.graphite,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: DriveColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: DriveColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  CupertinoIcons.chevron_forward,
                  size: 16,
                  color: DriveColors.mutedForeground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
