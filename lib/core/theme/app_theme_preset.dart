import 'package:flutter/material.dart';

enum AppThemePreset {
  slateIndigo,
  emeraldMint,
  midnightAmber,
  royalAmethyst,
  oceanCobalt,
}

class AppThemePalette {
  final AppThemePreset preset;
  final String name;
  final String tagline;
  final IconData icon;

  // Primary brand colors
  final Color primaryLight; // Used in light mode
  final Color primaryDark; // Used in dark mode (high contrast)
  final Color secondary; // Accent color

  // Backgrounds & Surfaces
  final Color backgroundLight;
  final Color backgroundDark;
  final Color surfaceLight;
  final Color surfaceDark;

  // Borders
  final Color cardBorderLight;
  final Color cardBorderDark;

  // Text
  final Color textPrimaryLight;
  final Color textSecondaryLight;
  final Color textPrimaryDark;
  final Color textSecondaryDark;

  // Feedback Colors
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  // Rich Theming Extensions: Shapes & Geometry
  final double cardRadius;
  final double buttonRadius;

  // Gradients
  final LinearGradient primaryGradient;
  final LinearGradient heroCardGradient;
  final LinearGradient cardGradientDark;
  final LinearGradient cardGradientLight;

  // Accent & Glow
  final Color accentGlow;
  final Color chipBgLight;
  final Color chipBgDark;
  final Color chipTextLight;
  final Color chipTextDark;

  // 3 Swatch colors for visual picker chips
  final List<Color> previewColors;

  const AppThemePalette({
    required this.preset,
    required this.name,
    required this.tagline,
    required this.icon,
    required this.primaryLight,
    required this.primaryDark,
    required this.secondary,
    required this.backgroundLight,
    required this.backgroundDark,
    required this.surfaceLight,
    required this.surfaceDark,
    required this.cardBorderLight,
    required this.cardBorderDark,
    this.textPrimaryLight = const Color(0xFF0F172A),
    this.textSecondaryLight = const Color(0xFF64748B),
    this.textPrimaryDark = const Color(0xFFF8FAFC),
    this.textSecondaryDark = const Color(0xFF94A3B8),
    this.success = const Color(0xFF10B981),
    this.warning = const Color(0xFFF59E0B),
    this.error = const Color(0xFFEF4444),
    this.info = const Color(0xFF3B82F6),
    required this.cardRadius,
    required this.buttonRadius,
    required this.primaryGradient,
    required this.heroCardGradient,
    required this.cardGradientDark,
    required this.cardGradientLight,
    required this.accentGlow,
    required this.chipBgLight,
    required this.chipBgDark,
    required this.chipTextLight,
    required this.chipTextDark,
    required this.previewColors,
  });

  /// Helper to get the correct primary color for current brightness
  Color primaryFor(Brightness brightness) =>
      brightness == Brightness.dark ? primaryDark : primaryLight;

  /// Helper to get background color for current brightness
  Color backgroundFor(Brightness brightness) =>
      brightness == Brightness.dark ? backgroundDark : backgroundLight;

  /// Helper to get surface color for current brightness
  Color surfaceFor(Brightness brightness) =>
      brightness == Brightness.dark ? surfaceDark : surfaceLight;

  /// Helper to get card border color for current brightness
  Color cardBorderFor(Brightness brightness) =>
      brightness == Brightness.dark ? cardBorderDark : cardBorderLight;

  /// Helper to get card gradient for current brightness
  LinearGradient cardGradientFor(Brightness brightness) =>
      brightness == Brightness.dark ? cardGradientDark : cardGradientLight;

  /// Helper to get chip background for current brightness
  Color chipBgFor(Brightness brightness) =>
      brightness == Brightness.dark ? chipBgDark : chipBgLight;

  /// Helper to get chip text color for current brightness
  Color chipTextFor(Brightness brightness) =>
      brightness == Brightness.dark ? chipTextDark : chipTextLight;
}

