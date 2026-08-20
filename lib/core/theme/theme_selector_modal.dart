import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../constants/app_colors.dart';
import 'app_theme_preset.dart';
import 'theme_cubit.dart';

class ThemeSelectorModal extends StatelessWidget {
  const ThemeSelectorModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const ThemeSelectorModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<ThemeCubit, ThemeState>(
      builder: (context, themeState) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top drag pill
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color:
                          isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (isDark
                                    ? AppColors.primaryLight
                                    : AppColors.primary)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.palette_rounded,
                            color: isDark
                                ? AppColors.primaryLight
                                : AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Theme & Appearance',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                            Text(
                              'Switch themes dynamically in real time',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // SECTION 1: Brightness Mode (Light / Dark / System)
                Text(
                  'APPEARANCE MODE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color:
                        isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? AppColors.cardBorderDark
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildModeOption(
                        context,
                        title: 'System',
                        icon: Icons.brightness_auto_rounded,
                        mode: ThemeMode.system,
                        selectedMode: themeState.themeMode,
                        isDark: isDark,
                      ),
                      _buildModeOption(
                        context,
                        title: 'Light',
                        icon: Icons.light_mode_rounded,
                        mode: ThemeMode.light,
                        selectedMode: themeState.themeMode,
                        isDark: isDark,
                      ),
                      _buildModeOption(
                        context,
                        title: 'Dark',
                        icon: Icons.dark_mode_rounded,
                        mode: ThemeMode.dark,
                        selectedMode: themeState.themeMode,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // SECTION 2: 5 Theme Palettes
                Text(
                  'COLOR PALETTE (5 THEMES)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 10),

                // List of 5 Presets
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: AppThemePalettes.all.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final palette = AppThemePalettes.all[index];
                    final isSelected = themeState.preset == palette.preset;

                    return _buildThemePaletteCard(
                      context,
                      palette: palette,
                      isSelected: isSelected,
                      isDark: isDark,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeOption(
    BuildContext context, {
    required String title,
    required IconData icon,
    required ThemeMode mode,
    required ThemeMode selectedMode,
    required bool isDark,
  }) {
    final isSelected = mode == selectedMode;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          context.read<ThemeCubit>().setThemeMode(mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.surfaceDark : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? (isDark ? AppColors.primaryLight : AppColors.primary)
                    : (isDark
                        ? AppColors.textSecondaryDark
                        : Colors.grey.shade600),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? AppColors.textPrimaryDark : Colors.black87)
                      : (isDark
                          ? AppColors.textSecondaryDark
                          : Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemePaletteCard(
    BuildContext context, {
    required AppThemePalette palette,
    required bool isSelected,
    required bool isDark,
  }) {
    final activePrimary = palette.primaryFor(
      isDark ? Brightness.dark : Brightness.light,
    );

    return InkWell(
      onTap: () {
        context.read<ThemeCubit>().setPreset(palette.preset);
      },
      borderRadius: BorderRadius.circular(palette.cardRadius),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? activePrimary.withValues(alpha: isDark ? 0.22 : 0.10)
              : (isDark ? palette.surfaceDark : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(palette.cardRadius),
          border: Border.all(
            color: isSelected
                ? activePrimary
                : (isDark ? palette.cardBorderDark : Colors.grey.shade200),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: palette.accentGlow,
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // Palette Icon with signature primary gradient
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: palette.primaryGradient,
                borderRadius: BorderRadius.circular(palette.buttonRadius * 0.7),
                boxShadow: [
                  BoxShadow(
                    color: palette.accentGlow,
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                palette.icon,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // Palette Name, Tagline & Card Radius Badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        palette.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? activePrimary
                              : (isDark
                                  ? palette.textPrimaryDark
                                  : palette.textPrimaryLight),
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: palette.primaryGradient,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'ACTIVE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    palette.tagline,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? palette.textSecondaryDark
                          : palette.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),

            // 3 Swatch circles
            Row(
              children: palette.previewColors.map((color) {
                return Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

            const SizedBox(width: 8),

            // Selection Checkmark
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? activePrimary : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? activePrimary
                      : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
