import 'dart:typed_data';

Future<String> writeImageFile(String dirPath, String name, Uint8List bytes) async {
  throw UnsupportedError('File persistence is not available on web');
}

Future<Uint8List?> readImageFile(String path) async => null;