class AppThemePalettes {
  // -------------------------------------------------------------
  // 1. Slate Indigo (Corporate Enterprise Standard)
  // Structured 14px radius, Steel Blue gradients, navy borders
  // -------------------------------------------------------------
  static const AppThemePalette slateIndigo = AppThemePalette(
    preset: AppThemePreset.slateIndigo,
    name: 'Slate Indigo',
    tagline: 'Corporate & Reliable',
    icon: Icons.business_rounded,
    primaryLight: Color(0xFF1E3A8A), // Deep Slate Navy
    primaryDark: Color(0xFF3B82F6), // Vibrant Electric Blue
    secondary: Color(0xFF0D9488), // Teal Accent
    backgroundLight: Color(0xFFF8FAFC),
    backgroundDark: Color(0xFF0F172A),
    surfaceLight: Color(0xFFFFFFFF),
    surfaceDark: Color(0xFF1E293B),
    cardBorderLight: Color(0xFFE2E8F0),
    cardBorderDark: Color(0xFF334155),
    cardRadius: 14.0,
    buttonRadius: 12.0,
    primaryGradient: LinearGradient(
      colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    heroCardGradient: LinearGradient(
      colors: [Color(0xFF172554), Color(0xFF1E3A8A), Color(0xFF2563EB)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    cardGradientLight: LinearGradient(
      colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    cardGradientDark: LinearGradient(
      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentGlow: Color(0x333B82F6),
    chipBgLight: Color(0xFFEFF6FF),
    chipBgDark: Color(0xFF1E3A8A),
    chipTextLight: Color(0xFF1E3A8A),
    chipTextDark: Color(0xFF93C5FD),
    previewColors: [
      Color(0xFF1E3A8A),
      Color(0xFF3B82F6),
      Color(0xFF0D9488),
    ],
  );

  // -------------------------------------------------------------
  // 2. Emerald Mint (Field & Eco Operations)
  // Soft 22px curved corners, Lush Forest gradients, Leaf Mint borders
  // -------------------------------------------------------------
  static const AppThemePalette emeraldMint = AppThemePalette(
    preset: AppThemePreset.emeraldMint,
    name: 'Emerald Mint',
    tagline: 'Field & Nature Tech',
    icon: Icons.eco_rounded,
    primaryLight: Color(0xFF047857), // Deep Forest Emerald
    primaryDark: Color(0xFF10B981), // Bright Vibrant Mint
    secondary: Color(0xFF06B6D4), // Cyan Accent
    backgroundLight: Color(0xFFF0FDF4),
    backgroundDark: Color(0xFF041E15),
    surfaceLight: Color(0xFFFFFFFF),
    surfaceDark: Color(0xFF0B3324),
    cardBorderLight: Color(0xFFA7F3D0),
    cardBorderDark: Color(0xFF135A3F),
    cardRadius: 22.0,
    buttonRadius: 20.0,
    primaryGradient: LinearGradient(
      colors: [Color(0xFF047857), Color(0xFF10B981)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    heroCardGradient: LinearGradient(
      colors: [Color(0xFF064E3B), Color(0xFF047857), Color(0xFF059669)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    cardGradientLight: LinearGradient(
      colors: [Color(0xFFFFFFFF), Color(0xFFF0FDF4)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    cardGradientDark: LinearGradient(
      colors: [Color(0xFF0D3D2B), Color(0xFF062319)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentGlow: Color(0x3310B981),
    chipBgLight: Color(0xFFECFDF5),
    chipBgDark: Color(0xFF064E3B),
    chipTextLight: Color(0xFF047857),
    chipTextDark: Color(0xFF6EE7B7),
    previewColors: [
      Color(0xFF047857),
      Color(0xFF10B981),
      Color(0xFF06B6D4),
    ],
  );

  // -------------------------------------------------------------
  // 3. Midnight Amber (Obsidian Luxury & Gold Contrast)
  // Sharp 10px architectural lines, Pure Obsidian, Warm 24K Gold gradients
  // -------------------------------------------------------------
  static const AppThemePalette midnightAmber = AppThemePalette(
    preset: AppThemePreset.midnightAmber,
    name: 'Midnight Amber',
    tagline: 'Obsidian & Warm Gold',
    icon: Icons.dark_mode_rounded,
    primaryLight: Color(0xFFB45309), // Warm Amber Brown
    primaryDark: Color(0xFFF59E0B), // Luminous 24K Gold Amber
    secondary: Color(0xFF6366F1), // Indigo Neon
    backgroundLight: Color(0xFFFFFBEB),
    backgroundDark: Color(0xFF0A0D14), // True Obsidian
    surfaceLight: Color(0xFFFFFFFF),
    surfaceDark: Color(0xFF151B27),
    cardBorderLight: Color(0xFFFDE68A),
    cardBorderDark: Color(0xFF3F3014),
    cardRadius: 10.0,
    buttonRadius: 8.0,
    primaryGradient: LinearGradient(
      colors: [Color(0xFF92400E), Color(0xFFD97706), Color(0xFFF59E0B)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    heroCardGradient: LinearGradient(
      colors: [Color(0xFF451A03), Color(0xFF78350F), Color(0xFFB45309)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    cardGradientLight: LinearGradient(
      colors: [Color(0xFFFFFFFF), Color(0xFFFFFBEB)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    cardGradientDark: LinearGradient(
      colors: [Color(0xFF192030), Color(0xFF0D121D)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentGlow: Color(0x44F59E0B),
    chipBgLight: Color(0xFFFEF3C7),
    chipBgDark: Color(0xFF451A03),
    chipTextLight: Color(0xFF92400E),
    chipTextDark: Color(0xFFFCD34D),
    previewColors: [
      Color(0xFFB45309),
      Color(0xFFF59E0B),
      Color(0xFF6366F1),
    ],
  );

  // -------------------------------------------------------------
  // 4. Royal Amethyst (Modern Creative Violet & Rose)
  // Ultra-rounded 24px pill cards, Deep Velvet Amethyst & Fuchsia
  // -------------------------------------------------------------
  static const AppThemePalette royalAmethyst = AppThemePalette(
    preset: AppThemePreset.royalAmethyst,
    name: 'Royal Amethyst',
    tagline: 'Modern & Creative Suite',
    icon: Icons.palette_rounded,
    primaryLight: Color(0xFF6D28D9), // Deep Royal Violet
    primaryDark: Color(0xFFA78BFA), // Radiant Lavender
    secondary: Color(0xFFEC4899), // Rose Pink
    backgroundLight: Color(0xFFFAF5FF),
    backgroundDark: Color(0xFF100922),
    surfaceLight: Color(0xFFFFFFFF),
    surfaceDark: Color(0xFF1F1238),
    cardBorderLight: Color(0xFFE9D5FF),
    cardBorderDark: Color(0xFF4C2882),
    cardRadius: 24.0,
    buttonRadius: 24.0,
    primaryGradient: LinearGradient(
      colors: [Color(0xFF581C87), Color(0xFF7C3AED), Color(0xFFEC4899)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    heroCardGradient: LinearGradient(
      colors: [Color(0xFF3B0764), Color(0xFF581C87), Color(0xFF7C3AED)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    cardGradientLight: LinearGradient(
      colors: [Color(0xFFFFFFFF), Color(0xFFFAF5FF)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    cardGradientDark: LinearGradient(
      colors: [Color(0xFF23143F), Color(0xFF120A24)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentGlow: Color(0x33A78BFA),
    chipBgLight: Color(0xFFF3E8FF),
    chipBgDark: Color(0xFF3B0764),
    chipTextLight: Color(0xFF6D28D9),
    chipTextDark: Color(0xFFD8B4FE),
    previewColors: [
      Color(0xFF6D28D9),
      Color(0xFFA78BFA),
      Color(0xFFEC4899),
    ],
  );

  // -------------------------------------------------------------
  // 5. Ocean Cobalt (High-Energy Electric Oceanic)
  // Dynamic 12px tech angles, Abyss Blue & Cyber Cyan with Crimson
  // -------------------------------------------------------------
  static const AppThemePalette oceanCobalt = AppThemePalette(
    preset: AppThemePreset.oceanCobalt,
    name: 'Ocean Cobalt',
    tagline: 'Electric Flow & Operations',
    icon: Icons.water_drop_rounded,
    primaryLight: Color(0xFF0284C7), // Deep Cobalt Blue
    primaryDark: Color(0xFF38BDF8), // Electric Sky Blue
    secondary: Color(0xFFE11D48), // Crimson Flare
    backgroundLight: Color(0xFFF0F9FF),
    backgroundDark: Color(0xFF071424),
    surfaceLight: Color(0xFFFFFFFF),
    surfaceDark: Color(0xFF0E223B),
    cardBorderLight: Color(0xFFBAE6FD),
    cardBorderDark: Color(0xFF173E67),
    cardRadius: 12.0,
    buttonRadius: 10.0,
    primaryGradient: LinearGradient(
      colors: [Color(0xFF0369A1), Color(0xFF0284C7), Color(0xFF38BDF8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    heroCardGradient: LinearGradient(
      colors: [Color(0xFF0C4A6E), Color(0xFF0369A1), Color(0xFF0284C7)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    cardGradientLight: LinearGradient(
      colors: [Color(0xFFFFFFFF), Color(0xFFF0F9FF)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    cardGradientDark: LinearGradient(
      colors: [Color(0xFF122842), Color(0xFF071526)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentGlow: Color(0x3338BDF8),
    chipBgLight: Color(0xFFE0F2FE),
    chipBgDark: Color(0xFF0C4A6E),
    chipTextLight: Color(0xFF0284C7),
    chipTextDark: Color(0xFF7DD3FC),
    previewColors: [
      Color(0xFF0284C7),
      Color(0xFF38BDF8),
      Color(0xFFE11D48),
    ],
  );

  static const List<AppThemePalette> all = [
    slateIndigo,
    emeraldMint,
    midnightAmber,
    royalAmethyst,
    oceanCobalt,
  ];

  static AppThemePalette getByPreset(AppThemePreset preset) {
    switch (preset) {
      case AppThemePreset.slateIndigo:
        return slateIndigo;
      case AppThemePreset.emeraldMint:
        return emeraldMint;
      case AppThemePreset.midnightAmber:
        return midnightAmber;
      case AppThemePreset.royalAmethyst:
        return royalAmethyst;
      case AppThemePreset.oceanCobalt:
        return oceanCobalt;
    }
  }
}
