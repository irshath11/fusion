import 'package:flutter/material.dart';
import '../../../../core/widgets/enterprise_card.dart';
import '../../../../core/widgets/metric_kpi_widget.dart';
import '../../../../database/local_database_service.dart';
import '../../../admin/domain/employee_entity.dart';

class EmployeeProfileView extends StatelessWidget {
  final String userName;
  final String userRole;
  final VoidCallback onLogoutPressed;

  const EmployeeProfileView({
    super.key,
    required this.userName,
    required this.userRole,
    required this.onLogoutPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final db = LocalDatabaseService();
    final user = db.currentUser;
    final allUserRecords = db.getAttendanceRecords();
    final employees = db.getEmployees();
    EmployeeEntity? matchingEmp;
    if (user != null) {
      for (final e in employees) {
        if ((e.email.isNotEmpty && e.email.trim().toLowerCase() == user.email.trim().toLowerCase()) ||
            e.id == user.id) {
          matchingEmp = e;
          break;
        }
      }
    }
    final empCode = matchingEmp?.employeeCode.isNotEmpty == true
        ? matchingEmp!.employeeCode
        : (user?.id.isNotEmpty == true ? user!.id : 'EMP-2026');

    final totalShiftsCount = allUserRecords.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Self Service'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Digital ID Badge Header
            EnterpriseCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'E',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    userName.isNotEmpty ? userName : 'Employee',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    userRole.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_user_rounded,
                            size: 14, color: Color(0xFF059669)),
                        const SizedBox(width: 6),
                        Text(
                          'Emp Code: $empCode',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Performance & Real Attendance Metrics
            Row(
              children: [
                Expanded(
                  child: MetricKpiWidget(
                    title: 'Total Shift Events',
                    value: '$totalShiftsCount Logs',
                    icon: Icons.history_rounded,
                    iconColor: Colors.deepOrange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricKpiWidget(
                    title: 'Account Status',
                    value: 'Active',
                    icon: Icons.check_circle_rounded,
                    iconColor: const Color(0xFF059669),
                    badgeText: 'Verified',
                    badgeColor: const Color(0xFF059669),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Settings & Actions Menu
            EnterpriseCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.email_outlined),
                    title: const Text('Email Address'),
                    subtitle: Text(user?.email ?? 'No email associated'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.security_rounded),
                    title: const Text('Security & Session'),
                    subtitle: const Text('Authenticated via Supabase Engine'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: onLogoutPressed,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text(
                  'LOG OUT OF SESSION',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
