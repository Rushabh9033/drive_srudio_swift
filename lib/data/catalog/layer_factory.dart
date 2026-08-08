import 'package:flutter/painting.dart';
import 'package:uuid/uuid.dart';

import '../models/anim_styles.dart';
import '../models/models.dart';

const _uuid = Uuid();

Layer baseLayer(LayerKind kind, {Map<String, Object?> overrides = const {}}) {
  final defaults = switch (kind) {
    LayerKind.text => Layer(
        id: _uuid.v4(),
        kind: kind,
        label: 'Text',
        text: 'Label',
        fontSize: 14,
        weight: 600,
      ),
    LayerKind.clock => Layer(
        id: _uuid.v4(),
        kind: kind,
        label: 'Clock',
        fontSize: 28,
        weight: 800,
        h: 24,
        animate: true,
        animStyle: AnimStyles.blinkColon,
        // HH:mm by default — HH:mm:ss in a narrow tile clips to "19:35:".
        showSeconds: false,
      ),
    LayerKind.date => Layer(
        id: _uuid.v4(),
        kind: kind,
        label: 'Date',
        fontSize: 12,
        weight: 500,
        color: '#A8B6CC',
      ),
    LayerKind.badge => Layer(
        id: _uuid.v4(),
        kind: kind,
        label: 'Badge',
        text: 'LIVE',
        fontSize: 11,
        weight: 700,
        w: 36,
        h: 14,
        radius: 8,
        align: TextAlign.center,
        animStyle: AnimStyles.glowBreathe,
      ),
    LayerKind.divider => Layer(
        id: _uuid.v4(),
        kind: kind,
        label: 'Divider',
        h: 2,
        w: 60,
        color: '#4D9EFF',
      ),
    LayerKind.shape => Layer(
        id: _uuid.v4(),
        kind: kind,
        label: 'Shape',
        w: 40,
        h: 40,
        radius: 12,
        color: '#2A2F3A',
        animate: false,
        animStyle: AnimStyles.ripple,
      ),
    LayerKind.image => Layer(
        id: _uuid.v4(),
        kind: kind,
        label: 'Image',
        w: 50,
        h: 40,
        radius: 10,
      ),
    LayerKind.draw => Layer(
        id: _uuid.v4(),
        kind: kind,
        label: 'Draw',
        x: 0,
        y: 0,
        w: 100,
        h: 100,
        color: '#4D9EFF',
        strokes: '[]',
      ),
    LayerKind.battery => Layer(
        id: _uuid.v4(),
        kind: kind,
        label: 'Battery',
        text: '86',
        format: 'panel',
        x: 8,
        y: 8,
        w: 84,
        h: 84,
        color: '#4D9EFF',
        animate: true,
        animStyle: AnimStyles.shimmer,
      ),
    LayerKind.analog => Layer(
        id: _uuid.v4(),
        kind: kind,
        label: 'Analog',
        format: 'classic',
        x: 10,
        y: 10,
        w: 80,
        h: 80,
        color: '#4D9EFF',
        animate: true,
        animStyle: AnimStyles.handSmooth,
        showSeconds: true,
      ),
  };

  return defaults.copyWith(
    label: overrides['label'] as String?,
    text: overrides['text'] as String?,
    x: (overrides['x'] as num?)?.toDouble(),
    y: (overrides['y'] as num?)?.toDouble(),
    w: (overrides['w'] as num?)?.toDouble(),
    h: (overrides['h'] as num?)?.toDouble(),
    fontSize: (overrides['fontSize'] as num?)?.toDouble(),
    weight: overrides['weight'] as int?,
    color: overrides['color'] as String?,
    letterSpacing: (overrides['letterSpacing'] as num?)?.toDouble(),
    radius: (overrides['radius'] as num?)?.toDouble(),
    format: overrides['format'] as String?,
    src: overrides['src'] as String?,
    role: overrides['role'] as String?,
    color2: overrides['color2'] as String?,
    color3: overrides['color3'] as String?,
    trackColor: overrides['trackColor'] as String?,
    shadow: overrides['shadow'] as bool?,
    shadowColor: overrides['shadowColor'] as String?,
    animate: overrides['animate'] as bool?,
    animStyle: overrides['animStyle'] as String?,
    animSpeed: (overrides['animSpeed'] as num?)?.toDouble(),
    showSeconds: overrides['showSeconds'] as bool?,
    opacity: (overrides['opacity'] as num?)?.toDouble(),
  );
}

/// Independent layers for one GPS speedometer cluster (digits + unit + optional badge).
///
/// Digits use [format] `gpsspeed` — live iPhone shows km/h when GPS known;
/// otherwise "—"; Studio thumbs sample.
/// [nestIndex] offsets placement so multiple adds do not stack on top of each other.
List<Layer> composeSpeedometerLayers({
  int nestIndex = 0,
  bool includeGpsBadge = true,
}) {
  final dx = (nestIndex % 4) * 8.0;
  final dy = (nestIndex % 4) * 10.0;
  final digits = baseLayer(LayerKind.text, overrides: {
    'text': '—',
    'x': 18.0 + dx,
    'y': 28.0 + dy,
    'w': 64.0,
    'h': 40.0,
    'fontSize': 42.0,
    'weight': 800,
    'format': 'gpsspeed',
  }).copyWith(label: 'Speed', align: TextAlign.center);
  final unit = baseLayer(LayerKind.text, overrides: {
    'text': 'km/h',
    'label': 'Unit',
    'x': 28.0 + dx,
    'y': 72.0 + dy,
    'fontSize': 12.0,
    'weight': 600,
    'color': '#7FB6FF',
    'letterSpacing': 1.5,
  });
  if (!includeGpsBadge) return [digits, unit];
  final badge = baseLayer(LayerKind.badge, overrides: {
    'text': 'GPS',
    'label': 'GPS',
    'format': 'gpsspeed',
    'role': 'telemetry:gpsspeed',
    'x': 22.0 + dx,
    'y': 12.0 + dy,
    'w': 56.0,
    'color': '#4D9EFF',
  });
  return [badge, digits, unit];
}

/// Count existing speedometer digit layers (for nest offset on add).
int countSpeedometerClusters(Iterable<Layer> layers) {
  return layers
      .where(
        (l) =>
            l.format == 'gpsspeed' ||
            l.format == 'gps-speed' ||
            l.format == 'speed',
      )
      .where((l) => l.kind == LayerKind.text)
      .length;
}

/// True when a stock template should show a LIVE / Animated chip.
bool templateHasLiveMotion(WidgetSpec spec) {
  return spec.layers.any(
    (l) =>
        l.animate ||
        l.kind == LayerKind.clock ||
        l.kind == LayerKind.analog ||
        l.kind == LayerKind.battery,
  );
}

/// Primary motion style label for LIVE chip (optional style name).
String? templatePrimaryAnimLabel(WidgetSpec spec) {
  Layer? best;
  for (final l in spec.layers) {
    if (!l.animate &&
        l.kind != LayerKind.clock &&
        l.kind != LayerKind.analog &&
        l.kind != LayerKind.battery) {
      continue;
    }
    best ??= l;
    if (l.animate && l.animStyle.isNotEmpty) {
      best = l;
      break;
    }
  }
  if (best == null) return null;
  return AnimStyles.labelFor(best.resolvedAnimStyle);
}
