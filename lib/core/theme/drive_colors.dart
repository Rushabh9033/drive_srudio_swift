import 'package:flutter/painting.dart';

/// Drive Studio palette — OKLCH tokens approximated for Flutter sRGB.
/// Source of truth: DOCUMENTATION.md §D
abstract final class DriveColors {
  static const Color obsidian = Color(0xFF14151C);
  static const Color carbon = Color(0xFF1C1D26);
  static const Color graphite = Color(0xFF2A2B36);
  static const Color accentHover = Color(0xFF32364A);

  static const Color background = obsidian;
  static const Color card = carbon;
  static const Color secondary = graphite;
  static const Color muted = graphite;
  static const Color border = Color(0xFF3A3B48);
  static const Color input = Color(0xFF3A3B48);

  static const Color foreground = Color(0xFFF2F3F7);
  static const Color mutedForeground = Color(0xFF9A9BA8);

  /// Electric Blue — sole chromatic accent
  static const Color primary = Color(0xFF4D9EFF);
  static const Color primaryForeground = Color(0xFF12141C);
  static const Color primaryGlow = Color(0xFF7EB8FF);

  static const Color destructive = Color(0xFFE05A45);
  static const Color success = Color(0xFF4DC98A);
  static const Color warning = Color(0xFFE5B84A);
  static const Color ring = primary;

  static const Color shadowElevated = Color(0xE6080808);
  static const Color glowRing = Color(0x594D9EFF);
  static const Color glowSoft = Color(0xBF4D9EFF);
}
