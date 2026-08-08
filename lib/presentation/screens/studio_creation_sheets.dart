import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/nav/studio_browse.dart';
import '../../core/theme/drive_colors.dart';
import '../widgets/brand_monogram.dart';
import '../widgets/drive_ui.dart';

/// Image Selection: user photo only (gallery / camera) + in-app Remove BG.
Future<ImageSelectionChoice?> showImageSelectionSheet(BuildContext context) {
  return DriveSheet.show<ImageSelectionChoice>(
    context: context,
    builder: (ctx) => DriveSheet(
      title: null,
      maxHeightFactor: 0.72,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Add your photo',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Your car only — no stock photos in the app',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: DriveColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    backgroundColor: DriveColors.graphite,
                    foregroundColor: DriveColors.foreground,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: DriveColors.primary,
                foregroundColor: DriveColors.primaryForeground,
                minimumSize: const Size.fromHeight(52),
                textStyle: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              onPressed: () =>
                  Navigator.pop(ctx, ImageSelectionChoice.removeBg),
              icon: const Icon(Icons.auto_fix_high, size: 22),
              label: const Text('Remove BG'),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              child: Text(
                'Picks your photo, then cuts out the background in-app.',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  height: 1.35,
                  color: DriveColors.mutedForeground,
                ),
              ),
            ),
            const Divider(height: 24, color: DriveColors.border),
            _ImageOption(
              icon: CupertinoIcons.photo_on_rectangle,
              iconColor: DriveColors.success,
              title: 'Choose Gallery',
              subtitle: 'Use a photo from your device',
              onTap: () => Navigator.pop(ctx, ImageSelectionChoice.gallery),
            ),
            const SizedBox(height: 8),
            _ImageOption(
              icon: CupertinoIcons.camera_fill,
              iconColor: DriveColors.primary,
              title: 'Take photo',
              subtitle: 'Capture with the camera',
              onTap: () => Navigator.pop(ctx, ImageSelectionChoice.camera),
            ),
          ],
        ),
      ),
    ),
  );
}

enum ImageSelectionChoice { gallery, camera, removeBg }

/// Post-pick sheet — Remove BG or keep original.
enum RemoveBgPromptChoice { keep, removeBg }

Future<RemoveBgPromptChoice?> showRemoveBackgroundPrompt(BuildContext context) {
  return DriveSheet.show<RemoveBgPromptChoice>(
    context: context,
    builder: (ctx) => DriveSheet(
      title: 'Remove BG',
      maxHeightFactor: 0.55,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Cut the background from this photo in-app before placing it on the canvas.',
            style: GoogleFonts.manrope(
              fontSize: 14,
              height: 1.35,
              color: DriveColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: DriveColors.primary,
              foregroundColor: DriveColors.primaryForeground,
              minimumSize: const Size.fromHeight(52),
              textStyle: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            onPressed: () => Navigator.pop(ctx, RemoveBgPromptChoice.removeBg),
            icon: const Icon(Icons.auto_fix_high, size: 22),
            label: const Text('Remove BG'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(ctx, RemoveBgPromptChoice.keep),
            child: const Text('Keep original photo'),
          ),
        ],
      ),
    ),
  );
}

