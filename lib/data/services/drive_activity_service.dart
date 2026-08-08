import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class DriveActivityState {
  final bool isDriving;
  final double currentSpeedKph;
  final double tripDistanceKm;

  DriveActivityState({
    required this.isDriving,
    required this.currentSpeedKph,
    required this.tripDistanceKm,
  });

  factory DriveActivityState.initial() => DriveActivityState(
    isDriving: false,
    currentSpeedKph: 0.0,
    tripDistanceKm: 0.0,
  );

  factory DriveActivityState.fromMap(Map<dynamic, dynamic> map) {
    return DriveActivityState(
      isDriving: map['isDriving'] ?? false,
      currentSpeedKph: map['currentSpeedKph'] ?? 0.0,
      tripDistanceKm: map['tripDistanceKm'] ?? 0.0,
    );
  }
}

class DriveActivityService {
  static const MethodChannel _channel = MethodChannel(
    'drive_studio/drive_activity',
  );
  static const EventChannel _eventChannel = EventChannel(
    'drive_studio/drive_activity_events',
  );

  ValueNotifier<DriveActivityState> state = ValueNotifier(
    DriveActivityState.initial(),
  );

  DriveActivityService() {
    _init();
  }

  Future<void> _init() async {
    try {
      _eventChannel.receiveBroadcastStream().listen((event) {
        state.value = DriveActivityState.fromMap(event);
      });
    } catch (e) {
      debugPrint('Failed to init drive activity: $e');
    }
  }

  Future<void> startTracking() async {
    try {
      await _channel.invokeMethod('startTracking');
    } catch (e) {
      debugPrint('Failed to start tracking: $e');
    }
  }

  Future<void> stopTracking() async {
    try {
      await _channel.invokeMethod('stopTracking');
    } catch (e) {
      debugPrint('Failed to stop tracking: $e');
    }
  }
}
