import 'package:flutter_test/flutter_test.dart';
import 'package:drive_studio/core/nav/deep_links.dart';

void main() {
  group('DriveDeepLink.resolve', () {
    test('maps drivestudio:// host targets', () {
      expect(
        DriveDeepLink.resolve(Uri.parse('drivestudio://sounds')),
        '/sounds',
      );
      expect(DriveDeepLink.resolve(Uri.parse('drivestudio://setup')), '/setup');
      expect(DriveDeepLink.resolve(Uri.parse('drivestudio://home')), '/home');
      expect(
        DriveDeepLink.resolve(Uri.parse('drivestudio://garage')),
        '/garage',
      );
    });

    test('maps path and app-host forms', () {
      expect(
        DriveDeepLink.resolve(Uri.parse('drivestudio:///sounds')),
        '/sounds',
      );
      expect(
        DriveDeepLink.resolve(Uri.parse('drivestudio://app/setup')),
        '/setup',
      );
    });

    test('maps /deeplink aliases and web query', () {
      expect(DriveDeepLink.resolve(Uri.parse('/deeplink/sounds')), '/sounds');
      expect(
        DriveDeepLink.resolve(Uri.parse('http://localhost:5173/?dl=setup')),
        '/setup',
      );
      expect(
        DriveDeepLink.resolve(Uri.parse('http://localhost:5173/?link=home')),
        '/home',
      );
    });

    test('returns null for unrelated uris', () {
      expect(
        DriveDeepLink.resolve(Uri.parse('https://example.com/foo')),
        isNull,
      );
      expect(DriveDeepLink.resolve(Uri.parse('/studio')), isNull);
    });
  });
}
