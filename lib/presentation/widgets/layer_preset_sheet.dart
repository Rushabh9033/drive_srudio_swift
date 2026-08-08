import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/drive_colors.dart';
import '../../core/theme/drive_colors.dart';
import '../../data/catalog/layer_presets.dart';
import '../../data/models/models.dart';
import 'drive_ui.dart';
import 'preview_widget_canvas.dart';

class LayerPresetSheet extends StatelessWidget {
  const LayerPresetSheet({
    super.key,
    required this.kind,
    required this.onSelect,
  });

  final LayerKind kind;
  final ValueChanged<Layer> onSelect;

  @override
  Widget build(BuildContext context) {
    final presets = kLayerPresets[kind] ?? [];

    // If no presets exist for this kind, just invoke with a base layer immediately
    // but the editor shouldn't open this sheet if there are no presets.

    return DriveSheet(
      title: 'Select preset',
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 8, bottom: 40),
        itemCount: presets.length,
        separatorBuilder: (ctx, i) => Divider(
          color: DriveColors.border,
          height: 1,
          indent: 20,
          endIndent: 20,
        ),
        itemBuilder: (ctx, i) {
          final preset = presets[i];

          // Center the layer inside a 360x360 canvas for the preview thumbnail
          final previewLayer = preset.layer.copyWith(
            x: 50 - preset.layer.w / 2,
            y: 50 - preset.layer.h / 2,
          );

          final previewSpec = WidgetSpec(
            background: WidgetBackground(
              type: BgType.solid,
              from: '#06080A',
              to: '',
            ),
            layers: [previewLayer],
          );

          return CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            onPressed: () {
              Navigator.pop(context);
              // Give them the original preset layer (not the re-centered preview one)
              onSelect(preset.layer);
            },
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: DriveColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: DriveColors.border),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Center(
                    child: SizedBox(
                      width: 50,
                      height: 50,
                      child: PreviewWidgetCanvas(
                        spec: previewSpec,
                        samplePreview: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preset.name,
                        style: GoogleFonts.manrope(
                          color: DriveColors.foreground,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        preset.description,
                        style: GoogleFonts.manrope(
                          color: DriveColors.mutedForeground,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  CupertinoIcons.add_circled,
                  color: DriveColors.primary,
                  size: 20,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
