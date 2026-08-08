import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/drive_colors.dart';
import '../../data/catalog/catalog.dart';
import '../../data/models/models.dart';

/// Hero / thumbnail vehicle imagery.
///
/// Prefers bundled **photographic** PNGs under `assets/vehicles/` (and
/// per-model heroes). CustomPainter silhouette is a last-resort fallback
/// only when an asset fails to decode.
class VehicleArt extends StatelessWidget {
  const VehicleArt({
    super.key,
    required this.kind,
    this.height = 128,
    this.modelId,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.expand = false,
  });

  final ArtworkKind kind;

  /// Ignored when [expand] is true (fills parent constraints).
  final double height;

  /// When set, loads `assets/vehicles/models/<modelId>.png` first.
  final String? modelId;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  /// Fill parent (grid / card photo area) instead of a fixed [height].
  final bool expand;

  String get _primaryAsset {
    if (modelId != null) {
      final modelPath = Catalog.vehicleAssetForModel(modelId!);
      if (modelPath != null) return modelPath;
    }
    return Catalog.vehicleAssetForKind(kind);
  }

  Widget _image() {
    return Image.asset(
      _primaryAsset,
      fit: fit,
      width: double.infinity,
      height: expand ? double.infinity : height,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) {
        if (modelId != null) {
          return Image.asset(
            Catalog.vehicleAssetForKind(kind),
            fit: fit,
            width: double.infinity,
            height: expand ? double.infinity : height,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) =>
                CustomPaint(painter: _VehiclePainter(kind)),
          );
        }
        return CustomPaint(painter: _VehiclePainter(kind));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(16);
    return Semantics(
      label: '${kind.name} vehicle photo',
      image: true,
      child: ClipRRect(
        borderRadius: radius,
        child: expand
            ? SizedBox.expand(child: _image())
            : SizedBox(
                height: height,
                width: double.infinity,
                child: _image(),
              ),
      ),
    );
  }
}

class _VehiclePainter extends CustomPainter {
  _VehiclePainter(this.kind);

  final ArtworkKind kind;

  static const _bodies = {
    ArtworkKind.coupe:
        'M 10 62 C 22 40 38 32 62 30 C 86 28 108 34 124 44 L 162 48 C 176 50 184 56 184 62 Z',
    ArtworkKind.sedan:
        'M 8 62 C 18 44 34 34 60 32 L 112 32 C 140 34 160 42 176 50 L 184 62 Z',
    ArtworkKind.suv:
        'M 10 62 L 10 44 C 10 36 20 30 34 28 L 128 26 C 150 26 168 34 178 48 L 184 62 Z',
    ArtworkKind.wagon:
        'M 8 62 L 8 42 C 8 34 20 30 36 28 L 140 28 C 160 28 174 38 182 52 L 186 62 Z',
    ArtworkKind.roadster:
        'M 6 62 C 18 46 36 38 64 36 C 96 34 128 38 152 44 L 178 52 C 186 56 188 60 186 62 Z',
    ArtworkKind.hatch:
        'M 12 62 L 12 46 C 12 36 26 30 44 28 L 120 28 C 148 30 168 40 178 54 L 182 62 Z',
  };

  Path _parse(String d, double sx, double sy) {
    final path = Path();
    final tokens =
        d.replaceAll(',', ' ').split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    var i = 0;
    double x = 0, y = 0;
    while (i < tokens.length) {
      final cmd = tokens[i++];
      switch (cmd) {
        case 'M':
          x = double.parse(tokens[i++]) * sx;
          y = double.parse(tokens[i++]) * sy;
          path.moveTo(x, y);
        case 'L':
          x = double.parse(tokens[i++]) * sx;
          y = double.parse(tokens[i++]) * sy;
          path.lineTo(x, y);
        case 'C':
          final x1 = double.parse(tokens[i++]) * sx;
          final y1 = double.parse(tokens[i++]) * sy;
          final x2 = double.parse(tokens[i++]) * sx;
          final y2 = double.parse(tokens[i++]) * sy;
          x = double.parse(tokens[i++]) * sx;
          y = double.parse(tokens[i++]) * sy;
          path.cubicTo(x1, y1, x2, y2, x, y);
        case 'Z':
        case 'z':
          path.close();
      }
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 196;
    final sy = size.height / 78;
    final body = _parse(_bodies[kind] ?? _bodies[ArtworkKind.coupe]!, sx, sy);

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          DriveColors.primaryGlow.withValues(alpha: 0.95),
          DriveColors.primary.withValues(alpha: 0.45),
        ],
      ).createShader(Offset.zero & size);

