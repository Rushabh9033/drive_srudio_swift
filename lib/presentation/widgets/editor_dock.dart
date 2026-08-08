import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/drive_colors.dart';

class EditorDock extends StatelessWidget {
  const EditorDock({
    super.key,
    required this.drawMode,
    required this.onImage,
    required this.onText,
    required this.onWidget,
    required this.onDraw,
    required this.onBackground,
  });

  final bool drawMode;
  final VoidCallback onImage;
  final VoidCallback onText;
  final VoidCallback onWidget;
  final VoidCallback onDraw;
  final VoidCallback onBackground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: DriveColors.obsidian,
        border: Border(top: BorderSide(color: DriveColors.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _DockItem(
              icon: CupertinoIcons.photo,
              label: 'Image',
              isActive: false,
              onTap: onImage,
            ),
            _DockItem(
              icon: CupertinoIcons.textformat,
              label: 'Text',
              isActive: false,
              onTap: onText,
            ),
            _DockItem(
              icon: CupertinoIcons.plus_app,
              label: 'Widget',
              isActive: false,
              onTap: onWidget,
            ),
            _DockItem(
              icon: CupertinoIcons.scribble,
              label: 'Draw',
              isActive: drawMode,
              onTap: onDraw,
            ),
            _DockItem(
              icon: CupertinoIcons.color_filter,
              label: 'Background',
              isActive: false,
              onTap: onBackground,
            ),
          ],
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? DriveColors.primary : DriveColors.mutedForeground;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
