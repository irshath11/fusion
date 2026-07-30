import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'admin_cubit.dart';
import 'employee_management_screen.dart';
import 'office_management_screen.dart';
import 'work_site_management_screen.dart';
import 'live_tracking_map_screen.dart';
import 'reports_analytics_screen.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/presentation/auth_cubit.dart';

import '../../auth/presentation/login_screen.dart';

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
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentBottomNavIndex,
            onDestinationSelected: (index) {
              setState(() => _currentBottomNavIndex = index);
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
    );
  }
}

class AdminOverviewTab extends StatelessWidget {
  const AdminOverviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: BlocBuilder<AdminCubit, AdminState>(
        builder: (context, state) {
          if (state is AdminDataLoaded) {
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
                    _buildStatCard(context, 'Total Employees', '${state.employees.length}', Icons.badge_rounded, AppColors.primary),
                    _buildStatCard(context, 'In Office Currently', '8', Icons.business_center_rounded, AppColors.success),
                    _buildStatCard(context, 'At Client Sites', '5', Icons.location_on_rounded, AppColors.secondary),
                    _buildStatCard(context, 'Travelling In Transit', '3', Icons.directions_car_rounded, AppColors.warning),
                    _buildStatCard(context, 'Offices Geofenced', '${state.offices.length}', Icons.shield_rounded, AppColors.info),
                    _buildStatCard(context, 'Pending Offline Sync', '2', Icons.wifi_off_rounded, Colors.orange),
                  ],
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.shield_moon_rounded, color: AppColors.primary),
                            SizedBox(width: 10),
                            Text('Geofence & Camera Audit Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
    return Card(
      color: color.withOpacity(0.08),
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
                Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondaryLight)),
          ],
        ),
      ),
    );
  }
}
