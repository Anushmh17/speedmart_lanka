import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography system for Speedmart Lanka.
/// All text styles use Outfit from Google Fonts.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle get _base => GoogleFonts.outfit();

  // ── Display ───────────────────────────────────────────────────────────────
  static TextStyle display1(Color color) => _base.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: color,
      );

  static TextStyle display2(Color color) => _base.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: color,
      );

  // ── Headlines ─────────────────────────────────────────────────────────────
  static TextStyle h1(Color color) => _base.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: color,
      );

  static TextStyle h2(Color color) => _base.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle h3(Color color) => _base.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle subtitle(Color color) => _base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: color,
      );

  // ── Body ──────────────────────────────────────────────────────────────────
  static TextStyle bodyLarge(Color color) => _base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.5,
      );

  static TextStyle bodyMedium(Color color) => _base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.5,
      );

  static TextStyle bodySmall(Color color) => _base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.4,
      );

  // ── Labels ────────────────────────────────────────────────────────────────
  static TextStyle labelLarge(Color color) => _base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle labelMedium(Color color) => _base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: color,
      );

  static TextStyle labelSmall(Color color) => _base.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: color,
      );

  // ── Button ────────────────────────────────────────────────────────────────
  static TextStyle button(Color color) => _base.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: color,
      );

  // ── Caption ───────────────────────────────────────────────────────────────
  static TextStyle caption(Color color) => _base.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.3,
      );

  // ── App-wide TextTheme ────────────────────────────────────────────────────
  static TextTheme get textTheme => GoogleFonts.outfitTextTheme();
  static TextTheme get darkTextTheme =>
      GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme);
}
