import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/telemetry/device_telemetry.dart';
import '../../core/theme/drive_colors.dart';
import '../../data/models/anim_styles.dart';
import '../../data/models/models.dart';

export '../../core/telemetry/telemetry_snapshot.dart'
    show
        resolveLiveBatteryPercent,
        resolveDisplayBatteryPercent,
        samplePreviewTelemetry,
        kSamplePreviewBatteryPercent;

/// Resolves battery % for paint.
///
/// Live path: [DeviceTelemetry] only — `null` = unavailable ("—").
/// Sample path: when [samplePreview], stable catalog fill (never App Group).
int? resolveBatteryPercent(
  Layer layer, [
  DateTime? now,
  TelemetrySnapshot? telemetry,
  bool samplePreview = false,
]) {
  return resolveDisplayBatteryPercent(
    layer,
    telemetry,
    now: now,
    samplePreview: samplePreview,
  );
}

/// Premium battery visuals — Electric Blue / obsidian, original Drive Studio art.
/// Live: real phone % or honest "—". Preview: stable sample fill for catalog tiles.
class BatteryLayerView extends StatefulWidget {
  const BatteryLayerView({
    super.key,
    required this.layer,
    this.now,
    this.samplePreview = false,
  });

  final Layer layer;
  final DateTime? now;

  /// Catalog / grid / rail thumbs only — never editor, slots, or live device.
  final bool samplePreview;

  @override
  State<BatteryLayerView> createState() => _BatteryLayerViewState();
}

class _BatteryLayerViewState extends State<BatteryLayerView>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(covariant BatteryLayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layer.animate != widget.layer.animate ||
        oldWidget.layer.animStyle != widget.layer.animStyle ||
        oldWidget.layer.animSpeed != widget.layer.animSpeed) {
      _arm();
    }
  }

  TelemetrySnapshot? _snapOrNull(BuildContext context, {required bool listen}) {
    try {
      final t = Provider.of<DeviceTelemetry>(context, listen: listen);
      return t.snapshot;
    } on ProviderNotFoundException {
      return null;
    }
  }

  void _arm() {
    if (widget.layer.animate) {
      final ms = (2000 / widget.layer.resolvedAnimSpeed).round();
      _pulse ??= AnimationController(
        vsync: this,
        duration: Duration(milliseconds: ms),
      );
      final style = widget.layer.resolvedAnimStyle;
      final reverse = style != AnimStyles.progressLoop &&
          style != AnimStyles.shimmer &&
          style != AnimStyles.sweep &&
          style != AnimStyles.rotateSlow;
      _pulse!
        ..duration = Duration(milliseconds: ms)
        ..repeat(reverse: reverse);
    } else {
      _pulse?.dispose();
      _pulse = null;
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TelemetrySnapshot? telemetry = widget.samplePreview
        ? samplePreviewTelemetry
        : _snapOrNull(context, listen: true);
    final layer = widget.layer;
    final knownBattery = telemetry != null &&
        telemetry.liveDataEnabled &&
        telemetry.batteryKnown;
    final charging = knownBattery && telemetry.isCharging;
    final resolved = resolveBatteryPercent(
      widget.layer,
      widget.now,
      telemetry,
      widget.samplePreview,
    );
    // dayprogress is clock-derived (real); battery styles need known %.
    final known = resolved != null;
    final pct = resolved ?? 0;
    final accent = _hex(layer.color, opacity: layer.opacity);
    final accent2 = layer.color2 != null && layer.color2!.isNotEmpty
        ? _hex(layer.color2!, opacity: layer.opacity)
        : DriveColors.primaryGlow;
    final ink = layer.color3 != null && layer.color3!.isNotEmpty
        ? _hex(layer.color3!)
        : DriveColors.foreground;
    final track = layer.trackColor != null && layer.trackColor!.isNotEmpty
        ? _hex(layer.trackColor!)
        : DriveColors.graphite.withValues(alpha: 0.9);
    final style = layer.format.isEmpty ? 'panel' : layer.format;
    final ctrl = _pulse;
    final styleName = layer.resolvedAnimStyle;

    Widget paintFor(double motion, int percent, {required bool dataKnown}) =>
        CustomPaint(
          painter: _BatteryPainter(
            style: style,
            percent: percent,
            known: dataKnown,
            accent: accent,
            accent2: accent2,
            muted: DriveColors.mutedForeground.withValues(alpha: 0.55),
            track: track,
            ink: ink,
            motion: motion,
            isCharging: charging,
          ),
          child: const SizedBox.expand(),
        );

    if (ctrl == null) return paintFor(0, pct, dataKnown: known);

    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        final t = ctrl.value;
        final paint = paintFor(t, pct, dataKnown: known);
        // Decorative motion only — never invent a charge % fill.
        if (!known) return paint;
        if (styleName == AnimStyles.pulse || styleName == AnimStyles.breathe) {
          return Opacity(opacity: 0.82 + 0.18 * t, child: paint);
        }
        if (styleName == AnimStyles.glowBreathe) {
          return Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.2 + 0.35 * t),
                  blurRadius: 12 + 10 * t,
                ),
              ],
            ),
            child: paint,
          );
        }
        if (styleName == AnimStyles.progressLoop) return paint;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final slide = t;
            return LinearGradient(
              begin: Alignment(-1.4 + slide * 2.4, -0.3),
              end: Alignment(-0.4 + slide * 2.4, 0.5),
              colors: [
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: 0.28),
                Colors.white.withValues(alpha: 0),
              ],
            ).createShader(bounds);
          },
          child: paint,
        );
      },
    );
  }
}

