import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'admin_cubit.dart';
import 'employee_management_screen.dart';
import 'office_management_screen.dart';
import 'work_site_management_screen.dart';
import 'live_tracking_map_screen.dart';
import 'reports_analytics_screen.dart';
import 'ownership_transfer_dialog.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_enums.dart';
import '../../../database/local_database_service.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../auth/presentation/login_screen.dart';

import '../../../core/widgets/app_bounceable.dart';
import '../../../core/widgets/app_glass_card.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/staggered_animated_item.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentNavIndex = 0;

  final List<NavDestinationItem> _navItems = const [
    NavDestinationItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      label: 'Overview',
    ),
    NavDestinationItem(
      icon: Icons.people_outline_rounded,
      activeIcon: Icons.people_alt_rounded,
      label: 'Employees',
    ),
    NavDestinationItem(
      icon: Icons.business_outlined,
      activeIcon: Icons.business_rounded,
      label: 'Offices',
    ),
    NavDestinationItem(
      icon: Icons.location_city_outlined,
      activeIcon: Icons.location_city_rounded,
      label: 'Work Sites',
    ),
    NavDestinationItem(
      icon: Icons.map_outlined,
      activeIcon: Icons.map_rounded,
      label: 'Live Map',
    ),
    NavDestinationItem(
      icon: Icons.analytics_outlined,
      activeIcon: Icons.analytics_rounded,
      label: 'Reports',
    ),
  ];

  void _showOwnershipTransferDialog() {
    showDialog(
      context: context,
      builder: (ctx) => const OwnershipTransferDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AdminCubit(),
      child: Builder(
        builder: (adminCtx) {
          return BlocListener<AuthCubit, AuthState>(
            listener: (context, state) {
              if (state is Unauthenticated) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (ctx) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: AppShell(
              title: _navItems[_currentNavIndex].label,
              selectedIndex: _currentNavIndex,
              onDestinationSelected: (index) {
                setState(() => _currentNavIndex = index);
                adminCtx.read<AdminCubit>().loadDashboardData();
              },
              destinations: _navItems,
              userRoleLabel: 'System Admin',
              actions: [
                IconButton(
                  icon: const Icon(Icons.swap_horiz_rounded),
                  tooltip: 'Transfer Ownership',
                  onPressed: _showOwnershipTransferDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                  tooltip: 'Sign Out',
                  onPressed: () {
                    context.read<AuthCubit>().logout();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (ctx) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                ),
              ],
              body: IndexedStack(
                index: _currentNavIndex,
                children: [
                  AdminOverviewTab(key: ValueKey('overview_$_currentNavIndex')),
                  EmployeeManagementScreen(key: ValueKey('employee_$_currentNavIndex')),
                  OfficeManagementScreen(key: ValueKey('office_$_currentNavIndex')),
                  WorkSiteManagementScreen(key: ValueKey('worksite_$_currentNavIndex')),
                  LiveTrackingMapScreen(key: ValueKey('live_map_$_currentNavIndex')),
                  ReportsAnalyticsScreen(key: ValueKey('reports_$_currentNavIndex')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class AdminOverviewTab extends StatelessWidget {
  const AdminOverviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    final db = LocalDatabaseService();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: BlocBuilder<AdminCubit, AdminState>(
        builder: (context, state) {
          if (state is AdminDataLoaded) {
            final employees = state.employees.isNotEmpty
                ? state.employees
                : db.getEmployees();
            final offices = db.getOffices();
            final allRecords = db.getAttendanceRecords();
            final pendingSyncCount = db.getPendingSyncRecords().length;

            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);

            final todayRecords = allRecords.where((r) {
              final rDate = DateTime(r.eventTimestamp.year,
                  r.eventTimestamp.month, r.eventTimestamp.day);
              return rDate.isAtSameMomentAs(today);
            }).toList();

            final checkedInEmpIds =
                todayRecords.map((r) => r.employeeId).toSet();
            final totalCheckedInToday = checkedInEmpIds.length;

            final completedEmpIds = todayRecords
                .where((r) =>
                    r.workflowStep == WorkflowStep.officeCheckOut ||
                    r.workflowStep == WorkflowStep.completed)
                .map((r) => r.employeeId)
                .toSet();
            final totalCompletedToday = completedEmpIds.length;

            final onDutyCount = (totalCheckedInToday - totalCompletedToday)
                .clamp(0, totalCheckedInToday);

            final isDark = Theme.of(context).brightness == Brightness.dark;
            final palette = AppTheme.currentColors;
            final primary =
                palette.primaryFor(isDark ? Brightness.dark : Brightness.light);

            final statItems = [
              {
                'title': 'Total Employees',
                'value': '${employees.length}',
                'icon': Icons.badge_rounded,
                'color': primary
              },
              {
                'title': 'On Duty Currently',
                'value': '$onDutyCount',
                'icon': Icons.access_time_filled_rounded,
                'color': palette.success
              },
              {
                'title': 'Checked In Today',
                'value': '$totalCheckedInToday',
                'icon': Icons.how_to_reg_rounded,
                'color': palette.secondary
              },
              {
                'title': 'Shift Completed',
                'value': '$totalCompletedToday',
                'icon': Icons.task_alt_rounded,
                'color': palette.info
              },
              {
                'title': 'Offices Geofenced',
                'value': '${offices.length}',
                'icon': Icons.business_rounded,
                'color': primary
              },
              {
                'title': 'Pending Offline Sync',
                'value': '$pendingSyncCount',
                'icon': Icons.wifi_off_rounded,
                'color': palette.warning
              },
            ];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Real-time Field Operations Command Center',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 900;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: statItems.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isWide ? 3 : 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: isWide ? 2.2 : 1.5,
                      ),
                      itemBuilder: (context, index) {
                        final item = statItems[index];
                        return StaggeredAnimatedItem(
                          index: index,
                          child: AppBounceable(
                            child: _buildStatCard(
                              context,
                              item['title'] as String,
                              item['value'] as String,
                              item['icon'] as IconData,
                              item['color'] as Color,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 24),
                StaggeredAnimatedItem(
                  index: 6,
                  child: AppGlassCard(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.shield_moon_rounded, color: primary),
                            const SizedBox(width: 10),
                            const Text(
                              'Geofence & Camera Audit Security Status',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                            '• Live Front Camera Verification: Enforced on all check-ins/check-outs across mobile devices.'),
                        const SizedBox(height: 6),
                        const Text(
                            '• Haversine Distance Calculation: 200m strict radius geofencing active for all designated offices.'),
                        const SizedBox(height: 6),
                        const Text(
                            '• Cloud & Offline Architecture: High-concurrency Supabase PostgreSQL backend with Hive local fallback.'),
                      ],
                    ),
                  ),
                )
              ],
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value,
      IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = AppTheme.currentColors;

    return AppGlassCard(
      customBackgroundColor: color.withValues(alpha: isDark ? 0.18 : 0.08),
      customBorderColor: color.withValues(alpha: isDark ? 0.4 : 0.25),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 28),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(title,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? palette.textSecondaryDark
                        : palette.textSecondaryLight)),
          ),
        ],
      ),
    );
  }
}
