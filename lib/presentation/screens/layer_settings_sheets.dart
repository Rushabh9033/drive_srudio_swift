import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/media/image_store.dart';
import '../../core/theme/drive_colors.dart';
import '../../data/models/anim_styles.dart';
import '../../data/models/models.dart';
import '../widgets/color_field.dart';
import '../widgets/drive_ui.dart';

/// Full kind-aware layer editor opened from double-tap / Inspect.
Future<Layer?> showLayerSettingsSheet(
  BuildContext context, {
  required Layer layer,
}) {
  return DriveSheet.show<Layer>(
    context: context,
    builder: (ctx) => DriveSheet(
      title: 'Edit ${layer.kind.name}',
      child: _LayerSettingsBody(layer: layer),
    ),
  );
}

class _LayerSettingsBody extends StatefulWidget {
  const _LayerSettingsBody({required this.layer});
  final Layer layer;

  @override
  State<_LayerSettingsBody> createState() => _LayerSettingsBodyState();
}

class _LayerSettingsBodyState extends State<_LayerSettingsBody> {
  late Layer _draft;
  late final TextEditingController _text;
  late final TextEditingController _label;

  static const _batteryStyles = [
    'panel',
    'metrics',
    'icon',
    'ring',
    'pill',
    'bars',
    'hud',
    'orbit',
    'large',
    'pie',
    'dayprogress',
  ];

  static const _analogStyles = [
    'classic',
    'minimal',
    'neon',
    'rings',
    'sport',
    'arc',
    'thin',
    'luxury',
    'ticks',
    'dual',
    'field',
  ];

  @override
  void initState() {
    super.initState();
    _draft = Layer.fromJson(widget.layer.toJson());
    _text = TextEditingController(text: _draft.text);
    _label = TextEditingController(text: _draft.label);
  }

  @override
  void dispose() {
    _text.dispose();
    _label.dispose();
    super.dispose();
  }

  void _patch(Layer Function(Layer) fn) {
    setState(() => _draft = fn(_draft));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        TextField(
          controller: _label,
          decoration: const InputDecoration(labelText: 'Label'),
          onChanged: (v) => _patch((l) => l.copyWith(label: v)),
        ),
        const SizedBox(height: 8),
        if (_draft.kind == LayerKind.battery) ..._batteryControls(),
        if (_draft.kind == LayerKind.analog) ..._analogControls(),
        if (_draft.kind == LayerKind.clock) ..._clockControls(),
        if (_draft.kind == LayerKind.date) ..._dateControls(),
        if (_draft.kind == LayerKind.text ||
            _draft.kind == LayerKind.badge) ..._textControls(),
        if (_draft.kind == LayerKind.image) ..._imageControls(),
        if (_draft.kind == LayerKind.shape) ..._shapeControls(),
        ..._colorControls(),
        if (_draft.supportsAnimation) ..._animateControls(),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _draft),
          child: const Text('Apply'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  List<Widget> _colorControls() {
    final kind = _draft.kind;
    return [
      const Divider(height: 28),
      Text(
        'Colors',
        style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 16),
      ),
      const SizedBox(height: 10),
      ColorField(
        label: switch (kind) {
          LayerKind.battery => 'Bar / fill',
          LayerKind.analog => 'Accent ring',
          LayerKind.clock || LayerKind.date || LayerKind.text => 'Text',
          LayerKind.badge => 'Badge stroke / text',
          LayerKind.shape => 'Fill',
          LayerKind.divider => 'Line',
          _ => 'Primary',
        },
        value: _draft.color,
        onChanged: (v) => _patch((l) => l.copyWith(color: v)),
      ),
      if (kind == LayerKind.battery) ...[
        ColorField(
          label: 'Accent / glow',
          value: _draft.color2,
          allowClear: true,
          onClear: () => _patch((l) => l.copyWith(clearColor2: true)),
          onChanged: (v) => _patch((l) => l.copyWith(color2: v)),
        ),
        ColorField(
          label: 'Label / percent text',
          value: _draft.color3,
          allowClear: true,
          onClear: () => _patch((l) => l.copyWith(clearColor3: true)),
          onChanged: (v) => _patch((l) => l.copyWith(color3: v)),
        ),
        ColorField(
          label: 'Track',
          value: _draft.trackColor,
          allowClear: true,
          onClear: () => _patch((l) => l.copyWith(clearTrackColor: true)),
          onChanged: (v) => _patch((l) => l.copyWith(trackColor: v)),
        ),
      ],
      if (kind == LayerKind.analog) ...[
        ColorField(
          label: 'Hands',
          value: _draft.color2,
          allowClear: true,
          onClear: () => _patch((l) => l.copyWith(clearColor2: true)),
          onChanged: (v) => _patch((l) => l.copyWith(color2: v)),
        ),
        ColorField(
          label: 'Ticks marks',
          value: _draft.color3,
          allowClear: true,
          onClear: () => _patch((l) => l.copyWith(clearColor3: true)),
          onChanged: (v) => _patch((l) => l.copyWith(color3: v)),
        ),
        ColorField(
          label: 'Face',
          value: _draft.trackColor,
          allowClear: true,
          onClear: () => _patch((l) => l.copyWith(clearTrackColor: true)),
          onChanged: (v) => _patch((l) => l.copyWith(trackColor: v)),
        ),
      ],
      if (kind == LayerKind.clock ||
          kind == LayerKind.text ||
          kind == LayerKind.date) ...[
        ColorField(
          label: kind == LayerKind.text ? 'Gradient end' : 'Secondary',
          value: _draft.color2,
          allowClear: true,
          onClear: () => _patch((l) => l.copyWith(clearColor2: true)),
          onChanged: (v) => _patch((l) => l.copyWith(color2: v)),
        ),
        ColorField(
          label: 'Glow / shadow',
          value: _draft.shadowColor,
          allowClear: true,
          onClear: () => _patch((l) => l.copyWith(clearShadowColor: true)),
          onChanged: (v) =>
              _patch((l) => l.copyWith(shadowColor: v, shadow: true)),
        ),
      ],
      if (kind == LayerKind.badge || kind == LayerKind.shape) ...[
        ColorField(
          label: 'Accent',
          value: _draft.color2,
          allowClear: true,
          onClear: () => _patch((l) => l.copyWith(clearColor2: true)),
          onChanged: (v) => _patch((l) => l.copyWith(color2: v)),
        ),
      ],
    ];
  }

