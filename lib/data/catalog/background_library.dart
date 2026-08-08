import '../models/models.dart';

enum BgCategory { solid, gradient, texture, scene }

/// Curated Drive Studio background preset for the editor BG library.
class BackgroundPreset {
  const BackgroundPreset({
    required this.id,
    required this.name,
    required this.category,
    required this.background,
    this.premium = false,
    this.tags = const [],
  });

  final String id;
  final String name;
  final BgCategory category;
  final WidgetBackground background;
  final bool premium;
  final List<String> tags;

  bool matchesQuery(String q) {
    if (q.isEmpty) return true;
    final needle = q.toLowerCase();
    return name.toLowerCase().contains(needle) ||
        category.name.contains(needle) ||
        tags.any((t) => t.toLowerCase().contains(needle));
  }
}

/// Background pack — solids, gradients, bundled textures, automotive scenes.
abstract final class BackgroundLibrary {
  static const categories = [
    BgCategory.solid,
    BgCategory.gradient,
    BgCategory.texture,
    BgCategory.scene,
  ];

  static String categoryLabel(BgCategory c) => switch (c) {
        BgCategory.solid => 'Solid',
        BgCategory.gradient => 'Gradient',
        BgCategory.texture => 'Texture',
        BgCategory.scene => 'Scene',
      };

