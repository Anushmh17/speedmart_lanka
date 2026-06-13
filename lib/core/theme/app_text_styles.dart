import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Theme 3: Typography system
/// Uses Inter font for modern, clean aesthetics.
class AppTextStyles {
  AppTextStyles._();

  // Safe Inter font loading with system fallback
  static TextStyle _getBaseFont() {
    try {
      return GoogleFonts.inter();
    } catch (e) {
      return const TextStyle(fontFamily: 'System');
    }
  }

  static TextStyle get _base => _getBaseFont();

  // ── Display ───────────────────────────────────────────────────────────────
  static TextStyle display1(Color color) => _base.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.2,
        color: color,
      );

  static TextStyle display2(Color color) => _base.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        height: 1.2,
        color: color,
      );

  // ── Headlines ─────────────────────────────────────────────────────────────
  static TextStyle h1(Color color) => _base.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.3,
        color: color,
      );

  static TextStyle h2(Color color) => _base.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: color,
      );

  static TextStyle h3(Color color) => _base.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: color,
      );

  static TextStyle subtitle(Color color) => _base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.5,
        color: color,
      );

  // ── Body ──────────────────────────────────────────────────────────────────
  static TextStyle bodyLarge(Color color) => _base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.6,
        color: color,
      );

  static TextStyle bodyMedium(Color color) => _base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: color,
      );

  static TextStyle bodySmall(Color color) => _base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: color,
      );

  // ── Labels ────────────────────────────────────────────────────────────────
  static TextStyle labelLarge(Color color) => _base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: color,
      );

  static TextStyle labelMedium(Color color) => _base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: color,
      );

  static TextStyle labelSmall(Color color) => _base.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: color,
      );

  // ── Button ────────────────────────────────────────────────────────────────
  static TextStyle button(Color color) => _base.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: color,
      );

  // ── Caption ───────────────────────────────────────────────────────────────
  static TextStyle caption(Color color) => _base.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        height: 1.3,
        color: color,
      );

  // ── TextTheme for Material ───────────────────────────────────────────────
  static TextTheme get textTheme {
    try {
      return GoogleFonts.interTextTheme();
    } catch (e) {
      return ThemeData.light().textTheme;
    }
  }

  static TextTheme get darkTextTheme {
    try {
      return GoogleFonts.interTextTheme(ThemeData.dark().textTheme);
    } catch (e) {
      return ThemeData.dark().textTheme;
    }
  }
}
