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
import '../../../core/theme/app_theme_preset.dart';
import '../../../core/constants/app_enums.dart';
import '../../../database/local_database_service.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../auth/presentation/login_screen.dart';
import '../domain/employee_entity.dart';
import '../../attendance/domain/attendance_record.dart';


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

  void _showResetCacheDialog(BuildContext adminCtx) {
    showDialog(
      context: adminCtx,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.cleaning_services_rounded, color: Colors.orangeAccent),
              SizedBox(width: 10),
              Text('Reset Attendance Cache'),
            ],
          ),
          content: const Text(
            'Are you sure you want to clear all locally cached attendance records? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                LocalDatabaseService().clearAttendanceCache();
                Navigator.pop(dialogCtx);
                adminCtx.read<AdminCubit>().loadDashboardData('Local attendance cache cleared.');
                ScaffoldMessenger.of(adminCtx).showSnackBar(
                  const SnackBar(
                    content: Text('Local attendance cache cleared successfully.'),
                    backgroundColor: Colors.orangeAccent,
                  ),
                );
              },
              child: const Text('Clear Cache'),
            ),
          ],
        );
      },
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
                  icon: const Icon(Icons.cleaning_services_rounded),
                  tooltip: 'Clear Local Cache',
                  onPressed: () => _showResetCacheDialog(adminCtx),
                ),
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
                  AdminOverviewTab(
                    key: ValueKey('overview_$_currentNavIndex'),
                    onNavigateTab: (index) {
                      setState(() => _currentNavIndex = index);
                      adminCtx.read<AdminCubit>().loadDashboardData();
                    },
                  ),
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
  final Function(int)? onNavigateTab;
  const AdminOverviewTab({super.key, this.onNavigateTab});

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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.bolt_rounded, color: primary, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Live Activity & Operations Hub',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    Text(
                                      'Real-time attendance stream and rapid admin shortcuts',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? palette.textSecondaryDark
                                            : palette.textSecondaryLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: palette.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: palette.success.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: palette.success,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'LIVE',
                                    style: TextStyle(
                                      color: palette.success,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 16),
                        
                        // Recent activity events stream
                        ..._buildRecentActivityList(context, todayRecords, employees, isDark, palette),

                        const SizedBox(height: 16),
                        
                        // Quick Action Navigation Bar
                        Text(
                          'Quick Administrative Actions',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? palette.textSecondaryDark : palette.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _buildQuickActionButton(
                              context: context,
                              icon: Icons.map_rounded,
                              label: 'Live Field Map',
                              color: primary,
                              onTap: () => onNavigateTab?.call(4),
                            ),
                            _buildQuickActionButton(
                              context: context,
                              icon: Icons.analytics_rounded,
                              label: 'Reports & Timesheets',
                              color: palette.secondary,
                              onTap: () => onNavigateTab?.call(5),
                            ),
                            _buildQuickActionButton(
                              context: context,
                              icon: Icons.people_alt_rounded,
                              label: 'Manage Team',
                              color: palette.info,
                              onTap: () => onNavigateTab?.call(1),
                            ),
                            _buildQuickActionButton(
                              context: context,
                              icon: Icons.business_rounded,
                              label: 'Office Stations',
                              color: palette.warning,
                              onTap: () => onNavigateTab?.call(2),
                            ),
                          ],
                        ),
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

  List<Widget> _buildRecentActivityList(
    BuildContext context,
    List<AttendanceRecord> todayRecords,
    List<EmployeeEntity> employees,
    bool isDark,
    AppThemePalette palette,
  ) {
    if (todayRecords.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.history_toggle_off_rounded,
                  color: isDark ? palette.textSecondaryDark : palette.textSecondaryLight, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No check-in activities recorded today yet. Real-time updates will stream here automatically as field officers clock in.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? palette.textSecondaryDark : palette.textSecondaryLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ];
    }

    final sorted = List<AttendanceRecord>.from(todayRecords)
      ..sort((a, b) => b.eventTimestamp.compareTo(a.eventTimestamp));
    final recentRecords = sorted.take(4).toList();

    return recentRecords.map((r) {
      final empMatches = employees.where((e) => e.id == r.employeeId);
      final empName = empMatches.isNotEmpty ? empMatches.first.name : r.employeeName;
      final stepInfo = _getStepDisplayInfo(r.workflowStep, palette, isDark);
      final timeStr =
          '${r.eventTimestamp.hour.toString().padLeft(2, '0')}:${r.eventTimestamp.minute.toString().padLeft(2, '0')}';
      final locationStr = (r.siteName != null && r.siteName!.isNotEmpty)
          ? r.siteName!
          : (r.address.isNotEmpty ? r.address : 'HQ Office');

      return Padding(
        padding: const EdgeInsets.only(bottom: 10.0),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: stepInfo.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(stepInfo.icon, color: stepInfo.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            empName.isNotEmpty ? empName : 'Field Officer',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: stepInfo.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            stepInfo.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: stepInfo.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      locationStr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? palette.textSecondaryDark : palette.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeStr,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        r.isGeofenceValid ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                        size: 12,
                        color: r.isGeofenceValid ? palette.success : palette.warning,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        r.isGeofenceValid ? 'Verified' : 'Outside',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: r.isGeofenceValid ? palette.success : palette.warning,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  _StepInfo _getStepDisplayInfo(WorkflowStep step, AppThemePalette palette, bool isDark) {
    final primary = palette.primaryFor(isDark ? Brightness.dark : Brightness.light);
    switch (step) {
      case WorkflowStep.officeCheckIn:
        return _StepInfo('Office Check-In', Icons.login_rounded, primary);
      case WorkflowStep.siteCheckIn:
        return _StepInfo('Site Check-In', Icons.location_on_rounded, palette.secondary);
      case WorkflowStep.siteCheckOut:
        return _StepInfo('Site Check-Out', Icons.logout_rounded, palette.warning);
      case WorkflowStep.breakStart:
        return _StepInfo('Break Start', Icons.coffee_rounded, palette.info);
      case WorkflowStep.breakEnd:
        return _StepInfo('Break End', Icons.coffee_maker_rounded, palette.info);
      case WorkflowStep.officeCheckOut:
        return _StepInfo('Office Check-Out', Icons.task_alt_rounded, palette.success);
      case WorkflowStep.completed:
        return _StepInfo('Shift Completed', Icons.verified_rounded, palette.success);
    }
  }

  Widget _buildQuickActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppBounceable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: isDark ? 0.35 : 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
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

class _StepInfo {
  final String label;
  final IconData icon;
  final Color color;
  _StepInfo(this.label, this.icon, this.color);
}


