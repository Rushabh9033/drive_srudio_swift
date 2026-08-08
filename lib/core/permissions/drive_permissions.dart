import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/drive_colors.dart';

/// Permissions Drive Studio asks for before system dialogs.
enum DrivePermissionKind { photos, camera, locationWhenInUse }

/// Outcome of [DrivePermissions.ensure].
enum DrivePermissionOutcome {
  /// Proceed with the gated action (picker / GPS stream).
  granted,

  /// User declined our in-app pre-prompt.
  declined,

  /// System denied; may ask again later.
  denied,

  /// User must open OS Settings; we offered a deep-link.
  permanentlyDenied,

  /// Platform cannot grant this (e.g. live GPS on web preview).
  unavailable,
}

/// In-app permission UX: honest pre-prompt → system dialog → Settings if needed.
class DrivePermissions {
  DrivePermissions._();

  /// True when we can meaningfully request OS permissions (iOS / Android).
  static bool get supportsOsPermissions =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  /// Ensure [kind] before opening the picker / starting GPS.
  ///
  /// On web / desktop: photos & camera return [granted] after an optional soft
  /// tip (browser / file picker owns the real prompt). Location returns
  /// [unavailable] — live GPS is iPhone/Android only.
  static Future<DrivePermissionOutcome> ensure(
    BuildContext context,
    DrivePermissionKind kind, {
    bool showPrePrompt = true,
  }) async {
    if (!supportsOsPermissions) {
      if (kind == DrivePermissionKind.locationWhenInUse) {
        return DrivePermissionOutcome.unavailable;
      }
      // Web / Windows / desktop: file picker / browser owns access — no fake OS dialog.
      return DrivePermissionOutcome.granted;
    }

    if (kind == DrivePermissionKind.locationWhenInUse) {
      return _ensureLocation(context, showPrePrompt: showPrePrompt);
    }

    return _ensureMedia(context, kind: kind, showPrePrompt: showPrePrompt);
  }

  static Future<DrivePermissionOutcome> _ensureMedia(
    BuildContext context, {
    required DrivePermissionKind kind,
    required bool showPrePrompt,
  }) async {
    assert(
      kind == DrivePermissionKind.photos || kind == DrivePermissionKind.camera,
    );

    Future<PermissionStatus> readStatus() async {
      if (kind == DrivePermissionKind.camera) {
        return Permission.camera.status;
      }
      var s = await Permission.photos.status;
      if (s.isGranted || s.isLimited) return s;
      // Android 12 and below: gallery often gated by storage.
      if (defaultTargetPlatform == TargetPlatform.android) {
        final storage = await Permission.storage.status;
        if (storage.isGranted) return storage;
      }
      return s;
    }

    Future<PermissionStatus> requestAccess() async {
      if (kind == DrivePermissionKind.camera) {
        return Permission.camera.request();
      }
      var s = await Permission.photos.request();
      if (s.isGranted || s.isLimited) return s;
      if (defaultTargetPlatform == TargetPlatform.android) {
        final storage = await Permission.storage.request();
        if (storage.isGranted) return storage;
        return s.isDenied ? storage : s;
      }
      return s;
    }

    var status = await readStatus();
    if (status.isGranted || status.isLimited) {
      return DrivePermissionOutcome.granted;
    }

    if (status.isPermanentlyDenied || status.isRestricted) {
      if (context.mounted) {
        await _offerOpenSettings(context, kind);
      }
      return DrivePermissionOutcome.permanentlyDenied;
    }

    if (showPrePrompt && context.mounted) {
      final proceed = await _showPrePrompt(context, kind, soft: false);
      if (!proceed) return DrivePermissionOutcome.declined;
    }
    if (!context.mounted) return DrivePermissionOutcome.declined;

    status = await requestAccess();
    if (status.isGranted || status.isLimited) {
      return DrivePermissionOutcome.granted;
    }
    if (status.isPermanentlyDenied) {
      if (context.mounted) {
        await _offerOpenSettings(context, kind);
      }
      return DrivePermissionOutcome.permanentlyDenied;
    }
    return DrivePermissionOutcome.denied;
  }

