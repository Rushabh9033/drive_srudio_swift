import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models/anim_styles.dart';
import '../../data/models/models.dart';

/// Isolated motion wrapper — only mounts a [AnimationController] when needed.
/// Never placed above the editor gesture overlay.
class AnimatedLayerFx extends StatefulWidget {
  const AnimatedLayerFx({super.key, required this.layer, required this.child});

  final Layer layer;
  final Widget child;

  @override
  State<AnimatedLayerFx> createState() => _AnimatedLayerFxState();
}

class _AnimatedLayerFxState extends State<AnimatedLayerFx>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  static const _wrapperStyles = {
    AnimStyles.pulse,
    AnimStyles.shimmer,
    AnimStyles.breathe,
    AnimStyles.rotateSlow,
    AnimStyles.sweep,
    AnimStyles.bounceSoft,
    AnimStyles.glowBreathe,
    AnimStyles.flickerNeon,
    AnimStyles.slideInLoop,
    AnimStyles.ripple,
  };

  bool get _wantsFx {
    final layer = widget.layer;
    if (!layer.animate) return false;
    return _wrapperStyles.contains(layer.resolvedAnimStyle);
  }

  Duration get _baseDuration {
    final style = widget.layer.resolvedAnimStyle;
    final ms = switch (style) {
      AnimStyles.rotateSlow => 12000,
      AnimStyles.shimmer || AnimStyles.sweep => 1800,
      AnimStyles.flickerNeon => 900,
      AnimStyles.bounceSoft => 1400,
      AnimStyles.slideInLoop => 2600,
      AnimStyles.ripple => 2000,
      _ => 2200,
    };
    return Duration(
      milliseconds: (ms / widget.layer.resolvedAnimSpeed).round(),
    );
  }

  bool get _reverse => switch (widget.layer.resolvedAnimStyle) {
    AnimStyles.rotateSlow ||
    AnimStyles.shimmer ||
    AnimStyles.sweep ||
    AnimStyles.slideInLoop ||
    AnimStyles.ripple => false,
    _ => true,
  };

  @override
  void initState() {
    super.initState();
    _syncController();
  }

  @override
  void didUpdateWidget(covariant AnimatedLayerFx oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layer.animate != widget.layer.animate ||
        oldWidget.layer.animStyle != widget.layer.animStyle ||
        oldWidget.layer.animSpeed != widget.layer.animSpeed ||
        oldWidget.layer.kind != widget.layer.kind) {
      _syncController();
    }
  }

  void _syncController() {
    if (_wantsFx) {
      _controller ??= AnimationController(vsync: this, duration: _baseDuration);
      _controller!
        ..duration = _baseDuration
        ..repeat(reverse: _reverse);
    } else {
      _controller?.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    final ctrl = _controller;
    if (!_wantsFx || ctrl == null) return child;

    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        final t = ctrl.value;
        final style = widget.layer.resolvedAnimStyle;
        switch (style) {
          case AnimStyles.pulse:
            return Opacity(
              opacity: 0.62 + 0.38 * (0.5 + 0.5 * math.sin(t * math.pi * 2)),
              child: child,
            );
          case AnimStyles.breathe:
            final s = 0.97 + 0.03 * (0.5 + 0.5 * math.sin(t * math.pi * 2));
            return Transform.scale(scale: s, child: child);
          case AnimStyles.bounceSoft:
            final y = -4 * math.sin(t * math.pi);
            final s = 1 + 0.04 * math.sin(t * math.pi);
            return Transform.translate(
              offset: Offset(0, y),
              child: Transform.scale(scale: s, child: child),
            );
          case AnimStyles.rotateSlow:
            return Transform.rotate(angle: t * math.pi * 2, child: child);
          case AnimStyles.slideInLoop:
            final x = (1 - Curves.easeOutCubic.transform(t)) * 18;
            final op = 0.35 + 0.65 * Curves.easeOut.transform(t.clamp(0, 1));
            return Opacity(
              opacity: op,
              child: Transform.translate(offset: Offset(x, 0), child: child),
            );
          case AnimStyles.glowBreathe:
            final glow = 0.25 + 0.55 * (0.5 + 0.5 * math.sin(t * math.pi * 2));
            return Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: glow * 0.35),
                    blurRadius: 10 + glow * 14,
                    spreadRadius: glow * 2,
                  ),
                ],
              ),
              child: Opacity(opacity: 0.85 + 0.15 * glow, child: child),
            );
          case AnimStyles.flickerNeon:
            final flicker =
                0.55 +
                0.45 *
                    (0.5 +
                        0.5 *
                            math.sin(t * math.pi * 11) *
                            math.sin(t * math.pi * 3.7));
            return Opacity(
              opacity: flicker.clamp(0.4, 1),
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.cyanAccent.withValues(alpha: 0.15 * flicker),
                  BlendMode.plus,
                ),
                child: child,
              ),
            );
          case AnimStyles.ripple:
            final s = 1 + 0.06 * math.sin(t * math.pi * 2);
            return Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: (1 - t) * 0.35,
                  child: Transform.scale(scale: 1 + t * 0.18, child: child),
                ),
                Transform.scale(scale: s, child: child),
              ],
            );
          case AnimStyles.shimmer:
          case AnimStyles.sweep:
            return ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (bounds) {
                final slide = style == AnimStyles.sweep
                    ? t
                    : (t * 2 - 0.5).clamp(-0.2, 1.2);
                return LinearGradient(
                  begin: Alignment(-1.2 + slide * 2, -0.4),
                  end: Alignment(-0.2 + slide * 2, 0.6),
                  colors: [
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(
                      alpha: style == AnimStyles.sweep ? 0.5 : 0.35,
                    ),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                  stops: const [0.35, 0.5, 0.65],
                ).createShader(bounds);
              },
              child: child,
            );
          default:
            return child;
        }
      },
    );
  }
}

