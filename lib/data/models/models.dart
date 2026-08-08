import 'package:flutter/painting.dart';
import 'package:uuid/uuid.dart';

import 'anim_styles.dart';

const _layerIdUuid = Uuid();

enum LayerKind {
  text,
  image,
  clock,
  date,
  badge,
  divider,
  shape,
  draw,

  /// Device battery visual. [Layer.format] selects template style.
  /// Percent comes only from live phone battery (`battery_plus`); when
  /// unavailable the canvas shows "—" / Unavailable — never invented %.
  battery,

  /// Analog clock face with live hands. [Layer.format] selects face style.
  analog,
}

enum ArtworkKind { coupe, sedan, suv, wagon, roadster, hatch }

enum SoundGroup { connect, disconnect, reminder }

class Layer {
  Layer({
    required this.id,
    required this.kind,
    required this.label,
    this.text = '',
    this.x = 10,
    this.y = 20,
    this.w = 80,
    this.h = 18,
    this.fontSize = 14,
    this.weight = 600,
    this.align = TextAlign.left,
    this.color = '#F2F5FA',
    this.opacity = 1,
    this.radius = 0,
    this.letterSpacing = 0,
    this.shadow = false,
    this.locked = false,
    this.hidden = false,
    this.fit = BoxFit.cover,
    this.flipH = false,
    this.maxLines = 2,
    this.src,
    this.role = '',
    this.format = '',
    this.color2,
    this.color3,
    this.trackColor,
    this.shadowColor,
    this.strokes = '',
    this.animate = false,
    this.animStyle = '',
    this.animSpeed = 1,
    this.showSeconds = false,
  });

  final String id;
  final LayerKind kind;
  String label;
  String text;
  double x;
  double y;
  double w;
  double h;
  double fontSize;
  int weight;
  TextAlign align;
  String color;
  double opacity;
  double radius;
  double letterSpacing;
  bool shadow;
  bool locked;
  bool hidden;
  BoxFit fit;
  bool flipH;
  int maxLines;

  /// File path, data URL, network URL, or `monogram:Brand` for [LayerKind.image].
  String? src;

  /// Semantic role: logo | stock | gallery | ''.
  String role;

  /// Clock: `12` | `24`. Date: `short` | `medium` | `full` | `abbrev`.
  /// Battery: `panel` | `metrics` | `icon` | `dots` | `matrix` | `lightning` |
  /// `pill` | `pie` | `large` | `ring` | `dayprogress` | …
  /// Analog: `classic` | `minimal` | `neon` | `rings` | `sport` | `arc` | …
  String format;

  /// Secondary / accent / gradient end / hand color.
  String? color2;

  /// Tertiary: label text, tick marks, etc.
  String? color3;

  /// Track / face / background accent fill.
  String? trackColor;
  String? shadowColor;

  /// JSON stroke paths for [LayerKind.draw]: list of point lists in 0–100 space.
  String strokes;

  /// When true, layer runs isolated motion (pulse / shimmer / colon blink / smooth hands).
  bool animate;

  /// Motion style id — see [AnimStyles]. Empty uses kind default.
  String animStyle;

  /// Motion speed multiplier (0.35–2.5). Default 1.
  double animSpeed;

  /// Analog / digital: show second hand or seconds field.
  bool showSeconds;

  /// Kinds that support the editor Animate toggle / motion FX.
  bool get supportsAnimation =>
      kind == LayerKind.clock ||
      kind == LayerKind.analog ||
      kind == LayerKind.battery ||
      kind == LayerKind.badge ||
      kind == LayerKind.shape ||
      kind == LayerKind.text ||
      kind == LayerKind.date;

  /// Resolved motion style when [animate] is on.
  String get resolvedAnimStyle {
    if (animStyle.isNotEmpty) return AnimStyles.normalize(animStyle);
    return switch (kind) {
      LayerKind.battery => AnimStyles.shimmer,
      LayerKind.analog => AnimStyles.handSmooth,
      LayerKind.clock => AnimStyles.blinkColon,
      LayerKind.badge || LayerKind.shape => AnimStyles.glowBreathe,
      LayerKind.date || LayerKind.text => AnimStyles.breathe,
      _ => AnimStyles.breathe,
    };
  }

  double get resolvedAnimSpeed => animSpeed.clamp(0.35, 2.5);

  bool get isLogo =>
      role == 'logo' ||
      (src?.startsWith('monogram:') ?? false) ||
      (src?.startsWith('assets/logos/') ?? false);
  bool get isStockImage => role == 'stock' || role == 'gallery';

  /// Full-canvas draw layer with no ink — must not steal editor hit-tests.
  bool get isEmptyDraw {
    if (kind != LayerKind.draw) return false;
    final raw = strokes.trim();
    return raw.isEmpty || raw == '[]' || raw == 'null';
  }

