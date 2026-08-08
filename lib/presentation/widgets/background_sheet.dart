import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/drive_colors.dart';
import 'drive_ui.dart';
import '../../data/models/models.dart';

class BackgroundSheet extends StatefulWidget {
  const BackgroundSheet({
    super.key,
    required this.spec,
    required this.onChanged,
    required this.onPickImage,
  });

  final WidgetSpec spec;
  final ValueChanged<WidgetSpec> onChanged;
  final Future<WidgetBackground?> Function() onPickImage;

  static Future<void> show(
    BuildContext context,
    WidgetSpec spec,
    ValueChanged<WidgetSpec> onChanged,
    Future<WidgetBackground?> Function() onPickImage,
  ) {
    return DriveSheet.show<void>(
      context: context,
      builder: (ctx) => BackgroundSheet(
        spec: spec,
        onChanged: onChanged,
        onPickImage: onPickImage,
      ),
    );
  }

  @override
  State<BackgroundSheet> createState() => _BackgroundSheetState();
}

class _BackgroundSheetState extends State<BackgroundSheet> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return DriveSheet(
      title: 'Background',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: CupertinoSlidingSegmentedControl<int>(
              groupValue: _tab,
              children: const {
                0: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Image'),
                ),
                1: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Color'),
                ),
              },
              onValueChanged: (v) {
                if (v != null) setState(() => _tab = v);
              },
            ),
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                if (_tab == 0) _buildImageGrid() else _buildColorGrid(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.0,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index == 0) {
            return _Tile(
              icon: CupertinoIcons.photo,
              label: 'Choose\nPhoto',
              onTap: () async {
                final bg = await widget.onPickImage();
                if (bg != null) {
                  widget.onChanged(
                    WidgetSpec(background: bg, layers: widget.spec.layers),
                  );
                }
                if (context.mounted) Navigator.pop(context);
              },
            );
          }
          if (index == 1) {
            return _Tile(
              icon: CupertinoIcons.clear,
              label: 'No Image',
              onTap: () {
                widget.onChanged(
                  WidgetSpec(
                    layers: widget.spec.layers,
                    background: const WidgetBackground(
                      type: BgType.solid,
                      from: '#111111',
                      to: '#111111',
                    ),
                  ),
                );
              },
            );
          }
          return const SizedBox(); // Placeholder for prebundled
        }, childCount: 2),
      ),
    );
  }

  Widget _buildColorGrid() {
    final colors = [
      '#000000',
      '#1C1C1E',
      '#333333',
      '#007AFF',
      '#FF3B30',
      '#34C759',
    ];
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.0,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final hex = colors[index];
          final color = Color(
            int.parse(hex.substring(1), radix: 16) + 0xFF000000,
          );
          return GestureDetector(
            onTap: () {
              widget.onChanged(
                WidgetSpec(
                  layers: widget.spec.layers,
                  background: WidgetBackground(
                    type: BgType.solid,
                    from: hex,
                    to: hex,
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: DriveColors.border, width: 2),
              ),
            ),
          );
        }, childCount: colors.length),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: DriveColors.graphite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DriveColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: DriveColors.primary, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: DriveColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
