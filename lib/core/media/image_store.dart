import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'image_store_io.dart' if (dart.library.html) 'image_store_stub.dart'
    as io;

const _uuid = Uuid();

/// Saves a picked image to app documents after client-side resize.
/// Returns a stable file path (or compact data URL on web).
Future<String?> persistPickedImage(
  Uint8List bytes, {
  int maxEdge = 1024,
  int jpegQuality = 82,
}) async {
  final resized =
      await compute(_resizeJpeg, _ResizeArgs(bytes, maxEdge, jpegQuality));
  if (resized == null) return null;

  if (kIsWeb) {
    final b64 = base64Encode(resized);
    return 'data:image/jpeg;base64,$b64';
  }

  try {
    final dir = await getApplicationDocumentsDirectory();
    return io.writeImageFile(dir.path, '${_uuid.v4()}.jpg', resized);
  } catch (e) {
    if (kDebugMode) debugPrint('persistPickedImage failed: $e');
    return null;
  }
}

/// Persists a PNG (keeps alpha — for rembg cutouts).
Future<String?> persistPickedPng(
  Uint8List bytes, {
  int maxEdge = 1024,
}) async {
  final resized =
      await compute(_resizePng, _ResizeArgs(bytes, maxEdge, 100));
  if (resized == null) return null;

  if (kIsWeb) {
    final b64 = base64Encode(resized);
    return 'data:image/png;base64,$b64';
  }

  try {
    final dir = await getApplicationDocumentsDirectory();
    return io.writeImageFile(dir.path, '${_uuid.v4()}.png', resized);
  } catch (e) {
    if (kDebugMode) debugPrint('persistPickedPng failed: $e');
    return null;
  }
}

Future<Uint8List?> loadImageBytes(String? src) async {
  if (src == null || src.isEmpty) return null;
  try {
    if (src.startsWith('data:')) {
      final comma = src.indexOf(',');
      if (comma < 0) return null;
      return base64Decode(src.substring(comma + 1));
    }
    if (kIsWeb) return null;
    
    var bytes = await io.readImageFile(src);
    if (bytes != null) return bytes;
    
    // Resolve dynamic iOS sandbox paths
    final filename = src.split('/').last;
    final dir = await getApplicationDocumentsDirectory();
    final newPath = '${dir.path}/drive_studio_images/$filename';
    return await io.readImageFile(newPath);
  } catch (_) {}
  return null;
}

class _ResizeArgs {
  const _ResizeArgs(this.bytes, this.maxEdge, this.quality);
  final Uint8List bytes;
  final int maxEdge;
  final int quality;
}

img.Image? _scaleToMaxEdge(img.Image decoded, int maxEdge) {
  final longest =
      decoded.width > decoded.height ? decoded.width : decoded.height;
  if (longest <= maxEdge) return decoded;
  if (decoded.width >= decoded.height) {
    return img.copyResize(
      decoded,
      width: maxEdge,
      interpolation: img.Interpolation.average,
    );
  }
  return img.copyResize(
    decoded,
    height: maxEdge,
    interpolation: img.Interpolation.average,
  );
}

Uint8List? _resizeJpeg(_ResizeArgs args) {
  try {
    final decoded = img.decodeImage(args.bytes);
    if (decoded == null) return null;
    final out = _scaleToMaxEdge(decoded, args.maxEdge);
    if (out == null) return null;
    return Uint8List.fromList(img.encodeJpg(out, quality: args.quality));
  } catch (_) {
    return null;
  }
}

Uint8List? _resizePng(_ResizeArgs args) {
  try {
    final decoded = img.decodeImage(args.bytes);
    if (decoded == null) return null;
    final out = _scaleToMaxEdge(decoded, args.maxEdge);
    if (out == null) return null;
    return Uint8List.fromList(img.encodePng(out));
  } catch (_) {
    return null;
  }
}
