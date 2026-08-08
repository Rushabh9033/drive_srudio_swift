import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drive_studio/core/telemetry/device_telemetry.dart';
import 'package:drive_studio/data/catalog/layer_factory.dart';
import 'package:drive_studio/data/models/models.dart';
import 'package:drive_studio/data/store/app_group_export.dart';
import 'package:drive_studio/data/store/app_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('resolveLiveBatteryPercent', () {
    test('uses live telemetry when enabled and known', () {
      final layer = baseLayer(LayerKind.battery, overrides: {'text': '40'});
      final snap = TelemetrySnapshot(
        batteryPercent: 91,
        isCharging: true,
        batteryKnown: true,
        carConnected: false,
        carLinkSource: CarLinkSource.none,
        networkOnline: true,
        liveDataEnabled: true,
        supportsLiveHardware: true,
        updatedAt: DateTime(2026, 8, 2),
      );
      expect(resolveLiveBatteryPercent(layer, snap), 91);
    });

    test('returns null when battery unavailable — never invents %', () {
      final layer = baseLayer(LayerKind.battery, overrides: {'text': '55'});
      final snap = TelemetrySnapshot(
        batteryPercent: 91,
        isCharging: false,
        batteryKnown: false,
        carConnected: false,
        carLinkSource: CarLinkSource.none,
        networkOnline: true,
        liveDataEnabled: false,
        supportsLiveHardware: false,
        updatedAt: DateTime(2026, 8, 2),
      );
      expect(resolveLiveBatteryPercent(layer, snap), isNull);
    });

    test('rejects sample-preview snapshot on live resolver', () {
      final layer = baseLayer(LayerKind.battery);
      expect(resolveLiveBatteryPercent(layer, samplePreviewTelemetry), isNull);
    });

    test('dayprogress ignores device battery', () {
      final layer = baseLayer(
        LayerKind.battery,
        overrides: {'format': 'dayprogress', 'text': '10'},
      );
      final noon = DateTime(2026, 8, 2, 12, 0, 0);
      final snap = TelemetrySnapshot(
        batteryPercent: 10,
        isCharging: false,
        batteryKnown: true,
        carConnected: false,
        carLinkSource: CarLinkSource.none,
        networkOnline: true,
        liveDataEnabled: true,
        supportsLiveHardware: true,
        updatedAt: noon,
      );
      expect(resolveLiveBatteryPercent(layer, snap, noon), 50);
    });
  });

  group('resolveDisplayBatteryPercent sample vs live', () {
    test('samplePreview paints stable catalog fill', () {
      final layer = baseLayer(LayerKind.battery);
      expect(
        resolveDisplayBatteryPercent(layer, null, samplePreview: true),
        kSamplePreviewBatteryPercent,
      );
      expect(
        resolveDisplayBatteryPercent(
          layer,
          samplePreviewTelemetry,
          samplePreview: true,
        ),
        72,
      );
    });

    test('live path with no sensor stays null — no sample fallback', () {
      final layer = baseLayer(LayerKind.battery);
      expect(
        resolveDisplayBatteryPercent(layer, null, samplePreview: false),
        isNull,
      );
      final unknown = TelemetrySnapshot(
        batteryPercent: 0,
        isCharging: false,
        batteryKnown: false,
        carConnected: false,
        carLinkSource: CarLinkSource.none,
        networkOnline: false,
        liveDataEnabled: false,
        supportsLiveHardware: false,
        updatedAt: DateTime(2026, 8, 3),
      );
      expect(
        resolveDisplayBatteryPercent(layer, unknown, samplePreview: false),
        isNull,
      );
    });

    test(
      'samplePreview never leaks into liveSource of DeviceTelemetry path',
      () {
        expect(samplePreviewTelemetry.isSamplePreview, isTrue);
        expect(samplePreviewTelemetry.liveSource, 'sample-preview');
        expect(samplePreviewTelemetry.isCharging, isFalse);
        expect(samplePreviewTelemetry.batteryPercent, 72);
      },
    );
  });

  group('telemetryStatusLabel', () {
    test('car link and charging labels', () {
      final car = baseLayer(
        LayerKind.badge,
        overrides: {'format': 'carlink', 'text': 'x'},
      );
      final charge = baseLayer(
        LayerKind.badge,
        overrides: {'format': 'charging', 'text': 'x'},
      );
      final batt = baseLayer(
        LayerKind.badge,
        overrides: {'format': 'batterylive', 'text': 'x'},
      );
      final on = TelemetrySnapshot(
        batteryPercent: 80,
        isCharging: true,
        batteryKnown: true,
        carConnected: true,
        carLinkSource: CarLinkSource.manual,
        networkOnline: true,
        liveDataEnabled: true,
        supportsLiveHardware: true,
        updatedAt: DateTime.now(),
      );
      expect(telemetryStatusLabel(car, on), 'Car link · on');
      expect(telemetryStatusLabel(charge, on), 'Charging');
      expect(telemetryStatusLabel(batt, on), 'Battery 80%');

      final off = TelemetrySnapshot(
        batteryPercent: 0,
        isCharging: false,
        batteryKnown: false,
        carConnected: false,
        carLinkSource: CarLinkSource.none,
        networkOnline: false,
        liveDataEnabled: false,
        supportsLiveHardware: false,
        updatedAt: DateTime.now(),
      );
      expect(telemetryStatusLabel(batt, off), 'Battery · unavailable');
      expect(telemetryStatusLabel(charge, off), 'Charge · unavailable');
    });

    test('sample preview labels look filled', () {
      final batt = baseLayer(
        LayerKind.badge,
        overrides: {'format': 'batterylive', 'text': 'x'},
      );
      final charge = baseLayer(
        LayerKind.badge,
        overrides: {'format': 'charging', 'text': 'x'},
      );
      expect(telemetryStatusLabel(batt, samplePreviewTelemetry), 'Battery 72%');
      expect(
        telemetryStatusLabel(charge, samplePreviewTelemetry),
        'On battery',
      );
    });
  });

  group('DeviceTelemetry + AppStore', () {
    test('manual car connected and app group telemetry mirror', () async {
      SharedPreferences.setMockInitialValues({});
      final store = AppStore();
      await store.hydrate();
      store.setUseLiveDeviceData(true);
      store.setManualCarConnected(true);

      final telemetry = DeviceTelemetry();
      await telemetry.start(store);
      telemetry.debugSetBattery(percent: 67, charging: true);
      telemetry.debugSetConnectivity(bluetooth: false, online: true);

      final snap = telemetry.snapshot;
      expect(snap.batteryPercent, 67);
      expect(snap.isCharging, isTrue);
      expect(snap.carConnected, isTrue);
      expect(snap.carLinkSource, CarLinkSource.manual);
      expect(store.lastTelemetry?.batteryPercent, 67);
      expect(snap.liveSource, isNotEmpty);
      expect(snap.isSamplePreview, isFalse);

      final payload = await store.buildAppGroupPayload();
      expect(payload['telemetry'], isA<Map>());
      final tel = payload['telemetry'] as Map;
      expect(tel['batteryPercent'], 67);
      expect(tel['liveSource'], isNot('sample-preview'));
      expect(tel.containsKey('bluetoothProxySupported'), isTrue);
      expect(validateAppGroupPayload(payload), isTrue);

      store.setManualCarConnected(false);
      telemetry.debugSetConnectivity(bluetooth: true, online: true);
      // BT auto car-link only when the platform supports it (Android).
      // On iOS / desktop test host, manual remains the reliable path.
      if (telemetry.bluetoothProxySupported) {
        expect(telemetry.snapshot.carConnected, isTrue);
        expect(telemetry.snapshot.carLinkSource, CarLinkSource.bluetoothProxy);
      } else {
        expect(telemetry.snapshot.carConnected, isFalse);
        expect(telemetry.snapshot.carLinkSource, CarLinkSource.none);
      }

      await telemetry.stop();
    });

    test('live off does not claim batteryKnown or invent percent', () async {
      SharedPreferences.setMockInitialValues({});
      final store = AppStore();
      await store.hydrate();
      store.setUseLiveDeviceData(false);

      final telemetry = DeviceTelemetry();
      await telemetry.start(store);
      telemetry.debugSetBattery(percent: 33, charging: false);

      expect(telemetry.snapshot.liveDataEnabled, isFalse);
      expect(telemetry.snapshot.batteryKnown, isFalse);
      expect(telemetry.snapshot.batteryPercent, 0);
      expect(telemetry.snapshot.toJson()['batteryPercent'], isNull);

      await telemetry.stop();
    });

    test('first-run live default follows supportsLiveHardware', () async {
      SharedPreferences.setMockInitialValues({});
      final store = AppStore();
      await store.hydrate();
      expect(store.liveDataPreferenceSet, isFalse);

      final telemetry = DeviceTelemetry();
      await telemetry.start(store);

      expect(store.liveDataPreferenceSet, isTrue);
      // Web/desktop test host → false; physical iPhone/Android → true.
      expect(store.useLiveDeviceData, telemetry.supportsLiveHardware);

      await telemetry.stop();
    });
  });
}
