import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../database/local_database_service.dart';
import 'app_theme_preset.dart';
import '../constants/app_theme.dart';

class ThemeState {
  final AppThemePreset preset;
  final ThemeMode themeMode;
  final AppThemePalette palette;

  const ThemeState({
    required this.preset,
    required this.themeMode,
    required this.palette,
  });

  ThemeState copyWith({
    AppThemePreset? preset,
    ThemeMode? themeMode,
    AppThemePalette? palette,
  }) {
    return ThemeState(
      preset: preset ?? this.preset,
      themeMode: themeMode ?? this.themeMode,
      palette: palette ?? this.palette,
    );
  }

  bool isDarkMode(BuildContext context) {
    if (themeMode == ThemeMode.dark) return true;
    if (themeMode == ThemeMode.light) return false;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }
}

class ThemeCubit extends Cubit<ThemeState> {
  ThemeCubit()
      : super(
          ThemeState(
            preset: AppThemePreset.slateIndigo,
            themeMode: ThemeMode.system,
            palette: AppThemePalettes.slateIndigo,
          ),
        );

  /// Loads saved theme settings from local Hive database
  void loadSavedTheme() {
    final db = LocalDatabaseService();
    final savedPresetStr = db.getSavedThemePresetName();
    final savedModeStr = db.getSavedThemeModeName();

    AppThemePreset loadedPreset = AppThemePreset.slateIndigo;
    for (final p in AppThemePreset.values) {
      if (p.name == savedPresetStr) {
        loadedPreset = p;
        break;
      }
    }

    ThemeMode loadedMode = ThemeMode.system;
    if (savedModeStr == 'light') {
      loadedMode = ThemeMode.light;
    } else if (savedModeStr == 'dark') {
      loadedMode = ThemeMode.dark;
    }

    final palette = AppThemePalettes.getByPreset(loadedPreset);
    AppTheme.currentColors = palette;
    AppTheme.currentPreset = loadedPreset;

    emit(ThemeState(
      preset: loadedPreset,
      themeMode: loadedMode,
      palette: palette,
    ));
  }

  /// Sets active theme palette preset dynamically in real-time
  Future<void> setPreset(AppThemePreset newPreset) async {
    final palette = AppThemePalettes.getByPreset(newPreset);
    AppTheme.currentColors = palette;
    AppTheme.currentPreset = newPreset;

    emit(state.copyWith(
      preset: newPreset,
      palette: palette,
    ));

    await LocalDatabaseService().saveThemePresetName(newPreset.name);
  }

  /// Sets active theme brightness mode (system, light, dark) dynamically in real-time
  Future<void> setThemeMode(ThemeMode newMode) async {
    emit(state.copyWith(themeMode: newMode));

    String modeStr = 'system';
    if (newMode == ThemeMode.light) modeStr = 'light';
    if (newMode == ThemeMode.dark) modeStr = 'dark';

    await LocalDatabaseService().saveThemeModeName(modeStr);
  }

  /// Toggles between Light and Dark mode
  Future<void> toggleThemeMode(BuildContext context) async {
    final currentlyDark = state.isDarkMode(context);
    await setThemeMode(currentlyDark ? ThemeMode.light : ThemeMode.dark);
  }
}
