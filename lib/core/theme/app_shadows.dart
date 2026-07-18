import 'package:flutter/material.dart';

/// Theme 3: Shadow system
/// Consistent shadow/elevation tokens for Speedmart Lanka.
class AppShadows {
  AppShadows._();
  
  // Light theme shadows
  static List<BoxShadow> get sm => [
        const BoxShadow(
          color: Color(0x0F000000),
          blurRadius: 3,
          offset: Offset(0, 1),
        ),
      ];
  
  static List<BoxShadow> get md => [
        const BoxShadow(
          color: Color(0x14000000),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ];
  
  static List<BoxShadow> get lg => [
        const BoxShadow(
          color: Color(0x1A000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ];
  
  static List<BoxShadow> get xl => [
        const BoxShadow(
          color: Color(0x1F000000),
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
      ];
  
  // Dark theme shadows (more subtle)
  static List<BoxShadow> get smDark => [
        const BoxShadow(
          color: Color(0x1A000000),
          blurRadius: 2,
          offset: Offset(0, 1),
        ),
      ];
  
  static List<BoxShadow> get mdDark => [
        const BoxShadow(
          color: Color(0x29000000),
          blurRadius: 4,
          offset: Offset(0, 2),
        ),
      ];
  
  static List<BoxShadow> get lgDark => [
        const BoxShadow(
          color: Color(0x3D000000),
          blurRadius: 8,
          offset: Offset(0, 4),
        ),
      ];
  
  static List<BoxShadow> get xlDark => [
        const BoxShadow(
          color: Color(0x52000000),
          blurRadius: 16,
          offset: Offset(0, 8),
        ),
      ];
}