  Layer copyWith({
    String? id,
    String? label,
    String? text,
    double? x,
    double? y,
    double? w,
    double? h,
    double? fontSize,
    int? weight,
    TextAlign? align,
    String? color,
    double? opacity,
    double? radius,
    double? letterSpacing,
    bool? shadow,
    bool? locked,
    bool? hidden,
    BoxFit? fit,
    bool? flipH,
    int? maxLines,
    String? src,
    bool clearSrc = false,
    String? role,
    String? format,
    String? color2,
    bool clearColor2 = false,
    String? color3,
    bool clearColor3 = false,
    String? trackColor,
    bool clearTrackColor = false,
    String? shadowColor,
    bool clearShadowColor = false,
    String? strokes,
    bool? animate,
    String? animStyle,
    double? animSpeed,
    bool? showSeconds,
  }) {
    return Layer(
      id: id ?? this.id,
      kind: kind,
      label: label ?? this.label,
      text: text ?? this.text,
      x: x ?? this.x,
      y: y ?? this.y,
      w: w ?? this.w,
      h: h ?? this.h,
      fontSize: fontSize ?? this.fontSize,
      weight: weight ?? this.weight,
      align: align ?? this.align,
      color: color ?? this.color,
      opacity: opacity ?? this.opacity,
      radius: radius ?? this.radius,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      shadow: shadow ?? this.shadow,
      locked: locked ?? this.locked,
      hidden: hidden ?? this.hidden,
      fit: fit ?? this.fit,
      flipH: flipH ?? this.flipH,
      maxLines: maxLines ?? this.maxLines,
      src: clearSrc ? null : (src ?? this.src),
      role: role ?? this.role,
      format: format ?? this.format,
      color2: clearColor2 ? null : (color2 ?? this.color2),
      color3: clearColor3 ? null : (color3 ?? this.color3),
      trackColor: clearTrackColor ? null : (trackColor ?? this.trackColor),
      shadowColor: clearShadowColor ? null : (shadowColor ?? this.shadowColor),
      strokes: strokes ?? this.strokes,
      animate: animate ?? this.animate,
      animStyle: animStyle ?? this.animStyle,
      animSpeed: animSpeed ?? this.animSpeed,
      showSeconds: showSeconds ?? this.showSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'label': label,
    'text': text,
    'x': x,
    'y': y,
    'w': w,
    'h': h,
    'fontSize': fontSize,
    'weight': weight,
    'align': align.name,
    'color': color,
    'opacity': opacity,
    'radius': radius,
    'letterSpacing': letterSpacing,
    'shadow': shadow,
    'locked': locked,
    'hidden': hidden,
    'fit': fit.name,
    'flipH': flipH,
    'maxLines': maxLines,
    if (src != null) 'src': src,
    if (role.isNotEmpty) 'role': role,
    if (format.isNotEmpty) 'format': format,
    if (color2 != null) 'color2': color2,
    if (color3 != null) 'color3': color3,
    if (trackColor != null) 'trackColor': trackColor,
    if (shadowColor != null) 'shadowColor': shadowColor,
    if (strokes.isNotEmpty) 'strokes': strokes,
    if (animate) 'animate': animate,
    if (animStyle.isNotEmpty) 'animStyle': animStyle,
    if (animSpeed != 1) 'animSpeed': animSpeed,
    // Persist always for clock/analog so HH:mm vs HH:mm:ss is unambiguous.
    if (kind == LayerKind.clock || kind == LayerKind.analog)
      'showSeconds': showSeconds,
  };

  factory Layer.fromJson(Map<String, dynamic> j) {
    final kind = LayerKind.values.firstWhere(
      (k) => k.name == j['kind'],
      orElse: () => LayerKind.text,
    );
    return Layer(
      id: j['id'] as String? ?? 'layer-${_layerIdUuid.v4()}',
      kind: kind,
      label: j['label'] as String? ?? '',
      text: j['text'] as String? ?? '',
      x: (j['x'] as num?)?.toDouble() ?? 10,
      y: (j['y'] as num?)?.toDouble() ?? 20,
      w: (j['w'] as num?)?.toDouble() ?? 80,
      h: (j['h'] as num?)?.toDouble() ?? 18,
      fontSize: (j['fontSize'] as num?)?.toDouble() ?? 14,
      weight: j['weight'] as int? ?? 600,
      align: TextAlign.values.firstWhere(
        (a) => a.name == j['align'],
        orElse: () => TextAlign.left,
      ),
      color: j['color'] as String? ?? '#F2F5FA',
      opacity: (j['opacity'] as num?)?.toDouble() ?? 1,
      radius: (j['radius'] as num?)?.toDouble() ?? 0,
      letterSpacing: (j['letterSpacing'] as num?)?.toDouble() ?? 0,
      shadow: j['shadow'] as bool? ?? false,
      locked: j['locked'] as bool? ?? false,
      hidden: j['hidden'] as bool? ?? false,
      fit: BoxFit.values.firstWhere(
        (f) => f.name == j['fit'],
        orElse: () => BoxFit.cover,
      ),
      flipH: j['flipH'] as bool? ?? false,
      maxLines: j['maxLines'] as int? ?? 2,
      src: j['src'] as String?,
      role: j['role'] as String? ?? '',
      format: j['format'] as String? ?? '',
      color2: j['color2'] as String?,
      color3: j['color3'] as String?,
      trackColor: j['trackColor'] as String?,
      shadowColor: j['shadowColor'] as String?,
      strokes: j['strokes'] as String? ?? '',
      animate: j['animate'] as bool? ?? false,
      animStyle: j['animStyle'] as String? ?? '',
      animSpeed: (j['animSpeed'] as num?)?.toDouble() ?? 1,
      // Legacy JSON omitted the field (old default true). Digital clocks must
      // default to HH:mm so narrow tiles never clip to a dangling "19:35:".
      showSeconds: j['showSeconds'] as bool? ?? kind == LayerKind.analog,
    );
  }
}

enum BgType { solid, gradient, image }

class WidgetBackground {
  const WidgetBackground({
    required this.type,
    required this.from,
    this.to,
    this.imageSrc,
  });

