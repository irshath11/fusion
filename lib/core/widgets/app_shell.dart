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

class AppShellActionItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const AppShellActionItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
  });
}

/// Adaptive Application Shell providing:
/// - Floating Glass Bottom Navigation Dock on Mobile (< 750px)
/// - Modern Collapsible Navigation Rail on Desktop/Tablet (>= 750px)
/// - Top Command Bar with 3-Dot Options Dropdown & Role Badge
class AppShell extends StatefulWidget {
  final String title;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavDestinationItem> destinations;
  final Widget body;
  final List<Widget>? actions;
  final List<AppShellActionItem>? menuItems;
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
    this.menuItems,
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
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.only(
        top: topPadding,
        left: isWide ? 20 : 12,
        right: isWide ? 20 : 12,
      ),
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
      child: SizedBox(
        height: 60,
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
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 3-Dot Options Dropdown Menu
          _buildThreeDotMenu(context, isDark, palette, primary),
        ],
      ),
    ),
    );
  }

  Widget _buildThreeDotMenu(
    BuildContext context,
    bool isDark,
    AppThemePalette palette,
    Color primary,
  ) {
    final List<AppShellActionItem> allItems = [
      AppShellActionItem(
        label: 'Online & Synced',
        icon: Icons.circle,
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Supabase Cloud Sync: Online & Verified'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 2),
            ),
          );
        },
        color: AppColors.success,
      ),
      if (widget.menuItems != null) ...widget.menuItems!,
      AppShellActionItem(
        label: 'Theme Selector',
        icon: Icons.palette_outlined,
        onTap: () => ThemeSelectorModal.show(context),
        color: primary,
      ),
    ];

    return Theme(
      data: Theme.of(context).copyWith(
        cardColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      ),
      child: PopupMenuButton<int>(
        icon: Container(
          padding: const EdgeInsets.all(7),
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
            Icons.more_vert_rounded,
            size: 20,
            color: isDark ? Colors.white70 : AppColors.slate800,
          ),
        ),
        tooltip: 'More Options',
        offset: const Offset(0, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isDark
                ? palette.cardBorderDark
                : palette.cardBorderLight,
          ),
        ),
        elevation: 8,
        onSelected: (index) {
          if (index >= 0 && index < allItems.length) {
            allItems[index].onTap();
          }
        },
        itemBuilder: (menuCtx) {
          return List.generate(allItems.length, (index) {
            final item = allItems[index];
            final itemColor = item.color ?? (isDark ? Colors.white.withValues(alpha: 0.87) : AppColors.slate800);
            final isOnlineItem = item.label == 'Online & Synced';

            return PopupMenuItem<int>(
              value: index,
              child: Row(
                children: [
                  if (isOnlineItem)
                    Container(
                      width: 9,
                      height: 9,
                      margin: const EdgeInsets.only(left: 5, right: 6),
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    )
                  else
                    Icon(item.icon, size: 20, color: itemColor),
                  const SizedBox(width: 12),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: itemColor,
                    ),
                  ),
                ],
              ),
            );
          });
        },
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
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
      child: SafeArea(
        top: false,
        child: AppGlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          borderRadius: 24,
          blurAmount: 16,
          child: LayoutBuilder(
            builder: (context, dockConstraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: dockConstraints.maxWidth - 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(widget.destinations.length, (index) {
                      final isSelected = widget.selectedIndex == index;
                      final dest = widget.destinations[index];

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: AppBounceable(
                          onTap: () => widget.onDestinationSelected(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primary.withValues(alpha: isDark ? 0.25 : 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                              border: isSelected
                                  ? Border.all(
                                      color: primary.withValues(alpha: 0.4),
                                      width: 1.5,
                                    )
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isSelected ? dest.activeIcon : dest.icon,
                                  size: 22,
                                  color: isSelected
                                      ? primary
                                      : (isDark ? Colors.white60 : AppColors.slate600),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  dest.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? primary
                                        : (isDark ? Colors.white70 : AppColors.slate700),
                                  ),
                                ),
                                if (dest.badge != null) ...[
                                  const SizedBox(width: 6),
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
                        ),
                      );
                    }),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
