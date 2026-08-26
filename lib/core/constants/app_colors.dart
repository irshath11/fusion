import 'package:flutter/material.dart';
import '../theme/app_theme_preset.dart';
import 'app_theme.dart';

class AppColors {
  AppColors._();

  // Core Theme Palette Constants (Default fallback & const widget support)
  static const Color primary = Color(0xFF1E3A8A); // Slate Navy / Brand Primary
  static const Color primaryLight = Color(0xFF3B82F6); // Indigo / Accent Blue
  static const Color secondary = Color(0xFF0D9488); // Teal Accent

  // Backgrounds & Surfaces
  static const Color backgroundLight = Color(0xFFF8FAFC); // Clean Slate Ice
  static const Color backgroundDark = Color(0xFF0B0F19); // Midnight Charcoal
  static const Color surfaceLight = Color(0xFFFFFFFF); // Pure White
  static const Color surfaceDark = Color(0xFF111827); // Deep Obsidian

  // Card Borders & Outlines
  static const Color cardBorderLight = Color(0xFFE2E8F0);
  static const Color cardBorderDark = Color(0xFF1F2937);

  // Status & Feedback Colors
  static const Color success = Color(0xFF10B981); // Emerald Green
  static const Color warning = Color(0xFFF59E0B); // Amber Orange
  static const Color error = Color(0xFFEF4444); // Coral Red
  static const Color info = Color(0xFF3B82F6); // Sky Blue

  // Text Hierarchy
  static const Color textPrimaryLight = Color(0xFF0F172A); // Slate 900
  static const Color textSecondaryLight = Color(0xFF64748B); // Slate 500
  static const Color textPrimaryDark = Color(0xFFF8FAFC); // Slate 50
  static const Color textSecondaryDark = Color(0xFF94A3B8); // Slate 400

  // Slate Color Palette Constants
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate950 = Color(0xFF020617);

  // Geometry & Radii
  static const double cardRadius = 16.0;
  static const double buttonRadius = 12.0;

  // Active theme accessors (for dynamic themed widgets)
  static AppThemePalette get current => AppTheme.currentColors;
  static Color get activePrimary => AppTheme.currentColors.primaryLight;
  static Color get activePrimaryDark => AppTheme.currentColors.primaryDark;
  static Color get activeSecondary => AppTheme.currentColors.secondary;

  // Dynamic Context-Aware Theme Helpers
  static Color dynamicPrimary(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppTheme.currentColors.primaryFor(
        isDark ? Brightness.dark : Brightness.light);
  }

  static Color dynamicSecondary(BuildContext context) {
    return AppTheme.currentColors.secondary;
  }

  static Color dynamicBackground(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppTheme.currentColors.backgroundFor(
        isDark ? Brightness.dark : Brightness.light);
  }

  static Color dynamicSurface(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppTheme.currentColors.surfaceFor(
        isDark ? Brightness.dark : Brightness.light);
  }

  static Color dynamicBorder(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppTheme.currentColors.cardBorderFor(
        isDark ? Brightness.dark : Brightness.light);
  }
}