/// Live analog faces — hands driven by [now], optional smooth second-hand ticker.
class AnalogLayerView extends StatefulWidget {
  const AnalogLayerView({
    super.key,
    required this.layer,
    this.now,
  });

  final Layer layer;
  final DateTime? now;

  @override
  State<AnalogLayerView> createState() => _AnalogLayerViewState();
}

class _AnalogLayerViewState extends State<AnalogLayerView>
    with SingleTickerProviderStateMixin {
  AnimationController? _smooth;

  bool get _wantsSmooth =>
      widget.layer.animate &&
      (widget.layer.resolvedAnimStyle == AnimStyles.handSmooth ||
          widget.layer.resolvedAnimStyle == AnimStyles.rotateSlow ||
          (widget.layer.showSeconds && widget.layer.format != 'minimal'));

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(covariant AnalogLayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layer.animate != widget.layer.animate ||
        oldWidget.layer.showSeconds != widget.layer.showSeconds ||
        oldWidget.layer.animStyle != widget.layer.animStyle ||
        oldWidget.layer.animSpeed != widget.layer.animSpeed ||
        oldWidget.layer.format != widget.layer.format) {
      _arm();
    }
  }

  void _arm() {
    if (_wantsSmooth) {
      final ms = (1000 / widget.layer.resolvedAnimSpeed).round();
      _smooth ??= AnimationController(
        vsync: this,
        duration: Duration(milliseconds: ms),
      );
      _smooth!
        ..duration = Duration(milliseconds: ms)
        ..repeat();
    } else {
      _smooth?.dispose();
      _smooth = null;
    }
  }

  @override
  void dispose() {
    _smooth?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layer = widget.layer;
    final accent = _hex(layer.color, opacity: layer.opacity);
    final hands = layer.color2 != null && layer.color2!.isNotEmpty
        ? _hex(layer.color2!)
        : DriveColors.foreground;
    final ticks = layer.color3 != null && layer.color3!.isNotEmpty
        ? _hex(layer.color3!)
        : DriveColors.mutedForeground;
    final faceColor = layer.trackColor != null && layer.trackColor!.isNotEmpty
        ? _hex(layer.trackColor!)
        : DriveColors.carbon;
    final style = layer.format.isEmpty ? 'classic' : layer.format;
    final showSeconds = layer.showSeconds && style != 'minimal';
    final ctrl = _smooth;

    Widget face(DateTime stamp) => CustomPaint(
          painter: _AnalogPainter(
            style: style,
            now: stamp,
            accent: accent,
            face: faceColor,
            ink: hands,
            muted: ticks,
            showSeconds: showSeconds,
            ringSpin: layer.animate &&
                    layer.resolvedAnimStyle == AnimStyles.rotateSlow
                ? (ctrl?.value ?? 0)
                : 0,
          ),
          child: const SizedBox.expand(),
        );

    if (ctrl == null) {
      return face(widget.now ?? DateTime.now());
    }

    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) => face(DateTime.now()),
    );
  }
}

Color _hex(String hex, {double opacity = 1}) {
  var h = hex.replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16) ?? 0xFF4D9EFF;
  return Color(v).withValues(alpha: opacity.clamp(0, 1));
}

class _BatteryPainter extends CustomPainter {
  _BatteryPainter({
    required this.style,
    required this.percent,
    required this.known,
    required this.accent,
    required this.accent2,
    required this.muted,
    required this.track,
    required this.ink,
    this.motion = 0,
    this.isCharging = false,
  });

  final String style;
  final int percent;
  final bool known;
  final Color accent;
  final Color accent2;
  final Color muted;
  final Color track;
  final Color ink;
  final double motion;
  final bool isCharging;

  /// Fill level — 0 when unavailable (never invent a charge).
  int get _fill => known ? percent.clamp(0, 100) : 0;

  String get _num => known ? '$percent' : '—';
  String get _numPct => known ? '$percent%' : '—';

  @override
  void paint(Canvas canvas, Size size) {
    switch (style) {
      case 'metrics':
        _paintMetrics(canvas, size);
      case 'icon':
        _paintIcon(canvas, size);
      case 'dots':
        _paintDots(canvas, size);
      case 'matrix':
        _paintMatrix(canvas, size);
      case 'lightning':
        _paintLightning(canvas, size);
      case 'pill':
        _paintPill(canvas, size);
      case 'pie':
        _paintPie(canvas, size);
      case 'large':
        _paintLarge(canvas, size);
      case 'ring':
      case 'dayprogress':
        _paintRing(canvas, size);
      case 'bars':
        _paintBars(canvas, size);
      case 'hud':
        _paintHud(canvas, size);
      case 'minimal':
        _paintMinimalBatt(canvas, size);
      case 'dual':
        _paintDual(canvas, size);
      case 'segmented':
        _paintSegmented(canvas, size);
      case 'wave':
        _paintWave(canvas, size);
      case 'vertbar':
        _paintVertBar(canvas, size);
      case 'orbit':
        _paintOrbit(canvas, size);
      case 'panel':
      default:
        _paintPanel(canvas, size);
    }
  }

  void _paintPanel(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(18),
    );
    canvas.drawRRect(
      r,
      Paint()..color = DriveColors.obsidian.withValues(alpha: 0.35),
    );