/// Digital clock colon blink — own ticker, no editor overlay rebuild.
class ColonBlinkClock extends StatefulWidget {
  const ColonBlinkClock({
    super.key,
    required this.timeLabel,
    required this.style,
    required this.align,
    required this.maxLines,
    this.enabled = true,
    this.speed = 1,
  });

  final String timeLabel;
  final TextStyle style;
  final TextAlign align;
  final int maxLines;
  final bool enabled;
  final double speed;

  @override
  State<ColonBlinkClock> createState() => _ColonBlinkClockState();
}

class _ColonBlinkClockState extends State<ColonBlinkClock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: (1000 / widget.speed.clamp(0.35, 2.5)).round(),
      ),
    );
    if (widget.enabled) _blink.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant ColonBlinkClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.speed != widget.speed) {
      _blink.duration = Duration(
        milliseconds: (1000 / widget.speed.clamp(0.35, 2.5)).round(),
      );
    }
    if (widget.enabled && !_blink.isAnimating) {
      _blink.repeat(reverse: true);
    } else if (!widget.enabled && _blink.isAnimating) {
      _blink.stop();
      _blink.value = 1;
    }
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Never render a dangling trailing colon (e.g. "19:35:").
    final label = _sanitizeClockLabel(widget.timeLabel);
    // Pulse opacity of the HH↔MM colon only; do not append an extra ":".
    final colon = label.indexOf(':');
    final canBlink =
        widget.enabled &&
        colon > 0 &&
        colon < label.length - 1 &&
        label.substring(colon + 1).isNotEmpty;

    if (!canBlink) {
      return Text(
        label,
        textAlign: widget.align,
        maxLines: widget.maxLines,
        softWrap: false,
        overflow: TextOverflow.clip,
        style: widget.style,
      );
    }

    final left = label.substring(0, colon);
    final right = label.substring(colon + 1);

    return AnimatedBuilder(
      animation: _blink,
      builder: (context, _) {
        final on = _blink.value > 0.35;
        return Text.rich(
          TextSpan(
            style: widget.style,
            children: [
              TextSpan(text: left),
              TextSpan(
                text: ':',
                style: widget.style.copyWith(
                  color: (widget.style.color ?? Colors.white).withValues(
                    alpha: on ? 1 : 0.18,
                  ),
                ),
              ),
              TextSpan(text: right),
            ],
          ),
          textAlign: widget.align,
          maxLines: widget.maxLines,
          softWrap: false,
          overflow: TextOverflow.clip,
        );
      },
    );
  }
}

/// Strips dangling colons so clocks never display `19:35:`.
String _sanitizeClockLabel(String raw) {
  var s = raw.trimRight();
  while (s.endsWith(':')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}
