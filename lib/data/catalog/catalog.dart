import '../models/models.dart';
import 'layer_factory.dart';
import 'sound_library.dart';
import 'apex_templates.dart';
import 'stock_widget_templates.dart';

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
    apexTemplateCategory,
    'Digital Clock',
    'Analog Clock',
    'Calendar',
    'Drive',
    'Battery',
    'Featured',
    'Minimal',
    'Night',
    'Utility',
    'Travel',
    'Performance',
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

  static final templates = <TemplateItem>[
    TemplateItem(
      id: "blank",
      name: "Blank Canvas",
      category: "Minimal",
      premium: false,
      createdAt: "2026-08-01",
      spec: _spec('#0C1016', '#182232', []),
    ),
    ...buildApexWidgetTemplates(),
    ...buildStockWidgetTemplates().where(
      (template) => template.category != 'Weather',
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