  List<Widget> _batteryControls() {
    return [
      Text(
        'Phone battery only',
        style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 6),
      Text(
        'Charge % comes from this device via battery_plus. '
        'When unavailable the widget shows "—" — no invented numbers.',
        style: GoogleFonts.manrope(
          fontSize: 12,
          height: 1.35,
          color: DriveColors.mutedForeground,
        ),
      ),
      const SizedBox(height: 12),
      Text('Style', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final s in _batteryStyles)
            ChoiceChip(
              label: Text(s),
              selected: (_draft.format.isEmpty ? 'panel' : _draft.format) == s,
              onSelected: (_) => _patch((l) => l.copyWith(format: s)),
            ),
        ],
      ),
      const SizedBox(height: 12),
    ];
  }

  List<Widget> _analogControls() {
    return [
      Text('Face style',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final s in _analogStyles)
            ChoiceChip(
              label: Text(s),
              selected:
                  (_draft.format.isEmpty ? 'classic' : _draft.format) == s,
              onSelected: (_) => _patch((l) => l.copyWith(format: s)),
            ),
        ],
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text('Show seconds',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
        value: _draft.showSeconds,
        onChanged: (v) => _patch((l) => l.copyWith(showSeconds: v)),
      ),
    ];
  }

  List<Widget> _clockControls() {
    final fmt = _draft.format.isEmpty ? '24' : _draft.format;
    return [
      Text('Format', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final opt in [
            ('24', '24-hour'),
            ('12', '12-hour'),
            ('12ap', '12 + AM/PM'),
            ('ss', 'Seconds only'),
          ])
            ChoiceChip(
              label: Text(opt.$2),
              selected: fmt == opt.$1,
              onSelected: (_) => _patch((l) => l.copyWith(format: opt.$1)),
            ),
        ],
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text('Show seconds',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
        subtitle: Text(
          'HH:mm:ss live field',
          style: GoogleFonts.manrope(
            fontSize: 12,
            color: DriveColors.mutedForeground,
          ),
        ),
        value: _draft.showSeconds,
        onChanged: (v) => _patch((l) => l.copyWith(showSeconds: v)),
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text('Shadow',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
        value: _draft.shadow,
        onChanged: (v) => _patch((l) => l.copyWith(shadow: v)),
      ),
    ];
  }

  List<Widget> _dateControls() {
    final fmt = _draft.format.isEmpty ? 'abbrev' : _draft.format;
    return [
      Text('Format', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final opt in [
            ('abbrev', 'Abbrev'),
            ('short', 'Short'),
            ('medium', 'Full month'),
            ('full', 'Weekday + month'),
          ])
            ChoiceChip(
              label: Text(opt.$2),
              selected: fmt == opt.$1,
              onSelected: (_) => _patch((l) => l.copyWith(format: opt.$1)),
            ),
        ],
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text('Shadow',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
        value: _draft.shadow,
        onChanged: (v) => _patch((l) => l.copyWith(shadow: v)),
      ),
    ];
  }

  List<Widget> _textControls() {
    return [
      TextField(
        controller: _text,
        decoration: const InputDecoration(labelText: 'Content'),
        onChanged: (v) => _patch((l) => l.copyWith(text: v)),
      ),
      Text('Weight', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
      Wrap(
        spacing: 6,
        children: [
          for (final w in [400, 500, 600, 700, 800])
            ChoiceChip(
              label: Text('$w'),
              selected: _draft.weight == w,
              onSelected: (_) => _patch((l) => l.copyWith(weight: w)),
            ),
        ],
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text('Shadow',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
        value: _draft.shadow,
        onChanged: (v) => _patch((l) => l.copyWith(shadow: v)),
      ),
      Text('Font size',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
      Slider(
        value: _draft.fontSize.clamp(8, 64),
        min: 8,
        max: 64,
        onChanged: (v) => _patch((l) => l.copyWith(fontSize: v)),
      ),
    ];
  }

  List<Widget> _shapeControls() {
    return [
      Text('Corner radius',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
      Slider(
        value: _draft.radius.clamp(0, 48),
        min: 0,
        max: 48,
        onChanged: (v) => _patch((l) => l.copyWith(radius: v)),
      ),
    ];
  }

  List<Widget> _imageControls() {
    return [
      Text(
        'Size (width %)',
        style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
      ),
      Slider(
        value: _draft.w.clamp(10, 100),
        min: 10,
        max: 100,
        onChanged: (v) {
          final scale = v / _draft.w;
          _patch(
            (l) => l.copyWith(
              w: v,
              h: (l.h * scale).clamp(8, 100),
            ),
          );
        },
      ),
      Text(
        'Corner radius',
        style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
      ),
      Slider(
        value: _draft.radius.clamp(0, 40),
        min: 0,
        max: 40,
        onChanged: (v) => _patch((l) => l.copyWith(radius: v)),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: DriveColors.card,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: DriveColors.border),
            ),
          ),
          icon: const Icon(CupertinoIcons.photo, size: 18),
          label: const Text('Choose Photo from Library'),
          onPressed: () async {
            final picker = ImagePicker();
            final file = await picker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 85,
            );
            if (file != null) {
              final bytes = await file.readAsBytes();
              final path = await persistPickedImage(bytes);
              if (path != null) {
                _patch((l) => l.copyWith(src: path));
              }
            }
          },
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Or leave blank to use your default Home Page vehicle photo.',
        style: GoogleFonts.manrope(
          fontSize: 12,
          color: DriveColors.mutedForeground,
        ),
      ),
      const SizedBox(height: 8),
    ];
  }

  List<Widget> _animateControls() {
    final current = _draft.animStyle.isEmpty
        ? ''
        : AnimStyles.normalize(_draft.animStyle);
    return [
      const Divider(height: 28),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        secondary: const Icon(CupertinoIcons.sparkles,
            color: DriveColors.primary, size: 20),
        title: Text('Animate',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        subtitle: Text(
          'LIVE · ${AnimStyles.labelFor(_draft.resolvedAnimStyle)}',
          style: GoogleFonts.manrope(
            fontSize: 12,
            color: DriveColors.mutedForeground,
          ),
        ),
        value: _draft.animate,
        onChanged: (v) => _patch(
          (l) => l.copyWith(
            animate: v,
            animStyle: v && l.animStyle.isEmpty
                ? l.resolvedAnimStyle
                : l.animStyle,
          ),
        ),
      ),
      if (_draft.animate) ...[
        Text('Motion style',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in AnimStyles.choices)
              ChoiceChip(
                label: Text(s.$2),
                selected: current == s.$1 ||
                    (current.isEmpty && s.$1.isEmpty),
                onSelected: (_) => _patch((l) => l.copyWith(animStyle: s.$1)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Speed  ${_draft.animSpeed.toStringAsFixed(1)}×',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
        Slider(
          value: _draft.animSpeed.clamp(0.35, 2.5),
          min: 0.35,
          max: 2.5,
          divisions: 43,
          onChanged: (v) => _patch((l) => l.copyWith(animSpeed: v)),
        ),
      ],
    ];
  }
}