  /// Location via `geolocator` (same plugin that streams speed).
  static Future<DrivePermissionOutcome> _ensureLocation(
    BuildContext context, {
    required bool showPrePrompt,
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (context.mounted) {
          await _offerOpenLocationSettings(context);
        }
        return DrivePermissionOutcome.denied;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        return DrivePermissionOutcome.granted;
      }

      if (permission == LocationPermission.deniedForever) {
        if (context.mounted) {
          await _offerOpenSettings(
            context,
            DrivePermissionKind.locationWhenInUse,
          );
        }
        return DrivePermissionOutcome.permanentlyDenied;
      }

      if (showPrePrompt && context.mounted) {
        final proceed = await _showPrePrompt(
          context,
          DrivePermissionKind.locationWhenInUse,
          soft: false,
        );
        if (!proceed) return DrivePermissionOutcome.declined;
      }
      if (!context.mounted) return DrivePermissionOutcome.declined;

      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        return DrivePermissionOutcome.granted;
      }
      if (permission == LocationPermission.deniedForever) {
        if (context.mounted) {
          await _offerOpenSettings(
            context,
            DrivePermissionKind.locationWhenInUse,
          );
        }
        return DrivePermissionOutcome.permanentlyDenied;
      }
      return DrivePermissionOutcome.denied;
    } catch (e) {
      if (kDebugMode) debugPrint('DrivePermissions location: $e');
      return DrivePermissionOutcome.unavailable;
    }
  }

  /// Whether GPS permission is already granted (no dialogs).
  static Future<bool> isLocationGranted() async {
    if (!supportsOsPermissions) return false;
    try {
      final p = await Geolocator.checkPermission();
      return p == LocationPermission.whileInUse ||
          p == LocationPermission.always;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _showPrePrompt(
    BuildContext context,
    DrivePermissionKind kind, {
    required bool soft,
  }) async {
    final copy = _copyFor(kind, soft: soft);
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: DriveColors.carbon,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          copy.title,
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: Text(
          copy.body,
          style: GoogleFonts.manrope(
            color: DriveColors.mutedForeground,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(soft ? 'Cancel' : 'Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: DriveColors.primary,
              foregroundColor: DriveColors.primaryForeground,
            ),
            child: Text(soft ? 'Continue' : 'Continue'),
          ),
        ],
      ),
    );
    return result == true;
  }

  static Future<void> _offerOpenSettings(
    BuildContext context,
    DrivePermissionKind kind,
  ) async {
    final name = switch (kind) {
      DrivePermissionKind.photos => 'Photos',
      DrivePermissionKind.camera => 'Camera',
      DrivePermissionKind.locationWhenInUse => 'Location',
    };
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DriveColors.carbon,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '$name access is off',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: Text(
          'You previously denied $name for Drive Studio. '
          'Open system Settings to allow it, then return here.',
          style: GoogleFonts.manrope(
            color: DriveColors.mutedForeground,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: DriveColors.primary,
              foregroundColor: DriveColors.primaryForeground,
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    if (go == true) {
      await openAppSettings();
    }
  }

  static Future<void> _offerOpenLocationSettings(BuildContext context) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DriveColors.carbon,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Location services are off',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: Text(
          'Turn on Location Services to show live GPS speed. '
          'Without a fix, speedometers stay Unavailable — we never invent a speed.',
          style: GoogleFonts.manrope(
            color: DriveColors.mutedForeground,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: DriveColors.primary,
              foregroundColor: DriveColors.primaryForeground,
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    if (go == true) {
      await Geolocator.openLocationSettings();
    }
  }

  static ({String title, String body}) _copyFor(
    DrivePermissionKind kind, {
    required bool soft,
  }) {
    return switch (kind) {
      DrivePermissionKind.photos => (
        title: soft ? 'Choose a photo' : 'Allow photo access',
        body: soft
            ? 'Your browser or system may ask to share a photo. '
                  'Images stay on this device for your widgets — only pick photos you have rights to use.'
            : 'Drive Studio needs Photo Library access to place your car photos on widgets. '
                  'Photos stay on this device. We do not upload them.',
      ),
      DrivePermissionKind.camera => (
        title: soft ? 'Take a photo' : 'Allow camera access',
        body: soft
            ? 'Your browser or system may ask for camera access to photograph your car. '
                  'Photos stay on this device.'
            : 'Drive Studio needs the Camera to photograph your car for widget artwork. '
                  'Photos stay on this device. We do not upload them.',
      ),
      DrivePermissionKind.locationWhenInUse => (
        title: 'Allow location while using',
        body:
            'Drive Studio uses your location only while the app is open '
            'to show live GPS speed on speedometer widgets. '
            'If you decline, speed stays Unavailable — we never invent a reading. '
            'Location is not used for ads or tracking.',
      ),
    };
  }
}
