import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// DryClean Plus brand tokens (shared with the website and the intake app).
class DC {
  static const forest = Color(0xFF073B1B);
  static const forest2 = Color(0xFF0B5A2B);
  static const deep = Color(0xFF042511);
  static const emerald = Color(0xFF059669);
  static const emerald2 = Color(0xFF065F46);
  static const mint = Color(0xFFECFDF5);
  static const mint2 = Color(0xFFD1FAE5);
  static const gold = Color(0xFFFDE047);
  static const gold2 = Color(0xFFFACC15);
  static const blue = Color(0xFF1C61E4);
  static const blueSoft = Color(0xFFEFF6FF);
  static const ink = Color(0xFF0F172A);
  static const mut = Color(0xFF64748B);
  static const line = Color(0xFFE2E8F0);
  static const bg = Color(0xFFF4F7F5);
  static const red = Color(0xFFE5262D);
  static const redSoft = Color(0xFFFEF2F2);
  static const amber = Color(0xFFB45309);
  static const amberSoft = Color(0xFFFEF3C7);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [forest2, forest, deep],
    stops: [0, .6, 1],
  );

  static TextStyle h(double size, {Color color = ink, FontWeight w = FontWeight.w800}) =>
      GoogleFonts.outfit(fontSize: size, fontWeight: w, color: color, height: 1.1, letterSpacing: -.2);

  static TextStyle t(double size, {Color color = ink, FontWeight w = FontWeight.w600, double? height}) =>
      GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: w, color: color, height: height);

  static List<BoxShadow> shadow([double o = .10]) => [
        BoxShadow(color: forest.withValues(alpha: o), blurRadius: 24, offset: const Offset(0, 10), spreadRadius: -8),
      ];
}

ThemeData buildTheme() {
  final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
  return base.copyWith(
    scaffoldBackgroundColor: DC.bg,
    colorScheme: ColorScheme.fromSeed(seedColor: DC.forest, primary: DC.forest, secondary: DC.gold, surface: Colors.white, error: DC.red),
    textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(bodyColor: DC.ink, displayColor: DC.ink),
    appBarTheme: AppBarTheme(
      backgroundColor: DC.bg,
      foregroundColor: DC.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: DC.h(19),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: DC.ink,
      contentTextStyle: DC.t(14, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: DC.t(14, color: DC.mut),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: DC.line, width: 1.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: DC.line, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: DC.emerald, width: 2)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.white, showDragHandle: true, surfaceTintColor: Colors.white),
  );
}