  final BgType type;
  final String from;
  final String? to;

  /// File path or data URL when [type] is [BgType.image].
  final String? imageSrc;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'from': from,
    if (to != null) 'to': to,
    if (imageSrc != null) 'imageSrc': imageSrc,
  };

  factory WidgetBackground.fromJson(Map<String, dynamic> j) {
    return WidgetBackground(
      type: BgType.values.firstWhere(
        (t) => t.name == j['type'],
        orElse: () => BgType.gradient,
      ),
      from: j['from'] as String? ?? '#12141A',
      to: j['to'] as String?,
      imageSrc: j['imageSrc'] as String? ?? j['src'] as String?,
    );
  }
}

class WidgetSpec {
  WidgetSpec({required this.background, required this.layers});

  WidgetBackground background;
  List<Layer> layers;

  /// Deep-copies background + every layer. Never flattens to a single image.
  ///
  /// When [remintLayerIds] is true (draft create / Edit copy), each layer gets
  /// a fresh id so drafts never share identity with the template catalog.
  WidgetSpec clone({bool remintLayerIds = false}) => WidgetSpec(
    background: WidgetBackground(
      type: background.type,
      from: background.from,
      to: background.to,
      imageSrc: background.imageSrc,
    ),
    layers: [
      for (final l in layers)
        remintLayerIds
            ? Layer.fromJson(l.toJson()).copyWith(id: _layerIdUuid.v4())
            : Layer.fromJson(l.toJson()),
    ],
  );

  Map<String, dynamic> toJson() => {
    'background': background.toJson(),
    'layers': layers.map((l) => l.toJson()).toList(),
  };

