import 'package:flutter/material.dart';
import '../constants/app_theme.dart';

class TabItemData {
  final String label;
  final IconData icon;

  const TabItemData({
    required this.label,
    required this.icon,
  });
}

/// Fluid segmented tab switcher featuring a sliding background pill with spring curve physics.
class AppAnimatedTabSwitcher extends StatelessWidget {
  final int selectedIndex;
  final List<TabItemData> tabs;
  final ValueChanged<int> onTabChanged;

  const AppAnimatedTabSwitcher({
    super.key,
    required this.selectedIndex,
    required this.tabs,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = AppTheme.currentColors;
    final activePrimary = palette.primaryFor(isDark ? Brightness.dark : Brightness.light);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? palette.surfaceDark.withValues(alpha: 0.8) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(palette.cardRadius * 0.75),
        border: Border.all(
          color: isDark ? palette.cardBorderDark : Colors.transparent,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = (constraints.maxWidth - 8) / tabs.length;

          return Stack(
            children: [
              // Sliding active pill indicator
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                left: selectedIndex * tabWidth,
                top: 0,
                bottom: 0,
                width: tabWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? activePrimary.withValues(alpha: 0.22)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(palette.buttonRadius * 0.7),
                    border: isDark
                        ? Border.all(color: activePrimary.withValues(alpha: 0.45))
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: palette.accentGlow.withValues(alpha: isDark ? 0.3 : 0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                ),
              ),

              // Tab text and icons
              Row(
                children: List.generate(tabs.length, (index) {
                  final isSelected = selectedIndex == index;
                  final tab = tabs[index];

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onTabChanged(index),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              tab.icon,
                              size: 16,
                              color: isSelected
                                  ? activePrimary
                                  : (isDark
                                      ? palette.textSecondaryDark
                                      : Colors.grey.shade700),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                tab.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected
                                      ? activePrimary
                                      : (isDark
                                          ? palette.textSecondaryDark
                                          : Colors.grey.shade700),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}
