import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drive_studio/core/theme/drive_colors.dart';
import 'package:drive_studio/core/theme/drive_theme.dart';
import 'package:drive_studio/data/catalog/background_library.dart';
import 'package:drive_studio/data/catalog/catalog.dart';
import 'package:drive_studio/data/models/models.dart';
import 'package:drive_studio/data/purchase/purchase_service.dart';
import 'package:drive_studio/data/store/app_group_export.dart';
import 'package:drive_studio/data/store/app_store.dart';
import 'package:drive_studio/presentation/widgets/layer_editor_overlay.dart';
import 'package:drive_studio/presentation/widgets/stock_layer_painters.dart';
import 'package:drive_studio/presentation/widgets/widget_canvas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AppStore hydrates and completes intro', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.hydrate();
    expect(store.ready, isTrue);
    expect(store.introDone, isFalse);
    expect(store.slots.length, 4);
    store.completeIntro();
    expect(store.introDone, isTrue);

    final store2 = AppStore();
    await store2.hydrate();
    expect(store2.introDone, isTrue);
  });

  testWidgets('Premium gate blocks until unlocked', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.hydrate();
    expect(store.isPremium, isFalse);
    expect(store.canUsePremiumContent(true), isFalse);
    store.unlockPremiumDebug();
    expect(store.isPremium, isTrue);
    expect(store.canUsePremiumContent(true), isTrue);
  });

  testWidgets('Premium templates and sounds stay gated', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.hydrate();

    final premiumTpl = Catalog.templates.firstWhere(
      (t) => t.premium,
      orElse: () => Catalog.templates.first,
    );
    expect(premiumTpl.premium, isTrue);
    expect(store.createDraftFromTemplate(premiumTpl), isNull);

    final premiumSound = Catalog.sounds.firstWhere(
      (s) => s.premium,
      orElse: () => Catalog.sounds.first,
    );
    expect(premiumSound.premium, isTrue);
    expect(store.trySetSound(premiumSound.group, premiumSound.id), isFalse);

    store.unlockPremiumDebug();
    final id = store.createDraftFromTemplate(premiumTpl);
    expect(id, isNotNull);
    expect(store.trySetSound(premiumSound.group, premiumSound.id), isTrue);
  });

  testWidgets('Draft CRUD: create save duplicate delete', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.hydrate();

    final free = Catalog.templates.firstWhere((t) => !t.premium);
    final id = store.createDraftFromTemplate(free)!;
    expect(store.drafts.length, 1);
    expect(store.draftById(id)?.name, contains(free.name));

    store.saveDraft(id, name: 'Renamed Drive', spec: free.spec);
    expect(store.draftById(id)?.name, 'Renamed Drive');

    final dup = store.duplicateDraft(id);
    expect(dup, isNotNull);
    expect(store.drafts.length, 2);

    store.assignSlot(0, id);
    expect(store.slots[0], id);
    store.deleteDraft(id);
    expect(store.draftById(id), isNull);
    expect(store.slots[0], isNull);
    expect(store.drafts.length, 1);
  });

  testWidgets('DebugPurchaseService unlocks via PurchaseService', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.hydrate();
    final purchases = DebugPurchaseService(store);
    await purchases.init();
    expect(purchases.supportsStoreKit, isFalse);
    final result = await purchases.purchasePremium();
    expect(result.ok, isTrue);
    expect(store.isPremium, isTrue);
    purchases.lockDebug();
    expect(store.isPremium, isFalse);
    await purchases.dispose();
  });

  testWidgets('Corrupt drafts are skipped safely', (tester) async {
    SharedPreferences.setMockInitialValues({
      'drive-studio-state-v1': '''
{
  "introDone": true,
  "drafts": [
    {"id": "good", "name": "Ok", "updatedAt": 1, "spec": {"background": {"type": "solid", "from": "#12141A"}, "layers": []}},
    {"broken": true},
    "not-an-object"
  ],
  "slots": ["good", "missing", null, null],
  "vehicle": {},
  "sounds": {},
  "isPremium": false
}
''',
    });
    final store = AppStore();
    await store.hydrate();
    expect(store.drafts.length, 1);
    expect(store.drafts.first.id, 'good');
    expect(store.corruptDraftSkips, greaterThanOrEqualTo(1));
    expect(store.slots[0], 'good');
    expect(store.slots[1], isNull);
  });

  testWidgets('App Group payload validates and includes summary', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.hydrate();
    final id = store.createDraft('Test', Catalog.templates.first.spec);
    store.assignSlot(0, id);
    final payload = await store.buildAppGroupPayload();
    expect(validateAppGroupPayload(payload), isTrue);
    expect(payload['schemaVersion'], appGroupSchemaVersion);
    expect((payload['slots'] as List).length, 4);
    final slot0 = (payload['slots'] as List).first as Map;
    expect(slot0['draftId'], id);
    expect(slot0['summary'], isA<Map>());
    expect(slot0['summary']['bgFrom'], isNotNull);
    final encoded = encodeAppGroupPayload(payload);
    expect(encoded.contains('"schemaVersion":1'), isTrue);
    expect(appGroupMirrorKey.contains('widget_state'), isTrue);
    expect(appGroupSuiteName, 'group.com.drivestudio.shared');
  });

  testWidgets('Locking premium strips premium sound assignments', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.hydrate();
    final premiumSound = Catalog.sounds.firstWhere((s) => s.premium);
    store.unlockPremiumDebug();
    expect(store.trySetSound(premiumSound.group, premiumSound.id), isTrue);
    expect(
      store.sounds.connect == premiumSound.id ||
          store.sounds.disconnect == premiumSound.id ||
          store.sounds.reminder == premiumSound.id,
      isTrue,
    );

    store.lockPremiumDebug();
    expect(store.isPremium, isFalse);
    for (final id in [
      store.sounds.connect,
      store.sounds.disconnect,
      store.sounds.reminder,
    ]) {
      if (id == null) continue;
      final cue = Catalog.soundById(id);
      expect(cue == null || !cue.premium, isTrue);
    }
  });

  testWidgets('Hydrate scrubs premium sounds when not premium', (tester) async {
    final premium = Catalog.sounds.firstWhere((s) => s.premium);
    SharedPreferences.setMockInitialValues({
      'drive-studio-state-v1':
          '''
{
  "introDone": true,
  "drafts": [],
  "slots": [null, null, null, null],
  "vehicle": {},
  "sounds": {"connect": "${premium.id}", "disconnect": null, "reminder": null},
  "isPremium": false
}
''',
    });
    final store = AppStore();
    await store.hydrate();
    expect(store.isPremium, isFalse);
    expect(store.sounds.connect, isNull);
  });

  testWidgets('App Group encode trims oversized specs', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.hydrate();
    // 256 * 1024 = 262144 chars is the trim threshold. Use 270000 to exceed it.
    final bigLayer = baseLayer(
      LayerKind.image,
      overrides: {'src': 'data:image/jpeg;base64,${'A' * 270000}'},
    );
    final id = store.createDraft(
      'Huge',
      WidgetSpec(
        background: const WidgetBackground(type: BgType.solid, from: '#12141A'),
        layers: [bigLayer],
      ),
    );
    store.assignSlot(0, id);
    final payload = await store.buildAppGroupPayload();
    expect(validateAppGroupPayload(payload), isTrue);
    final slot0 = (payload['slots'] as List).first as Map;
    final spec = slot0['spec'] as Map;
    final layers = spec['layers'] as List;
    expect(
      (layers.first as Map).containsKey('srcOmitted') ||
          !(layers.first as Map).containsKey('src'),
      isTrue,
    );
    final encoded = encodeAppGroupPayload(payload);
    expect(encoded.isNotEmpty, isTrue);
  });

  test('Catalog has free and premium templates', () {
    expect(Catalog.templates.where((t) => t.premium).length, greaterThan(0));
    expect(Catalog.templates.where((t) => !t.premium).length, greaterThan(0));
  });

  testWidgets('Theme is dark Electric Blue, not purple seed', (tester) async {
    final theme = buildDriveTheme();
    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, DriveColors.primary);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(body: Text('ok')),
      ),
    );
    expect(find.text('ok'), findsOneWidget);
  });

  testWidgets('WidgetCanvas renders clock layer without overflow', (
    tester,
  ) async {
    final spec = WidgetSpec(
      background: const WidgetBackground(
        type: BgType.gradient,
        from: '#101828',
        to: '#1E3A5F',
      ),
      layers: [
        baseLayer(
          LayerKind.clock,
          overrides: {'x': 10, 'y': 30, 'w': 80, 'h': 28, 'fontSize': 28},
        ),
        baseLayer(
          LayerKind.text,
          overrides: {'text': 'Drive', 'x': 10, 'y': 70},
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDriveTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: WidgetCanvas(spec: spec),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(WidgetCanvas), findsOneWidget);
  });

  test('Catalog has 12+ templates and 14+ sounds with premium mix', () {
    expect(Catalog.templates.length, greaterThanOrEqualTo(80));
    expect(Catalog.sounds.length, greaterThanOrEqualTo(14));
    expect(
      Catalog.templates.where((t) => t.premium).length,
      greaterThanOrEqualTo(4),
    );
    expect(
      Catalog.templates.where((t) => !t.premium).length,
      greaterThanOrEqualTo(4),
    );
    expect(Catalog.sounds.where((s) => s.premium).isNotEmpty, isTrue);
    // Fictional brands only
    expect(
      Catalog.brands.map((b) => b.id).toSet(),
      containsAll({'aurelio', 'velora', 'northstar', 'kinetic'}),
    );
    final cats = Catalog.templates.map((t) => t.category).toSet();
    expect(
      cats,
      containsAll({
        'Battery',
        'Digital Clock',
        'Analog Clock',
        'Calendar',
        'Drive',
        'Weather',
      }),
    );
    expect(Catalog.categories, containsAll(['Calendar', 'Drive', 'Weather']));
  });

  test('Stock templates have unique layout signatures', () {
    final ids = Catalog.templates.map((t) => t.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'duplicate template ids');

    String sig(TemplateItem t) {
      final bg =
          '${t.spec.background.type.name}:${t.spec.background.from}:${t.spec.background.to}';
      final layers = t.spec.layers
          .map(
            (l) =>
                '${l.kind.name}:${l.format}:${l.x.round()}:${l.y.round()}:${l.w.round()}:${l.h.round()}:${l.animStyle}',
          )
          .join('|');
      return '$bg::$layers';
    }

    final signatures = <String, String>{};
    for (final t in Catalog.templates) {
      final s = sig(t);
      final prior = signatures[s];
      expect(prior, isNull, reason: 'clone layout: ${t.id} matches $prior');
      signatures[s] = t.id;
    }

    // Within each category, battery/analog helpers must not share geometry.
    for (final cat in ['Battery', 'Analog Clock', 'Digital Clock']) {
      final group = Catalog.templates.where((t) => t.category == cat).toList();
      final geo = group.map((t) {
        final primary = t.spec.layers.firstWhere(
          (l) =>
              l.kind == LayerKind.battery ||
              l.kind == LayerKind.analog ||
              l.kind == LayerKind.clock,
          orElse: () => t.spec.layers.first,
        );
        return '${primary.kind.name}:${primary.format}:${primary.x}:${primary.y}:${primary.w}:${primary.h}:${t.spec.layers.length}';
      }).toList();
      expect(
        geo.toSet().length,
        geo.length,
        reason: '$cat near-clone geometry',
      );
    }
  });

  test('Bundled vehicle and sound asset paths cover catalog', () {
    expect(Catalog.sounds.length, greaterThanOrEqualTo(50));
    expect(
      Catalog.sounds.where((s) => s.group == SoundGroup.connect).length,
      greaterThanOrEqualTo(40),
    );
    for (final s in Catalog.sounds) {
      expect(s.assetPathOrDefault, startsWith('assets/sounds/'));
      expect(s.assetPathOrDefault, endsWith('.wav'));
      expect(s.durationMs, greaterThan(0));
    }
    for (final kind in ArtworkKind.values) {
      expect(
        Catalog.vehicleAssetForKind(kind),
        'assets/vehicles/${kind.name}.png',
      );
    }
    for (final id in Catalog.modelArtwork.keys) {
      expect(
        Catalog.vehicleAssetForModel(id),
        'assets/vehicles/models/$id.png',
      );
    }
  });

  test('Layer animate fields round-trip in JSON', () {
    final layer = baseLayer(
      LayerKind.battery,
      overrides: {
        'animate': true,
        'animStyle': 'shimmer',
        'text': '72',
        'format': 'ring',
        'color2': '#4DC98A',
        'color3': '#F2F5FA',
        'trackColor': '#1A2030',
        'animSpeed': 1.5,
      },
    );
    final again = Layer.fromJson(layer.toJson());
    expect(again.animate, isTrue);
    expect(again.animStyle, 'shimmer');
    expect(again.text, '72');
    expect(again.format, 'ring');
    expect(again.supportsAnimation, isTrue);
    expect(again.resolvedAnimStyle, 'shimmer');
    expect(again.color2, '#4DC98A');
    expect(again.color3, '#F2F5FA');
    expect(again.trackColor, '#1A2030');
    expect(again.animSpeed, 1.5);
  });

  test('Digital clock labels never trailing-colon', () {
    final stamp = DateTime(2026, 8, 2, 19, 35, 42);
    expect(formatClockLabel(stamp, '24', showSeconds: false), '19:35');
    expect(formatClockLabel(stamp, '24', showSeconds: true), '19:35:42');
    expect(formatClockLabel(stamp, 'HH:mm:', showSeconds: false), '19:35');
    expect(formatClockLabel(stamp, '12', showSeconds: false), '7:35');
    expect(baseLayer(LayerKind.clock).showSeconds, isFalse);
    expect(baseLayer(LayerKind.analog).showSeconds, isTrue);
    // Stock digital clocks with large type must not embed HH:mm:ss.
    for (final id in [
      'clock-digital',
      'clock-hhmm',
      'clock-pill',
      'clock-halo',
      'clock-neon-strip',
      'live-clock-hud',
    ]) {
      final t = Catalog.templates.firstWhere((e) => e.id == id);
      final main = t.spec.layers.firstWhere(
        (l) => l.kind == LayerKind.clock && l.format != 'ss',
      );
      expect(main.showSeconds, isFalse, reason: id);
    }
  });

  test('Anim style aliases and kind defaults resolve uniquely', () {
    expect(baseLayer(LayerKind.clock).resolvedAnimStyle, 'blink-colon');
    expect(baseLayer(LayerKind.analog).resolvedAnimStyle, 'hand-smooth');
    expect(baseLayer(LayerKind.battery).resolvedAnimStyle, 'shimmer');
    expect(baseLayer(LayerKind.badge).resolvedAnimStyle, 'glow-breathe');
    final legacy = baseLayer(
      LayerKind.analog,
      overrides: {'animStyle': 'smooth'},
    );
    expect(legacy.resolvedAnimStyle, 'hand-smooth');
    final colon = baseLayer(
      LayerKind.clock,
      overrides: {'animStyle': 'colon-blink'},
    );
    expect(colon.resolvedAnimStyle, 'blink-colon');
  });

  test('Background library has categories and premium subset', () {
    expect(BackgroundLibrary.all.length, greaterThanOrEqualTo(20));
    expect(
      BackgroundLibrary.all.where((p) => p.category == BgCategory.texture),
      isNotEmpty,
    );
    expect(
      BackgroundLibrary.all.where((p) => p.category == BgCategory.scene),
      isNotEmpty,
    );
    expect(BackgroundLibrary.all.where((p) => p.premium), isNotEmpty);
    final tex = BackgroundLibrary.all.firstWhere((p) => p.id == 'tex-carbon');
    expect(tex.background.type, BgType.image);
    expect(tex.background.imageSrc, startsWith('assets/backgrounds/'));
  });

  test('Live templates include clocks batteries and weather breathe', () {
    expect(
      Catalog.templates.where((t) => templateHasLiveMotion(t.spec)).length,
      greaterThan(10),
    );
    final analog = Catalog.templates.firstWhere(
      (t) => t.id == 'analog-classic',
    );
    expect(analog.spec.layers.first.animate, isTrue);
    expect(analog.spec.layers.first.resolvedAnimStyle, 'hand-smooth');
    final wx = Catalog.templates.firstWhere((t) => t.id == 'wx-outside-card');
    // Weather templates are clock/date art only — no fake °C; motion optional.
    expect(
      wx.spec.layers.any(
        (l) => l.kind == LayerKind.clock || l.kind == LayerKind.date,
      ),
      isTrue,
    );
    expect(
      wx.spec.layers.any(
        (l) =>
            l.kind == LayerKind.text &&
            (l.text.contains('°') || RegExp(r'^\d+$').hasMatch(l.text.trim())),
      ),
      isFalse,
    );
    final liveHud = Catalog.templates.firstWhere(
      (t) => t.id == 'live-clock-hud',
    );
    expect(templateHasLiveMotion(liveHud.spec), isTrue);
    expect(templatePrimaryAnimLabel(liveHud.spec), isNotNull);
    final day = Catalog.templates.firstWhere((t) => t.id == 'day-progress');
    expect(day.spec.layers.any((l) => l.format == 'dayprogress'), isTrue);
    final styles = Catalog.templates
        .expand((t) => t.spec.layers)
        .where((l) => l.animate && l.animStyle.isNotEmpty)
        .map((l) => l.animStyle)
        .toSet();
    expect(styles.length, greaterThanOrEqualTo(6));
  });

  testWidgets('Editor overlay survives clock paint ticks', (tester) async {
    final paintTick = ValueNotifier<int>(0);
    final editorKey = GlobalKey();
    final layer = baseLayer(
      LayerKind.clock,
      overrides: {
        'x': 10,
        'y': 30,
        'w': 80,
        'h': 28,
        'fontSize': 28,
        'animate': true,
      },
    );
    final spec = WidgetSpec(
      background: const WidgetBackground(type: BgType.solid, from: '#12141A'),
      layers: [layer],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDriveTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 320,
              child: WidgetCanvas(
                spec: spec,
                tickSeconds: 1,
                paintListenable: paintTick,
                child: LayerEditorOverlay(
                  key: editorKey,
                  spec: spec,
                  selectedId: layer.id,
                  onSelect: (_) {},
                  onGeometryPreview: (_, __, ___, ____, _____) {},
                  onGeometryCommit: (_, __, ___, ____, _____) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final stateBefore = editorKey.currentState;
    expect(stateBefore, isNotNull);

    paintTick.value++;
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(editorKey.currentState, same(stateBefore));
    expect(tester.takeException(), isNull);
    paintTick.dispose();
  });

  testWidgets('Logo asset layers use StoredImage not fixed monogram', (
    tester,
  ) async {
    final layer =
        baseLayer(
          LayerKind.image,
          overrides: {'x': 20, 'y': 20, 'w': 60, 'h': 60},
        ).copyWith(
          role: 'logo',
          src: 'assets/logos/bmw.png',
          text: 'BMW',
          fit: BoxFit.contain,
        );
    final spec = WidgetSpec(
      background: const WidgetBackground(type: BgType.solid, from: '#12141A'),
      layers: [layer],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDriveTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 220,
              height: 220,
              child: WidgetCanvas(spec: spec),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(StoredImage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Animated battery and analog paint without crashing', (
    tester,
  ) async {
    final spec = WidgetSpec(
      background: const WidgetBackground(type: BgType.solid, from: '#12141A'),
      layers: [
        baseLayer(
          LayerKind.battery,
          overrides: {
            'animate': true,
            'animStyle': 'shimmer',
            'format': 'ring',
            'x': 10,
            'y': 10,
            'w': 40,
            'h': 40,
          },
        ),
        baseLayer(
          LayerKind.analog,
          overrides: {
            'animate': true,
            'animStyle': 'hand-smooth',
            'format': 'classic',
            'x': 50,
            'y': 10,
            'w': 40,
            'h': 40,
            'color2': '#F2F5FA',
            'trackColor': '#12141A',
          },
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDriveTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 220,
              height: 220,
              child: WidgetCanvas(spec: spec),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('previewMode wires samplePreview; live path does not', (
    tester,
  ) async {
    final layer = baseLayer(
      LayerKind.battery,
      overrides: {
        'format': 'panel',
        'x': 5,
        'y': 5,
        'w': 90,
        'h': 90,
        'animate': false,
      },
    );
    final spec = WidgetSpec(
      background: const WidgetBackground(type: BgType.solid, from: '#0E1218'),
      layers: [layer],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDriveTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 220,
              height: 220,
              child: WidgetCanvas(spec: spec, previewMode: true),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final previewBatt = tester.widget<BatteryLayerView>(
      find.byType(BatteryLayerView),
    );
    expect(previewBatt.samplePreview, isTrue);
    // Catalog fill resolves to stable 72% without DeviceTelemetry.
    expect(resolveDisplayBatteryPercent(layer, null, samplePreview: true), 72);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDriveTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 220,
              height: 220,
              child: WidgetCanvas(
                spec: spec,
                previewMode: false,
                samplePreview: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final liveBatt = tester.widget<BatteryLayerView>(
      find.byType(BatteryLayerView),
    );
    expect(liveBatt.samplePreview, isFalse);
    expect(
      resolveDisplayBatteryPercent(layer, null, samplePreview: false),
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}
