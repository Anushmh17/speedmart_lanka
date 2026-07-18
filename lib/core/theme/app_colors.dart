import 'package:flutter/material.dart';

/// Theme 3: Soft Orange + White + Premium Dark Mode
/// All color tokens for Speedmart Lanka.
class AppColors {
  AppColors._();

  // ── Theme 3: Primary Orange ───────────────────────────────────────────────
  static const Color primary = Color(0xFFF59E0B); // Light theme primary
  static const Color primaryDark = Color(0xFFFFB84D); // Dark theme primary
  static const Color secondary = Color(0xFFFDBA74); // Secondary orange
  
  // ── Backgrounds ──────────────────────────────────────────────────────────
  static const Color backgroundLight = Color(0xFFFFFDF8); // Warm white
  static const Color backgroundDark = Color(0xFF0F1115); // Premium dark
  static const Color sectionBackgroundLight = Color(0xFFFFF7E6); // Section bg
  
  // ── Surfaces ─────────────────────────────────────────────────────────────
  static const Color surfaceLight = Color(0xFFFFFFFF); // Pure white
  static const Color surfaceDark = Color(0xFF171A21); // Dark surface
  static const Color surfaceElevatedDark = Color(0xFF1E222C); // Elevated dark
  
  // ── Cards ─────────────────────────────────────────────────────────────────
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF171A21);
  static const Color cardBorderLight = Color(0xFFF1E3B2); // Soft golden border
  
  // ── Borders ───────────────────────────────────────────────────────────────
  static const Color borderLight = Color(0xFFF1E3B2);
  static const Color borderDark = Color(0xFF2A2E38);
  
  // ── Text ─────────────────────────────────────────────────────────────────
  static const Color textPrimaryLight = Color(0xFF1F2937);
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color textHintLight = Color(0xFF9CA3AF);
  
  static const Color textPrimaryDark = Color(0xFFF9FAFB);
  static const Color textSecondaryDark = Color(0xFF9CA3AF);
  static const Color textHintDark = Color(0xFF6B7280);
  
  // ── Status ────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
  
  // Status containers
  static const Color successContainer = Color(0xFFDCFCE7);
  static const Color errorContainer = Color(0xFFFEE2E2);
  static const Color warningContainer = Color(0xFFFEF3C7);
  static const Color infoContainer = Color(0xFFDBEAFE);
  
  // ── Role Colors (legacy compatibility) ───────────────────────────────────
  static const Color customerColor = Color(0xFFF59E0B);
  static const Color customerColorDark = Color(0xFFFFB84D);
  static const Color customerContainer = Color(0xFFFEF3C7);
  
  static const Color vendorColor = Color(0xFF3B82F6);
  static const Color vendorColorDark = Color(0xFF60A5FA);
  static const Color vendorContainer = Color(0xFFDBEAFE);
  
  static const Color adminColor = Color(0xFFEF4444);
  static const Color adminColorDark = Color(0xFFF87171);
  static const Color adminContainer = Color(0xFFFEE2E2);
  
  // ── Accent (legacy compatibility) ─────────────────────────────────────────
  static const Color accent = Color(0xFFF59E0B);
  static const Color accentContainer = Color(0xFFFEF3C7);
  
  // ── Primary Container (legacy compatibility) ──────────────────────────────
  static const Color primaryContainer = Color(0xFFFEF3C7);
  static const Color primaryContainerDark = Color(0xFF78350F);
  
  // ── Request Status Colors (legacy compatibility) ─────────────────────────
  static const Color statusDraft = Color(0xFF9CA3AF);
  static const Color statusPending = Color(0xFFF59E0B);
  static const Color statusActive = Color(0xFF3B82F6);
  static const Color statusAccepted = Color(0xFF22C55E);
  static const Color statusRejected = Color(0xFFEF4444);
  static const Color statusDelivered = Color(0xFF8B5CF6);
  static const Color statusExpired = Color(0xFF6B7280);
  
  // ── Overlay ───────────────────────────────────────────────────────────────
  static const Color overlay = Color(0x80000000);
  static const Color shimmerBase = Color(0xFFF3F4F6);
  static const Color shimmerHighlight = Color(0xFFFFFFFF);
  static const Color shimmerBaseDark = Color(0xFF1E222C);
  static const Color shimmerHighlightDark = Color(0xFF2A2E38);
}

