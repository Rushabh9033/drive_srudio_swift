import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/media/image_store.dart';
import '../../data/assets/premium_asset_generator.dart';
import '../../core/telemetry/device_telemetry.dart';
import '../../core/theme/drive_colors.dart';
import '../../core/theme/drive_theme.dart';
import '../../data/models/models.dart';
import '../../data/store/app_store.dart';
import 'animated_layer_fx.dart';
import 'brand_monogram.dart';
import 'clock_ticker.dart';
import 'layer_editor_overlay.dart';
import 'stock_layer_painters.dart';

class WidgetCanvas extends StatefulWidget {
  const WidgetCanvas({
    super.key,
    required this.spec,
    this.scale = 1,
    this.child,
    this.tickSeconds = 30,
    this.paintListenable,
    this.previewMode = false,
    this.hideLiveLayers = false,
    this.aspectRatio = 1,
    bool? samplePreview,
  }) : samplePreview = samplePreview ?? previewMode;

  final WidgetSpec spec;
  final double scale;
  final Widget? child;
  /// When true, live-data layers (clock/battery/analog) are NOT rendered.
  /// Used when capturing the static base for the iOS widget so the widget
  /// can overlay its own live values on top.
  final bool hideLiveLayers;

  /// Aspect ratio of the canvas. Defaults to 1 (square) for the on-screen
  /// editor/preview. The hidden static-capture pass overrides this to match
  /// its SizedBox dimensions (Flutter-4) so the captured PNG is not cropped
  /// to a square when the source canvas is non-square.
  final double aspectRatio;

  /// Layer kinds that should be hidden from the rendered PNG (the widget
  /// extension overlays its own live values on top of the static PNG).
  static const _liveLayerKinds = {
    LayerKind.clock,
    LayerKind.date,
    LayerKind.battery,
    LayerKind.analog,
  };

  static bool _isLiveLayer(Layer layer) {
    if (_liveLayerKinds.contains(layer.kind)) return true;
    if (layer.kind == LayerKind.text) {
      return layer.format == 'gpsspeed' ||
          layer.format == 'gps-speed' ||
          layer.format == 'speed';
    }
    return false;
  }

  /// Rebuild interval for live clock/date layers (analog uses 1s).
  final int tickSeconds;

  /// Optional external signal (e.g. live geometry preview) that repaints
  /// layers without rebuilding [child] (the editor overlay).
  final Listenable? paintListenable;

  /// Grid / list thumbnails: frozen time, no timers, no AnimationControllers.
  final bool previewMode;

  /// When true, battery / charging / car-link layers paint stable sample
  /// values for visual fill (Studio stock, Home rails, template thumbs).
  /// Defaults to [previewMode]. Editor, assigned slots, and live device must
  /// pass `false` (or leave [previewMode] false) so only real telemetry binds.
  final bool samplePreview;

  @override
  State<WidgetCanvas> createState() => _WidgetCanvasState();
}

class _WidgetCanvasState extends State<WidgetCanvas> {
  Timer? _timer;
  final ValueNotifier<DateTime> _now = ValueNotifier(DateTime.now());
  Listenable? _mergedPaint;
  Listenable? _mergedExternal;

  bool _specNeedsTick(WidgetSpec spec) => spec.layers.any(
        (l) => !l.hidden && layerNeedsClockTick(l.kind),
      );

  bool _specHasAnalog(WidgetSpec spec) =>
      spec.layers.any((l) => !l.hidden && l.kind == LayerKind.analog);

  bool _specNeedsSecondTick(WidgetSpec spec) => spec.layers.any(
        (l) =>
            !l.hidden &&
            l.kind == LayerKind.clock &&
            l.animate &&
            l.showSeconds,
      );

  int _intervalFor(WidgetSpec spec, int tickSeconds) =>
      (_specHasAnalog(spec) || _specNeedsSecondTick(spec)) ? 1 : tickSeconds;

  bool get _needsTick =>
      !widget.previewMode && _specNeedsTick(widget.spec);

