import 'dart:typed_data';

/// Web / non-IO stub — on-device ONNX cutout is unavailable.
class OnDeviceBgRemover {
  OnDeviceBgRemover._();

  static const bool isSupported = false;

  static const unsupportedMessage =
      'Background removal runs on iPhone, Android, or desktop. '
      'On this web preview, keep the original photo or test on a device.';

  static Future<void> ensureInitialized() async {}

  static Future<OnDeviceBgResult> removeBackground(Uint8List bytes) async {
    return OnDeviceBgResult.fail(unsupportedMessage);
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
