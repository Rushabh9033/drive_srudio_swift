import '../models/models.dart';
import 'layer_factory.dart';

class LayerPreset {
  final String name;
  final String description;
  final Layer layer;

  LayerPreset({
    required this.name,
    required this.description,
    required this.layer,
  });
}

Map<LayerKind, List<LayerPreset>> get kLayerPresets {
  return {
    LayerKind.clock: [
      LayerPreset(
        name: 'Classic Bold',
        description: 'Thick HH:mm with blinking colon',
        layer: baseLayer(
          LayerKind.clock,
          overrides: {'format': 'hh', 'weight': 800, 'fontSize': 32},
        ),
      ),
      LayerPreset(
        name: 'Thin Minimalist',
        description: 'Elegant light weight',
        layer: baseLayer(
          LayerKind.clock,
          overrides: {'weight': 300, 'fontSize': 32},
        ),
      ),
      LayerPreset(
        name: 'Neon Glow',
        description: 'Cyan glow effect',
        layer: baseLayer(
          LayerKind.clock,
          overrides: {
            'weight': 600,
            'fontSize': 32,
            'color': '#66D9FF',
            'shadow': true,
            'shadowColor': '#66D9FF',
          },
        ),
      ),
      LayerPreset(
        name: 'With Seconds',
        description: 'HH:mm:ss format',
        layer: baseLayer(
          LayerKind.clock,
          overrides: {
            'showSeconds': true,
            'w': 100, // needs more width
          },
        ),
      ),
    ],
    LayerKind.date: [
      LayerPreset(
        name: 'Minimal Date',
        description: 'Simple month and day',
        layer: baseLayer(LayerKind.date),
      ),
      LayerPreset(
        name: 'Accent Date',
        description: 'Highlighted color',
        layer: baseLayer(
          LayerKind.date,
          overrides: {'color': '#FFB55C', 'weight': 700},
        ),
      ),
      LayerPreset(
        name: 'Large Date',
        description: 'Prominent calendar text',
        layer: baseLayer(
          LayerKind.date,
          overrides: {'fontSize': 16, 'weight': 800, 'color': '#F7F9FC'},
        ),
      ),
    ],
    LayerKind.badge: [
      LayerPreset(
        name: 'Status Badge',
        description: 'Live pill with glow',
        layer: baseLayer(LayerKind.badge),
      ),
      LayerPreset(
        name: 'EV Range',
        description: 'Green accent',
        layer: baseLayer(
          LayerKind.badge,
          overrides: {'color': '#A8FF60', 'text': 'EV', 'w': 28},
        ),
      ),
      LayerPreset(
        name: 'Sport Mode',
        description: 'Red performance tag',
        layer: baseLayer(
          LayerKind.badge,
          overrides: {'color': '#FF6B7A', 'text': 'SPORT', 'w': 48},
        ),
      ),
    ],
    LayerKind.divider: [
      LayerPreset(
        name: 'Thin Accent',
        description: 'Cyan divider line',
        layer: baseLayer(LayerKind.divider, overrides: {'color': '#66D9FF'}),
      ),
      LayerPreset(
        name: 'Subtle Line',
        description: 'Dark muted divider',
        layer: baseLayer(
          LayerKind.divider,
          overrides: {'color': '#28313B', 'h': 1},
        ),
      ),
      LayerPreset(
        name: 'Thick Bar',
        description: 'Prominent section break',
        layer: baseLayer(
          LayerKind.divider,
          overrides: {'color': '#BDA6FF', 'h': 4, 'w': 40},
        ),
      ),
    ],
    LayerKind.shape: [
      LayerPreset(
        name: 'Panel Container',
        description: 'Dark rounded backplate',
        layer: baseLayer(
          LayerKind.shape,
          overrides: {'color': '#111821', 'radius': 12, 'w': 100, 'h': 40},
        ),
      ),
      LayerPreset(
        name: 'Accent Pill',
        description: 'Cyan stadium shape',
        layer: baseLayer(
          LayerKind.shape,
          overrides: {'color': '#66D9FF', 'radius': 20, 'w': 60, 'h': 20},
        ),
      ),
    ],
    LayerKind.analog: [
      LayerPreset(
        name: 'Classic Sweep',
        description: 'Smooth sweeping second hand',
        layer: baseLayer(
          LayerKind.analog,
          overrides: {'w': 50, 'h': 50, 'format': 'classic'},
        ),
      ),
      LayerPreset(
        name: 'Sport Chrono',
        description: 'Red accents & ticks',
        layer: baseLayer(
          LayerKind.analog,
          overrides: {'w': 60, 'h': 60, 'format': 'sport', 'color': '#FF6B7A'},
        ),
      ),
      LayerPreset(
        name: 'Minimalist Dial',
        description: 'No numbers, just hands',
        layer: baseLayer(
          LayerKind.analog,
          overrides: {'w': 50, 'h': 50, 'format': 'minimal'},
        ),
      ),
    ],
    LayerKind.battery: [
      LayerPreset(
        name: 'Battery Ring',
        description: 'Circular progress',
        layer: baseLayer(
          LayerKind.battery,
          overrides: {'w': 30, 'h': 30, 'format': 'ring'},
        ),
      ),
      LayerPreset(
        name: 'Battery Bar',
        description: 'Linear capacity bar',
        layer: baseLayer(
          LayerKind.battery,
          overrides: {'w': 50, 'h': 10, 'format': 'bar'},
        ),
      ),
    ],
  };
}
