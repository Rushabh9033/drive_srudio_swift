import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/drive_colors.dart';
import '../../core/theme/drive_theme.dart';

/// Cupertino-feel modal sheet chrome used across Studio / Garage / Sounds.
class DriveSheet extends StatelessWidget {
  const DriveSheet({
    super.key,
    required this.child,
    this.title,
    this.maxHeightFactor = 0.82,
  });

  final Widget child;
  final String? title;
  final double maxHeightFactor;

  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: DriveColors.carbon,
      barrierColor: const Color(0x99080808),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DriveRadii.xxxl),
        ),
      ),
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * maxHeightFactor;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 10,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: DriveColors.graphite,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              if (title != null) ...[
                const SizedBox(height: 16),
                Text(title!.toUpperCase(), style: driveMonoLabel()),
              ],
              const SizedBox(height: 12),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class DashedBorderBox extends StatelessWidget {
  const DashedBorderBox({
    super.key,
    required this.child,
    this.radius = DriveRadii.xl,
    this.color = DriveColors.border,
  });

  final Widget child;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(radius: radius, color: color),
      child: child,
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({required this.radius, required this.color});

  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      const dash = 5.0;
      const gap = 4.0;
      while (distance < metric.length) {
        final next = mathMin(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  double mathMin(double a, double b) => a < b ? a : b;

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class WaveformBars extends StatelessWidget {
  const WaveformBars({
    super.key,
    required this.active,
    this.color = DriveColors.primary,
  });

  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(4, (i) {
          final h = active
              ? [8.0, 14.0, 10.0, 16.0][i]
              : [6.0, 9.0, 7.0, 8.0][i];
          return AnimatedContainer(
            duration: Duration(milliseconds: 180 + i * 40),
            width: 4,
            height: h,
            decoration: BoxDecoration(
              color: color.withValues(alpha: active ? 1 : 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}

class TierBadge extends StatelessWidget {
  const TierBadge({super.key, required this.premium});

  final bool premium;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: premium
            ? DriveColors.primary.withValues(alpha: 0.14)
            : DriveColors.graphite,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: premium
              ? DriveColors.primary.withValues(alpha: 0.45)
              : DriveColors.border,
        ),
      ),
      child: Text(
        premium ? 'PREMIUM' : 'FREE',
        style: driveMonoLabel(
          size: 9,
          color: premium ? DriveColors.primary : DriveColors.mutedForeground,
        ),
      ),
    );
  }
}

/// Chip for stock templates with live clock / battery / motion layers.
class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key, this.label = 'LIVE', this.maxWidth = 112});

  final String label;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF0E2840).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: DriveColors.primary.withValues(alpha: 0.55),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: driveMonoLabel(size: 9, color: DriveColors.primaryGlow),
        ),
      ),
    );
  }
}

/// Compact filter chip with controlled height (avoids Material ChoiceChip overflow).
class DriveChip extends StatelessWidget {
  const DriveChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? DriveColors.primary.withValues(alpha: 0.18)
              : DriveColors.carbon,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? DriveColors.primary : DriveColors.border,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.manrope(
            fontSize: 12,
            height: 1.15,
            fontWeight: FontWeight.w600,
            color: selected ? DriveColors.primary : DriveColors.mutedForeground,
          ),
        ),
      ),
    );
  }
}
