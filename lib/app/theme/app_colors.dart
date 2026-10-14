import 'package:flutter/material.dart';

/// Centralized color palette and design tokens for QuickNews.
///
/// Follows Material 3 color roles with high contrast, editorial clarity,
/// and clean surface separation for light and dark modes.
abstract final class AppColors {
  // --- Light Theme Tokens ---
  /// Light Primary: #315CDB
  static const Color lightPrimary = Color(0xFF315CDB);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightPrimaryContainer = Color(0xFFDCE1FF);
  static const Color lightOnPrimaryContainer = Color(0xFF00164E);

  /// Light Secondary: #6276A8
  static const Color lightSecondary = Color(0xFF6276A8);
  static const Color lightOnSecondary = Color(0xFFFFFFFF);
  static const Color lightSecondaryContainer = Color(0xFFDFE4F9);
  static const Color lightOnSecondaryContainer = Color(0xFF1B2A50);

  /// Light Background: #F7F8FC
  static const Color lightBackground = Color(0xFFF7F8FC);
  static const Color lightOnBackground = Color(0xFF171A24);

  /// Light Surface: #FFFFFF
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightOnSurface = Color(0xFF171A24);
  static const Color lightSurfaceVariant = Color(0xFFF0F2F8);
  static const Color lightOnSurfaceVariant = Color(0xFF697386);

  /// Light Text
  static const Color lightTextPrimary = Color(0xFF171A24);
  static const Color lightTextSecondary = Color(0xFF697386);

  /// Light Divider: #E5E8F0
  static const Color lightDivider = Color(0xFFE5E8F0);

  /// Light Error: #BA1A1A
  static const Color lightError = Color(0xFFBA1A1A);
  static const Color lightOnError = Color(0xFFFFFFFF);

  // --- Dark Theme Tokens ---
  /// Dark Primary: #9DB3FF
  static const Color darkPrimary = Color(0xFF9DB3FF);
  static const Color darkOnPrimary = Color(0xFF00277D);
  static const Color darkPrimaryContainer = Color(0xFF133EBF);
  static const Color darkOnPrimaryContainer = Color(0xFFDCE1FF);

  /// Dark Secondary: #B7C5EA
  static const Color darkSecondary = Color(0xFFB7C5EA);
  static const Color darkOnSecondary = Color(0xFF202F54);
  static const Color darkSecondaryContainer = Color(0xFF38466C);
  static const Color darkOnSecondaryContainer = Color(0xFFDFE4F9);

  /// Dark Background: #101218
  static const Color darkBackground = Color(0xFF101218);
  static const Color darkOnBackground = Color(0xFFF1F3F9);

  /// Dark Surface: #191D26
  static const Color darkSurface = Color(0xFF191D26);
  static const Color darkOnSurface = Color(0xFFF1F3F9);
  static const Color darkSurfaceVariant = Color(0xFF262C38);
  static const Color darkOnSurfaceVariant = Color(0xFFB0B7C6);

  /// Dark Text
  static const Color darkTextPrimary = Color(0xFFF1F3F9);
  static const Color darkTextSecondary = Color(0xFFB0B7C6);

  /// Dark Divider: #303644
  static const Color darkDivider = Color(0xFF303644);

  /// Dark Error: #FFB4AB
  static const Color darkError = Color(0xFFFFB4AB);
  static const Color darkOnError = Color(0xFF690005);

  // --- Functional / Semantic Colors ---
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF57C00);
  static const Color info = Color(0xFF0288D1);
  static const Color bookmarkGold = Color(0xFFF59E0B);
}
