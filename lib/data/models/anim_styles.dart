/// Canonical motion styles for Drive Studio layers.
abstract final class AnimStyles {
  static const pulse = 'pulse';
  static const shimmer = 'shimmer';
  static const breathe = 'breathe';
  static const blinkColon = 'blink-colon';
  static const sweep = 'sweep';
  static const rotateSlow = 'rotate-slow';
  static const bounceSoft = 'bounce-soft';
  static const glowBreathe = 'glow-breathe';
  static const progressLoop = 'progress-loop';
  static const handSmooth = 'hand-smooth';
  static const flickerNeon = 'flicker-neon';
  static const slideInLoop = 'slide-in-loop';
  static const ripple = 'ripple';

  /// Legacy aliases → canonical ids.
  static const Map<String, String> aliases = {
    'smooth': handSmooth,
    'colon-blink': blinkColon,
  };

  static String normalize(String style) {
    if (style.isEmpty) return style;
    return aliases[style] ?? style;
  }

  /// All selectable styles for the editor (id, label).
  static const List<(String, String)> choices = [
    ('', 'Default'),
    (pulse, 'Pulse'),
    (shimmer, 'Shimmer'),
    (breathe, 'Breathe'),
    (blinkColon, 'Blink colon'),
    (sweep, 'Sweep'),
    (rotateSlow, 'Rotate slow'),
    (bounceSoft, 'Bounce soft'),
    (glowBreathe, 'Glow breathe'),
    (progressLoop, 'Progress loop'),
    (handSmooth, 'Hand smooth'),
    (flickerNeon, 'Flicker neon'),
    (slideInLoop, 'Slide-in loop'),
    (ripple, 'Ripple'),
  ];

  static String labelFor(String style) {
    final n = normalize(style);
    for (final c in choices) {
      if (c.$1 == n) return c.$2;
    }
    if (n.isEmpty) return 'Default';
    return n;
  }
}
