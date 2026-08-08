import 'package:flutter_test/flutter_test.dart';
import 'package:drive_studio/data/catalog/catalog.dart';
import 'package:drive_studio/data/store/app_group_export.dart';
import 'package:drive_studio/data/models/models.dart';
import 'package:drive_studio/core/telemetry/telemetry_snapshot.dart';
import 'package:drive_studio/core/telemetry/device_telemetry.dart';
import 'package:drive_studio/presentation/widgets/stock_layer_painters.dart';

void main() {
  group('Telemetry Safety', () {
    test('Live templates do not leak fake data in preview or V2 JSON', () {
      final templates = Catalog.templates;
      for (final t in templates) {
        for (final layer in t.spec.layers) {
          if (layer.kind == LayerKind.text) {
            final text = layer.text;
            if (text != null && text.isNotEmpty) {
              expect(text.contains('°C'), isFalse, reason: t.id);
              expect(text.toLowerCase().contains('spotify'), isFalse, reason: t.id);
              expect(text.contains(' km'), isFalse, reason: t.id);
              expect(text.contains('%') && text.contains(RegExp(r'\d')), isFalse, reason: t.id);
            }
          }
        }
        final jsonStr = t.spec.toJson().toString();
        expect(jsonStr.contains('°C'), isFalse);
        expect(jsonStr.toLowerCase().contains('spotify'), isFalse);
      }
    });

    test('Missing telemetry resolves to safe fallbacks (— or empty) on Flutter renderer', () {
      final t = Catalog.templateById('speed-digital-core')!;
      final layer = t.spec.layers.firstWhere((l) => l.format == 'gpsspeed');
      
      final liveSnapshot = TelemetrySnapshot(
        batteryPercent: 50,
        isCharging: false,
        batteryKnown: true,
        carConnected: true,
        carLinkSource: CarLinkSource.manual,
        networkOnline: true,
        liveDataEnabled: true,
        supportsLiveHardware: true,
        speedKnown: false,
        speedKmh: null,
        updatedAt: DateTime.now(),
      );
      
      final resolved = resolveSpeedDigits(liveSnapshot, samplePreview: false);
      expect(resolved == '—' || resolved == '' || resolved == null, isTrue);
      
      final previewResolved = resolveSpeedDigits(liveSnapshot, samplePreview: true);
      expect(previewResolved, isNotNull);
      expect(previewResolved != '—', isTrue);
    });

    test('Slot export and WidgetKitSharedState safely handle missing telemetry', () async {
      final t = Catalog.templateById('speed-digital-core')!;
      final draft = Draft(
        id: 'draft_1',
        name: 'Safe Draft',
        spec: t.spec,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      
      final state = await buildWidgetKitSharedState(
        slots: ['draft_1', null, null, null],
        drafts: [draft],
        vehicle: Vehicle(brandId: 'b', modelId: 'm', artwork: ArtworkKind.coupe, displayName: 'Car'),
        sounds: SoundPrefs(),
        isPremium: true,
      );
      
      final stateStr = state.toString();
      expect(stateStr.contains('°C'), isFalse);
      expect(stateStr.toLowerCase().contains('spotify'), isFalse);
      expect(stateStr.contains('300 km'), isFalse);
    });
  });
}
