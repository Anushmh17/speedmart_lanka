import 'package:flutter/material.dart';

/// All color tokens for Speedmart Lanka.
/// Use these constants — never hardcode colors in widgets.
class AppColors {
  AppColors._();

  // ── Brand ─────────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF00C07F);
  static const Color primaryDark = Color(0xFF009965);
  static const Color primaryLight = Color(0xFF33D09B);
  static const Color primaryContainer = Color(0xFFD0F5E8);
  static const Color primaryContainerDark = Color(0xFF003D28);

  // ── Secondary ─────────────────────────────────────────────────────────────
  static const Color secondary = Color(0xFF1A73E8);
  static const Color secondaryDark = Color(0xFF1557B0);
  static const Color secondaryContainer = Color(0xFFD3E3FD);

  // ── Accent / Highlight ────────────────────────────────────────────────────
  static const Color accent = Color(0xFFFF6B35);
  static const Color accentContainer = Color(0xFFFFE5D9);

  // ── Backgrounds ──────────────────────────────────────────────────────────
  static const Color backgroundLight = Color(0xFFF5F7FA);
  static const Color backgroundDark = Color(0xFF0A0E1A);

  // ── Surfaces ─────────────────────────────────────────────────────────────
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF131929);

  // ── Cards ─────────────────────────────────────────────────────────────────
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF1A2235);

  // ── Borders ───────────────────────────────────────────────────────────────
  static const Color borderLight = Color(0xFFE0E4EC);
  static const Color borderDark = Color(0xFF2A3348);

  // ── Text ─────────────────────────────────────────────────────────────────
  static const Color textPrimaryLight = Color(0xFF1A1D2E);
  static const Color textSecondaryLight = Color(0xFF6B7A99);
  static const Color textHintLight = Color(0xFFADB5C7);

  static const Color textPrimaryDark = Color(0xFFEEF2FF);
  static const Color textSecondaryDark = Color(0xFF8894B2);
  static const Color textHintDark = Color(0xFF4A5568);

  // ── Status ────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color successContainer = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFEAB308);
  static const Color warningContainer = Color(0xFFFEF9C3);
  static const Color error = Color(0xFFEF4444);
  static const Color errorContainer = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoContainer = Color(0xFFDBEAFE);

  // ── Role Colors ───────────────────────────────────────────────────────────
  static const Color customerColor = Color(0xFF00C07F);
  static const Color customerColorDark = Color(0xFF009965);
  static const Color customerContainer = Color(0xFFD0F5E8);

  static const Color vendorColor = Color(0xFF1A73E8);
  static const Color vendorColorDark = Color(0xFF1557B0);
  static const Color vendorContainer = Color(0xFFD3E3FD);

  static const Color adminColor = Color(0xFFE8710A);
  static const Color adminColorDark = Color(0xFFB55708);
  static const Color adminContainer = Color(0xFFFFE5D9);

  // ── Request Status Colors ─────────────────────────────────────────────────
  static const Color statusDraft = Color(0xFF9CA3AF);
  static const Color statusPending = Color(0xFFEAB308);
  static const Color statusActive = Color(0xFF3B82F6);
  static const Color statusAccepted = Color(0xFF22C55E);
  static const Color statusRejected = Color(0xFFEF4444);
  static const Color statusDelivered = Color(0xFF8B5CF6);
  static const Color statusExpired = Color(0xFF6B7280);

  // ── Overlay ───────────────────────────────────────────────────────────────
  static const Color overlay = Color(0x80000000);
  static const Color shimmerBase = Color(0xFFE0E0E0);
  static const Color shimmerHighlight = Color(0xFFF5F5F5);
  static const Color shimmerBaseDark = Color(0xFF2A3348);
  static const Color shimmerHighlightDark = Color(0xFF3A4560);
}
