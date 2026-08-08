import 'dart:convert';

import 'package:drive_studio/data/catalog/catalog.dart';
import 'package:drive_studio/data/models/models.dart';
import 'package:drive_studio/data/store/app_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Sport Badge Edit copy keeps every layer separate', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.hydrate();
    store.unlockPremiumDebug();

    final template = Catalog.templates.firstWhere(
      (t) => t.id == 'analog-sport-badge',
    );
    expect(template.spec.layers.length, greaterThanOrEqualTo(3));
    final kinds = template.spec.layers.map((l) => l.kind).toList();
    expect(kinds, contains(LayerKind.badge));
    expect(kinds, contains(LayerKind.clock));
    expect(kinds, contains(LayerKind.analog));

    final draftId = store.createDraftFromTemplate(template);
    expect(draftId, isNotNull);
    final draft = store.draftById(draftId!)!;
    expect(draft.name, 'Sport Badge copy');
    expect(draft.spec.layers.length, template.spec.layers.length);
    expect(
      draft.spec.layers.map((l) => l.kind).toList(),
      template.spec.layers.map((l) => l.kind).toList(),
    );
    // Fresh ids — not aliased to the catalog template.
    final templateIds = template.spec.layers.map((l) => l.id).toSet();
    for (final l in draft.spec.layers) {
      expect(templateIds.contains(l.id), isFalse);
    }
  });

  test('Draft JSON round-trip never flattens multi-layer specs', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.hydrate();

    final free = Catalog.templates.firstWhere(
      (t) => !t.premium && t.spec.layers.length >= 3,
    );
    final id = store.createDraftFromTemplate(free)!;
    final before = store.draftById(id)!;
    final layerCount = before.spec.layers.length;
    final kinds = before.spec.layers.map((l) => l.kind.name).toList();

    store.saveDraft(id, spec: before.spec);
    await store.hydrate(); // re-read from prefs via fresh store below

    final store2 = AppStore();
    await store2.hydrate();
    final after = store2.draftById(id)!;
    expect(after.spec.layers.length, layerCount);
    expect(after.spec.layers.map((l) => l.kind.name).toList(), kinds);

    // Explicit encode/decode path used by SharedPreferences.
    final encoded = jsonEncode(after.toJson());
    final decoded = Draft.fromJson(
      Map<String, dynamic>.from(jsonDecode(encoded) as Map),
    );
    expect(decoded.spec.layers.length, layerCount);
    expect(decoded.spec.layers.map((l) => l.kind.name).toList(), kinds);
  });

  test('Empty draw layers are detected for hit-test skip', () {
    final empty = Layer(
      id: 'd1',
      kind: LayerKind.draw,
      label: 'Draw',
      strokes: '[]',
    );
    final inked = empty.copyWith(
      strokes: jsonEncode([
        [
          [10.0, 10.0],
          [20.0, 20.0],
        ],
      ]),
    );
    expect(empty.isEmptyDraw, isTrue);
    expect(inked.isEmptyDraw, isFalse);
    expect(
      Layer(id: 't', kind: LayerKind.text, label: 'T').isEmptyDraw,
      isFalse,
    );
  });

  test('WidgetSpec.clone(remintLayerIds) preserves layer count', () {
    final tpl = Catalog.templates.firstWhere(
      (t) => t.id == 'analog-sport-badge',
    );
    final a = tpl.spec.clone(remintLayerIds: true);
    final b = tpl.spec.clone(remintLayerIds: true);
    expect(a.layers.length, tpl.spec.layers.length);
    expect(b.layers.length, tpl.spec.layers.length);
    expect(
      a.layers
          .map((l) => l.id)
          .toSet()
          .intersection(b.layers.map((l) => l.id).toSet()),
      isEmpty,
    );
  });
}
