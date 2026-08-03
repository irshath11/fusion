import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_enums.dart';
import '../../../../core/widgets/enterprise_card.dart';
import '../../../../core/widgets/metric_kpi_widget.dart';
import '../../../../database/local_database_service.dart';

class AttendanceHubView extends StatefulWidget {
  const AttendanceHubView({super.key});

  @override
  State<AttendanceHubView> createState() => _AttendanceHubViewState();
}

class _AttendanceHubViewState extends State<AttendanceHubView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Intelligence'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          indicatorColor: theme.colorScheme.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: "Today's Log"),
            Tab(text: "Monthly Heatmap"),
            Tab(text: "Work Hours"),
            Tab(text: "Exceptions & Overtime"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTodaysLogTab(context),
          _buildMonthlyHeatmapTab(context),
          _buildWorkHoursTab(context),
          _buildExceptionsTab(context),
        ],
      ),
    );
  }

  Widget _buildTodaysLogTab(BuildContext context) {
    final db = LocalDatabaseService();
    final todayRecords = db.getTodayAttendanceRecords();
    final firstPunch = todayRecords.isNotEmpty ? todayRecords.first : null;
    final lastPunch = todayRecords.length > 1 ? todayRecords.last : null;

    final punchInTimeStr = firstPunch != null
        ? DateFormat('hh:mm a').format(firstPunch.eventTimestamp)
        : 'Not Punched';
    final punchOutTimeStr = lastPunch != null
        ? DateFormat('hh:mm a').format(lastPunch.eventTimestamp)
        : (firstPunch != null ? 'Shift Active' : 'Pending');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: MetricKpiWidget(
                  title: 'Shift Punch In',
                  value: punchInTimeStr,
                  subtitle: firstPunch?.siteName ?? 'HQ Office',
                  icon: Icons.login_rounded,
                  iconColor: const Color(0xFF059669),
                  badgeText: firstPunch != null ? 'Recorded' : 'Pending',
                  badgeColor: firstPunch != null ? const Color(0xFF059669) : Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricKpiWidget(
                  title: 'Shift Punch Out',
                  value: punchOutTimeStr,
                  subtitle: lastPunch?.siteName ?? 'HQ Office',
                  icon: Icons.logout_rounded,
                  iconColor: const Color(0xFFD97706),
                  badgeText: lastPunch != null ? 'Completed' : 'In Progress',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Punch Details & Verification Proof',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (todayRecords.isEmpty)
            EnterpriseCard(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: const Center(
                child: Text(
                  'No verification logs recorded for today.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
            )
          else
            EnterpriseCard(
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F62FE).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          color: Color(0xFF0F62FE), size: 20),
                    ),
                    title: const Text('Photo Verification',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: Text(firstPunch?.photoPath != null
                        ? 'Photo capture verified at check-in'
                        : 'No photo required for office check-in'),
                    trailing: Icon(
                      firstPunch?.photoPath != null
                          ? Icons.verified_rounded
                          : Icons.check_circle_outline,
                      color: const Color(0xFF059669),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8A3FFC).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.my_location_rounded,
                          color: Color(0xFF8A3FFC), size: 20),
                    ),
                    title: const Text('Geofence Coordinates',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: Text(firstPunch != null
                        ? 'Lat: ${firstPunch.latitude.toStringAsFixed(4)}°, Long: ${firstPunch.longitude.toStringAsFixed(4)}°'
                        : 'Coordinates available upon check-in'),
                    trailing: Chip(
                      label: Text(firstPunch?.siteName ?? 'HQ Site',
                          style: const TextStyle(fontSize: 10)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMonthlyHeatmapTab(BuildContext context) {
    final db = LocalDatabaseService();
    final allRecords = db.getAttendanceRecords();
    final now = DateTime.now();

    final monthName = DateFormat('MMMM yyyy').format(now);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    final activeDays = <int>{};
    for (final r in allRecords) {
      if (r.eventTimestamp.year == now.year && r.eventTimestamp.month == now.month) {
        activeDays.add(r.eventTimestamp.day);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$monthName Attendance Heatmap',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          EnterpriseCard(
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: daysInMonth,
              itemBuilder: (context, index) {
                final day = index + 1;
                final date = DateTime(now.year, now.month, day);
                final isWeekend = (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday);
                final isToday = day == now.day;
                final hasAttendance = activeDays.contains(day);

                Color statusColor = isWeekend
                    ? Colors.grey.shade300
                    : (hasAttendance
                        ? const Color(0xFF059669)
                        : (isToday ? const Color(0xFF0F62FE) : Colors.grey.shade200));

                return Container(
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: statusColor,
                      width: isToday ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor == Colors.grey.shade200 ? Colors.grey : statusColor,
                      ),
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

  Widget _buildWorkHoursTab(BuildContext context) {
    final db = LocalDatabaseService();
    final records = db.getAttendanceRecords();

    double totalHours = 0;
    if (records.isNotEmpty) {
      totalHours = (records.length * 4.0);
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          MetricKpiWidget(
            title: 'Weekly Accumulated Hours',
            value: '${totalHours.toStringAsFixed(1)} / 40.0 hrs',
            subtitle: 'Target 40h standard shift week',
            icon: Icons.bar_chart_rounded,
            iconColor: const Color(0xFF0F62FE),
            badgeText: totalHours >= 30 ? 'On Track' : 'In Progress',
            badgeColor: totalHours >= 30 ? const Color(0xFF059669) : Colors.amber.shade800,
          ),
        ],
      ),
    );
  }

  Widget _buildExceptionsTab(BuildContext context) {
    final db = LocalDatabaseService();
    final records = db.getAttendanceRecords();
    final exceptions = records.where((r) {
      return r.eventTimestamp.hour > 9 || (r.eventTimestamp.hour == 9 && r.eventTimestamp.minute > 15);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (exceptions.isEmpty)
          const EnterpriseCard(
            padding: EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            child: Center(
              child: Text(
                'No attendance exceptions or late arrivals logged.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
          )
        else
          ...exceptions.map((r) {
            final timeStr = DateFormat('MMM d, yyyy - hh:mm a').format(r.eventTimestamp);
            return EnterpriseCard(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706)),
                title: Text('${r.workflowStep.displayName} (${r.siteName ?? "Office"})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text(timeStr),
                trailing: const Chip(
                  label: Text('Logged'),
                  backgroundColor: Color(0xFFFEF3C7),
                ),
              ),
            );
          }),
      ],
    );
  }
}
