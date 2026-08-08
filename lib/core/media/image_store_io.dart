import 'dart:io';
import 'dart:typed_data';

Future<String> writeImageFile(
  String dirPath,
  String name,
  Uint8List bytes,
) async {
  final folder = Directory(
    '$dirPath${Platform.pathSeparator}drive_studio_images',
  );
  if (!await folder.exists()) {
    await folder.create(recursive: true);
  }
  final path = '${folder.path}${Platform.pathSeparator}$name';
  await File(path).writeAsBytes(bytes, flush: true);
  return path;
}

Future<Uint8List?> readImageFile(String path) async {
  final file = File(path);
  if (await file.exists()) return file.readAsBytes();
  return null;
}