    canvas.drawPath(body, fill);
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = DriveColors.primary.withValues(alpha: 0.7),
    );

    final wheelR = (10 * sx).clamp(6.0, 14.0);
    final wheel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = DriveColors.foreground.withValues(alpha: 0.75);
    canvas.drawCircle(Offset(54 * sx, 63 * sy), wheelR, wheel);
    canvas.drawCircle(Offset(146 * sx, 63 * sy), wheelR, wheel);

    canvas.drawLine(
      Offset(20 * sx, 74 * sy),
      Offset(176 * sx, 74 * sy),
      Paint()
        ..color = DriveColors.foreground.withValues(alpha: 0.2)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _VehiclePainter oldDelegate) =>
      oldDelegate.kind != kind;
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, required this.brandId, this.size = 32});

  final String brandId;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _BrandPainter(brandId)),
    );
  }
}

class _BrandPainter extends CustomPainter {
  _BrandPainter(this.brandId);

  final String brandId;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = DriveColors.primary;
    final stroke = Paint()
      ..color = DriveColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.12;
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2;

    switch (brandId) {
      case 'aurelio':
        canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy - r * 0.85)
            ..lineTo(c.dx + r * 0.78, c.dy + r * 0.7)
            ..lineTo(c.dx - r * 0.78, c.dy + r * 0.7)
            ..close(),
          paint,
        );
      case 'velora':
        canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy - r * 0.82)
            ..lineTo(c.dx + r * 0.7, c.dy)
            ..lineTo(c.dx, c.dy + r * 0.82)
            ..lineTo(c.dx - r * 0.7, c.dy)
            ..close(),
          paint,
        );
      case 'northstar':
        final path = Path();
        for (var i = 0; i < 8; i++) {
          final angle = (i * 45 - 90) * math.pi / 180;
          final rad = i.isEven ? r * 0.9 : r * 0.38;
          final pt = Offset(
            c.dx + rad * math.cos(angle),
            c.dy + rad * math.sin(angle),
          );
          if (i == 0) {
            path.moveTo(pt.dx, pt.dy);
          } else {
            path.lineTo(pt.dx, pt.dy);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
      default:
        canvas.drawCircle(c, r * 0.72, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _BrandPainter oldDelegate) =>
      oldDelegate.brandId != brandId;
}

class OnboardArt extends StatelessWidget {
  const OnboardArt({super.key, required this.variant});

  final int variant;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 240 / 180,
      child: CustomPaint(painter: _OnboardPainter(variant)),
    );
  }
}

class _OnboardPainter extends CustomPainter {
  _OnboardPainter(this.variant);

  final int variant;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 240;
    final sy = size.height / 180;
    RRect rr(double x, double y, double w, double h, double r) =>
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x * sx, y * sy, w * sx, h * sy),
          Radius.circular(r * sx),
        );

    final fill = Paint()..color = DriveColors.primary.withValues(alpha: 0.85);
    final soft = Paint()..color = DriveColors.primary.withValues(alpha: 0.35);
    final faint = Paint()..color = DriveColors.primary.withValues(alpha: 0.18);

    switch (variant) {
      case 1:
        canvas.drawRRect(rr(40, 28, 100, 100, 18), fill);
        canvas.drawRRect(rr(152, 28, 48, 46, 12), soft);
        canvas.drawRRect(rr(152, 84, 48, 44, 12), soft);
        canvas.drawRRect(rr(40, 140, 160, 18, 8), faint);
      case 2:
        for (var i = 0; i < 4; i++) {
          canvas.drawRRect(
            rr(36.0 + i * 46, 30, 36, 120, 10),
            i < 2 ? fill : faint,
          );
        }
      default:
        canvas.drawRRect(rr(48, 36, 144, 108, 22), soft);
        canvas.drawRRect(rr(72, 58, 96, 64, 14), fill);
        canvas.drawRRect(rr(86, 130, 68, 10, 5), faint);
    }
  }

  @override
  bool shouldRepaint(covariant _OnboardPainter oldDelegate) =>
      oldDelegate.variant != variant;
}
