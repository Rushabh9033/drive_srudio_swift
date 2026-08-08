import '../models/anim_styles.dart';
import '../models/models.dart';
import 'layer_factory.dart';
import 'sound_library.dart';
import 'stock_widget_templates.dart';
import 'apex_templates.dart';

export 'layer_factory.dart'
    show
        baseLayer,
        composeSpeedometerLayers,
        countSpeedometerClusters,
        templateHasLiveMotion,
        templatePrimaryAnimLabel;
export 'sound_library.dart';

WidgetSpec _spec(
  String from,
  String to,
  List<Layer> layers, {
  BgType type = BgType.gradient,
}) {
  return WidgetSpec(
    background: WidgetBackground(type: type, from: from, to: to),
    layers: layers,
  );
}

abstract final class Catalog {
  static const categories = [
    'Speedometer',
    'Digital Clock',
    'Analog Clock',
    'Calendar',
    'Drive',
    'Battery',
    'Weather',
    'Featured',
    'Minimal',
    'Night',
    'Utility',
    'Travel',
    'Performance',
    'Apex',
  ];

  static const brands = [
    VehicleBrand(
      id: 'aurelio',
      name: 'Aurelio',
      tagline: 'Sculpted grand touring',
      models: [
        VehicleModel(id: 'aurelio-gt', name: 'GT Corsa'),
        VehicleModel(id: 'aurelio-lumen', name: 'Lumen S'),
        VehicleModel(id: 'aurelio-vento', name: 'Vento'),
      ],
    ),
    VehicleBrand(
      id: 'velora',
      name: 'Velora',
      tagline: 'Electric performance',
      models: [
        VehicleModel(id: 'velora-pulse', name: 'V8 Pulse'),
        VehicleModel(id: 'velora-ex', name: 'EX Coupe'),
        VehicleModel(id: 'velora-arc', name: 'Arc Sedan'),
      ],
    ),
    VehicleBrand(
      id: 'northstar',
      name: 'Northstar',
      tagline: 'Expedition utility',
      models: [
        VehicleModel(id: 'northstar-trail', name: 'Trail 90'),
        VehicleModel(id: 'northstar-peak', name: 'Peak XL'),
      ],
    ),
    VehicleBrand(
      id: 'kinetic',
      name: 'Kinetic',
      tagline: 'Urban compact',
      models: [
        VehicleModel(id: 'kinetic-mono', name: 'Mono One'),
        VehicleModel(id: 'kinetic-flux', name: 'Flux'),
      ],
    ),
  ];

  /// Master voice library (connect / disconnect / reminder) from studio WAVs.
  static final List<SoundCue> sounds = SoundLibrary.cues;

  /// Default artwork kind for each catalog model (car-picker heroes).
  static const modelArtwork = <String, ArtworkKind>{
    'aurelio-gt': ArtworkKind.coupe,
    'aurelio-lumen': ArtworkKind.sedan,
    'aurelio-vento': ArtworkKind.roadster,
    'velora-pulse': ArtworkKind.coupe,
    'velora-ex': ArtworkKind.coupe,
    'velora-arc': ArtworkKind.sedan,
    'northstar-trail': ArtworkKind.suv,
    'northstar-peak': ArtworkKind.wagon,
    'kinetic-mono': ArtworkKind.hatch,
    'kinetic-flux': ArtworkKind.hatch,
  };

  static String vehicleAssetForKind(ArtworkKind kind) =>
      'assets/vehicles/${kind.name}.png';

  static String? vehicleAssetForModel(String modelId) {
    final path = 'assets/vehicles/models/$modelId.png';
    if (modelArtwork.containsKey(modelId)) return path;
    return null;
  }

  static ArtworkKind artworkForModel(String modelId) =>
      modelArtwork[modelId] ?? ArtworkKind.coupe;