class _ImageOption extends StatelessWidget {
  const _ImageOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.manrope(
                        color: DriveColors.mutedForeground,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_forward,
                size: 18,
                color: DriveColors.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Text editor: color, weight, shadow, radius, optional gradient.
Future<Map<String, dynamic>?> showTextEditorSheet(
  BuildContext context, {
  required String initialText,
  required String color,
  String? color2,
  required int weight,
  required bool shadow,
  String? shadowColor,
  required double radius,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: DriveColors.carbon,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => _TextEditorBody(
      initialText: initialText,
      color: color,
      color2: color2,
      weight: weight,
      shadow: shadow,
      shadowColor: shadowColor,
      radius: radius,
    ),
  );
}

class _TextEditorBody extends StatefulWidget {
  const _TextEditorBody({
    required this.initialText,
    required this.color,
    this.color2,
    required this.weight,
    required this.shadow,
    this.shadowColor,
    required this.radius,
  });

  final String initialText;
  final String color;
  final String? color2;
  final int weight;
  final bool shadow;
  final String? shadowColor;
  final double radius;

  @override
  State<_TextEditorBody> createState() => _TextEditorBodyState();
}

class _TextEditorBodyState extends State<_TextEditorBody> {
  late final TextEditingController _text;
  late String _color;
  String? _color2;
  late int _weight;
  late bool _shadow;
  String? _shadowColor;
  late double _radius;

  static const _palette = [
    '#FFFFFF',
    '#9A9BA8',
    '#E8913A',
    '#4DC98A',
    '#2BB8A8',
    '#4D9EFF',
    '#7A6FF0',
    '#8B5A3C',
    '#12141A',
    '#E05A45',
    '#E5B84A',
    '#1E3A5F',
    '#7FB6FF',
    '#D946EF',
    '#F472B6',
    '#CBD5E1',
  ];

  static const _gradients = [
    ('#FFFFFF', '#9A9BA8'),
    ('#12141A', '#2A2B36'),
    ('#4D9EFF', '#7EB8FF'),
    ('#E05A45', '#E5B84A'),
    ('#4DC98A', '#2BB8A8'),
    ('#F472B6', '#7A6FF0'),
  ];

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.initialText);
    _color = widget.color;
    _color2 = widget.color2;
    _weight = widget.weight;
    _shadow = widget.shadow;
    _shadowColor = widget.shadowColor;
    _radius = widget.radius;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    backgroundColor: DriveColors.graphite,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Cancel'),
                ),
                Expanded(
                  child: Text(
                    'Edit Text',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, {
                    'text': _text.text,
                    'color': _color,
                    'color2': _color2,
                    'weight': _weight,
                    'shadow': _shadow,
                    'shadowColor': _shadowColor,
                    'radius': _radius,
                  }),
                  style: TextButton.styleFrom(
                    backgroundColor: DriveColors.graphite,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _text,
              style: GoogleFonts.manrope(
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
              decoration: const InputDecoration(
                hintText: 'Enter Text',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Color',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final hex in _palette)
                  GestureDetector(
                    onTap: () => setState(() {
                      _color = hex;
                      _color2 = null;
                    }),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Color(
                          int.parse('FF${hex.substring(1)}', radix: 16),
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color.toUpperCase() == hex && _color2 == null
                              ? DriveColors.primary
                              : DriveColors.border,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Gradient',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 28,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final g in _gradients)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _color = g.$1;
                          _color2 = g.$2;
                        }),
                        child: Container(
                          width: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: LinearGradient(
                              colors: [
                                Color(
                                  int.parse(
                                    'FF${g.$1.substring(1)}',
                                    radix: 16,
                                  ),
                                ),
                                Color(
                                  int.parse(
                                    'FF${g.$2.substring(1)}',
                                    radix: 16,
                                  ),
                                ),
                              ],
                            ),
                            border: Border.all(
                              color: _color == g.$1 && _color2 == g.$2
                                  ? DriveColors.primary
                                  : DriveColors.border,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Weight',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final w in [400, 500, 600, 700, 800])
                  ChoiceChip(
                    label: Text('$w'),
                    selected: _weight == w,
                    onSelected: (_) => setState(() => _weight = w),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Shadow',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Switch(
                  value: _shadow,
                  onChanged: (v) => setState(() => _shadow = v),
                ),
              ],
            ),
            Text(
              'Radius',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
            ),
            Slider(
              value: _radius.clamp(0, 24),
              min: 0,
              max: 24,
              onChanged: (v) => setState(() => _radius = v),
            ),
          ],
        ),
      ),
    );
  }
}

Future<Map<String, String>?> showClockEditorSheet(
  BuildContext context, {
  required String clockFormat,
  required String dateFormat,
}) {
  return showModalBottomSheet<Map<String, String>>(
    context: context,
    backgroundColor: DriveColors.carbon,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) {
      final maxH = MediaQuery.sizeOf(ctx).height * 0.88;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: _ClockEditorBody(
          clockFormat: clockFormat,
          dateFormat: dateFormat,
        ),
      );
    },
  );
}

