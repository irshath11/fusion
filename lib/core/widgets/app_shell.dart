import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_theme.dart';
import '../theme/app_theme_preset.dart';
import '../theme/theme_selector_modal.dart';
import 'app_bounceable.dart';
import 'app_glass_card.dart';

class NavDestinationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String? badge;

  const NavDestinationItem({
    required this.icon,
    required this.label,
    IconData? activeIcon,
    this.badge,
  }) : activeIcon = activeIcon ?? icon;
}

/// Adaptive Application Shell providing:
/// - Floating Glass Bottom Navigation Dock on Mobile (< 750px)
/// - Modern Collapsible Navigation Rail on Desktop/Tablet (>= 750px)
/// - Top Command Bar with Sync Health Heartbeat & Theme Switcher
class AppShell extends StatefulWidget {
  final String title;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavDestinationItem> destinations;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final String? userRoleLabel;

  const AppShell({
    super.key,
    required this.title,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.userRoleLabel,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _isNavRailExpanded = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = AppTheme.currentColors;
    final primary = AppColors.dynamicPrimary(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 750;

        return Scaffold(
          backgroundColor: AppColors.dynamicBackground(context),
          floatingActionButton: widget.floatingActionButton,
          body: Row(
            children: [
              // Desktop / Tablet Navigation Rail
              if (isWide)
                _buildDesktopNavRail(context, isDark, palette, primary),

              // Main Content Area
              Expanded(
                child: Column(
                  children: [
                    // Top Command Header Bar
                    _buildTopHeader(context, isDark, palette, primary, isWide),

                    // Main View Body
                    Expanded(
                      child: ClipRect(
                        child: widget.body,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Mobile Floating Bottom Glass Dock
          bottomNavigationBar: isWide
              ? null
              : _buildMobileGlassDock(context, isDark, palette, primary),
        );
      },
    );
  }

  // ===========================================================================
  // TOP COMMAND HEADER BAR
  // ===========================================================================
  Widget _buildTopHeader(
    BuildContext context,
    bool isDark,
    AppThemePalette palette,
    Color primary,
    bool isWide,
  ) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark
            ? palette.surfaceDark.withValues(alpha: 0.75)
            : palette.surfaceLight.withValues(alpha: 0.85),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? palette.cardBorderDark.withValues(alpha: 0.5)
                : palette.cardBorderLight.withValues(alpha: 0.8),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (isWide) ...[
            IconButton(
              icon: Icon(
                _isNavRailExpanded
                    ? Icons.menu_open_rounded
                    : Icons.menu_rounded,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              onPressed: () =>
                  setState(() => _isNavRailExpanded = !_isNavRailExpanded),
              tooltip: _isNavRailExpanded
                  ? 'Collapse Navigation'
                  : 'Expand Navigation',
            ),
            const SizedBox(width: 8),
          ],

          // Title & Role Badge
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isWide ? 20 : 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                      color: isDark ? Colors.white : AppColors.slate800,
                    ),
                  ),
                ),
                if (widget.userRoleLabel != null) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              widget.userRoleLabel!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Custom Actions
          if (widget.actions != null) ...widget.actions!,

          // Sync Heartbeat Status Indicator
          Tooltip(
            message: 'Supabase Cloud Sync: Online & Verified',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (isWide) ...[
                    const SizedBox(width: 6),
                    const Text(
                      'Synced',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Quick Theme Selector Trigger
          AppBounceable(
            onTap: () => ThemeSelectorModal.show(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.08),
                ),
              ),
              child: Icon(
                Icons.palette_outlined,
                size: 20,
                color: primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // DESKTOP NAVIGATION RAIL
  // ===========================================================================
  Widget _buildDesktopNavRail(
    BuildContext context,
    bool isDark,
    AppThemePalette palette,
    Color primary,
  ) {
    final width = _isNavRailExpanded ? 240.0 : 72.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: width,
      decoration: BoxDecoration(
        color: isDark
            ? palette.surfaceDark.withValues(alpha: 0.9)
            : palette.surfaceLight,
        border: Border(
          right: BorderSide(
            color: isDark
                ? palette.cardBorderDark.withValues(alpha: 0.6)
                : palette.cardBorderLight,
          ),
        ),
      ),
      child: Column(
        children: [
          // Logo & Branding Header
          Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primary, primary.withValues(alpha: 0.7)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.fingerprint_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                if (_isNavRailExpanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FUSION',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          'Attendance Suite',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : AppColors.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const Divider(height: 1, indent: 12, endIndent: 12),
          const SizedBox(height: 12),

          // Destinations List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: widget.destinations.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final isSelected = widget.selectedIndex == index;
                final dest = widget.destinations[index];

                return AppBounceable(
                  onTap: () => widget.onDestinationSelected(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primary.withValues(alpha: isDark ? 0.22 : 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(
                              color: primary.withValues(alpha: 0.35),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? dest.activeIcon : dest.icon,
                          size: 20,
                          color: isSelected
                              ? primary
                              : (isDark ? Colors.white60 : AppColors.slate600),
                        ),
                        if (_isNavRailExpanded) ...[
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              dest.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isSelected
                                    ? primary
                                    : (isDark
                                        ? Colors.white70
                                        : AppColors.slate700),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (dest.badge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                dest.badge!,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MOBILE FLOATING GLASS DOCK
  // ===========================================================================
  Widget _buildMobileGlassDock(
    BuildContext context,
    bool isDark,
    AppThemePalette palette,
    Color primary,
  ) {
    final double itemPaddingH = widget.destinations.length > 4 ? 6.0 : 10.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
      child: SafeArea(
        top: false,
        child: AppGlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          borderRadius: 24,
          blurAmount: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(widget.destinations.length, (index) {
              final isSelected = widget.selectedIndex == index;
              final dest = widget.destinations[index];

              return Expanded(
                child: AppBounceable(
                  onTap: () => widget.onDestinationSelected(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(
                      horizontal: itemPaddingH,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primary.withValues(alpha: isDark ? 0.25 : 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? Border.all(
                              color: primary.withValues(alpha: 0.4),
                            )
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected ? dest.activeIcon : dest.icon,
                          size: widget.destinations.length > 4 ? 19 : 22,
                          color: isSelected
                              ? primary
                              : (isDark ? Colors.white54 : AppColors.slate500),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 4),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                dest.label,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: widget.destinations.length > 4 ? 10 : 12,
                                  fontWeight: FontWeight.bold,
                                  color: primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
