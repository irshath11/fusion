import 'package:flutter/material.dart';
import '../theme/app_theme_preset.dart';

class AppTheme {
  static AppThemePreset currentPreset = AppThemePreset.slateIndigo;
  static AppThemePalette currentColors = AppThemePalettes.slateIndigo;

  static ThemeData getThemeData({
    required AppThemePreset preset,
    required bool isDark,
  }) {
    final palette = AppThemePalettes.getByPreset(preset);

    final primary = isDark ? palette.primaryDark : palette.primaryLight;
    final background =
        isDark ? palette.backgroundDark : palette.backgroundLight;
    final surface = isDark ? palette.surfaceDark : palette.surfaceLight;
    final cardBorder =
        isDark ? palette.cardBorderDark : palette.cardBorderLight;
    final textPrimary =
        isDark ? palette.textPrimaryDark : palette.textPrimaryLight;
    final textSecondary =
        isDark ? palette.textSecondaryDark : palette.textSecondaryLight;

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: primary,
        onPrimary: Colors.white,
        secondary: palette.secondary,
        onSecondary: Colors.white,
        error: palette.error,
        onError: Colors.white,
        surface: surface,
        onSurface: textPrimary,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: isDark ? 0 : 1,
        shadowColor: palette.accentGlow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(palette.cardRadius),
          side: BorderSide(
            color: cardBorder,
            width: isDark ? 1.2 : 1.0,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: palette.accentGlow,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: isDark ? 1 : 2,
          shadowColor: palette.accentGlow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(palette.buttonRadius),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(palette.buttonRadius),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? surface : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(palette.buttonRadius),
          borderSide: BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(palette.buttonRadius),
          borderSide: BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(palette.buttonRadius),
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 6,
        shadowColor: palette.accentGlow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(palette.cardRadius),
          side: BorderSide(color: cardBorder, width: isDark ? 1.2 : 1),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(palette.cardRadius + 4)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: primary,
            );
          }
          return TextStyle(
            fontSize: 12,
            color: textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primary);
          }
          return IconThemeData(color: textSecondary);
        }),
      ),
    );
  }

  // Backwards-compatible getters
  static ThemeData get lightTheme =>
      getThemeData(preset: currentPreset, isDark: false);
  static ThemeData get darkTheme =>
      getThemeData(preset: currentPreset, isDark: true);
}
