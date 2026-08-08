import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

enum MusicAuthorizationStatus { notDetermined, denied, restricted, authorized }

class AppleMusicService {
  static const MethodChannel _channel = MethodChannel(
    'drive_studio/apple_music',
  );

  ValueNotifier<MusicAuthorizationStatus> authStatus = ValueNotifier(
    MusicAuthorizationStatus.notDetermined,
  );

  Future<void> checkAuthorization() async {
    try {
      final status = await _channel.invokeMethod<int>('checkAuthorization');
      authStatus.value = MusicAuthorizationStatus.values[status ?? 0];
    } catch (e) {
      debugPrint('Failed to check Music authorization: $e');
    }
  }

  Future<void> requestAuthorization() async {
    try {
      final status = await _channel.invokeMethod<int>('requestAuthorization');
      authStatus.value = MusicAuthorizationStatus.values[status ?? 0];
    } catch (e) {
      debugPrint('Failed to request Music authorization: $e');
    }
  }

  Future<void> play() async {
    try {
      await _channel.invokeMethod('play');
    } catch (e) {
      debugPrint('Failed to play: $e');
    }
  }

  Future<void> pause() async {
    try {
      await _channel.invokeMethod('pause');
    } catch (e) {
      debugPrint('Failed to pause: $e');
    }
  }

  Future<void> skipToNext() async {
    try {
      await _channel.invokeMethod('skipToNext');
    } catch (e) {
      debugPrint('Failed to skip to next: $e');
    }
  }

  Future<void> skipToPrevious() async {
    try {
      await _channel.invokeMethod('skipToPrevious');
    } catch (e) {
      debugPrint('Failed to skip to previous: $e');
    }
  }
}
