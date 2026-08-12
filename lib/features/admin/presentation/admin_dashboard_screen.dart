import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_cubit.dart';
import 'employee_management_screen.dart';
import 'office_management_screen.dart';
import 'work_site_management_screen.dart';
import 'live_tracking_map_screen.dart';
import 'reports_analytics_screen.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/widgets/animated_widgets.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../database/local_database_service.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../auth/presentation/login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentTabIndex = 0;

  final List<Widget> _pages = const [
    AdminOverviewTab(),
    EmployeeManagementScreen(),
    OfficeManagementScreen(),
    WorkSiteManagementScreen(),
    ReportsAnalyticsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final org = LocalDatabaseService().organization;

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
          backgroundColor:
              isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  org?.name ?? 'Enterprise HQ',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Command Center & Field Ops Suite',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.map_rounded, color: AppColors.primary),
                tooltip: 'Live Telemetry Map',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (ctx) => const LiveTrackingMapScreen()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded),
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
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: IndexedStack(
                    index: _currentTabIndex,
                    children: _pages,
                  ),
                ),
                // Executive 5-Segmented Sliding Navigation Bar
                SegmentedPillNavBar(
                  selectedIndex: _currentTabIndex,
                  onTabSelected: (index) =>
                      setState(() => _currentTabIndex = index),
                  items: const [
                    SegmentedTabItem(
                      label: 'Command',
                      icon: Icons.dashboard_outlined,
                      activeIcon: Icons.dashboard_rounded,
                    ),
                    SegmentedTabItem(
                      label: 'Staff',
                      icon: Icons.people_outline_rounded,
                      activeIcon: Icons.people_alt_rounded,
                    ),
                    SegmentedTabItem(
                      label: 'Offices',
                      icon: Icons.domain_outlined,
                      activeIcon: Icons.domain_rounded,
                    ),
                    SegmentedTabItem(
                      label: 'Work Sites',
                      icon: Icons.location_city_outlined,
                      activeIcon: Icons.location_city_rounded,
                    ),
                    SegmentedTabItem(
                      label: 'Reports',
                      icon: Icons.analytics_outlined,
                      activeIcon: Icons.analytics_rounded,
                    ),
                  ],
                ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
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

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Live Operations Radar Card
                GlassSurfaceCard(
                  padding: const EdgeInsets.all(18),
                  borderRadius: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Live Fleet & Field Radar',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Real-time workforce presence & telemetry',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                      const StatusBadge(
                        label: 'Active Cloud Sync',
                        color: AppColors.success,
                        isLive: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2x3 Metric Stat Grid
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.35,
                  children: [
                    _buildStatCard(
                      title: 'Total Workforce',
                      value: '${employees.length}',
                      subtitle: 'Active Staff',
                      icon: Icons.badge_rounded,
                      color: AppColors.primary,
                      isDark: isDark,
                    ),
                    _buildStatCard(
                      title: 'On Duty Now',
                      value: '$onDutyCount',
                      subtitle: 'Field & Office',
                      icon: Icons.access_time_filled_rounded,
                      color: AppColors.success,
                      isDark: isDark,
                    ),
                    _buildStatCard(
                      title: 'Checked In Today',
                      value: '$totalCheckedInToday',
                      subtitle: 'Shift Started',
                      icon: Icons.how_to_reg_rounded,
                      color: AppColors.secondary,
                      isDark: isDark,
                    ),
                    _buildStatCard(
                      title: 'Completed Shifts',
                      value: '$totalCompletedToday',
                      subtitle: 'Shift Finished',
                      icon: Icons.task_alt_rounded,
                      color: const Color(0xFF0284C7),
                      isDark: isDark,
                    ),
                    _buildStatCard(
                      title: 'Geofenced Hubs',
                      value: '${offices.length}',
                      subtitle: 'Active Offices',
                      icon: Icons.business_rounded,
                      color: const Color(0xFF6366F1),
                      isDark: isDark,
                    ),
                    _buildStatCard(
                      title: 'Offline Queue',
                      value: '$pendingSyncCount',
                      subtitle: 'Pending Sync',
                      icon: Icons.cloud_queue_rounded,
                      color: Colors.amber.shade700,
                      isDark: isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Security & Geofence Policy Banner
                GlassSurfaceCard(
                  padding: const EdgeInsets.all(18),
                  borderRadius: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.shield_rounded,
                                color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Enterprise Geofence & Audit Protocol',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildAuditPoint('• Live front camera verification enforced on all office check-ins & check-outs.', isDark),
                      const SizedBox(height: 6),
                      _buildAuditPoint('• High-precision Haversine 200m geofence active across all branches.', isDark),
                      const SizedBox(height: 6),
                      _buildAuditPoint('• Auto 8-Hour shift closure applied for sessions exceeding 24 hours.', isDark),
                      const SizedBox(height: 6),
                      _buildAuditPoint('• Encrypted Supabase PostgreSQL replication with local Hive fallbacks.', isDark),
                    ],
                  ),
                ),
              ],
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _buildAuditPoint(String text, bool isDark) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        color: isDark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight,
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
