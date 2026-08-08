import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/drive_colors.dart';
import 'drive_ui.dart';
import '../../data/catalog/stock_widget_templates.dart';
import '../../data/models/models.dart';
import 'widget_canvas.dart';

class WidgetLibrarySheet extends StatelessWidget {
  const WidgetLibrarySheet({super.key});

  static Future<List<Layer>?> show(BuildContext context) {
    return DriveSheet.show<List<Layer>>(
      context: context,
      builder: (ctx) => const WidgetLibrarySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allTemplates = buildStockWidgetTemplates();
    final categories = <String, List<TemplateItem>>{};

    // Restore all categories so the user doesn't have to manually align complex layouts
    for (final t in allTemplates) {
      var cat = t.category;
      if (cat == 'Digital Clock' || cat == 'Analog Clock') cat = 'Clock';
      if (cat == 'Calendar') cat = 'Date';

      categories.putIfAbsent(cat, () => []).add(t);
    }

    final order = [
      'Clock',
      'Date',
      'Battery',
      'Drive',
      'Speedometer',
      'Weather',
      'Utility',
      'Minimal',
    ];
    final sortedKeys = categories.keys.toList()
      ..sort((a, b) {
        final idxA = order.indexOf(a);
        final idxB = order.indexOf(b);
        if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
        if (idxA != -1) return -1;
        if (idxB != -1) return 1;
        return a.compareTo(b);
      });

    return DriveSheet(
      title: 'Widget Library',
      child: CustomScrollView(
        slivers: [
          for (final cat in sortedKeys) _buildSection(cat, categories[cat]!),
          const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<TemplateItem> templates) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 12, left: 16),
            child: Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: DriveColors.foreground,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.0,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final template = templates[index];
              return _PresetTile(template: template);
            }, childCount: templates.length),
          ),
        ),
      ],
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({required this.template});

  final TemplateItem template;

  @override
  Widget build(BuildContext context) {
    final spec = template.spec;

    return GestureDetector(
      onTap: () {
        final cloned = spec.clone(remintLayerIds: true);
        Navigator.of(context).pop(cloned.layers);
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DriveColors.border.withValues(alpha: 0.5)),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          children: [
            Expanded(
              child: IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: 300,
                      height: 300,
                      child: WidgetCanvas(spec: spec, tickSeconds: 30),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              color: DriveColors.graphite,
              child: Text(
                template.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: DriveColors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
