import 'package:flutter/material.dart';

/// 9ja Transport design tokens — mirrors Docs/design-system-preview.html
class AppColors {
  static const danfoYellow = Color(0xFFFFC300);
  static const parkGreen = Color(0xFF0A7A3B);
  static const charcoal = Color(0xFF121212);
  static const muted = Color(0xFF6B7280);
  static const paper = Color(0xFFFFFFFF);
  static const cream = Color(0xFFFFF8E1);
  static const danger = Color(0xFFD92D20);
  static const amber = Color(0xFFF79009);
  static const info = Color(0xFF175CD3);
  static const successBg = Color(0xFFDCFAE6);
  static const warnBg = Color(0xFFFEF0C7);
}

class AppRadius {
  static const card = 12.0;
  static const button = 8.0;
  static const sheet = 16.0;
  static const pill = 999.0;
}

class AppTheme {
  static const danfoYellow = AppColors.danfoYellow;
  static const parkGreen = AppColors.parkGreen;
  static const charcoal = AppColors.charcoal;
  static const muted = AppColors.muted;
  static const cream = AppColors.cream;
  static const danger = AppColors.danger;
  static const amber = AppColors.amber;
  static const info = AppColors.info;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: danfoYellow);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.paper,
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 28, height: 34 / 28, fontWeight: FontWeight.w800),
        titleLarge: TextStyle(fontSize: 20, height: 26 / 20, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(fontSize: 16, height: 24 / 16),
        bodyMedium: TextStyle(fontSize: 14, height: 20 / 14),
        labelSmall: TextStyle(fontSize: 12, height: 16 / 12, letterSpacing: 0.4),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: danfoYellow,
          foregroundColor: charcoal,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      ),
    );
  }

  /// Park Mode dark theme — black bg, huge scan CTA.
  static ThemeData parkMode() {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: Colors.black,
      colorScheme: const ColorScheme.dark(primary: danfoYellow, secondary: parkGreen),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: danfoYellow,
          foregroundColor: Colors.black,
          minimumSize: const Size(200, 64),
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
