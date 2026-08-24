import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'admin_cubit.dart';
import 'employee_management_screen.dart';
import 'office_management_screen.dart';
import 'work_site_management_screen.dart';
import 'live_tracking_map_screen.dart';
import 'reports_analytics_screen.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_enums.dart';
import '../../../database/local_database_service.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../auth/presentation/login_screen.dart';

import '../../../core/theme/theme_selector_modal.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentBottomNavIndex = 0;

  final List<Widget> _pages = const [
    AdminOverviewTab(),
    EmployeeManagementScreen(),
    OfficeManagementScreen(),
    WorkSiteManagementScreen(),
    ReportsAnalyticsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AdminCubit(),
      child: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is Unauthenticated) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (ctx) => const LoginScreen()),
              (route) => false,
            );
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Super Admin Management Suite'),
            actions: [
              IconButton(
                icon: const Icon(Icons.map_rounded),
                tooltip: 'Live Field Tracking Map',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (ctx) => const LiveTrackingMapScreen()),
                  );
                },
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                tooltip: 'More options',
                onSelected: (value) {
                  if (value == 'theme') {
                    ThemeSelectorModal.show(context);
                  } else if (value == 'reset_cache') {
                    _showResetCacheDialog(context);
                  } else if (value == 'logout') {
                    context.read<AuthCubit>().logout();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (ctx) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'theme',
                    child: Row(
                      children: [
                        Icon(Icons.palette_rounded, size: 20),
                        SizedBox(width: 12),
                        Text('Theme & Appearance'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'reset_cache',
                    child: Row(
                      children: [
                        Icon(Icons.cleaning_services_rounded, size: 20, color: Colors.orange),
                        SizedBox(width: 12),
                        Text('Reset Local Cache'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout_rounded, size: 20, color: Colors.red),
                        SizedBox(width: 12),
                        Text('Logout', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: IndexedStack(
            index: _currentBottomNavIndex,
            children: _pages,
          ),
          bottomNavigationBar: Builder(
            builder: (ctx) => NavigationBar(
              selectedIndex: _currentBottomNavIndex,
              onDestinationSelected: (index) {
                setState(() => _currentBottomNavIndex = index);
                try {
                  ctx.read<AdminCubit>().loadDashboardData();
                } catch (_) {}
              },
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.dashboard_rounded), label: 'Overview'),
                NavigationDestination(
                    icon: Icon(Icons.people_alt_rounded), label: 'Employees'),
                NavigationDestination(
                    icon: Icon(Icons.business_rounded), label: 'Offices'),
                NavigationDestination(
                    icon: Icon(Icons.location_city_rounded),
                    label: 'Work Sites'),
                NavigationDestination(
                    icon: Icon(Icons.analytics_rounded), label: 'Reports'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showResetCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cleaning_services_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Reset Local Cache'),
          ],
        ),
        content: const Text(
          'This will purge all locally cached attendance records from this device.\n\n'
          'Use this if you deleted logs directly in Supabase or want to clear old offline data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              LocalDatabaseService().clearLocalAttendanceRecords();
              try {
                context.read<AdminCubit>().loadDashboardData('Local attendance cache reset.');
              } catch (_) {}
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Local attendance records cleared successfully.'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Reset Cache'),
          ),
        ],
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
      padding: const EdgeInsets.all(16.0),
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

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Real-time Field Operations Overview',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: [
                    _buildStatCard(context, 'Total Employees',
                        '${employees.length}', Icons.badge_rounded, primary),
                    _buildStatCard(context, 'On Duty Currently', '$onDutyCount',
                        Icons.access_time_filled_rounded, palette.success),
                    _buildStatCard(
                        context,
                        'Checked In Today',
                        '$totalCheckedInToday',
                        Icons.how_to_reg_rounded,
                        palette.secondary),
                    _buildStatCard(
                        context,
                        'Shift Completed Today',
                        '$totalCompletedToday',
                        Icons.task_alt_rounded,
                        palette.info),
                    _buildStatCard(context, 'Offices Geofenced',
                        '${offices.length}', Icons.business_rounded, primary),
                    _buildStatCard(
                        context,
                        'Pending Offline Sync',
                        '$pendingSyncCount',
                        Icons.wifi_off_rounded,
                        palette.secondary),
                  ],
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.history_rounded, color: primary),
                                const SizedBox(width: 10),
                                const Text(
                                  'Recent Punch Activity',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: primary.withValues(
                                    alpha: isDark ? 0.2 : 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${todayRecords.length} Logs Today',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        if (todayRecords.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: Center(
                              child: Text(
                                'No attendance punches recorded yet today.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          )
                        else
                          Builder(
                            builder: (context) {
                              final recentLogs = todayRecords.toList()
                                ..sort((a, b) => b.eventTimestamp
                                    .compareTo(a.eventTimestamp));
                              final displayLogs = recentLogs.take(5).toList();

                              return ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: displayLogs.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(height: 16),
                                itemBuilder: (context, index) {
                                  final r = displayLogs[index];
                                  final timeStr = DateFormat('hh:mm a')
                                      .format(r.eventTimestamp.toLocal());

                                  return Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: primary.withValues(
                                            alpha: isDark ? 0.2 : 0.1),
                                        child: Icon(
                                          _getStepIcon(r.workflowStep),
                                          size: 16,
                                          color: primary,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              r.employeeName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13.5,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              '${r.workflowStep.displayName} • $timeStr',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: isDark
                                                    ? palette.textSecondaryDark
                                                    : palette
                                                        .textSecondaryLight,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: (r.isGeofenceValid
                                                  ? palette.success
                                                  : palette.error)
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          r.isGeofenceValid
                                              ? 'VALID'
                                              : 'VIOLATION',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: r.isGeofenceValid
                                                ? palette.success
                                                : palette.error,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
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

  Widget _buildStatCard(BuildContext context, String title, String value,
      IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = AppTheme.currentColors;

    return Card(
      color: color.withValues(alpha: isDark ? 0.15 : 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(palette.cardRadius * 0.8),
        side: BorderSide(
          color: color.withValues(alpha: isDark ? 0.35 : 0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(value,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
      ),
    );
  }

  IconData _getStepIcon(WorkflowStep step) {
    switch (step) {
      case WorkflowStep.officeCheckIn:
        return Icons.login_rounded;
      case WorkflowStep.siteCheckIn:
        return Icons.location_city_rounded;
      case WorkflowStep.siteCheckOut:
        return Icons.departure_board_rounded;
      case WorkflowStep.breakStart:
        return Icons.free_breakfast_rounded;
      case WorkflowStep.breakEnd:
        return Icons.work_rounded;
      case WorkflowStep.officeCheckOut:
        return Icons.logout_rounded;
      default:
        return Icons.touch_app_rounded;
    }
  }
}