  /// Premium-only subset of [templates]. Useful for the "Upgrade" card and
  /// the recently-added / stock highlight reels on the home screen.
  static List<TemplateItem> get premiumTemplates =>
      templates.where((t) => t.premium).toList(growable: false);

  /// Free-only subset of [templates]. Useful for the Featured rail / chip
  /// filters that should never surface locked content.
  static List<TemplateItem> get freeTemplates =>
      templates.where((t) => !t.premium).toList(growable: false);

  /// Templates visible to the current user.
  ///
  /// - When [isPremium] is true, every catalog item is returned.
  /// - When false, every item is *still* returned so the UI can render
  ///   premium tiles as Upgrade placeholders rather than hiding them.
  ///   Use the per-item [TemplateItem.premium] flag (combined with
  ///   [isPremium]) to decide whether to render the preview or a locked
  ///   placeholder.
  static List<TemplateItem> visibleTemplates({required bool isPremium}) {
    // Both groups see the full catalog; gating is decided at the render
    // layer so the upgrade path is always visible.
    return templates;
  }

  /// True when the user should see premium templates as locked
  /// placeholders instead of the live preview.
  static bool isLocked(TemplateItem t, {required bool isPremium}) =>
      t.premium && !isPremium;

  static final templates = <TemplateItem>[
    ...buildApexWidgetTemplates(),
    ...buildStockWidgetTemplates(),
    TemplateItem(
      id: 'midnight-run',
      name: 'Midnight Run',
      category: 'Night',
      premium: false,
      createdAt: '2026-07-18',
      spec: _spec('#060A14', '#101828', [
        baseLayer(LayerKind.shape, overrides: {
          'x': 0,
          'y': 0,
          'w': 100,
          'h': 22,
          'radius': 0,
          'color': '#0A1428',
        }),
        baseLayer(LayerKind.text, overrides: {
          'text': 'MIDNIGHT RUN',
          'x': 10,
          'y': 6,
          'fontSize': 10,
          'letterSpacing': 2,
          'color': '#7FB6FF',
        }),
        baseLayer(LayerKind.clock, overrides: {
          'x': 10,
          'y': 32,
          'w': 56,
          'h': 28,
          'fontSize': 28,
          'weight': 800,
          'showSeconds': false,
        }),
        baseLayer(LayerKind.battery, overrides: {
          'label': 'Midnight range',
          'format': 'pill',
          'text': '',
          'x': 10,
          'y': 66,
          'w': 50,
          'h': 22,
          'color': '#4D9EFF',
          'animate': true,
          'animStyle': AnimStyles.progressLoop,
        }),
        baseLayer(LayerKind.badge, overrides: {
          'label': 'Car Link',
          'text': 'Car link',
          'format': 'carlink',
          'role': 'telemetry:carlink',
          'x': 64,
          'y': 34,
          'w': 28,
          'h': 36,
          'fontSize': 10,
          'color': '#4DC98A',
        }),
      ]),
    ),
    TemplateItem(
      id: 'pure-lines',
      name: 'Pure Lines',
      category: 'Minimal',
      premium: false,
      createdAt: '2026-07-19',
      spec: WidgetSpec(
        background: const WidgetBackground(type: BgType.solid, from: '#0E0F12'),
        layers: [
          baseLayer(LayerKind.divider, overrides: {
            'x': 12,
            'y': 20,
            'w': 76,
            'h': 1,
            'color': '#2A2F3A',
          }),
          baseLayer(LayerKind.divider, overrides: {
            'x': 12,
            'y': 80,
            'w': 76,
            'h': 1,
            'color': '#2A2F3A',
          }),
          baseLayer(LayerKind.text, overrides: {
            'text': 'DRIVE',
            'x': 12,
            'y': 28,
            'fontSize': 11,
            'letterSpacing': 6,
            'color': '#6A7080',
          }),
          baseLayer(LayerKind.clock, overrides: {
            'x': 12,
            'y': 46,
            'fontSize': 26,
            'weight': 300,
            'h': 24,
            'letterSpacing': 4,
            'showSeconds': false,
          }),
        ],
      ),
    ),
    TemplateItem(
      id: 'trip-meter',
      name: 'Trip Meter',
      category: 'Travel',
      premium: true,
      createdAt: '2026-07-20',
      spec: _spec('#132118', '#20463A', [
        baseLayer(LayerKind.badge, overrides: {
          'text': 'TRIP',
          'x': 12,
          'y': 12,
          'color': '#4DC98A',
        }),
        baseLayer(LayerKind.clock, overrides: {
          'x': 12, 'y': 32, 'w': 76, 'h': 32, 'fontSize': 32, 'weight': 800,
          'format': '24', 'showSeconds': false,
        }),
        baseLayer(LayerKind.divider, overrides: {
          'x': 12, 'y': 68, 'w': 36, 'color': '#4DC98A',
        }),
        baseLayer(LayerKind.date, overrides: {
          'x': 12, 'y': 76, 'fontSize': 11, 'format': 'abbrev', 'color': '#A8B6CC',
        }),
      ]),
    ),
    TemplateItem(
      id: 'carbon-grid',
      name: 'Carbon Grid',
      category: 'Performance',
      premium: true,
      createdAt: '2026-07-21',
      spec: _spec('#16181D', '#2A2F3A', [
        baseLayer(LayerKind.shape, overrides: {
          'x': 10,
          'y': 12,
          'w': 26,
          'h': 26,
          'color': '#2A2F3A',
        }),
        baseLayer(LayerKind.text, overrides: {
          'text': 'LAP',
          'x': 42,
          'y': 14,
          'fontSize': 11,
          'letterSpacing': 2,
          'color': '#7FB6FF',
        }),
        baseLayer(LayerKind.text, overrides: {
          'text': 'S1',
          'x': 42,
          'y': 28,
          'fontSize': 10,
          'color': '#A8B6CC',
        }),
        baseLayer(LayerKind.clock, overrides: {
          'x': 12, 'y': 48, 'w': 76, 'h': 26, 'fontSize': 26, 'weight': 800,
          'format': '24', 'showSeconds': true,
        }),
        baseLayer(LayerKind.clock, overrides: {
          'x': 12,
          'y': 78,
          'fontSize': 12,
          'weight': 500,
          'h': 14,
        }),
      ]),
    ),
    TemplateItem(
      id: 'commuter',
      name: 'Commuter',
      category: 'Utility',
      premium: false,
      createdAt: '2026-07-22',
      spec: _spec('#141519', '#262A33', [
        baseLayer(LayerKind.text, overrides: {
          'text': 'COMMUTE',
          'x': 10,
          'y': 10,
          'fontSize': 9,
          'letterSpacing': 2,
          'color': '#7FB6FF',
        }),
        baseLayer(LayerKind.badge, overrides: {
          'text': 'COMMUTE',
          'x': 10,
          'y': 28,
          'w': 56,
          'color': '#4DC98A',
          'animate': true,
          'animStyle': AnimStyles.pulse,
        }),
        baseLayer(LayerKind.clock, overrides: {
          'x': 10,
          'y': 52,
          'w': 50,
          'fontSize': 22,
          'weight': 800,
          'h': 22,
          'showSeconds': false,
        }),
        baseLayer(LayerKind.date, overrides: {
          'x': 10,
          'y': 80,
          'fontSize': 11,
          'format': 'weekdayShort',
          'color': '#A8B6CC',
        }),
        baseLayer(LayerKind.battery, overrides: {
          'label': 'Commuter', 'format': 'icon', 'text': '',
          'x': 66, 'y': 50, 'w': 28, 'h': 28, 'color': '#7EB8FF',
        }),
      ]),
    ),
    TemplateItem(
      id: 'aurora-drive',
      name: 'Aurora Drive',
      category: 'Featured',
      premium: false,
      createdAt: '2026-07-23',
      spec: _spec('#101A2B', '#2C4C7C', [
        baseLayer(LayerKind.text, overrides: {
          'text': 'AURORA',
          'x': 12,
          'y': 12,
          'fontSize': 11,
          'letterSpacing': 3,
          'color': '#7FB6FF',
        }),
        baseLayer(LayerKind.text, overrides: {
          'text': 'Northbound',
          'x': 12,
          'y': 30,
          'fontSize': 20,
          'weight': 700,
        }),
        baseLayer(LayerKind.clock, overrides: {
          'x': 12,
          'y': 54,
          'fontSize': 16,
          'weight': 600,
          'h': 16,
        }),
        baseLayer(LayerKind.divider, overrides: {'x': 12, 'y': 74, 'w': 36}),
        baseLayer(LayerKind.text, overrides: {
          'text': 'Night drive art',
          'x': 12,
          'y': 80,
          'fontSize': 12,
          'color': '#A8B6CC',
        }),
      ]),
    ),
    TemplateItem(
      id: 'night-shift',
      name: 'Night Shift',
      category: 'Night',
      premium: true,
      createdAt: '2026-07-24',
      spec: _spec('#0B0C10', '#1B1F2A', [
        baseLayer(LayerKind.shape, overrides: {
          'x': 8,
          'y': 8,
          'w': 84,
          'h': 84,
          'radius': 12,
          'color': '#12141A',
        }),
        baseLayer(LayerKind.badge, overrides: {
          'text': 'NIGHT',
          'x': 16,
          'y': 16,
          'w': 44,
          'color': '#7FB6FF',
          'animate': true,
          'animStyle': AnimStyles.breathe,
        }),
        baseLayer(LayerKind.analog, overrides: {
          'label': 'Night Shift',
          'format': 'minimal',
          'x': 50,
          'y': 14,
          'w': 34,
          'h': 34,
          'color': '#4D9EFF',
          'animate': true,
          'animStyle': AnimStyles.handSmooth,
          'showSeconds': false,
        }),
        baseLayer(LayerKind.clock, overrides: {
          'x': 16,
          'y': 48,
          'w': 68,
          'fontSize': 28,
          'weight': 800,
          'h': 26,
          'showSeconds': false,
        }),
        baseLayer(LayerKind.date, overrides: {
          'x': 16,
          'y': 78,
          'fontSize': 11,
          'format': 'abbrev',
          'color': '#A8B6CC',
        }),
      ]),
    ),
    TemplateItem(
      id: 'cargo',
      name: 'Cargo',
      category: 'Utility',
      premium: false,
      createdAt: '2026-07-25',
      spec: _spec('#1A1509', '#3A2E12', [
        baseLayer(LayerKind.badge, overrides: {
          'text': 'LOAD',
          'x': 12,
          'y': 12,
          'color': '#E5B84A',
        }),
        baseLayer(LayerKind.battery, overrides: {
          'label': 'Cargo', 'format': 'large', 'text': '',
          'x': 8, 'y': 28, 'w': 70, 'h': 40, 'color': '#E5B84A',
        }),
        baseLayer(LayerKind.badge, overrides: {
          'label': 'Charging', 'text': 'Charge', 'format': 'charging',
          'role': 'telemetry:charging',
          'x': 12, 'y': 74, 'w': 40, 'h': 14, 'color': '#A8B6CC',
        }),
        baseLayer(LayerKind.divider, overrides: {
          'x': 12,
          'y': 86,
          'w': 50,
          'color': '#E5B84A',
        }),
      ]),
    ),
    TemplateItem(
      id: 'lumen-range',
      name: 'Lumen Range',
      category: 'Featured',
      premium: false,
      createdAt: '2026-07-26',
      spec: _spec('#0F141C', '#1A3348', [
        baseLayer(LayerKind.shape, overrides: {
          'x': 8,
          'y': 8,
          'w': 84,
          'h': 18,
          'color': '#1E2A3A',
        }),
        baseLayer(LayerKind.text, overrides: {
          'text': 'AURELIO LUMEN',
          'x': 12,
          'y': 11,
          'fontSize': 10,
          'letterSpacing': 1.5,
          'color': '#7FB6FF',
        }),
        baseLayer(LayerKind.clock, overrides: {
          'x': 12,
          'y': 34,
          'w': 70,
          'h': 26,
          'fontSize': 30,
          'weight': 800,
        }),
        baseLayer(LayerKind.divider, overrides: {
          'x': 12,
          'y': 64,
          'w': 32,
          'color': '#4D9EFF',
        }),
        baseLayer(LayerKind.text, overrides: {
          'text': 'Quiet mode art',
          'x': 12,
          'y': 72,
          'fontSize': 12,
          'color': '#A8B6CC',
        }),
        baseLayer(LayerKind.badge, overrides: {
          'text': 'EV',
          'x': 72,
          'y': 72,
          'w': 18,
          'h': 14,
          'color': '#4DC98A',
        }),
      ]),
    ),
    TemplateItem(
      id: 'velora-pulse',
      name: 'Velora Pulse',
      category: 'Performance',
      premium: true,
      createdAt: '2026-07-27',
      spec: _spec('#120E18', '#2A1838', [
        baseLayer(LayerKind.badge, overrides: {
          'text': 'PULSE',
          'x': 12,
          'y': 12,
          'w': 48,
          'color': '#7FB6FF',
        }),
        baseLayer(LayerKind.text, overrides: {
          'text': 'PULSE',
          'x': 12,
          'y': 34,
          'fontSize': 12,
          'letterSpacing': 2,
          'color': '#A8B6CC',
        }),
        baseLayer(LayerKind.clock, overrides: {
          'x': 12, 'y': 48, 'w': 76, 'h': 32, 'fontSize': 32, 'weight': 800,
          'format': '24', 'showSeconds': false,
        }),
        baseLayer(LayerKind.divider, overrides: {
          'x': 12,
          'y': 82,
          'w': 40,
          'color': '#4D9EFF',
        }),
        baseLayer(LayerKind.date, overrides: {
          'x': 56,
          'y': 80,
          'fontSize': 11,
          'color': '#A8B6CC',
        }),
      ]),
    ),
    TemplateItem(
      id: 'trail-compass',
      name: 'Trail Compass',
      category: 'Travel',
      premium: false,
      createdAt: '2026-07-28',
      spec: _spec('#12180F', '#2A3A1C', [
        baseLayer(LayerKind.text, overrides: {
          'text': 'NORTHSTAR',
          'x': 12,
          'y': 12,
          'fontSize': 10,
          'letterSpacing': 2,
          'color': '#4DC98A',
        }),
        baseLayer(LayerKind.text, overrides: {
          'text': 'Peak XL',
          'x': 12,
          'y': 28,
          'fontSize': 20,
          'weight': 700,
        }),
        baseLayer(LayerKind.shape, overrides: {
          'x': 70,
          'y': 14,
          'w': 18,
          'h': 18,
          'color': '#2A3A1C',
        }),
        baseLayer(LayerKind.clock, overrides: {
          'x': 12,
          'y': 56,
          'fontSize': 18,
          'weight': 700,
          'h': 18,
        }),
        baseLayer(LayerKind.text, overrides: {
          'text': 'Trail art · clear',
          'x': 12,
          'y': 80,
          'fontSize': 11,
          'color': '#A8B6CC',
        }),
      ]),
    ),
    TemplateItem(
      id: 'kinetic-metro',
      name: 'Kinetic Metro',
      category: 'Minimal',
      premium: false,
      createdAt: '2026-07-29',
      spec: _spec('#10141C', '#1A2838', [
        baseLayer(LayerKind.badge, overrides: {
          'text': 'METRO',
          'x': 10,
          'y': 10,
          'w': 44,
          'color': '#4D9EFF',
          'animate': true,
          'animStyle': AnimStyles.slideInLoop,
        }),
        baseLayer(LayerKind.clock, overrides: {
          'x': 10,
          'y': 34,
          'w': 48,
          'h': 28,
          'fontSize': 26,
          'weight': 800,
          'format': 'hh',
          'showSeconds': false,
        }),
        baseLayer(LayerKind.clock, overrides: {
          'x': 56,
          'y': 34,
          'w': 36,
          'h': 28,
          'fontSize': 26,
          'weight': 300,
          'format': 'mm',
          'showSeconds': false,
          'color': '#7EB8FF',
        }),
        baseLayer(LayerKind.shape, overrides: {
          'x': 10,
          'y': 72,
          'w': 80,
          'h': 16,
          'radius': 4,
          'color': '#1A2740',
        }),
        baseLayer(LayerKind.text, overrides: {
          'text': 'Metro art',
          'x': 16,
          'y': 74,
          'fontSize': 11,
          'color': '#A8B6CC',
        }),
      ]),
    ),
    TemplateItem(
      id: 'ember-night',
      name: 'Ember Night',
      category: 'Night',
      premium: true,
      createdAt: '2026-07-30',
      spec: _spec('#1A100C', '#3A2218', [
        baseLayer(LayerKind.badge, overrides: {
          'text': 'EMBER',
          'x': 12,
          'y': 12,
          'w': 52,
          'color': '#E5B84A',
        }),
        baseLayer(LayerKind.clock, overrides: {
          'x': 12,
          'y': 36,
          'fontSize': 34,
          'weight': 800,
          'h': 30,
        }),
        baseLayer(LayerKind.text, overrides: {
          'text': 'Cabin night art',
          'x': 12,
          'y': 74,
          'fontSize': 12,
          'color': '#A8B6CC',
        }),
        baseLayer(LayerKind.divider, overrides: {
          'x': 12,
          'y': 90,
          'w': 36,
          'color': '#E05A45',
        }),
      ]),
    ),
    TemplateItem(
      id: 'harbor-eta',
      name: 'Harbor ETA',
      category: 'Utility',
      premium: true,
      createdAt: '2026-07-31',
      spec: _spec('#0C141A', '#1A2E3A', [
        baseLayer(LayerKind.text, overrides: {
          'text': 'ARRIVAL',
          'x': 12,
          'y': 12,
          'fontSize': 11,
          'letterSpacing': 2,
          'color': '#7FB6FF',
        }),
        baseLayer(LayerKind.clock, overrides: {
          'x': 12, 'y': 30, 'w': 76, 'h': 36, 'fontSize': 36, 'weight': 800,
          'format': '24', 'showSeconds': false, 'animate': true, 'animStyle': AnimStyles.blinkColon,
        }),
        baseLayer(LayerKind.badge, overrides: {
          'label': 'Car Link', 'text': 'Car link', 'format': 'carlink',
          'role': 'telemetry:carlink',
          'x': 12, 'y': 72, 'w': 58, 'color': '#4DC98A',
        }),
        baseLayer(LayerKind.clock, overrides: {
          'x': 74,
          'y': 74,
          'w': 20,
          'h': 12,
          'fontSize': 11,
          'weight': 500,
        }),
      ]),
    ),
  ];

  static VehicleBrand? brandById(String id) {
    for (final b in brands) {
      if (b.id == id) return b;
    }
    return null;
  }

  static VehicleModel? modelById(String brandId, String modelId) {
    final b = brandById(brandId);
    if (b == null) return null;
    for (final m in b.models) {
      if (m.id == modelId) return m;
    }
    return null;
  }

  static TemplateItem? templateById(String id) {
    for (final t in templates) {
      if (t.id == id) return t;
    }
    return null;
  }

  static SoundCue? soundById(String? id) {
    if (id == null) return null;
    for (final s in sounds) {
      if (s.id == id) return s;
    }
    return null;
  }
}
