import 'package:flutter/services.dart';

/// Light haptic stubs — real on iOS; soft / no-op on web & many desktops.
class DriveHaptics {
  DriveHaptics._();

  static Future<void> selection() async {
    await HapticFeedback.selectionClick();
  }

  static Future<void> light() async {
    await HapticFeedback.lightImpact();
  }

  static Future<void> medium() async {
    await HapticFeedback.mediumImpact();
  }
}
