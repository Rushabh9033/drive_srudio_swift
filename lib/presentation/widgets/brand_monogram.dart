import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/drive_colors.dart';

/// Abstract monogram / text badge — never scrapes OEM trademark logos.
/// Prefers bundled PNG lettermarks under `assets/logos/`.
class BrandMonogram extends StatelessWidget {
  const BrandMonogram({
    super.key,
    required this.brand,
    this.size = 48,
    this.color = DriveColors.foreground,
    this.fill = DriveColors.graphite,
  });

  final String brand;
  final double size;
  final Color color;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return _PaintedMonogram(
      brand: brand,
      size: size,
      color: color,
      fill: fill,
    );
  }
}

class _PaintedMonogram extends StatelessWidget {
  const _PaintedMonogram({
    required this.brand,
    required this.size,
    required this.color,
    required this.fill,
  });

  final String brand;
  final double size;
  final Color color;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final mark = brand.trim().isEmpty ? '?' : brand.trim().substring(0, 1).toUpperCase();
    final hue = (brand.toLowerCase().hashCode.abs() % 360).toDouble();
    final accent = HSLColor.fromAHSL(1, hue, 0.45, 0.52).toColor();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            fill,
            Color.lerp(fill, accent, 0.35)!,
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.22),
            blurRadius: size * 0.18,
            offset: Offset(0, size * 0.06),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        mark,
        style: GoogleFonts.manrope(
          fontSize: size * (mark.length > 2 ? 0.28 : 0.36),
          fontWeight: FontWeight.w800,
          letterSpacing: mark.length > 2 ? -0.5 : 0.5,
          color: color,
        ),
      ),
    );
  }
}

class BrandTextBadge extends StatelessWidget {
  const BrandTextBadge({
    super.key,
    required this.brand,
    this.compact = false,
  });

  final String brand;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMonogram(brand: brand, size: compact ? 28 : 36),
        if (!compact) ...[
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              brand,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
