import re

with open('lib/data/catalog/layer_presets.dart', 'r') as f:
    content = f.read()

# Add analog clock and battery to layer_presets.dart
analog_presets = """    LayerKind.analog: [
      LayerPreset(
        name: 'Classic Sweep',
        description: 'Smooth sweeping second hand',
        layer: baseLayer(LayerKind.analog, overrides: {
          'w': 50,
          'h': 50,
          'format': 'classic'
        }),
      ),
      LayerPreset(
        name: 'Sport Chrono',
        description: 'Red accents & ticks',
        layer: baseLayer(LayerKind.analog, overrides: {
          'w': 60,
          'h': 60,
          'format': 'sport',
          'color': '#FF6B7A'
        }),
      ),
      LayerPreset(
        name: 'Minimalist Dial',
        description: 'No numbers, just hands',
        layer: baseLayer(LayerKind.analog, overrides: {
          'w': 50,
          'h': 50,
          'format': 'minimal'
        }),
      ),
    ],
    LayerKind.battery: [
      LayerPreset(
        name: 'Battery Ring',
        description: 'Circular progress',
        layer: baseLayer(LayerKind.battery, overrides: {
          'w': 30,
          'h': 30,
          'format': 'ring'
        }),
      ),
      LayerPreset(
        name: 'Battery Bar',
        description: 'Linear capacity bar',
        layer: baseLayer(LayerKind.battery, overrides: {
          'w': 50,
          'h': 10,
          'format': 'bar'
        }),
      ),
    ],"""

content = content.replace("  };\n}\n", analog_presets + "\n  };\n}\n")

with open('lib/data/catalog/layer_presets.dart', 'w') as f:
    f.write(content)
