import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/drive_colors.dart';
import '../../core/theme/drive_theme.dart';
import '../../data/catalog/background_library.dart';
import '../../data/models/models.dart';
import '../../data/store/app_store.dart';
import '../widgets/drive_ui.dart';
import '../widgets/widget_canvas.dart';

/// AutoDash-style background library — grid thumbnails, categories, search.
Future<WidgetBackground?> showBackgroundPickerSheet(
  BuildContext context, {
  required WidgetBackground current,
  required Future<WidgetBackground?> Function() onPickGallery,
}) {
  return DriveSheet.show<WidgetBackground>(
    context: context,
    builder: (ctx) => DriveSheet(
      title: 'Background',
      maxHeightFactor: 0.9,
      child: _BackgroundPickerBody(
        current: current,
        onPickGallery: onPickGallery,
      ),
    ),
  );
}

class _BackgroundPickerBody extends StatefulWidget {
  const _BackgroundPickerBody({
    required this.current,
    required this.onPickGallery,
  });

  final WidgetBackground current;
  final Future<WidgetBackground?> Function() onPickGallery;

  @override
  State<_BackgroundPickerBody> createState() => _BackgroundPickerBodyState();
}

class _BackgroundPickerBodyState extends State<_BackgroundPickerBody> {
  BgCategory? _category;
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final presets = BackgroundLibrary.filtered(
      category: _category,
      query: _query.text.trim(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _query,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search backgrounds',
            prefixIcon: const Icon(CupertinoIcons.search, size: 18),
            isDense: true,
            filled: true,
            fillColor: DriveColors.graphite,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: DriveChip(
                  label: 'All',
                  selected: _category == null,
                  onTap: () => setState(() => _category = null),
                ),
              ),
              for (final c in BackgroundLibrary.categories)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: DriveChip(
                    label: BackgroundLibrary.categoryLabel(c),
                    selected: _category == c,
                    onTap: () => setState(() => _category = c),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Material(
          color: DriveColors.graphite,
          borderRadius: BorderRadius.circular(DriveRadii.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(DriveRadii.lg),
            onTap: () async {
              final bg = await widget.onPickGallery();
              if (bg != null && context.mounted) {
                Navigator.pop(context, bg);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.photo_on_rectangle, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Gallery photo',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Icon(CupertinoIcons.chevron_right, size: 16),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: presets.isEmpty
              ? Center(
                  child: Text(
                    'No backgrounds match',
                    style: GoogleFonts.manrope(
                      color: DriveColors.mutedForeground,
                    ),
                  ),
                )
              : GridView.builder(
                  itemCount: presets.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.05,
                  ),
                  itemBuilder: (context, i) {
                    final p = presets[i];
                    final locked = p.premium && !store.isPremium;
                    final selected = _sameBg(widget.current, p.background);
                    return _BgTile(
                      preset: p,
                      selected: selected,
                      locked: locked,
                      onTap: () {
                        if (locked) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Premium background — unlock in Settings',
                              ),
                            ),
                          );
                          return;
                        }
                        Navigator.pop(context, p.background);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  bool _sameBg(WidgetBackground a, WidgetBackground b) {
    return a.type == b.type &&
        a.from == b.from &&
        a.to == b.to &&
        a.imageSrc == b.imageSrc;
  }
}

class _BgTile extends StatelessWidget {
  const _BgTile({
    required this.preset,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final BackgroundPreset preset;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? DriveColors.primary
                  : DriveColors.border.withValues(alpha: 0.8),
              width: selected ? 2 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _thumb(preset.background),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: Text(
                    preset.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      shadows: const [
                        Shadow(color: Color(0xCC000000), blurRadius: 8),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Text(
                    BackgroundLibrary.categoryLabel(
                      preset.category,
                    ).toUpperCase(),
                    style: driveMono(
                      size: 9,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                if (preset.premium)
                  const Positioned(
                    top: 6,
                    right: 6,
                    child: TierBadge(premium: true),
                  ),
                if (locked)
                  ColoredBox(
                    color: Colors.black.withValues(alpha: 0.45),
                    child: const Center(
                      child: Icon(
                        CupertinoIcons.lock_fill,
                        size: 18,
                        color: Colors.white70,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumb(WidgetBackground bg) {
    if (bg.type == BgType.image &&
        bg.imageSrc != null &&
        bg.imageSrc!.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_hex(bg.from), _hex(bg.to ?? bg.from)],
              ),
            ),
          ),
          StoredImage(src: bg.imageSrc, fit: BoxFit.cover),
        ],
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(-0.6, -1),
          end: const Alignment(0.8, 1),
          colors: [_hex(bg.from), _hex(bg.to ?? bg.from)],
        ),
      ),
    );
  }

  Color _hex(String hex) {
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.tryParse(h, radix: 16) ?? 0xFF12141A);
  }
}