    final label = TextPainter(
      text: TextSpan(
        text: !known
            ? 'UNAVAILABLE'
            : (isCharging ? 'CHARGING' : 'BATTERY'),
        style: GoogleFonts.dmMono(
          fontSize: size.width * 0.07,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.2,
          color: accent.withValues(alpha: 0.85),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(size.width * 0.1, size.height * 0.1));
    if (isCharging) {
      _paintChargeBolt(
        canvas,
        Offset(size.width * 0.78, size.height * 0.12),
        size.width * 0.12,
      );
    }

    final pctPainter = TextPainter(
      text: TextSpan(
        text: _num,
        style: GoogleFonts.manrope(
          fontSize: size.width * 0.28,
          fontWeight: FontWeight.w800,
          color: ink,
          height: 1,
        ),
        children: known
            ? [
                TextSpan(
                  text: '%',
                  style: GoogleFonts.manrope(
                    fontSize: size.width * 0.12,
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
              ]
            : null,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    pctPainter.paint(
      canvas,
      Offset(size.width * 0.1, size.height * 0.28),
    );

    final barTop = size.height * 0.72;
    final barH = size.height * 0.1;
    final barW = size.width * 0.8;
    final barLeft = size.width * 0.1;
    final trackR = RRect.fromRectAndRadius(
      Rect.fromLTWH(barLeft, barTop, barW, barH),
      Radius.circular(barH),
    );
    canvas.drawRRect(trackR, Paint()..color = track);
    final fillW = barW * (_fill / 100);
    if (fillW > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(barLeft, barTop, fillW, barH),
          Radius.circular(barH),
        ),
        Paint()
          ..shader = LinearGradient(
            colors: [accent, accent2],
          ).createShader(Rect.fromLTWH(barLeft, barTop, fillW, barH)),
      );
    }
  }

  void _paintMetrics(Canvas canvas, Size size) {
    final title = TextPainter(
      text: TextSpan(
        text: !known
            ? 'UNAVAILABLE'
            : (isCharging ? 'CHARGING' : 'ON BATTERY'),
        style: GoogleFonts.dmMono(
          fontSize: size.width * 0.065,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.8,
          color: isCharging ? accent : muted,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    title.paint(canvas, Offset(size.width * 0.08, size.height * 0.08));

    final big = TextPainter(
      text: TextSpan(
        text: _numPct,
        style: GoogleFonts.manrope(
          fontSize: size.width * 0.22,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    big.paint(canvas, Offset(size.width * 0.08, size.height * 0.22));

    // Honest secondary rows — no fabricated car-pack telemetry.
    _metricRow(
      canvas,
      size,
      y: size.height * 0.55,
      label: 'SOURCE',
      value: known ? 'PHONE' : '—',
    );
    _metricRow(
      canvas,
      size,
      y: size.height * 0.72,
      label: 'STATUS',
      value: known ? (isCharging ? 'CHARGING' : 'READY') : 'UNAVAILABLE',
    );

    final accentBar = Rect.fromLTWH(
      size.width * 0.08,
      size.height * 0.9,
      size.width * 0.35,
      3,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(accentBar, const Radius.circular(2)),
      Paint()..color = accent,
    );
  }

  void _metricRow(
    Canvas canvas,
    Size size, {
    required double y,
    required String label,
    required String value,
  }) {
    final l = TextPainter(
      text: TextSpan(
        text: label,
        style: GoogleFonts.dmMono(
          fontSize: size.width * 0.055,
          letterSpacing: 1.4,
          color: muted,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    l.paint(canvas, Offset(size.width * 0.08, y));

    final v = TextPainter(
      text: TextSpan(
        text: value,
        style: GoogleFonts.manrope(
          fontSize: size.width * 0.07,
          fontWeight: FontWeight.w700,
          color: accent,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    v.paint(canvas, Offset(size.width * 0.55, y - 2));
  }

  void _paintIcon(Canvas canvas, Size size) {
    final cx = size.width * 0.5;
    final cy = size.height * 0.42;
    final bw = size.width * 0.42;
    final bh = size.height * 0.28;
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: bw, height: bh),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..color = accent,
    );
    // Cap
    final cap = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx + bw / 2 + size.width * 0.035, cy),
        width: size.width * 0.045,
        height: bh * 0.42,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(cap, Paint()..color = accent);

    final inset = 5.0;
    final inner = Rect.fromCenter(
      center: Offset(cx, cy),
      width: bw - inset * 2,
      height: bh - inset * 2,
    );
    final fillW = inner.width * (_fill / 100);
    canvas.drawRRect(
      RRect.fromRectAndRadius(inner, const Radius.circular(6)),
      Paint()..color = track,
    );
    if (fillW > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(inner.left, inner.top, fillW, inner.height),
          const Radius.circular(6),
        ),
        Paint()..color = accent,
      );
    }

    final pct = TextPainter(
      text: TextSpan(
        text: _numPct,
        style: GoogleFonts.manrope(
          fontSize: size.width * 0.14,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    pct.paint(
      canvas,
      Offset((size.width - pct.width) / 2, size.height * 0.72),
    );
  }

  void _paintDots(Canvas canvas, Size size) {
    final cols = 5;
    final rows = 2;
    final filled = ((_fill / 100) * cols * rows).round().clamp(0, cols * rows);
    final gap = size.width * 0.04;
    final dotW = (size.width * 0.7 - gap * (cols - 1)) / cols;
    final startX = size.width * 0.15;
    final startY = size.height * 0.38;

    final title = TextPainter(
      text: TextSpan(
        text: 'CHARGE',
        style: GoogleFonts.dmMono(
          fontSize: size.width * 0.065,
          letterSpacing: 2,
          fontWeight: FontWeight.w700,
          color: muted,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    title.paint(canvas, Offset(size.width * 0.15, size.height * 0.14));

    var i = 0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final on = i < filled;
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            startX + c * (dotW + gap),
            startY + r * (dotW * 0.7 + gap),
            dotW,
            dotW * 0.55,
          ),
          Radius.circular(dotW * 0.2),
        );
        canvas.drawRRect(
          rect,
          Paint()..color = on ? accent : track,
        );
        i++;
      }
    }

    final pct = TextPainter(
      text: TextSpan(
        text: _numPct,
        style: GoogleFonts.manrope(
          fontSize: size.width * 0.12,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    pct.paint(
      canvas,
      Offset((size.width - pct.width) / 2, size.height * 0.78),
    );
  }

  void _paintMatrix(Canvas canvas, Size size) {
    const n = 4;
    final gap = size.width * 0.03;
    final cell = (size.width * 0.7 - gap * (n - 1)) / n;
    final origin = Offset(size.width * 0.15, size.height * 0.22);
    final lit = ((_fill / 100) * n * n).round();

    var i = 0;
    for (var r = n - 1; r >= 0; r--) {
      for (var c = 0; c < n; c++) {
        final on = i < lit;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              origin.dx + c * (cell + gap),
              origin.dy + (n - 1 - r) * (cell + gap),
              cell,
              cell,
            ),
            Radius.circular(cell * 0.18),
          ),
          Paint()
            ..color = on
                ? accent.withValues(alpha: 0.55 + 0.45 * ((i % 4) / 4))
                : track,
        );
        i++;
      }
    }

    final pct = TextPainter(
      text: TextSpan(
        text: _num,
        style: GoogleFonts.dmMono(
          fontSize: size.width * 0.11,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    pct.paint(
      canvas,
      Offset((size.width - pct.width) / 2, size.height * 0.86),
    );
  }

  void _paintLightning(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.55, size.height * 0.12)
      ..lineTo(size.width * 0.32, size.height * 0.52)
      ..lineTo(size.width * 0.48, size.height * 0.52)
      ..lineTo(size.width * 0.38, size.height * 0.88)
      ..lineTo(size.width * 0.72, size.height * 0.42)
      ..lineTo(size.width * 0.52, size.height * 0.42)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [DriveColors.primaryGlow, accent],
        ).createShader(Offset.zero & size),
    );

    final pct = TextPainter(
      text: TextSpan(
        text: _numPct,
        style: GoogleFonts.manrope(
          fontSize: size.width * 0.13,
          fontWeight: FontWeight.w800,
          color: ink,
          shadows: const [Shadow(blurRadius: 12, color: Colors.black54)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    pct.paint(
      canvas,
      Offset((size.width - pct.width) / 2, size.height * 0.78),
    );
  }

  void _paintPill(Canvas canvas, Size size) {
    final pillH = size.height * 0.28;
    final pill = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.42),
        width: size.width * 0.78,
        height: pillH,
      ),
      Radius.circular(pillH),
    );
    canvas.drawRRect(pill, Paint()..color = track);
    final fill = size.width * 0.78 * (_fill / 100);
    canvas.save();
    canvas.clipRRect(pill);
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.11,
        size.height * 0.42 - pillH / 2,
        fill,
        pillH,
      ),
      Paint()
        ..shader = LinearGradient(
          colors: [accent.withValues(alpha: 0.75), accent],
        ).createShader(
          Rect.fromLTWH(size.width * 0.11, 0, size.width * 0.78, pillH),
        ),
    );
    canvas.restore();

    final pct = TextPainter(
      text: TextSpan(
        text: _numPct,
        style: GoogleFonts.manrope(
          fontSize: size.width * 0.12,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    pct.paint(
      canvas,
      Offset((size.width - pct.width) / 2, size.height * 0.68),
    );
  }

  void _paintPie(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.42);
    final radius = size.width * 0.28;
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..color = track
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, radius, bg);
    final sweep = (_fill / 100) * math.pi * 2;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.08
        ..color = accent
        ..strokeCap = StrokeCap.round,
    );

    final pct = TextPainter(
      text: TextSpan(
        text: _num,
        style: GoogleFonts.manrope(
          fontSize: size.width * 0.16,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    pct.paint(canvas, Offset(c.dx - pct.width / 2, c.dy - pct.height / 2));

    final sub = TextPainter(
      text: TextSpan(
        text: 'PERCENT',
        style: GoogleFonts.dmMono(
          fontSize: size.width * 0.055,
          letterSpacing: 1.5,
          color: muted,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    sub.paint(
      canvas,
      Offset((size.width - sub.width) / 2, size.height * 0.78),
    );
  }

  void _paintLarge(Canvas canvas, Size size) {
    final pct = TextPainter(
      text: TextSpan(
        text: _num,
        style: GoogleFonts.manrope(
          fontSize: size.width * 0.42,
          fontWeight: FontWeight.w800,
          color: ink,
          height: 0.9,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    pct.paint(
      canvas,
      Offset((size.width - pct.width) / 2, size.height * 0.12),
    );

    final unit = TextPainter(
      text: TextSpan(
        text: '% CHARGE',
        style: GoogleFonts.dmMono(
          fontSize: size.width * 0.07,
          letterSpacing: 2,
          fontWeight: FontWeight.w700,
          color: accent,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    unit.paint(
      canvas,
      Offset((size.width - unit.width) / 2, size.height * 0.62),
    );

    final bar = Rect.fromLTWH(
      size.width * 0.15,
      size.height * 0.78,
      size.width * 0.7,
      size.height * 0.07,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bar, Radius.circular(bar.height)),
      Paint()..color = track,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bar.left, bar.top, bar.width * _fill / 100, bar.height),
        Radius.circular(bar.height),
      ),
      Paint()..color = accent,
    );
  }

  void _paintRing(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.46);
    final radius = size.width * 0.32;
    final stroke = size.width * 0.07;
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: radius),
      -math.pi / 2,
      (_fill / 100) * math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: math.pi * 1.5,
          colors: [accent, accent2, accent],
        ).createShader(Rect.fromCircle(center: c, radius: radius))
        ..strokeCap = StrokeCap.round,
    );
    final pct = TextPainter(
      text: TextSpan(
        text: _num,
        style: GoogleFonts.manrope(
          fontSize: size.width * 0.2,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    pct.paint(canvas, Offset(c.dx - pct.width / 2, c.dy - pct.height / 2));
    final sub = TextPainter(
      text: TextSpan(
        text: style == 'dayprogress' ? 'DAY %' : (known ? 'PHONE' : '—'),
        style: GoogleFonts.dmMono(
          fontSize: size.width * 0.055,
          letterSpacing: 1.6,
          color: muted,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    sub.paint(
      canvas,
      Offset((size.width - sub.width) / 2, size.height * 0.84),
    );
  }

  void _paintBars(Canvas canvas, Size size) {
    const n = 8;
    final gap = size.width * 0.02;
    final barW = (size.width * 0.72 - gap * (n - 1)) / n;
    final baseY = size.height * 0.78;
    final maxH = size.height * 0.55;
    final lit = ((_fill / 100) * n).ceil().clamp(0, n);
    final originX = size.width * 0.14;

    final title = TextPainter(
      text: TextSpan(
        text: 'PHONE LEVEL',
        style: GoogleFonts.dmMono(
          fontSize: size.width * 0.06,
          letterSpacing: 1.8,
          fontWeight: FontWeight.w700,
          color: muted,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    title.paint(canvas, Offset(originX, size.height * 0.1));

    for (var i = 0; i < n; i++) {
      final h = maxH * (0.35 + 0.65 * ((i + 1) / n));
      final on = i < lit;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(originX + i * (barW + gap), baseY - h, barW, h),
        Radius.circular(barW * 0.35),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color = on
              ? accent.withValues(alpha: 0.45 + 0.55 * (i / n))
              : track,
      );
    }
  }

  void _paintHud(Canvas canvas, Size size) {
    final inset = size.width * 0.08;
    final frame = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = accent.withValues(alpha: 0.55),
    );
    // Corner ticks
    for (final corner in [
      Offset(inset + 4, inset + 4),
      Offset(size.width - inset - 4, inset + 4),
      Offset(inset + 4, size.height - inset - 4),
      Offset(size.width - inset - 4, size.height - inset - 4),
    ]) {
      canvas.drawCircle(corner, 2.2, Paint()..color = accent);
    }

    final label = TextPainter(
      text: TextSpan(
        text: 'BATT HUD',
        style: GoogleFonts.dmMono(
          fontSize: size.width * 0.06,
          letterSpacing: 2,
          color: accent,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(size.width * 0.14, size.height * 0.16));

    final pct = TextPainter(
      text: TextSpan(
        text: _numPct,
        style: GoogleFonts.manrope(
          fontSize: size.width * 0.26,
          fontWeight: FontWeight.w800,
          color: ink,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    pct.paint(canvas, Offset(size.width * 0.14, size.height * 0.34));

    final range = TextPainter(
      text: TextSpan(
        text: known
            ? (isCharging ? 'CHARGING · PHONE' : 'PHONE BATTERY')
            : 'CONNECT IPHONE',
        style: GoogleFonts.dmMono(
          fontSize: size.width * 0.055,
          letterSpacing: 1.2,
          color: muted,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    range.paint(canvas, Offset(size.width * 0.14, size.height * 0.72));

    final rail = Rect.fromLTWH(
      size.width * 0.14,
      size.height * 0.82,
      size.width * 0.72,
      3,
    );
    canvas.drawRect(rail, Paint()..color = track);
    canvas.drawRect(
      Rect.fromLTWH(rail.left, rail.top, rail.width * _fill / 100, rail.height),
      Paint()..color = accent,
    );
  }

  void _paintMinimalBatt(Canvas canvas, Size size) {
    final pct = TextPainter(
      text: TextSpan(
        text: _num,
        style: GoogleFonts.manrope(
          fontSize: size.width * 0.38,
          fontWeight: FontWeight.w700,
          color: ink,
          height: 0.95,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    pct.paint(
      canvas,
      Offset((size.width - pct.width) / 2, size.height * 0.22),
    );
    final unit = TextPainter(
      text: TextSpan(
        text: '%',
        style: GoogleFonts.dmMono(
          fontSize: size.width * 0.1,
          color: accent,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    unit.paint(
      canvas,
      Offset((size.width - unit.width) / 2, size.height * 0.62),
    );
    canvas.drawLine(
      Offset(size.width * 0.35, size.height * 0.78),
      Offset(size.width * 0.65, size.height * 0.78),
      Paint()
        ..color = accent
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintDual(Canvas canvas, Size size) {
    final usable = known ? (percent * 0.92).round().clamp(0, 100) : 0;
    _dualBlock(
      canvas,
      size,
      x: size.width * 0.08,
      label: 'SOC',
      value: known ? percent : 0,
    );
    _dualBlock(
      canvas,
      size,
      x: size.width * 0.52,
      label: 'USE',
      value: usable,
    );
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.22),
      Offset(size.width * 0.5, size.height * 0.78),
      Paint()
        ..color = track
        ..strokeWidth = 1.5,
    );
  }

  void _dualBlock(
    Canvas canvas,
    Size size, {
    required double x,
    required String label,
    required int value,
  }) {
    final l = TextPainter(
      text: TextSpan(
        text: label,
        style: GoogleFonts.dmMono(
          fontSize: size.width * 0.055,
          letterSpacing: 1.5,
          color: muted,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    l.paint(canvas, Offset(x, size.height * 0.18));

    final v = TextPainter(
      text: TextSpan(
        text: known ? '$value%' : '—',
        style: GoogleFonts.manrope(
          fontSize: size.width * 0.16,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    v.paint(canvas, Offset(x, size.height * 0.36));

    final bar = Rect.fromLTWH(x, size.height * 0.7, size.width * 0.36, 6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bar, const Radius.circular(3)),
      Paint()..color = track,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bar.left, bar.top, bar.width * value / 100, bar.height),
        const Radius.circular(3),
      ),
      Paint()..color = accent,
    );
  }

  void _paintSegmented(Canvas canvas, Size size) {
    const segs = 10;
    final gap = size.width * 0.015;
    final segW = (size.width * 0.8 - gap * (segs - 1)) / segs;
    final y = size.height * 0.48;
    final h = size.height * 0.16;
    final lit = ((_fill / 100) * segs).round().clamp(0, segs);
    final x0 = size.width * 0.1;

    final title = TextPainter(
      text: TextSpan(
        text: 'CELLS',
        style: GoogleFonts.dmMono(
          fontSize: size.width * 0.065,
          letterSpacing: 2,
          color: muted,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    title.paint(canvas, Offset(x0, size.height * 0.18));

    for (var i = 0; i < segs; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x0 + i * (segW + gap), y, segW, h),
          Radius.circular(segW * 0.25),
        ),
        Paint()
          ..color = i < lit
              ? (i >= segs - 2
                  ? DriveColors.primaryGlow
                  : accent.withValues(alpha: 0.55 + 0.45 * (i / segs)))
              : track,
      );
    }

    final pct = TextPainter(
      text: TextSpan(
        text: _numPct,
        style: GoogleFonts.manrope(
          fontSize: size.width * 0.12,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    pct.paint(canvas, Offset(x0, size.height * 0.74));
  }

  void _paintWave(Canvas canvas, Size size) {
    final path = Path()..moveTo(0, size.height);
    final mid = size.height * (1 - _fill / 100 * 0.55 - 0.2);
    for (var x = 0.0; x <= size.width; x += 2) {
      final wave = math.sin(x / size.width * math.pi * 3) * size.height * 0.04;
      path.lineTo(x, mid + wave);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: 0.85),
            accent.withValues(alpha: 0.25),
          ],
        ).createShader(Offset.zero & size),
    );

    final pct = TextPainter(
      text: TextSpan(
        text: _numPct,
        style: GoogleFonts.manrope(
          fontSize: size.width * 0.18,
          fontWeight: FontWeight.w800,
          color: ink,
          shadows: const [Shadow(blurRadius: 8, color: Colors.black54)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    pct.paint(
      canvas,
      Offset((size.width - pct.width) / 2, size.height * 0.18),
    );
  }

  void _paintVertBar(Canvas canvas, Size size) {
    final trackR = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.38,
        size.height * 0.12,
        size.width * 0.24,
        size.height * 0.62,
      ),
      const Radius.circular(14),
    );
    canvas.drawRRect(trackR, Paint()..color = track);
    final fillH = size.height * 0.62 * _fill / 100;
    canvas.save();
    canvas.clipRRect(trackR);
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.38,
        size.height * 0.12 + size.height * 0.62 - fillH,
        size.width * 0.24,
        fillH,
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [accent, DriveColors.primaryGlow],
        ).createShader(trackR.outerRect),
    );
    canvas.restore();

    final pct = TextPainter(
      text: TextSpan(
        text: _numPct,
        style: GoogleFonts.manrope(
          fontSize: size.width * 0.12,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    pct.paint(
      canvas,
      Offset((size.width - pct.width) / 2, size.height * 0.8),
    );
  }

  void _paintOrbit(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.48);
    for (final f in [0.9, 0.68, 0.46]) {
      canvas.drawCircle(
        c,
        size.width * 0.36 * f,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = accent.withValues(alpha: 0.2 + 0.25 * f),
      );
    }
    final a = -math.pi / 2 + (_fill / 100) * math.pi * 2;
    final r = size.width * 0.36 * 0.68;
    canvas.drawCircle(
      Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r),
      5,
      Paint()..color = accent,
    );
    final pct = TextPainter(
      text: TextSpan(
        text: _num,
        style: GoogleFonts.manrope(
          fontSize: size.width * 0.18,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    pct.paint(canvas, Offset(c.dx - pct.width / 2, c.dy - pct.height / 2));
  }

  void _paintChargeBolt(Canvas canvas, Offset origin, double size) {
    final path = Path()
      ..moveTo(origin.dx + size * 0.55, origin.dy)
      ..lineTo(origin.dx + size * 0.15, origin.dy + size * 0.55)
      ..lineTo(origin.dx + size * 0.42, origin.dy + size * 0.55)
      ..lineTo(origin.dx + size * 0.28, origin.dy + size)
      ..lineTo(origin.dx + size * 0.85, origin.dy + size * 0.4)
      ..lineTo(origin.dx + size * 0.52, origin.dy + size * 0.4)
      ..close();
    canvas.drawPath(path, Paint()..color = accent2);
  }

  @override
  bool shouldRepaint(covariant _BatteryPainter oldDelegate) =>
      oldDelegate.style != style ||
      oldDelegate.percent != percent ||
      oldDelegate.known != known ||
      oldDelegate.accent != accent ||
      oldDelegate.accent2 != accent2 ||
      oldDelegate.track != track ||
      oldDelegate.ink != ink ||
      oldDelegate.motion != motion ||
      oldDelegate.isCharging != isCharging;
}

class _AnalogPainter extends CustomPainter {
  _AnalogPainter({
    required this.style,
    required this.now,
    required this.accent,
    required this.face,
    required this.ink,
    required this.muted,
    this.showSeconds = true,
    this.ringSpin = 0,
  });

  final String style;
  final DateTime now;
  final Color accent;
  final Color face;
  final Color ink;
  final Color muted;
  final bool showSeconds;
  final double ringSpin;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 * 0.92;

    switch (style) {
      case 'minimal':
        _faceMinimal(canvas, c, r);
      case 'neon':
        _faceNeon(canvas, c, r);
      case 'rings':
        _faceRings(canvas, c, r);
      case 'sport':
        _faceSport(canvas, c, r);
      case 'arc':
        _faceArc(canvas, c, r);
      case 'thin':
        _faceThin(canvas, c, r);
      case 'luxury':
        _faceLuxury(canvas, c, r);
      case 'ticks':
        _faceTicks(canvas, c, r);
      case 'dual':
        _faceDual(canvas, c, r);
      case 'field':
        _faceField(canvas, c, r);
      case 'classic':
      default:
        _faceClassic(canvas, c, r);
    }

    _drawHands(canvas, c, r, style);
  }

  void _faceClassic(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r, Paint()..color = face);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = accent.withValues(alpha: 0.55),
    );
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6 - math.pi / 2;
      final outer = Offset(c.dx + math.cos(a) * r * 0.88, c.dy + math.sin(a) * r * 0.88);
      final inner = Offset(c.dx + math.cos(a) * r * 0.72, c.dy + math.sin(a) * r * 0.72);
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..color = i % 3 == 0 ? ink : muted
          ..strokeWidth = i % 3 == 0 ? 2.4 : 1.2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _faceMinimal(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r, Paint()..color = DriveColors.obsidian);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = muted.withValues(alpha: 0.4),
    );
    for (final i in [0, 3, 6, 9]) {
      final a = i * math.pi / 6 - math.pi / 2;
      canvas.drawCircle(
        Offset(c.dx + math.cos(a) * r * 0.78, c.dy + math.sin(a) * r * 0.78),
        2.2,
        Paint()..color = accent,
      );
    }
  }

  void _faceNeon(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF0A1020));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = accent
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(
      c,
      r * 0.96,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = DriveColors.primaryGlow,
    );
    for (var i = 0; i < 60; i += 5) {
      final a = i * math.pi / 30 - math.pi / 2;
      canvas.drawLine(
        Offset(c.dx + math.cos(a) * r * 0.82, c.dy + math.sin(a) * r * 0.82),
        Offset(c.dx + math.cos(a) * r * 0.9, c.dy + math.sin(a) * r * 0.9),
        Paint()
          ..color = accent.withValues(alpha: 0.7)
          ..strokeWidth = 1.4,
      );
    }
  }

  void _faceRings(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r, Paint()..color = face);
    if (ringSpin != 0) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(ringSpin * math.pi * 2);
      canvas.translate(-c.dx, -c.dy);
    }
    for (final f in [1.0, 0.78, 0.56]) {
      canvas.drawCircle(
        c,
        r * f,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = accent.withValues(alpha: 0.25 + 0.2 * f),
      );
    }
    if (ringSpin != 0) canvas.restore();
  }

  void _faceSport(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF12141C));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = accent,
    );
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6 - math.pi / 2;
      canvas.drawLine(
        Offset(c.dx + math.cos(a) * r * 0.7, c.dy + math.sin(a) * r * 0.7),
        Offset(c.dx + math.cos(a) * r * 0.88, c.dy + math.sin(a) * r * 0.88),
        Paint()
          ..color = ink
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _faceArc(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r, Paint()..color = face);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.92),
      math.pi * 0.85,
      math.pi * 1.3,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = accent
        ..strokeCap = StrokeCap.round,
    );
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6 - math.pi / 2;
      canvas.drawCircle(
        Offset(c.dx + math.cos(a) * r * 0.75, c.dy + math.sin(a) * r * 0.75),
        i % 3 == 0 ? 2.5 : 1.4,
        Paint()..color = i % 3 == 0 ? ink : muted,
      );
    }
  }

  void _faceThin(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r, Paint()..color = DriveColors.obsidian);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = muted.withValues(alpha: 0.35),
    );
    for (var i = 0; i < 60; i++) {
      if (i % 5 != 0) continue;
      final a = i * math.pi / 30 - math.pi / 2;
      canvas.drawLine(
        Offset(c.dx + math.cos(a) * r * 0.86, c.dy + math.sin(a) * r * 0.86),
        Offset(c.dx + math.cos(a) * r * 0.94, c.dy + math.sin(a) * r * 0.94),
        Paint()
          ..color = ink.withValues(alpha: 0.7)
          ..strokeWidth = 1.1
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _faceLuxury(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF141820));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = accent.withValues(alpha: 0.35),
    );
    canvas.drawCircle(
      c,
      r * 0.92,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = DriveColors.primaryGlow.withValues(alpha: 0.5),
    );
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6 - math.pi / 2;
      final major = i % 3 == 0;
      canvas.drawLine(
        Offset(c.dx + math.cos(a) * r * (major ? 0.68 : 0.78),
            c.dy + math.sin(a) * r * (major ? 0.68 : 0.78)),
        Offset(c.dx + math.cos(a) * r * 0.88, c.dy + math.sin(a) * r * 0.88),
        Paint()
          ..color = major ? ink : muted
          ..strokeWidth = major ? 2.8 : 1.2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _faceTicks(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r, Paint()..color = face);
    for (var i = 0; i < 60; i++) {
      final a = i * math.pi / 30 - math.pi / 2;
      final major = i % 5 == 0;
      canvas.drawLine(
        Offset(
          c.dx + math.cos(a) * r * (major ? 0.74 : 0.84),
          c.dy + math.sin(a) * r * (major ? 0.74 : 0.84),
        ),
        Offset(c.dx + math.cos(a) * r * 0.92, c.dy + math.sin(a) * r * 0.92),
        Paint()
          ..color = major ? accent : muted.withValues(alpha: 0.55)
          ..strokeWidth = major ? 2 : 0.9
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _faceDual(Canvas canvas, Offset c, double r) {
    // Primary dial + inset GMT-style subdial for dual-timezone look.
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF10141C));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent.withValues(alpha: 0.6),
    );
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6 - math.pi / 2;
      canvas.drawCircle(
        Offset(c.dx + math.cos(a) * r * 0.82, c.dy + math.sin(a) * r * 0.82),
        i % 3 == 0 ? 2.4 : 1.2,
        Paint()..color = i % 3 == 0 ? ink : muted,
      );
    }
    final sub = Offset(c.dx, c.dy + r * 0.28);
    final sr = r * 0.28;
    canvas.drawCircle(sub, sr, Paint()..color = DriveColors.obsidian);
    canvas.drawCircle(
      sub,
      sr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = accent.withValues(alpha: 0.7),
    );
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 - math.pi / 2;
      canvas.drawLine(
        Offset(sub.dx + math.cos(a) * sr * 0.55, sub.dy + math.sin(a) * sr * 0.55),
        Offset(sub.dx + math.cos(a) * sr * 0.85, sub.dy + math.sin(a) * sr * 0.85),
        Paint()
          ..color = muted
          ..strokeWidth = 1,
      );
    }
  }

  void _faceField(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF0C121A));
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.95),
      math.pi * 0.75,
      math.pi * 1.5,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = muted.withValues(alpha: 0.35)
        ..strokeCap = StrokeCap.butt,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.95),
      math.pi * 0.75,
      math.pi * 1.5 * 0.62,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = accent
        ..strokeCap = StrokeCap.butt,
    );
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6 - math.pi / 2;
      canvas.drawLine(
        Offset(c.dx + math.cos(a) * r * 0.7, c.dy + math.sin(a) * r * 0.7),
        Offset(c.dx + math.cos(a) * r * 0.82, c.dy + math.sin(a) * r * 0.82),
        Paint()
          ..color = ink.withValues(alpha: 0.8)
          ..strokeWidth = 1.6,
      );
    }
  }

  void _drawHands(Canvas canvas, Offset c, double r, String style) {
    final h = now.hour % 12 + now.minute / 60;
    final m = now.minute + now.second / 60;
    final s = now.second + now.millisecond / 1000;

    final hourA = h * math.pi / 6 - math.pi / 2;
    final minA = m * math.pi / 30 - math.pi / 2;
    final secA = s * math.pi / 30 - math.pi / 2;

    final handColor = style == 'neon' ? DriveColors.primaryGlow : ink;
    final accentHand = accent;

    canvas.drawLine(
      c,
      Offset(c.dx + math.cos(hourA) * r * 0.45, c.dy + math.sin(hourA) * r * 0.45),
      Paint()
        ..color = handColor
        ..strokeWidth = 3.8
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      c,
      Offset(c.dx + math.cos(minA) * r * 0.68, c.dy + math.sin(minA) * r * 0.68),
      Paint()
        ..color = handColor.withValues(alpha: 0.9)
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );
    if (showSeconds && style != 'minimal') {
      canvas.drawLine(
        c,
        Offset(c.dx + math.cos(secA) * r * 0.78, c.dy + math.sin(secA) * r * 0.78),
        Paint()
          ..color = accentHand
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawCircle(c, 3.5, Paint()..color = accentHand);
  }

  @override
  bool shouldRepaint(covariant _AnalogPainter oldDelegate) =>
      oldDelegate.now != now ||
      oldDelegate.style != style ||
      oldDelegate.accent != accent ||
      oldDelegate.showSeconds != showSeconds ||
      oldDelegate.ringSpin != ringSpin;
}
