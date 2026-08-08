import 'dart:typed_data';

import 'on_device_bg_remover.dart';

/// How to cut out a photo background.
enum BgCutoutMode {
  /// In-app ONNX only (`image_background_remover`). No rembg HTTP.
  onDevice,
}

/// On-device cutout only — never calls the optional rembg helper server.
class BgCutoutService {
  BgCutoutService();

  Future<BgCutoutResult> cutout(
    Uint8List bytes, {
    required BgCutoutMode mode,
  }) async {
    if (!OnDeviceBgRemover.isSupported) {
      return BgCutoutResult.fail(OnDeviceBgRemover.unsupportedMessage);
    }
    final local = await OnDeviceBgRemover.removeBackground(bytes);
    if (local.ok && local.pngBytes != null) {
      return BgCutoutResult.ok(local.pngBytes!, engine: 'on-device');
    }
    return BgCutoutResult.fail(
      local.error ?? 'Background removal failed',
    );
  }
}

class BgCutoutResult {
  const BgCutoutResult._({this.pngBytes, this.error, this.engine});

  factory BgCutoutResult.ok(Uint8List png, {required String engine}) =>
      BgCutoutResult._(pngBytes: png, engine: engine);
  factory BgCutoutResult.fail(String message) =>
      BgCutoutResult._(error: message);

  final Uint8List? pngBytes;
  final String? error;
  final String? engine;

  bool get ok => pngBytes != null && error == null;
}
