import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'drive_colors.dart';

abstract final class DriveRadii {
  static const double base = 16;
  static const double sm = 12;
  static const double md = 14;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 28;
  static const double huge = 32;
}

abstract final class DriveShadows {
  static List<BoxShadow> get elevated => [
    BoxShadow(
      color: DriveColors.shadowElevated,
      blurRadius: 60,
      offset: const Offset(0, -28),
      spreadRadius: -28,
    ),
  ];

  static List<BoxShadow> get glow => [
    const BoxShadow(
      color: DriveColors.glowRing,
      blurRadius: 0,
      spreadRadius: 1,
    ),
    BoxShadow(
      color: DriveColors.glowSoft.withValues(alpha: 0.35),
      blurRadius: 45,
      offset: const Offset(0, 18),
      spreadRadius: -22,
    ),
  ];
}

ThemeData buildDriveTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: DriveColors.background,
    canvasColor: DriveColors.background,
    colorScheme: const ColorScheme.dark(
      surface: DriveColors.background,
      primary: DriveColors.primary,
      onPrimary: DriveColors.primaryForeground,
      secondary: DriveColors.graphite,
      onSecondary: DriveColors.foreground,
      error: DriveColors.destructive,
      onError: DriveColors.foreground,
      onSurface: DriveColors.foreground,
      outline: DriveColors.border,
    ),
    dividerColor: DriveColors.border,
    splashFactory: InkSparkle.splashFactory,
  );

  final manrope = GoogleFonts.manropeTextTheme(base.textTheme).apply(
    bodyColor: DriveColors.foreground,
    displayColor: DriveColors.foreground,
  );

  return base.copyWith(
    textTheme: manrope.copyWith(
      headlineLarge: manrope.headlineLarge?.copyWith(
        letterSpacing: -0.02 * 32,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: manrope.headlineMedium?.copyWith(
        letterSpacing: -0.02 * 28,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: manrope.headlineSmall?.copyWith(
        letterSpacing: -0.02 * 24,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: manrope.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: manrope.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: manrope.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: manrope.bodyMedium?.copyWith(height: 1.45),
      labelSmall: GoogleFonts.dmMono(
        fontSize: 11,
        letterSpacing: 1.32,
        fontWeight: FontWeight.w500,
        color: DriveColors.mutedForeground,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: DriveColors.background,
      foregroundColor: DriveColors.foreground,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.manrope(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: DriveColors.foreground,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: DriveColors.carbon,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DriveRadii.xxl),
        side: const BorderSide(color: DriveColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: DriveColors.carbon,
      hintStyle: GoogleFonts.manrope(color: DriveColors.mutedForeground),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DriveRadii.lg),
        borderSide: const BorderSide(color: DriveColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DriveRadii.lg),
        borderSide: const BorderSide(color: DriveColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DriveRadii.lg),
        borderSide: const BorderSide(color: DriveColors.primary, width: 1.2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: DriveColors.primary,
        foregroundColor: DriveColors.primaryForeground,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DriveRadii.lg),
        ),
        textStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: DriveColors.foreground,
        side: const BorderSide(color: DriveColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DriveRadii.lg),
        ),
        textStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: DriveColors.primary,
        textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w600),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: DriveColors.primary,
      inactiveTrackColor: DriveColors.graphite,
      thumbColor: DriveColors.primary,
      overlayColor: DriveColors.primary.withValues(alpha: 0.18),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected))
          return DriveColors.primaryForeground;
        return DriveColors.mutedForeground;
      }),
      trackColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected)) return DriveColors.primary;
        return DriveColors.graphite;
      }),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: DriveColors.carbon,
      modalBackgroundColor: DriveColors.carbon,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DriveRadii.xxxl),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: DriveColors.carbon,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DriveRadii.xxl),
        side: const BorderSide(color: DriveColors.border),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: DriveColors.graphite,
      contentTextStyle: GoogleFonts.manrope(color: DriveColors.foreground),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DriveRadii.lg),
      ),
    ),
  );
}

TextStyle driveMonoLabel({Color? color, double size = 11}) {
  return GoogleFonts.dmMono(
    fontSize: size,
    letterSpacing: 1.32,
    fontWeight: FontWeight.w500,
    color: color ?? DriveColors.mutedForeground,
  );
}

TextStyle driveMono({
  double size = 13,
  FontWeight weight = FontWeight.w500,
  Color? color,
}) {
  return GoogleFonts.dmMono(
    fontSize: size,
    fontWeight: weight,
    color: color ?? DriveColors.primary,
  );
}
