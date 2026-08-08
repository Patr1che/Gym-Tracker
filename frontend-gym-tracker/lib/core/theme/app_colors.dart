import 'package:flutter/material.dart';

/// Design-system palette. Dark is the primary brand theme; a light variant
/// exists for the settings toggle.
abstract final class AppColors {
  // Brand
  static const Color primary = Color(0xFFA3E635);
  static const Color primaryDim = Color(0xFF65A30D);
  static const Color secondary = Color(0xFF22D3EE);
  static const Color secondaryDim = Color(0xFF0891B2);

  static const Color success = Color(0xFF34D399);
  static const Color warning = Color(0xFFFBBF24);
  static const Color danger = Color(0xFFFB7185);

  // Dark theme
  static const Color bgDark = Color(0xFF0A0E17);
  static const Color bgDarkAlt = Color(0xFF0E1524);
  static const Color surfaceDark = Color(0xFF131B2E);
  static const Color glassFillDark = Color(0x14FFFFFF); // white 8%
  static const Color glassBorderDark = Color(0x1FFFFFFF); // white 12%
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textTertiaryDark = Color(0xFF64748B);

  // Light theme
  static const Color bgLight = Color(0xFFF2F5FA);
  static const Color bgLightAlt = Color(0xFFE8EEF7);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color glassFillLight = Color(0xB3FFFFFF); // white 70%
  static const Color glassBorderLight = Color(0x14000000); // black 8%
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textTertiaryLight = Color(0xFF94A3B8);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFA3E635), Color(0xFF4ADE80)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [Color(0xFF22D3EE), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Gradients used for exercise image placeholders, keyed by muscle group.
  static const Map<String, LinearGradient> muscleGradients = {
    'chest': LinearGradient(colors: [Color(0xFFF87171), Color(0xFFFB923C)]),
    'back': LinearGradient(colors: [Color(0xFF60A5FA), Color(0xFF22D3EE)]),
    'shoulders': LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFFF97316)]),
    'arms': LinearGradient(colors: [Color(0xFFC084FC), Color(0xFF818CF8)]),
    'legs': LinearGradient(colors: [Color(0xFF34D399), Color(0xFF10B981)]),
    'core': LinearGradient(colors: [Color(0xFFF472B6), Color(0xFFFB7185)]),
    'cardio': LinearGradient(colors: [Color(0xFF38BDF8), Color(0xFF818CF8)]),
  };

  static LinearGradient muscleGradient(String group) =>
      muscleGradients[group] ?? primaryGradient;
}
