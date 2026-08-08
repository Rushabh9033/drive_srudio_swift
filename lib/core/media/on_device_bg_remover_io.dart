import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image_background_remover/image_background_remover.dart';

/// On-device cutout via `image_background_remover` (ONNX / flutter_onnxruntime).
/// Platforms: iOS 16+, Android, Windows, macOS, Linux. Not used on web.
class OnDeviceBgRemover {
  OnDeviceBgRemover._();

  static const bool isSupported = true;

  static const unsupportedMessage =
      'On-device background removal is not available on this platform.';

  static bool _ready = false;

  static Future<void> ensureInitialized() async {
    if (_ready) return;
    await BackgroundRemover.instance.initializeOrt();
    _ready = true;
  }

  static Future<OnDeviceBgResult> removeBackground(Uint8List bytes) async {
    try {
      await ensureInitialized();
      final image = await BackgroundRemover.instance.removeBg(bytes);
      final bd = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bd == null || bd.lengthInBytes == 0) {
        return OnDeviceBgResult.fail('Empty on-device cutout');
      }
      return OnDeviceBgResult.ok(bd.buffer.asUint8List());
    } catch (e) {
      return OnDeviceBgResult.fail('On-device remove failed: $e');
    }
  }
}

class OnDeviceBgResult {
  const OnDeviceBgResult._({this.pngBytes, this.error});

  factory OnDeviceBgResult.ok(Uint8List png) =>
      OnDeviceBgResult._(pngBytes: png);
  factory OnDeviceBgResult.fail(String message) =>
      OnDeviceBgResult._(error: message);

  final Uint8List? pngBytes;
  final String? error;

  bool get ok => pngBytes != null && error == null;
}
