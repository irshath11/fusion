import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
                icon: const Icon(Icons.palette_rounded),
                tooltip: 'Theme & Appearance',
                onPressed: () => ThemeSelectorModal.show(context),
              ),
              IconButton(
                icon: const Icon(Icons.map_rounded),
                tooltip: 'Live Field Tracking Map',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (ctx) => const LiveTrackingMapScreen()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                tooltip: 'Logout',
                onPressed: () {
                  context.read<AuthCubit>().logout();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (ctx) => const LoginScreen()),
                    (route) => false,
                  );
                },
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
              NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Overview'),
              NavigationDestination(icon: Icon(Icons.people_alt_rounded), label: 'Employees'),
              NavigationDestination(icon: Icon(Icons.business_rounded), label: 'Offices'),
              NavigationDestination(icon: Icon(Icons.location_city_rounded), label: 'Work Sites'),
              NavigationDestination(icon: Icon(Icons.analytics_rounded), label: 'Reports'),
            ],
          ),
        ),
      ),
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
            final employees = state.employees.isNotEmpty ? state.employees : db.getEmployees();
            final offices = db.getOffices();
            final allRecords = db.getAttendanceRecords();
            final pendingSyncCount = db.getPendingSyncRecords().length;

            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);

            final todayRecords = allRecords.where((r) {
              final rDate = DateTime(r.eventTimestamp.year, r.eventTimestamp.month, r.eventTimestamp.day);
              return rDate.isAtSameMomentAs(today);
            }).toList();

            final checkedInEmpIds = todayRecords.map((r) => r.employeeId).toSet();
            final totalCheckedInToday = checkedInEmpIds.length;

            final completedEmpIds = todayRecords
                .where((r) => r.workflowStep == WorkflowStep.officeCheckOut || r.workflowStep == WorkflowStep.completed)
                .map((r) => r.employeeId)
                .toSet();
            final totalCompletedToday = completedEmpIds.length;

            final onDutyCount = (totalCheckedInToday - totalCompletedToday).clamp(0, totalCheckedInToday);

            final isDark = Theme.of(context).brightness == Brightness.dark;
            final palette = AppTheme.currentColors;
            final primary = palette.primaryFor(isDark ? Brightness.dark : Brightness.light);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Real-time Field Operations Overview',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                    _buildStatCard(context, 'Total Employees', '${employees.length}', Icons.badge_rounded, primary),
                    _buildStatCard(context, 'On Duty Currently', '$onDutyCount', Icons.access_time_filled_rounded, palette.success),
                    _buildStatCard(context, 'Checked In Today', '$totalCheckedInToday', Icons.how_to_reg_rounded, palette.secondary),
                    _buildStatCard(context, 'Shift Completed Today', '$totalCompletedToday', Icons.task_alt_rounded, palette.info),
                    _buildStatCard(context, 'Offices Geofenced', '${offices.length}', Icons.business_rounded, primary),
                    _buildStatCard(context, 'Pending Offline Sync', '$pendingSyncCount', Icons.wifi_off_rounded, palette.warning),
                  ],
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.shield_moon_rounded, color: primary),
                            const SizedBox(width: 10),
                            const Text('Geofence & Camera Audit Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text('• All attendance check-ins enforced via live front camera.'),
                        const Text('• 200m Haversine distance geofence active across all office locations.'),
                        const Text('• Real-time Supabase PostgreSQL sync active with Hive offline caching.'),
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

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
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
                  child: Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
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
}