  factory WidgetSpec.fromJson(Map<String, dynamic> j) {
    final rawLayers = j['layers'];
    final parsed = <Layer>[];
    if (rawLayers is List) {
      for (final e in rawLayers) {
        if (e is Map) {
          parsed.add(Layer.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    return WidgetSpec(
      background: WidgetBackground.fromJson(
        Map<String, dynamic>.from(j['background'] as Map? ?? {}),
      ),
      // Preserve every serialized layer — never collapse to one image/layer.
      layers: parsed,
    );
  }
}

class Draft {
  Draft({
    required this.id,
    required this.name,
    required this.updatedAt,
    required this.spec,
    this.widgetImagePath,
  });

  final String id;
  String name;
  int updatedAt;
  WidgetSpec spec;

  /// Path to a pre-rendered PNG of the static (non-live) design. The iOS
  /// widget extension displays this as a base layer and overlays live data
  /// (clock/battery/analog) on top.
  String? widgetImagePath;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'updatedAt': updatedAt,
    'spec': spec.toJson(),
    if (widgetImagePath != null) 'widgetImagePath': widgetImagePath,
  };

  factory Draft.fromJson(Map<String, dynamic> j) {
    final id = j['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Draft missing id');
    }
    return Draft(
      id: id,
      name: j['name'] as String? ?? 'Untitled',
      updatedAt: j['updatedAt'] as int? ?? 0,
      spec: WidgetSpec.fromJson(
        Map<String, dynamic>.from(j['spec'] as Map? ?? {}),
      ),
      widgetImagePath: j['widgetImagePath'] as String?,
    );
  }
}

class Vehicle {
  Vehicle({
    required this.brandId,
    required this.modelId,
    required this.artwork,
    this.displayName = '',
    this.customImage,
    this.catalogBrand,
    this.catalogModel,
    this.catalogBrandId,
    this.catalogModelId,
  });

  String brandId;
  String modelId;
  ArtworkKind artwork;
  String displayName;

  /// File path or data URL for custom garage photo.
  String? customImage;

  /// Real make/model from the cars-only catalog picker (optional).
  String? catalogBrand;
  String? catalogModel;
  String? catalogBrandId;
  String? catalogModelId;

  Map<String, dynamic> toJson() => {
    'brandId': brandId,
    'modelId': modelId,
    'artwork': artwork.name,
    'displayName': displayName,
    'customImage': customImage,
    'catalogBrand': catalogBrand,
    'catalogModel': catalogModel,
    'catalogBrandId': catalogBrandId,
    'catalogModelId': catalogModelId,
  };

  factory Vehicle.fromJson(Map<String, dynamic> j) {
    return Vehicle(
      brandId: j['brandId'] as String? ?? 'aurelio',
      modelId: j['modelId'] as String? ?? 'aurelio-gt',
      artwork: ArtworkKind.values.firstWhere(
        (a) => a.name == j['artwork'],
        orElse: () => ArtworkKind.coupe,
      ),
      displayName: j['displayName'] as String? ?? '',
      customImage: j['customImage'] as String?,
      catalogBrand: j['catalogBrand'] as String?,
      catalogModel: j['catalogModel'] as String?,
      catalogBrandId: j['catalogBrandId'] as String?,
      catalogModelId: j['catalogModelId'] as String?,
    );
  }

  Vehicle copy() => Vehicle(
    brandId: brandId,
    modelId: modelId,
    artwork: artwork,
    displayName: displayName,
    customImage: customImage,
    catalogBrand: catalogBrand,
    catalogModel: catalogModel,
    catalogBrandId: catalogBrandId,
    catalogModelId: catalogModelId,
  );
}

class SoundPrefs {
  SoundPrefs({this.connect, this.disconnect, this.reminder});

  String? connect;
  String? disconnect;
  String? reminder;

  Map<String, dynamic> toJson() => {
    'connect': connect,
    'disconnect': disconnect,
    'reminder': reminder,
  };

  factory SoundPrefs.fromJson(Map<String, dynamic> j) {
    return SoundPrefs(
      connect: j['connect'] as String?,
      disconnect: j['disconnect'] as String?,
      reminder: j['reminder'] as String?,
    );
  }
}

class VehicleBrand {
  const VehicleBrand({
    required this.id,
    required this.name,
    required this.tagline,
    required this.models,
  });

  final String id;
  final String name;
  final String tagline;
  final List<VehicleModel> models;
}

class VehicleModel {
  const VehicleModel({required this.id, required this.name});

  final String id;
  final String name;
}

class SoundCue {
  const SoundCue({
    required this.id,
    required this.name,
    required this.group,
    required this.freq,
    this.description = '',
    this.premium = false,
    this.assetPath,
    this.durationMs = 1150,
  });

  final String id;
  final String name;
  final SoundGroup group;
  final double freq;

  /// One-line explanation shown under the cue name (not a music track).
  final String description;
  final bool premium;

  /// Bundled WAV under `assets/sounds/` (e.g. `assets/sounds/soft-chime.wav`).
  final String? assetPath;

  /// Nominal clip length for UI; matches generated assets.
  final int durationMs;

  String get assetPathOrDefault => assetPath ?? 'assets/sounds/$id.wav';

  String get durationLabel {
    final sec = durationMs / 1000.0;
    return '${sec.toStringAsFixed(2)}s';
  }
}

/// UI copy for Connect / Disconnect / Reminder cue slots.
extension SoundGroupCopy on SoundGroup {
  String get monoLabel => switch (this) {
    SoundGroup.connect => 'Connect',
    SoundGroup.disconnect => 'Disconnect',
    SoundGroup.reminder => 'Reminder',
  };

  /// Short product meaning for in-app labels.
  String get oneLiner => switch (this) {
    SoundGroup.connect =>
      'Plays when iPhone connects to the car (CarPlay / Bluetooth)',
    SoundGroup.disconnect => 'Plays when the phone disconnects from the car',
    SoundGroup.reminder =>
      'Optional cue for a reminder automation — not a music track',
  };
}

class TemplateItem {
  const TemplateItem({
    required this.id,
    required this.name,
    required this.category,
    required this.premium,
    required this.spec,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String category;
  final bool premium;
  final WidgetSpec spec;
  final String createdAt;
}
