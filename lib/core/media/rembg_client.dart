import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// HTTP client for the rembg FastAPI server (`tools/rembg_server`).
///
/// Kept for optional / web fallback use. Primary in-app path is on-device
/// (`image_background_remover`) via [BgCutoutService]. No editor UI entry.
class RembgClient {
  RembgClient({this.baseUrl = defaultBaseUrl, http.Client? client})
      : _client = client ?? http.Client();

  /// Local Windows / desktop demo (uvicorn on 8787).
  static const defaultBaseUrl = 'http://127.0.0.1:8787';

  /// Production / iPhone placeholder — replace with your hosted HTTPS rembg API.
  static const productionUrlPlaceholder = 'https://rembg.example.com';

  /// Shown when the rembg server cannot be reached (fallback / settings ping).
  static const serverDownMessage =
      'Background removal helper server is not reachable';

  final String baseUrl;
  final http.Client _client;

  Uri get _healthUri => Uri.parse('${_normalize(baseUrl)}/health');
  Uri get _removeUri => Uri.parse('${_normalize(baseUrl)}/remove-bg');

  Future<bool> healthCheck({Duration timeout = const Duration(seconds: 3)}) async {
    try {
      final res = await _client.get(_healthUri).timeout(timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Uploads image bytes; returns PNG cutout with alpha, or failure.
  Future<RembgResult> removeBackground(
    Uint8List bytes, {
    String filename = 'car.jpg',
    Duration timeout = const Duration(seconds: 120),
  }) async {
    try {
      final req = http.MultipartRequest('POST', _removeUri)
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: filename,
          ),
        );
      final streamed = await _client.send(req).timeout(timeout);
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode != 200) {
        final body = res.body.trim();
        if (res.statusCode == 404 ||
            res.statusCode >= 500 ||
            body.isEmpty) {
          return RembgResult.fail(serverDownMessage);
        }
        return RembgResult.fail(
          'Server ${res.statusCode}: ${body.isEmpty ? 'remove-bg failed' : body}',
        );
      }
      if (res.bodyBytes.isEmpty) {
        return RembgResult.fail('Empty cutout from rembg server');
      }
      return RembgResult.ok(Uint8List.fromList(res.bodyBytes));
    } catch (_) {
      return RembgResult.fail(serverDownMessage);
    }
  }

  void close() => _client.close();

  static String _normalize(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u.isEmpty ? defaultBaseUrl : u;
  }
}

class RembgResult {
  const RembgResult._({this.pngBytes, this.error});

  factory RembgResult.ok(Uint8List png) => RembgResult._(pngBytes: png);
  factory RembgResult.fail(String message) => RembgResult._(error: message);

  final Uint8List? pngBytes;
  final String? error;

  bool get ok => pngBytes != null && error == null;
}
