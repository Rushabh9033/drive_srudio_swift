import 'package:flutter/painting.dart';
import 'package:flutter/physics.dart';

abstract final class DriveTokens {
  // Surface Colors
  static const Color bgBase = Color(0xFF14151C);
  static const Color bgSurface = Color(0xFF1C1D26);
  static const Color bgOverlay = Color(0xFF2A2B36);

  // Accent Colors
  static const Color accentBlue = Color(0xFF4D9EFF);
  static const Color accentCyan = Color(0xFF4DD1FF);
  static const Color accentAmber = Color(0xFFE5B84A);
  static const Color accentRed = Color(0xFFE05A45);

  // Stroke Widths
  static const double strokeThin = 1.0;
  static const double strokeRegular = 1.5;
  static const double strokeBold = 2.5;

  // Spacing
  static const double spaceXxs = 4.0;
  static const double spaceXs = 8.0;
  static const double spaceSm = 12.0;
  static const double spaceMd = 16.0;
  static const double spaceLg = 24.0;
  static const double spaceXl = 32.0;

  // Widget-Safe Padding
  static const double widgetSafeFringe = 16.0;

  // Glow Intensity
  static const double glowLow = 0.2;
  static const double glowMedium = 0.45;
  static const double glowHigh = 0.8;

  // Animation Duration
  static const Duration animSnappy = Duration(milliseconds: 150);
  static const Duration animStandard = Duration(milliseconds: 250);
  static const Duration animRelaxed = Duration(milliseconds: 400);

  // Spring Behavior
  static final SpringDescription springBouncy = SpringDescription(
    mass: 1.0,
    stiffness: 200.0,
    damping: 15.0,
  );
  static final SpringDescription springSmooth = SpringDescription(
    mass: 1.0,
    stiffness: 100.0,
    damping: 20.0,
  );
}
