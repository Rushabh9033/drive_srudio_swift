import 'package:drive_studio/core/telemetry/device_telemetry.dart';
import 'package:drive_studio/data/catalog/catalog.dart';
import 'package:drive_studio/data/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Speedometer catalog', () {
    test('Speedometer category is first-class and has templates', () {
      expect(Catalog.categories, contains('Speedometer'));
      expect(Catalog.categories.first, 'Speedometer');
      final speedos = Catalog.templates
          .where((t) => t.category == 'Speedometer')
          .toList();
      expect(speedos.length, greaterThanOrEqualTo(13));
      final premium = speedos.where((t) => t.premium).length;
      expect(premium, greaterThanOrEqualTo(8));
      final ids = speedos.map((t) => t.id).toSet();
      expect(
        ids.length,
        speedos.length,
        reason: 'speedometer template ids must be unique',
      );
      expect(
        ids,
        containsAll([
          'speed-arc-gauge',
          'speed-chrome-ring',
          'speed-obsidian-pill',
          'speed-hud-brackets',
          'speed-perf-strip',
        ]),
      );
      for (final t in speedos) {
        expect(
          t.spec.layers.any(
            (l) =>
                l.format == 'gpsspeed' ||
                l.format == 'gps-speed' ||
                l.role == 'telemetry:gpsspeed',
          ),
          isTrue,
          reason: '${t.id} should include a gpsspeed layer',
        );
      }
    });
  });

  group('composeSpeedometerLayers', () {
    test('drops independent speed + unit + GPS badge layers', () {
      final cluster = composeSpeedometerLayers();
      expect(cluster.length, 3);
      expect(cluster.map((l) => l.kind).toList(), [
        LayerKind.badge,
        LayerKind.text,
        LayerKind.text,
      ]);
      final digits = cluster.firstWhere(
        (l) => l.kind == LayerKind.text && l.format == 'gpsspeed',
      );
      expect(digits.text, '—');
      expect(digits.label, 'Speed');
      expect(countSpeedometerClusters(cluster), 1);
    });

    test('multiple nests offset so layers do not stack', () {
      final a = composeSpeedometerLayers(nestIndex: 0);
      final b = composeSpeedometerLayers(nestIndex: 1);
      final ax = a.firstWhere((l) => l.format == 'gpsspeed').x;
      final bx = b.firstWhere((l) => l.format == 'gpsspeed').x;
      expect(bx, greaterThan(ax));
      expect(countSpeedometerClusters([...a, ...b]), 2);
    });
  });

  group('resolveSpeedDigits honesty', () {
    test('sample preview shows catalog digits; live shows em dash', () {
      expect(
        resolveSpeedDigits(null, samplePreview: true),
        '$kSamplePreviewSpeedKmh',
      );
      expect(resolveSpeedDigits(null), '—');
      expect(
        resolveSpeedDigits(samplePreviewTelemetry),
        '$kSamplePreviewSpeedKmh',
      );
    });

    test('telemetry badge never invents live GPS speed', () {
      final badge = baseLayer(
        LayerKind.badge,
        overrides: {
          'format': 'gpsspeed',
          'role': 'telemetry:gpsspeed',
          'text': 'GPS',
        },
      );
      final snap = TelemetrySnapshot(
        batteryPercent: 0,
        isCharging: false,
        batteryKnown: false,
        carConnected: false,
        carLinkSource: CarLinkSource.none,
        networkOnline: true,
        liveDataEnabled: false,
        supportsLiveHardware: false,
        updatedAt: DateTime(2026, 8, 3),
      );
      expect(telemetryStatusLabel(badge, snap), 'GPS · unavailable');
    });

    test('live GPS digits when speedKnown', () {
      final snap = TelemetrySnapshot(
        batteryPercent: 80,
        isCharging: false,
        batteryKnown: true,
        carConnected: false,
        carLinkSource: CarLinkSource.none,
        networkOnline: true,
        liveDataEnabled: true,
        supportsLiveHardware: true,
        speedKmh: 72.4,
        speedKnown: true,
        updatedAt: DateTime(2026, 8, 3),
      );
      expect(resolveSpeedDigits(snap), '72');
      final badge = baseLayer(
        LayerKind.badge,
        overrides: {'format': 'gpsspeed', 'role': 'telemetry:gpsspeed'},
      );
      expect(telemetryStatusLabel(badge, snap), '72 km/h');
    });
  });
}
