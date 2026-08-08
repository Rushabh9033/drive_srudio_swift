import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/drive_colors.dart';

const kStudioPalette = [
  '#FFFFFF',
  '#F2F5FA',
  '#A8B6CC',
  '#9A9BA8',
  '#4D9EFF',
  '#7EB8FF',
  '#7FB6FF',
  '#4DC98A',
  '#E5B84A',
  '#E05A45',
  '#FF6B9D',
  '#C084FC',
  '#12141A',
  '#2A2F3A',
  '#0A1020',
  '#1A2740',
];

Color parseStudioHex(String hex, {double opacity = 1}) {
  var h = hex.replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16) ?? 0xFF4D9EFF;
  return Color(v).withValues(alpha: opacity.clamp(0, 1));
}

String colorToHex(Color c) {
  final r = (c.r * 255).round().toRadixString(16).padLeft(2, '0');
  final g = (c.g * 255).round().toRadixString(16).padLeft(2, '0');
  final b = (c.b * 255).round().toRadixString(16).padLeft(2, '0');
  return '#${(r + g + b).toUpperCase()}';
}

/// Premium swatch row + native HSV picker for a single color slot.
class ColorField extends StatelessWidget {
  const ColorField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.allowClear = false,
    this.onClear,
  });

  final String label;
  final String? value;
  final ValueChanged<String> onChanged;
  final bool allowClear;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final hex = value;
    final has = hex != null && hex.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
              ),
            ),
            if (allowClear && has)
              TextButton(
                onPressed: onClear,
                child: Text(
                  'Clear',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: DriveColors.mutedForeground,
                  ),
                ),
              ),
            GestureDetector(
              onTap: () => _openPicker(context, has ? hex : '#4D9EFF'),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: has
                      ? parseStudioHex(hex)
                      : DriveColors.graphite,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: DriveColors.primary.withValues(alpha: 0.65),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (has ? parseStudioHex(hex) : DriveColors.primary)
                          .withValues(alpha: 0.28),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: has
                    ? null
                    : const Icon(Icons.add, size: 16, color: Colors.white54),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in kStudioPalette)
              GestureDetector(
                onTap: () => onChanged(p),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: parseStudioHex(p),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: has && hex.toUpperCase() == p
                          ? DriveColors.primary
                          : DriveColors.border,
                      width: has && hex.toUpperCase() == p ? 2.5 : 1.2,
                    ),
                  ),
                ),
              ),
            GestureDetector(
              onTap: () => _openPicker(context, has ? hex : '#4D9EFF'),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const SweepGradient(
                    colors: [
                      Color(0xFFFF0000),
                      Color(0xFFFFFF00),
                      Color(0xFF00FF00),
                      Color(0xFF00FFFF),
                      Color(0xFF0000FF),
                      Color(0xFFFF00FF),
                      Color(0xFFFF0000),
                    ],
                  ),
                  border: Border.all(color: DriveColors.border),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Future<void> _openPicker(BuildContext context, String current) async {
    var draft = parseStudioHex(current);
    final picked = await showDialog<Color>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: DriveColors.carbon,
          title: Text(
            label,
            style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 280,
            child: StatefulBuilder(
              builder: (context, setLocal) {
                final hsv = HSVColor.fromColor(draft);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: draft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: DriveColors.border),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Hue',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: DriveColors.mutedForeground,
                        )),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 8,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 8,
                        ),
                      ),
                      child: Slider(
                        value: hsv.hue,
                        max: 360,
                        onChanged: (v) => setLocal(() {
                          draft = hsv.withHue(v).toColor();
                        }),
                      ),
                    ),
                    Text('Saturation',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: DriveColors.mutedForeground,
                        )),
                    Slider(
                      value: hsv.saturation,
                      onChanged: (v) => setLocal(() {
                        draft = hsv.withSaturation(v).toColor();
                      }),
                    ),
                    Text('Brightness',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: DriveColors.mutedForeground,
                        )),
                    Slider(
                      value: hsv.value,
                      onChanged: (v) => setLocal(() {
                        draft = hsv.withValue(v).toColor();
                      }),
                    ),
                    Text(
                      colorToHex(draft),
                      style: GoogleFonts.dmMono(
                        fontSize: 12,
                        color: DriveColors.primaryGlow,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, draft),
              child: const Text('Use color'),
            ),
          ],
        );
      },
    );
    if (picked != null) onChanged(colorToHex(picked));
  }
}
