import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class MapsLauncherService {
  static const MethodChannel _channel = MethodChannel(
    'drive_studio/maps_launcher',
  );

  Future<void> launchAppleMaps({
    required double latitude,
    required double longitude,
    String? label,
  }) async {
    try {
      await _channel.invokeMethod('launchAppleMaps', {
        'latitude': latitude,
        'longitude': longitude,
        'label': label,
      });
    } catch (e) {
      debugPrint('Failed to launch Apple Maps: $e');
    }
  }

  Future<void> launchGoogleMaps({
    required double latitude,
    required double longitude,
    String? label,
  }) async {
    try {
      await _channel.invokeMethod('launchGoogleMaps', {
        'latitude': latitude,
        'longitude': longitude,
        'label': label,
      });
    } catch (e) {
      debugPrint('Failed to launch Google Maps: $e');
    }
  }

  Future<void> launchWaze({
    required double latitude,
    required double longitude,
  }) async {
    try {
      await _channel.invokeMethod('launchWaze', {
        'latitude': latitude,
        'longitude': longitude,
      });
    } catch (e) {
      debugPrint('Failed to launch Waze: $e');
    }
  }
}