  int get _tickInterval =>
      _intervalFor(widget.spec, widget.tickSeconds);

  @override
  void initState() {
    super.initState();
    _armTimer();
  }

  @override
  void didUpdateWidget(covariant WidgetCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldNeeds =
        !oldWidget.previewMode && _specNeedsTick(oldWidget.spec);
    final oldInterval =
        _intervalFor(oldWidget.spec, oldWidget.tickSeconds);
    if (oldNeeds != _needsTick ||
        oldInterval != _tickInterval ||
        oldWidget.tickSeconds != widget.tickSeconds ||
        oldWidget.previewMode != widget.previewMode) {
      _armTimer();
    }
  }

  void _armTimer() {
    _timer?.cancel();
    _timer = null;
    if (!_needsTick) return;
    // Refresh stamp when (re)arming so a newly placed clock is current.
    _now.value = DateTime.now();
    _timer = Timer.periodic(Duration(seconds: _tickInterval), (_) {
      // CRITICAL: update the notifier only — never setState here.
      // setState rebuilt LayerEditorOverlay / Listener and dropped drag routing.
      if (!mounted) return;
      _now.value = DateTime.now();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _now.dispose();
    super.dispose();
  }

  Listenable get _paintSignal {
    final external = widget.paintListenable;
    if (external == null) return _now;
    if (_mergedPaint == null || _mergedExternal != external) {
      _mergedExternal = external;
      _mergedPaint = Listenable.merge([_now, external]);
    }
    return _mergedPaint!;
  }

  @override
  Widget build(BuildContext context) {
    // ClockTicker remains for any legacy watch() callers, but paint is driven
    // by ListenableBuilder so the editor [child] is a STABLE sibling that never
    return ClockTicker(
      notifier: _now,
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: LayoutBuilder(
          builder: (context, outer) {
            final hasOverlay = widget.child != null;
            final pad = hasOverlay ? kEditorEdgeOutset : 0.0;
            // Budget a square that fits, reserving fringe for off-canvas handles.
            final maxW = outer.maxWidth.isFinite ? outer.maxWidth : 360.0;
            final maxH = outer.maxHeight.isFinite ? outer.maxHeight : 360.0;
            final budget = math.min(maxW, maxH);
            final canvasSide = hasOverlay
                ? math.max(64.0, budget - pad * 2)
                : budget;
            final hostSide = canvasSide + pad * 2;

          Widget paintStack(Size canvas) {
            return DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(DriveRadii.xxxl),
                border: Border.all(color: DriveColors.border),
                boxShadow: DriveShadows.elevated,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(DriveRadii.xxxl),
                clipBehavior: Clip.antiAlias,
                child: ListenableBuilder(
                  listenable: _paintSignal,
                  builder: (context, _) {
                    final stamp = _now.value;
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        IgnorePointer(
                          child: _BackgroundPaint(
                            background: widget.spec.background,
                            previewMode: widget.previewMode,
                          ),
                        ),
                        IgnorePointer(
                          child: Transform.scale(
                            scale: hasOverlay ? widget.scale : 1.0,
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: canvas.width,
                              height: canvas.height,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  for (final layer in widget.spec.layers)
                                    if (!layer.hidden && !(widget.hideLiveLayers && WidgetCanvas._isLiveLayer(layer)))
                                      Positioned(
                                        left: canvas.width * layer.x / 100,
                                        top: canvas.height * layer.y / 100,
                                        width: canvas.width * layer.w / 100,
                                        height: canvas.height * layer.h / 100,
                                        child: LayerNode(
                                          key: ValueKey(layer.id),
                                          layer: layer,
                                          now: layerNeedsClockTick(layer.kind)
                                              ? stamp
                                              : null,
                                          previewMode: widget.previewMode,
                                          samplePreview: widget.samplePreview,
                                        ),
                                      ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          }

          if (!hasOverlay) {
            return paintStack(Size(maxW, maxH));
          }

          // Editor: host is larger than the clipped frame so fringe hits work.
          final canvas = Size(canvasSide, canvasSide);
          return SizedBox(
            width: hostSide,
            height: hostSide,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: pad,
                  top: pad,
                  width: canvasSide,
                  height: canvasSide,
                  child: paintStack(canvas),
                ),
                Positioned.fill(child: widget.child!),
              ],
            ),
          );
        },
      ),
      ),
    );
  }
}

class _BackgroundPaint extends StatelessWidget {
  const _BackgroundPaint({
    required this.background,
    this.previewMode = false,
  });
  final WidgetBackground background;
  final bool previewMode;

  @override
  Widget build(BuildContext context) {
    if (background.type == BgType.image &&
        background.imageSrc != null &&
        background.imageSrc!.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  hexColor(background.from),
                  hexColor(background.to ?? background.from),
                ],
              ),
            ),
          ),
          StoredImage(
            src: background.imageSrc,
            fit: BoxFit.cover,
            filterQuality:
                previewMode ? FilterQuality.low : FilterQuality.medium,
          ),
        ],
      );
    }

    final from = hexColor(background.from);
    final to = hexColor(background.to ?? background.from);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: switch (background.type) {
          BgType.solid => LinearGradient(colors: [from, from]),
          BgType.gradient || BgType.image => LinearGradient(
              begin: const Alignment(-0.6, -1),
              end: const Alignment(0.8, 1),
              colors: [from, to],
            ),
        },
      ),
    );
  }
}