class _ClockEditorBody extends StatefulWidget {
  const _ClockEditorBody({required this.clockFormat, required this.dateFormat});
  final String clockFormat;
  final String dateFormat;

  @override
  State<_ClockEditorBody> createState() => _ClockEditorBodyState();
}

class _ClockEditorBodyState extends State<_ClockEditorBody> {
  late String _clock;
  late String _date;

  @override
  void initState() {
    super.initState();
    _clock = widget.clockFormat.isEmpty ? '24' : widget.clockFormat;
    _date = widget.dateFormat.isEmpty ? 'abbrev' : widget.dateFormat;
  }

  void _browseStock(String category) {
    final router = GoRouter.of(context);
    StudioBrowse.openCategory(category);
    Navigator.pop(context);
    router.go('/studio');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  Expanded(
                    child: Text(
                      'Clock Editor',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, {
                      'clockFormat': _clock,
                      'dateFormat': _date,
                    }),
                    child: const Text('Done'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Formats for this clock/date layer only — not the full widget library.',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  height: 1.35,
                  color: DriveColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Browse full widgets',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Open Studio Stock for ready-made clocks, calendars, and speedometers.',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: DriveColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 10),
              _BrowseStockTile(
                title: 'Digital clocks',
                icon: CupertinoIcons.clock,
                onTap: () => _browseStock('Digital Clock'),
              ),
              _BrowseStockTile(
                title: 'Analog clocks',
                icon: CupertinoIcons.circle,
                onTap: () => _browseStock('Analog Clock'),
              ),
              _BrowseStockTile(
                title: 'Date & calendar',
                icon: CupertinoIcons.calendar,
                onTap: () => _browseStock('Calendar'),
              ),
              _BrowseStockTile(
                title: 'Speedometers',
                icon: CupertinoIcons.speedometer,
                onTap: () => _browseStock('Speedometer'),
              ),
              _BrowseStockTile(
                title: 'Drive HUDs',
                icon: CupertinoIcons.car_fill,
                onTap: () => _browseStock('Drive'),
              ),
              const SizedBox(height: 16),
              Text(
                'Time format',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              _FmtTile(
                title: 'Standard (12:55)',
                selected: _clock == '12',
                onTap: () => setState(() => _clock = '12'),
              ),
              _FmtTile(
                title: '24-Hour (15:30)',
                selected: _clock == '24',
                onTap: () => setState(() => _clock = '24'),
              ),
              const SizedBox(height: 16),
              Text(
                'Date format',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              _FmtTile(
                title: 'Standard (Oct 13)',
                selected: _date == 'short',
                onTap: () => setState(() => _date = 'short'),
              ),
              _FmtTile(
                title: 'Full Month (October 13)',
                selected: _date == 'medium',
                onTap: () => setState(() => _date = 'medium'),
              ),
              _FmtTile(
                title: 'Weekday (Sun, 2 Aug)',
                selected: _date == 'abbrev',
                onTap: () => setState(() => _date = 'abbrev'),
              ),
              _FmtTile(
                title: 'Full (Sunday, August 2)',
                selected: _date == 'full',
                onTap: () => setState(() => _date = 'full'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrowseStockTile extends StatelessWidget {
  const _BrowseStockTile({
    required this.title,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: DriveColors.graphite,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: DriveColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(
                  CupertinoIcons.chevron_right,
                  color: DriveColors.mutedForeground,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FmtTile extends StatelessWidget {
  const _FmtTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? DriveColors.primary.withValues(alpha: 0.15)
            : DriveColors.graphite,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                  ),
                ),
                if (selected)
                  const Icon(
                    CupertinoIcons.check_mark_circled_solid,
                    color: DriveColors.primary,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showHowToModal(BuildContext context, {VoidCallback? onYes}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: DriveColors.carbon,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Widget Configured!',
        style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
      ),
      content: Text(
        'Would you like to open the How To Set Widget page?',
        style: GoogleFonts.manrope(color: DriveColors.mutedForeground),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('No'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            onYes?.call();
          },
          child: const Text('Yes'),
        ),
      ],
    ),
  );
}
