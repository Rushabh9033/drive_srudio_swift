import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

enum PowerState { unknown, unplugged, charging, full }

class DeviceStatus {
  final int percent;
  final PowerState state;
  final bool isLowPowerMode;
  final bool isAvailable;

  const DeviceStatus({
    required this.percent,
    required this.state,
    required this.isLowPowerMode,
    this.isAvailable = true,
  });

  factory DeviceStatus.unavailable() => const DeviceStatus(
    percent: 0,
    state: PowerState.unknown,
    isLowPowerMode: false,
    isAvailable: false,
  );

  factory DeviceStatus.fromMap(Map<dynamic, dynamic> map) {
    return DeviceStatus(
      percent: map['percent'] as int? ?? 0,
      state: PowerState.values[map['state'] as int? ?? 0],
      isLowPowerMode: map['isLowPowerMode'] as bool? ?? false,
      isAvailable: map['isAvailable'] as bool? ?? true,
    );
  }
}

class DeviceStatusService {
  static const MethodChannel _channel = MethodChannel(
    'drive_studio/device_status',
  );
  static const EventChannel _eventChannel = EventChannel(
    'drive_studio/device_status_events',
  );

  ValueNotifier<DeviceStatus> status = ValueNotifier(
    DeviceStatus.unavailable(),
  );

  DeviceStatusService() {
    _init();
  }

  Future<void> _init() async {
    try {
      final initial = await _channel.invokeMethod('getInitialStatus');
      if (initial != null) {
        status.value = DeviceStatus.fromMap(initial);
      }
      _eventChannel.receiveBroadcastStream().listen((event) {
        status.value = DeviceStatus.fromMap(event);
      });
    } catch (e) {
      debugPrint('Failed to get device status: $e');
      status.value = DeviceStatus.unavailable();
    }
  }
}