class StoredImage extends StatefulWidget {
  const StoredImage({
    super.key,
    required this.src,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.filterQuality = FilterQuality.medium,
  });

  final String? src;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final FilterQuality filterQuality;

  @override
  State<StoredImage> createState() => _StoredImageState();
}

class _StoredImageState extends State<StoredImage> {
  Uint8List? _bytes;
  String? _loadedSrc;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant StoredImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.src != widget.src) _load();
  }

  Future<void> _load() async {
    final src = widget.src;
    if (src == null || src.isEmpty) {
      if (!mounted) return;
      setState(() {
        _bytes = null;
        _loadedSrc = src;
        _error = null;
      });
      return;
    }
    if (src == _loadedSrc && _bytes != null) return;

    // Premium assets — resolve logical asset names to procedurally generated
    // PNG bytes via PremiumAssetGenerator. These render the same in the editor
    // and get baked into the hybrid widget PNG.
    final premiumBytes = await _resolvePremiumAsset(src);
    if (premiumBytes != null) {
      if (!mounted) return;
      setState(() {
        _bytes = premiumBytes;
        _loadedSrc = src;
        _error = null;
      });
      return;
    }

    try {
      final bytes = await loadImageBytes(src);
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _loadedSrc = src;
        _error = bytes == null ? 'missing' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bytes = null;
        _loadedSrc = src;
        _error = e;
      });
    }
  }

  /// Resolves premium asset logical names (premium-battery-icon,
  /// premium-clock-face, premium-background-*) to PNG bytes via
  /// PremiumAssetGenerator. Returns null for non-premium paths.
  Future<Uint8List?> _resolvePremiumAsset(String src) async {
    if (!src.startsWith('premium-')) return null;
    try {
      if (src == 'premium-battery-icon') {
        return await PremiumAssetGenerator.generateBatteryIcon(
          level: BatteryLevel.half,
          style: BatteryStyle.classic,
        );
      }
      if (src.startsWith('premium-battery-icon:')) {
        // Format: premium-battery-icon:level=full,style=neon
        final params = _parsePremiumParams(src);
        final level = _parseBatteryLevel(params['level']) ?? BatteryLevel.half;
        final style = _parseBatteryStyle(params['style']) ?? BatteryStyle.classic;
        return await PremiumAssetGenerator.generateBatteryIcon(
          level: level,
          style: style,
        );
      }
      if (src == 'premium-clock-face') {
        return await PremiumAssetGenerator.generateClockFace(
          style: ClockFaceStyle.classic,
        );
      }
      if (src.startsWith('premium-clock-face:')) {
        final params = _parsePremiumParams(src);
        final style = _parseClockStyle(params['style']) ?? ClockFaceStyle.classic;
        return await PremiumAssetGenerator.generateClockFace(
          style: style,
        );
      }
      if (src.startsWith('premium-background:')) {
        final params = _parsePremiumParams(src);
        final preset = _parseBackgroundPreset(params['preset']) ?? BackgroundPreset.aurora;
        return await PremiumAssetGenerator.generateBackground(
          preset: preset,
        );
      }
    } catch (_) {}
    return null;
  }

  Map<String, String> _parsePremiumParams(String src) {
    final colonIdx = src.indexOf(':');
    if (colonIdx < 0) return const {};
    return {
      for (final part in src.substring(colonIdx + 1).split(','))
        if (part.contains('='))
          part.split('=').first: part.split('=').last,
    };
  }

  BatteryLevel? _parseBatteryLevel(String? s) {
    switch (s) {
      case 'zero': return BatteryLevel.zero;
      case 'quarter': return BatteryLevel.quarter;
      case 'half': return BatteryLevel.half;
      case 'threeQuarters': return BatteryLevel.threeQuarters;
      case 'full': return BatteryLevel.full;
      default: return null;
    }
  }

  BatteryStyle? _parseBatteryStyle(String? s) {
    switch (s) {
      case 'classic': return BatteryStyle.classic;
      case 'neon': return BatteryStyle.neon;
      case 'minimal': return BatteryStyle.minimal;
      case 'premium': return BatteryStyle.premium;
      case 'energy': return BatteryStyle.energy;
      default: return null;
    }
  }

  ClockFaceStyle? _parseClockStyle(String? s) {
    switch (s) {
      case 'classic': return ClockFaceStyle.classic;
      case 'pixel': return ClockFaceStyle.pixel;
      case 'neon': return ClockFaceStyle.neon;
      case 'sport': return ClockFaceStyle.sport;
      case 'rings': return ClockFaceStyle.rings;
      default: return null;
    }
  }

  BackgroundPreset? _parseBackgroundPreset(String? s) {
    switch (s) {
      case 'aurora': return BackgroundPreset.aurora;
      case 'midnight': return BackgroundPreset.midnight;
      case 'sandstorm': return BackgroundPreset.sandstorm;
      case 'neonGrid': return BackgroundPreset.neonGrid;
      case 'ocean': return BackgroundPreset.ocean;
      default: return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final src = widget.src;
    if (src != null && src.startsWith('assets/')) {
      Widget asset = Image.asset(
        src,
        fit: widget.fit,
        gaplessPlayback: true,
        filterQuality: widget.filterQuality,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
      if (widget.borderRadius != null) {
        asset = ClipRRect(borderRadius: widget.borderRadius!, child: asset);
      }
      return asset;
    }
    if (src != null &&
        (src.startsWith('http://') || src.startsWith('https://'))) {
      // Never use HTML <img> hit targets — overlay must own all drag pointers.
      Widget net = Image.network(
        src,
        fit: widget.fit,
        gaplessPlayback: true,
        filterQuality: widget.filterQuality,
        webHtmlElementStrategy: WebHtmlElementStrategy.never,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const ColoredBox(
            color: DriveColors.graphite,
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => _placeholder(),
      );
      if (widget.borderRadius != null) {
        net = ClipRRect(borderRadius: widget.borderRadius!, child: net);
      }
      return net;
    }

    Widget child;
    if (_bytes != null) {
      child = Image.memory(
        _bytes!,
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    } else if (_error != null || widget.src == null || widget.src!.isEmpty) {
      child = _placeholder();
    } else {
      child = const ColoredBox(
        color: DriveColors.graphite,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (widget.borderRadius != null) {
      return ClipRRect(borderRadius: widget.borderRadius!, child: child);
    }
    return child;
  }

  Widget _placeholder() {
    return Container(
      color: DriveColors.graphite,
      alignment: Alignment.center,
      child: Text('No image', style: driveMonoLabel(size: 9)),
    );
  }
}

/// Digital clock label — never ends with a dangling `:`.
String formatClockLabel(
  DateTime stamp,
  String format, {
  bool showSeconds = false,
}) {
  final raw = switch (format) {
    '12' => showSeconds
        ? DateFormat('h:mm:ss').format(stamp)
        : DateFormat('h:mm').format(stamp),
    '12ap' => showSeconds
        ? DateFormat('h:mm:ss a').format(stamp)
        : DateFormat('h:mm a').format(stamp),
    'hh' || 'hour' => DateFormat('HH').format(stamp),
    'h12' => DateFormat('h').format(stamp),
    'mm' || 'minute' => DateFormat('mm').format(stamp),
    'ss' || 'second' => DateFormat('ss').format(stamp),
    'colon' => ':',
    // Guard against presets that accidentally end with ":".
    final f when f.endsWith(':') => showSeconds
        ? DateFormat('HH:mm:ss').format(stamp)
        : DateFormat('HH:mm').format(stamp),
    _ => showSeconds
        ? DateFormat('HH:mm:ss').format(stamp)
        : DateFormat('HH:mm').format(stamp),
  };
  // Standalone colon separator layer is intentional; otherwise never trail.
  if (format == 'colon') return raw;
  var label = raw.trimRight();
  while (label.endsWith(':')) {
    label = label.substring(0, label.length - 1);
  }
  return label;
}

class LayerNode extends StatelessWidget {
  const LayerNode({
    super.key,
    required this.layer,
    this.now,
    this.previewMode = false,
    this.samplePreview = false,
  });

  final Layer layer;
  final DateTime? now;

  /// Freeze motion (timers / AnimationControllers) for thumbnail grids.
  final bool previewMode;

  /// Sample telemetry fill for catalog / rail thumbs — never live / editor.
  final bool samplePreview;

  @override
  Widget build(BuildContext context) {
    // Snapshot layer: disable animate so battery/analog/FX skip tickers.
    final layer = previewMode && this.layer.animate
        ? this.layer.copyWith(animate: false)
        : this.layer;
    final color = hexColor(layer.color, opacity: layer.opacity);
    final weight = FontWeight.values.firstWhere(
      (w) => w.value == layer.weight,
      orElse: () => FontWeight.w600,
    );
    final stamp = now ?? ClockTicker.peek(context) ?? DateTime.now();
    final imageQuality =
        previewMode ? FilterQuality.low : FilterQuality.medium;

    Widget content;
    switch (layer.kind) {
      case LayerKind.divider:
        content = Align(
          alignment: Alignment.centerLeft,
          child: Container(
            height: (layer.h / 6).clamp(1, 4),
            width: double.infinity,
            color: color,
          ),
        );
      case LayerKind.shape:
        content = Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(layer.radius),
          ),
        );
      case LayerKind.draw:
        content = CustomPaint(
          painter: _StrokePainter(
            strokesJson: layer.strokes,
            color: color,
            strokeWidth: (layer.fontSize / 8).clamp(1.5, 8),
          ),
          child: const SizedBox.expand(),
        );
      case LayerKind.battery:
        content = BatteryLayerView(
          layer: layer,
          now: stamp,
          samplePreview: samplePreview,
        );
      case LayerKind.analog:
        content = AnalogLayerView(layer: layer, now: stamp);
      case LayerKind.image:
        final src = layer.src;
        if (src != null && src.startsWith('monogram:')) {
          final brand = src.substring('monogram:'.length);
          content = LayoutBuilder(
            builder: (context, c) {
              final side = math.min(c.maxWidth, c.maxHeight).clamp(8.0, 512.0);
              return Center(
                child: BrandMonogram(brand: brand, size: side, color: color),
              );
            },
          );
        } else if (src == null || src.isEmpty) {
          // Logo role without a file → sized monogram fallback.
          if (layer.role == 'logo') {
            final brand =
                layer.text.isNotEmpty ? layer.text : layer.label;
            content = LayoutBuilder(
              builder: (context, c) {
                final side =
                    math.min(c.maxWidth, c.maxHeight).clamp(8.0, 512.0);
                return Center(
                  child: BrandMonogram(
                    brand: brand,
                    size: side,
                    color: color,
                  ),
                );
              },
            );
          } else {
            content = Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [DriveColors.graphite, DriveColors.obsidian],
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                'Add image',
                style: driveMonoLabel(size: 9),
                textAlign: TextAlign.center,
              ),
            );
          }
        } else {
          // Logos (assets/logos), stock, gallery — fill layer bounds so resize works.
          content = ClipRRect(
            borderRadius: BorderRadius.circular(layer.radius),
            child: StoredImage(
              src: src,
              fit: layer.fit,
              filterQuality: imageQuality,
            ),
          );
        }
      case LayerKind.badge:
        final badgeLabel = _telemetryBadgeLabel(
              context,
              layer,
              listen: !previewMode && !samplePreview,
              samplePreview: samplePreview,
            ) ??
            layer.text;
        content = Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(layer.radius.clamp(4, 40)),
            border: Border.all(color: color),
          ),
          alignment: Alignment.center,
          child: Text(
            badgeLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmMono(
              fontSize: layer.fontSize * 0.55,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        );
      case LayerKind.text:
      case LayerKind.clock:
      case LayerKind.date:
        final label = switch (layer.kind) {
          LayerKind.clock => _formatClock(
              stamp,
              layer.format,
              showSeconds: layer.showSeconds ||
                  layer.format == 'ss' ||
                  layer.format == 'second',
            ),
          LayerKind.date => _formatDate(stamp, layer.format),
          _ when layer.format == 'gpsspeed' ||
                  layer.format == 'gps-speed' ||
                  layer.format == 'speed' =>
            resolveSpeedDigits(
              samplePreview ? samplePreviewTelemetry : null,
              samplePreview: samplePreview,
            ),
          _ => layer.text,
        };
        final shadowColor = layer.shadowColor != null
            ? hexColor(layer.shadowColor!, opacity: 0.7)
            : const Color(0x88000000);
        final baseStyle = (layer.kind == LayerKind.clock
                ? GoogleFonts.dmMono
                : GoogleFonts.manrope)(
          fontSize: layer.fontSize,
          fontWeight: weight,
          letterSpacing: layer.letterSpacing,
          color: color,
          shadows: layer.shadow
              ? [
                  Shadow(
                    color: shadowColor,
                    blurRadius: 8 + layer.radius,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        );
        if (layer.color2 != null &&
            layer.color2!.isNotEmpty &&
            layer.kind == LayerKind.text) {
          content = ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => LinearGradient(
              colors: [color, hexColor(layer.color2!)],
            ).createShader(bounds),
            child: Text(
              label,
              textAlign: layer.align,
              maxLines: layer.maxLines,
              overflow: TextOverflow.ellipsis,
              style: baseStyle.copyWith(color: Colors.white),
            ),
          );
        } else if (!previewMode &&
            layer.kind == LayerKind.clock &&
            layer.animate &&
            (layer.resolvedAnimStyle == 'blink-colon' ||
                layer.animStyle.isEmpty)) {
          content = ColonBlinkClock(
            timeLabel: label,
            style: baseStyle,
            align: layer.align,
            maxLines: layer.maxLines,
            enabled: true,
            speed: layer.resolvedAnimSpeed,
          );
        } else {
          content = Text(
            label,
            textAlign: layer.align,
            maxLines: layer.maxLines,
            softWrap: layer.kind != LayerKind.clock,
            overflow: layer.kind == LayerKind.clock
                ? TextOverflow.clip
                : TextOverflow.ellipsis,
            style: baseStyle,
          );
        }
    }

    // Kind-specific tickers (battery/analog/colon) own their controllers.
    // Wrapper FX covers pulse / breathe / shimmer / glow / ripple / etc.
    final wrapperStyles = {
      'pulse',
      'shimmer',
      'breathe',
      'rotate-slow',
      'sweep',
      'bounce-soft',
      'glow-breathe',
      'flicker-neon',
      'slide-in-loop',
      'ripple',
    };
    final needsWrapperFx = !previewMode &&
        layer.animate &&
        layer.kind != LayerKind.battery &&
        layer.kind != LayerKind.analog &&
        !(layer.kind == LayerKind.clock &&
            layer.resolvedAnimStyle == 'blink-colon') &&
        wrapperStyles.contains(layer.resolvedAnimStyle);

    if (needsWrapperFx) {
      content = AnimatedLayerFx(layer: layer, child: content);
    }

    final flipped = layer.flipH
        ? Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(-1, 1, 1),
            child: content,
          )
        : content;

    return Opacity(opacity: layer.opacity.clamp(0, 1), child: flipped);
  }

  static String? _telemetryBadgeLabel(
    BuildContext context,
    Layer layer, {
    bool listen = true,
    bool samplePreview = false,
  }) {
    final isStatus = layer.format == 'carlink' ||
        layer.format == 'car-link' ||
        layer.format == 'batterylive' ||
        layer.format == 'battery-live' ||
        layer.format == 'charging' ||
        layer.format == 'network' ||
        layer.format == 'gpsspeed' ||
        layer.format == 'gps-speed' ||
        layer.format == 'speed' ||
        layer.role.startsWith('telemetry:');
    if (!isStatus) return null;
    if (samplePreview) {
      return telemetryStatusLabel(layer, samplePreviewTelemetry);
    }
    try {
      final snap = listen
          ? context.watch<DeviceTelemetry>().snapshot
          : Provider.of<DeviceTelemetry>(context, listen: false).snapshot;
      return telemetryStatusLabel(layer, snap);
    } on ProviderNotFoundException {
      return null;
    }
  }

  static String _formatClock(
    DateTime stamp,
    String format, {
    bool showSeconds = false,
  }) =>
      formatClockLabel(stamp, format, showSeconds: showSeconds);

  static String _formatDate(DateTime stamp, String format) {
    return switch (format) {
      'short' => DateFormat('MMM d').format(stamp),
      'medium' => DateFormat('MMMM d').format(stamp),
      'full' => DateFormat('EEEE, MMMM d').format(stamp),
      'abbrev' => DateFormat('E d MMM').format(stamp),
      'day' || 'daynum' => DateFormat('d').format(stamp),
      'weekday' => DateFormat('EEEE').format(stamp),
      'weekdayShort' => DateFormat('E').format(stamp),
      'month' => DateFormat('MMM').format(stamp),
      'monthFull' => DateFormat('MMMM').format(stamp),
      'year' => DateFormat('y').format(stamp),
      'md' => DateFormat('M/d').format(stamp),
      _ => DateFormat('E, d MMM').format(stamp),
    };
  }
}

class _StrokePainter extends CustomPainter {
  _StrokePainter({
    required this.strokesJson,
    required this.color,
    required this.strokeWidth,
  });

  final String strokesJson;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    List<dynamic> raw;
    try {
      raw = jsonDecode(strokesJson.isEmpty ? '[]' : strokesJson) as List;
    } catch (_) {
      return;
    }
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final stroke in raw) {
      if (stroke is! List || stroke.length < 2) continue;
      final path = ui.Path();
      for (var i = 0; i < stroke.length; i++) {
        final pt = stroke[i];
        if (pt is! List || pt.length < 2) continue;
        final dx = ((pt[0] as num).toDouble() / 100) * size.width;
        final dy = ((pt[1] as num).toDouble() / 100) * size.height;
        if (i == 0) {
          path.moveTo(dx, dy);
        } else {
          path.lineTo(dx, dy);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) =>
      oldDelegate.strokesJson != strokesJson ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}