  static final List<BackgroundPreset> all = [
    // ── Solid ──────────────────────────────────────────────
    const BackgroundPreset(
      id: 'solid-obsidian',
      name: 'Obsidian',
      category: BgCategory.solid,
      background: WidgetBackground(type: BgType.solid, from: '#12141A'),
      tags: ['dark', 'studio'],
    ),
    const BackgroundPreset(
      id: 'solid-void',
      name: 'Pure Black',
      category: BgCategory.solid,
      background: WidgetBackground(type: BgType.solid, from: '#000000'),
      tags: ['dark'],
    ),
    const BackgroundPreset(
      id: 'solid-graphite',
      name: 'Graphite',
      category: BgCategory.solid,
      background: WidgetBackground(type: BgType.solid, from: '#1A1D24'),
      tags: ['dark', 'neutral'],
    ),
    const BackgroundPreset(
      id: 'solid-navy',
      name: 'Deep Navy',
      category: BgCategory.solid,
      background: WidgetBackground(type: BgType.solid, from: '#0C1424'),
      tags: ['blue', 'night'],
    ),
    const BackgroundPreset(
      id: 'solid-forest',
      name: 'Cabin Forest',
      category: BgCategory.solid,
      background: WidgetBackground(type: BgType.solid, from: '#0E1612'),
      tags: ['green'],
    ),
    const BackgroundPreset(
      id: 'solid-ember',
      name: 'Ember Matte',
      category: BgCategory.solid,
      background: WidgetBackground(type: BgType.solid, from: '#16100C'),
      tags: ['warm'],
    ),

    // ── Gradient ───────────────────────────────────────────
    const BackgroundPreset(
      id: 'grad-night-blue',
      name: 'Night Blue',
      category: BgCategory.gradient,
      background: WidgetBackground(
        type: BgType.gradient,
        from: '#101828',
        to: '#1E3A5F',
      ),
      tags: ['blue', 'night'],
    ),
    const BackgroundPreset(
      id: 'grad-carbon',
      name: 'Carbon Fade',
      category: BgCategory.gradient,
      background: WidgetBackground(
        type: BgType.gradient,
        from: '#16181D',
        to: '#2A2F3A',
      ),
      tags: ['carbon', 'dark'],
    ),
    const BackgroundPreset(
      id: 'grad-aurora',
      name: 'Aurora Dash',
      category: BgCategory.gradient,
      background: WidgetBackground(
        type: BgType.gradient,
        from: '#101A2B',
        to: '#2C4C7C',
      ),
      tags: ['blue'],
    ),
    const BackgroundPreset(
      id: 'grad-forest',
      name: 'Forest Glow',
      category: BgCategory.gradient,
      background: WidgetBackground(
        type: BgType.gradient,
        from: '#132118',
        to: '#20463A',
      ),
      tags: ['green'],
    ),
    const BackgroundPreset(
      id: 'grad-ember',
      name: 'Ember Trail',
      category: BgCategory.gradient,
      background: WidgetBackground(
        type: BgType.gradient,
        from: '#1A120C',
        to: '#4A2A18',
      ),
      tags: ['warm'],
    ),
    const BackgroundPreset(
      id: 'grad-electric',
      name: 'Electric Blue',
      category: BgCategory.gradient,
      background: WidgetBackground(
        type: BgType.gradient,
        from: '#060A14',
        to: '#0E2848',
      ),
      tags: ['blue', 'studio'],
      premium: true,
    ),
    const BackgroundPreset(
      id: 'grad-midnight',
      name: 'Midnight Highway',
      category: BgCategory.gradient,
      background: WidgetBackground(
        type: BgType.gradient,
        from: '#080C14',
        to: '#1A2438',
      ),
      tags: ['night', 'road'],
    ),
    const BackgroundPreset(
      id: 'grad-steel',
      name: 'Steel Mist',
      category: BgCategory.gradient,
      background: WidgetBackground(
        type: BgType.gradient,
        from: '#141820',
        to: '#2A3448',
      ),
      tags: ['metal'],
      premium: true,
    ),

    // ── Texture (bundled assets) ───────────────────────────
    const BackgroundPreset(
      id: 'tex-carbon',
      name: 'Carbon Weave',
      category: BgCategory.texture,
      background: WidgetBackground(
        type: BgType.image,
        from: '#101218',
        to: '#1C2028',
        imageSrc: 'assets/backgrounds/carbon_weave.png',
      ),
      tags: ['carbon', 'texture', 'automotive'],
    ),
    const BackgroundPreset(
      id: 'tex-brushed',
      name: 'Brushed Metal',
      category: BgCategory.texture,
      background: WidgetBackground(
        type: BgType.image,
        from: '#16181C',
        to: '#2A2E36',
        imageSrc: 'assets/backgrounds/brushed_metal.png',
      ),
      tags: ['metal', 'texture'],
    ),
    const BackgroundPreset(
      id: 'tex-noise',
      name: 'Night Noise',
      category: BgCategory.texture,
      background: WidgetBackground(
        type: BgType.image,
        from: '#0A0C12',
        to: '#181C28',
        imageSrc: 'assets/backgrounds/night_noise.png',
      ),
      tags: ['noise', 'dark'],
    ),
    const BackgroundPreset(
      id: 'tex-grid',
      name: 'HUD Grid',
      category: BgCategory.texture,
      background: WidgetBackground(
        type: BgType.image,
        from: '#0A1018',
        to: '#142030',
        imageSrc: 'assets/backgrounds/hud_grid.png',
      ),
      tags: ['hud', 'grid'],
      premium: true,
    ),
    const BackgroundPreset(
      id: 'tex-garage',
      name: 'Garage Concrete',
      category: BgCategory.texture,
      background: WidgetBackground(
        type: BgType.image,
        from: '#12141A',
        to: '#22262E',
        imageSrc: 'assets/backgrounds/garage_concrete.png',
      ),
      tags: ['garage', 'texture'],
    ),
    const BackgroundPreset(
      id: 'tex-diagonal',
      name: 'Diagonal Carbon',
      category: BgCategory.texture,
      background: WidgetBackground(
        type: BgType.image,
        from: '#0E1014',
        to: '#1A1E26',
        imageSrc: 'assets/backgrounds/diagonal_carbon.png',
      ),
      tags: ['carbon'],
      premium: true,
    ),

    // ── Scene (dark automotive — remote, car-forward, no people hero) ──
    const BackgroundPreset(
      id: 'scene-night-coupe',
      name: 'Night Coupe',
      category: BgCategory.scene,
      background: WidgetBackground(
        type: BgType.image,
        from: '#0A0E16',
        to: '#1A2438',
        imageSrc:
            'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?auto=format&fit=crop&w=900&q=80',
      ),
      tags: ['car', 'night', 'coupe'],
    ),
    const BackgroundPreset(
      id: 'scene-garage-bay',
      name: 'Garage Bay',
      category: BgCategory.scene,
      background: WidgetBackground(
        type: BgType.image,
        from: '#101418',
        to: '#242830',
        imageSrc:
            'https://images.unsplash.com/photo-1486262715619-67b85e0b08d3?auto=format&fit=crop&w=900&q=80',
      ),
      tags: ['garage', 'car'],
    ),
    const BackgroundPreset(
      id: 'scene-city-asphalt',
      name: 'City Asphalt',
      category: BgCategory.scene,
      background: WidgetBackground(
        type: BgType.image,
        from: '#0C1018',
        to: '#1C2434',
        imageSrc:
            'https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=900&q=80',
      ),
      tags: ['city', 'night', 'car'],
      premium: true,
    ),
    const BackgroundPreset(
      id: 'scene-tunnel',
      name: 'Tunnel Light',
      category: BgCategory.scene,
      background: WidgetBackground(
        type: BgType.image,
        from: '#080A10',
        to: '#181C28',
        imageSrc:
            'https://images.unsplash.com/photo-1542362567-b07e54358753?auto=format&fit=crop&w=900&q=80',
      ),
      tags: ['night', 'road'],
    ),
    const BackgroundPreset(
      id: 'scene-detail',
      name: 'Body Detail',
      category: BgCategory.scene,
      background: WidgetBackground(
        type: BgType.image,
        from: '#101418',
        to: '#2A3038',
        imageSrc:
            'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?auto=format&fit=crop&w=900&q=80',
      ),
      tags: ['car', 'detail'],
      premium: true,
    ),
    const BackgroundPreset(
      id: 'scene-wet-road',
      name: 'Wet Road',
      category: BgCategory.scene,
      background: WidgetBackground(
        type: BgType.image,
        from: '#0A0E14',
        to: '#1A2230',
        imageSrc:
            'https://images.unsplash.com/photo-1511919884226-fd3cadac605f?auto=format&fit=crop&w=900&q=80',
      ),
      tags: ['road', 'night'],
    ),
    const BackgroundPreset(
      id: 'scene-street',
      name: 'Street Idle',
      category: BgCategory.scene,
      background: WidgetBackground(
        type: BgType.image,
        from: '#0E1218',
        to: '#222830',
        imageSrc:
            'https://images.unsplash.com/photo-1489824904134-891ab64532f1?auto=format&fit=crop&w=900&q=80',
      ),
      tags: ['street', 'car'],
      premium: true,
    ),
  ];

  static List<BackgroundPreset> filtered({
    BgCategory? category,
    String query = '',
  }) {
    return all
        .where((p) => category == null || p.category == category)
        .where((p) => p.matchesQuery(query))
        .toList(growable: false);
  }
}
