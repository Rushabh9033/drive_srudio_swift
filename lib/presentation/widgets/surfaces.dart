import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/drive_colors.dart';
import '../../core/theme/drive_theme.dart';

class MonoLabel extends StatelessWidget {
  const MonoLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: driveMonoLabel(color: color));
  }
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.glow = false,
    this.hero = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool glow;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(DriveRadii.xxl);
    final decoration = BoxDecoration(
      borderRadius: radius,
      border: Border.all(
        color: glow
            ? DriveColors.primary.withValues(alpha: 0.45)
            : DriveColors.border,
      ),
      gradient: hero
          ? const RadialGradient(
              center: Alignment(-0.7, -1.0),
              radius: 1.35,
              colors: [Color(0x664D9EFF), DriveColors.obsidian],
              stops: [0.0, 0.72],
            )
          : const LinearGradient(
              begin: Alignment(-0.8, -1),
              end: Alignment(0.9, 1),
              colors: [Color(0xFF222430), DriveColors.carbon],
            ),
      boxShadow: glow ? DriveShadows.glow : DriveShadows.elevated,
    );

    final content = Container(
      width: double.infinity,
      padding: padding,
      decoration: decoration,
      child: Material(type: MaterialType.transparency, child: child),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        splashColor: DriveColors.primary.withValues(alpha: 0.12),
        highlightColor: DriveColors.primary.withValues(alpha: 0.06),
        child: content,
      ),
    );
  }
}

class GradientWord extends StatelessWidget {
  const GradientWord(this.text, {super.key, this.size = 28});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [DriveColors.primary, DriveColors.primaryGlow],
      ).createShader(bounds),
      child: Text(
        text,
        style: GoogleFonts.manrope(
          fontSize: size,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
          color: Colors.white,
        ),
      ),
    );
  }
}

class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 768),
        child: Padding(
          padding: padding ?? const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: child,
        ),
      ),
    );
  }
}
