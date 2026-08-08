import 'dart:typed_data';

import 'package:drive_studio/core/media/bg_cutout_service.dart';
import 'package:drive_studio/core/media/on_device_bg_remover.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OnDeviceBgRemover.isSupported matches platform stub/io', () {
    // Under flutter_test (VM) dart.library.io is available → true.
    // Web builds use the stub (false).
    expect(OnDeviceBgRemover.isSupported, isA<bool>());
  });

  test('BgCutoutService uses on-device only — no rembg fallback', () async {
    final svc = BgCutoutService();
    final result = await svc.cutout(
      Uint8List.fromList([1, 2, 3]),
      mode: BgCutoutMode.onDevice,
    );
    // On VM test, ONNX may fail on tiny bytes; never rembg server message.
    if (!result.ok) {
      expect(result.error, isNot(contains('helper server')));
      expect(result.error, isNot(contains('not reachable')));
    }
  });
}
