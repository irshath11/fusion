import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'admin_cubit.dart';
import 'employee_management_screen.dart';
import 'office_management_screen.dart';
import 'work_site_management_screen.dart';
import 'live_tracking_map_screen.dart';
import 'reports_analytics_screen.dart';
import 'ownership_transfer_dialog.dart';
import '../../../core/constants/app_colors.dart';
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
  int _currentNavIndex = 0;

  final List<Widget> _pages = const [
    AdminOverviewTab(),
    EmployeeManagementScreen(),
    OfficeManagementScreen(),
    WorkSiteManagementScreen(),
    LiveTrackingMapScreen(),
    ReportsAnalyticsScreen(),
  ];

  final List<_NavDestination> _navItems = const [
    _NavDestination(icon: Icons.dashboard_rounded, label: 'Overview'),
    _NavDestination(icon: Icons.people_alt_rounded, label: 'Employees'),
    _NavDestination(icon: Icons.business_rounded, label: 'Offices'),
    _NavDestination(icon: Icons.location_city_rounded, label: 'Work Sites'),
    _NavDestination(icon: Icons.map_rounded, label: 'Live Tracking'),
    _NavDestination(icon: Icons.analytics_rounded, label: 'Reports'),
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
      child: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is Unauthenticated) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (ctx) => const LoginScreen()),
              (route) => false,
            );
          }
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktopWeb = kIsWeb || constraints.maxWidth >= 850;

            if (isDesktopWeb) {
              return Scaffold(
                body: Row(
                  children: [
                    // Desktop Enterprise Sidebar Navigation
                    Container(
                      width: 250,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F172A), // Dark Slate
                        border: Border(
                          right: BorderSide(color: Color(0xFF1E293B), width: 1),
                        ),
                      ),
                      child: Column(
                        children: [
                          // App Branding Header
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Color(0xFF1E293B)),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [AppColors.primary, AppColors.secondary],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'F360',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Fusion 360',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      'Admin Web Suite',
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Sidebar Nav Links
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              itemCount: _navItems.length,
                              itemBuilder: (context, index) {
                                final item = _navItems[index];
                                final isSelected = _currentNavIndex == index;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: InkWell(
                                    onTap: () => setState(() => _currentNavIndex = index),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                        border: isSelected
                                            ? Border.all(color: AppColors.primary.withValues(alpha: 0.4))
                                            : null,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            item.icon,
                                            size: 20,
                                            color: isSelected ? AppColors.primary : const Color(0xFF94A3B8),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            item.label,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                              color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          // Ownership Transfer & Logout Footer Section
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Color(0xFF1E293B)),
                              ),
                            ),
                            child: Column(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _showOwnershipTransferDialog,
                                  icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: Color(0xFFCBD5E1)),
                                  label: const Text('Transfer Ownership', style: TextStyle(fontSize: 12, color: Color(0xFFCBD5E1))),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 38),
                                    side: const BorderSide(color: Color(0xFF334155)),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () {
                                    context.read<AuthCubit>().logout();
                                    Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute(builder: (ctx) => const LoginScreen()),
                                      (route) => false,
                                    );
                                  },
                                  icon: const Icon(Icons.logout_rounded, size: 16, color: Colors.redAccent),
                                  label: const Text('Sign Out', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 36),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Main Viewport Area
                    Expanded(
                      child: Column(
                        children: [
                          // Top Desktop Header
                          Container(
                            height: 60,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _navItems[_currentNavIndex].label,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.circle, size: 8, color: Colors.green),
                                          SizedBox(width: 6),
                                          Text(
                                            'Supabase Cloud Active',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    IconButton(
                                      icon: const Icon(Icons.refresh_rounded),
                                      tooltip: 'Refresh Cloud Data',
                                      onPressed: () {
                                        context.read<AdminCubit>().loadDashboardData();
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Active Content Body
                          Expanded(
                            child: IndexedStack(
                              index: _currentNavIndex,
                              children: _pages,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            // Mobile App Layout Fallback
            return Scaffold(
              appBar: AppBar(
                title: Text(_navItems[_currentNavIndex].label),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.swap_horiz_rounded),
                    tooltip: 'Transfer Ownership',
                    onPressed: _showOwnershipTransferDialog,
                  ),
                  IconButton(
                    icon: const Icon(Icons.palette_rounded),
                    tooltip: 'Theme & Appearance',
                    onPressed: () => ThemeSelectorModal.show(context),
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
                index: _currentNavIndex,
                children: _pages,
              ),
              bottomNavigationBar: NavigationBar(
                selectedIndex: _currentNavIndex,
                onDestinationSelected: (index) {
                  setState(() => _currentNavIndex = index);
                },
                destinations: _navItems
                    .map((item) => NavigationDestination(
                          icon: Icon(item.icon),
                          label: item.label,
                        ))
                    .toList(),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NavDestination {
  final IconData icon;
  final String label;

  const _NavDestination({required this.icon, required this.label});
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
                  'Real-time Field Operations Command Center',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 900;
                    return GridView.count(
                      crossAxisCount: isWide ? 3 : 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: isWide ? 2.2 : 1.5,
                      children: [
                        _buildStatCard(context, 'Total Employees', '${employees.length}', Icons.badge_rounded, primary),
                        _buildStatCard(context, 'On Duty Currently', '$onDutyCount', Icons.access_time_filled_rounded, palette.success),
                        _buildStatCard(context, 'Checked In Today', '$totalCheckedInToday', Icons.how_to_reg_rounded, palette.secondary),
                        _buildStatCard(context, 'Shift Completed Today', '$totalCompletedToday', Icons.task_alt_rounded, palette.info),
                        _buildStatCard(context, 'Offices Geofenced', '${offices.length}', Icons.business_rounded, primary),
                        _buildStatCard(context, 'Pending Offline Sync', '$pendingSyncCount', Icons.wifi_off_rounded, palette.warning),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.shield_moon_rounded, color: primary),
                            const SizedBox(width: 10),
                            const Text('Geofence & Camera Audit Security Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text('• Live Front Camera Verification: Enforced on all check-ins/check-outs across mobile devices.'),
                        const SizedBox(height: 6),
                        const Text('• Haversine Distance Calculation: 200m strict radius geofencing active for all designated offices.'),
                        const SizedBox(height: 6),
                        const Text('• Cloud & Offline Architecture: High-concurrency Supabase PostgreSQL backend with Hive local fallback.'),
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
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color),
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
      ),
    );
  }
}
