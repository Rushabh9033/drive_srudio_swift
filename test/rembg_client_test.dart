import 'dart:typed_data';

import 'package:drive_studio/core/media/rembg_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('default and production URL constants', () {
    expect(RembgClient.defaultBaseUrl, 'http://127.0.0.1:8787');
    expect(RembgClient.productionUrlPlaceholder, startsWith('https://'));
    expect(RembgClient.serverDownMessage, contains('not reachable'));
  });

  test('healthCheck true on 200', () async {
    final client = RembgClient(
      client: MockClient((req) async {
        expect(req.url.path, '/health');
        return http.Response('{"ok":true}', 200);
      }),
    );
    expect(await client.healthCheck(), isTrue);
  });

  test('healthCheck false on network error', () async {
    final client = RembgClient(
      client: MockClient((req) async {
        throw Exception('down');
      }),
    );
    expect(await client.healthCheck(), isFalse);
  });

  test('removeBackground returns PNG bytes on 200', () async {
    final png = Uint8List.fromList([137, 80, 78, 71, 1, 2, 3]);
    final client = RembgClient(
      client: MockClient((req) async {
        expect(req.method, 'POST');
        expect(req.url.path, '/remove-bg');
        return http.Response.bytes(
          png,
          200,
          headers: {'content-type': 'image/png'},
        );
      }),
    );
    final result = await client.removeBackground(Uint8List.fromList([1, 2]));
    expect(result.ok, isTrue);
    expect(result.pngBytes, png);
  });

  test(
    'removeBackground maps connection failure to server-down message',
    () async {
      final client = RembgClient(
        client: MockClient((req) async {
          throw Exception('Connection refused');
        }),
      );
      final result = await client.removeBackground(Uint8List.fromList([1]));
      expect(result.ok, isFalse);
      expect(result.error, RembgClient.serverDownMessage);
    },
  );
}
