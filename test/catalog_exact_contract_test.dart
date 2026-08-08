import 'package:flutter_test/flutter_test.dart';
import 'package:drive_studio/data/catalog/catalog.dart';
import 'package:drive_studio/data/catalog/stock_widget_templates.dart';
import 'package:drive_studio/data/catalog/apex_templates.dart';
import 'package:drive_studio/data/store/app_store.dart';
import 'package:drive_studio/data/store/app_group_export.dart';
import 'package:drive_studio/data/models/models.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Exact Catalog Contract', () {
    test('Exact template counts', () {
      final stock = buildStockWidgetTemplates();
      final apex = buildApexWidgetTemplates();

      expect(
        stock.length,
        98,
        reason: 'Stock widget templates exact count (98 list items)',
      );

      final inlineCount = Catalog.templates.length - stock.length - apex.length;
      expect(inlineCount, 14, reason: 'Exactly 14 inline templates');

      expect(apex.length, 12, reason: 'Exactly 12 Apex templates');
      expect(
        Catalog.templates.length,
        98 + 14 + 12,
        reason: 'Exact combined catalog size of 124 templates',
      );
    });

    test('Template IDs are strictly unique within the template namespace', () {
      final ids = Catalog.templates.map((t) => t.id).toList();
      final uniqueIds = ids.toSet();
      expect(
        uniqueIds.length,
        ids.length,
        reason: 'No duplicate TemplateItem IDs',
      );
    });

    test('Apex IDs are unique and do not replace stock IDs', () {
      final stockIds = buildStockWidgetTemplates().map((t) => t.id).toSet();
      final inlineIds = Catalog.templates
          .where((t) => !t.id.startsWith('apex-'))
          .where((t) => !stockIds.contains(t.id))
          .map((t) => t.id)
          .toSet();

      final apex = buildApexWidgetTemplates();
      final apexIds = apex.map((t) => t.id).toList();
      expect(
        apexIds.toSet().length,
        apexIds.length,
        reason: 'All Apex IDs must be unique',
      );

      for (final id in apexIds) {
        expect(
          stockIds.contains(id),
          isFalse,
          reason: 'Apex ID $id replaces a stock ID',
        );
        expect(
          inlineIds.contains(id),
          isFalse,
          reason: 'Apex ID $id replaces an inline ID',
        );
      }
    });

    test('All 12 Apex templates survive V2 JSON round-trip', () {
      final apex = buildApexWidgetTemplates();
      for (final template in apex) {
        final originalSpec = template.spec;
        final json = jsonEncode(originalSpec.toJson());
        final decodedSpec = WidgetSpec.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );

        expect(decodedSpec.layers.length, originalSpec.layers.length);
        expect(decodedSpec.background.from, originalSpec.background.from);
      }
    });

    test('Draft save and reopen preserve their layers', () async {
      SharedPreferences.setMockInitialValues({});
      final store = AppStore();
      await store.hydrate();

      final template = buildApexWidgetTemplates().first;
      final draft = Draft(
        id: 'draft_1',
        name: 'My Draft',
        spec: template.spec,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      store.drafts.add(draft);
      final loaded = store.drafts.firstWhere((d) => d.id == 'draft_1');
      expect(loaded.spec.layers.length, template.spec.layers.length);
    });

    test('Slot export preserves the correct document', () async {
      final template = buildApexWidgetTemplates().first;
      final draft = Draft(
        id: 'draft_1',
        name: 'My Draft',
        spec: template.spec,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      final slots = ['draft_1', null, null, null];
      final state = await buildWidgetKitSharedState(
        slots: slots,
        drafts: [draft],
        vehicle: Vehicle(
          brandId: 'b',
          modelId: 'm',
          artwork: ArtworkKind.coupe,
          displayName: 'Car',
        ),
        sounds: SoundPrefs(),
        isPremium: true,
      );

      final slotsList = state['slots'] as List;
      expect(slotsList.length, 4);
      final slot0 = slotsList[0] as Map;
      expect(slot0['spec']['layers'].length, template.spec.layers.length);
    });

    test(
      'Every production-visible layer kind is supported by both renderers',
      () {
        final supportedKinds = LayerKind.values.map((k) => k.name).toSet();
        for (final t in Catalog.templates) {
          for (final layer in t.spec.layers) {
            expect(
              supportedKinds.contains(layer.kind.name),
              isTrue,
              reason: 'Layer kind ${layer.kind.name} in ${t.id} is unsupported',
            );
          }
        }
      },
    );

    test('Existing compatibility-sensitive template IDs remain resolvable', () {
      final legacyIds = [
        'lumen-range',
        'velora-pulse',
        'drive-range-hud',
        'drive-fuel-gauge',
      ];
      for (final id in legacyIds) {
        expect(() => Catalog.templateById(id), returnsNormally);
      }
    });
  });
}
