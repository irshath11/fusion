import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/enterprise_card.dart';
import '../../../../core/widgets/metric_kpi_widget.dart';
import '../../../../core/widgets/geofence_status_chip.dart';
import '../../../../core/widgets/hero_punch_button.dart';
import '../../../../database/local_database_service.dart';
import '../../../../core/constants/app_enums.dart';

class HomeDashboardView extends StatelessWidget {
  final String userName;
  final String userRole;
  final bool isCheckedIn;
  final bool isLoading;
  final String? activeSiteName;
  final int pendingSyncCount;
  final VoidCallback onPunchPressed;
  final VoidCallback onSyncPressed;

  const HomeDashboardView({
    super.key,
    required this.userName,
    required this.userRole,
    required this.isCheckedIn,
    required this.isLoading,
    this.activeSiteName,
    required this.pendingSyncCount,
    required this.onPunchPressed,
    required this.onSyncPressed,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, MMM d, yyyy').format(now);
    final theme = Theme.of(context);
    final db = LocalDatabaseService();

    final todayRecords = db.getTodayAttendanceRecords();
    final allRecords = db.getAttendanceRecords();

    // 1. Compute Real Today's Work Duration
    String workDurationStr = "00h 00m";
    if (todayRecords.isNotEmpty) {
      final firstRecord = todayRecords.first;
      final lastRecord = todayRecords.last;
      final endTime = isCheckedIn ? DateTime.now() : lastRecord.eventTimestamp;
      final diff = endTime.difference(firstRecord.eventTimestamp);
      if (!diff.isNegative) {
        final hours = diff.inHours.toString().padLeft(2, '0');
        final mins = (diff.inMinutes % 60).toString().padLeft(2, '0');
        workDurationStr = "${hours}h ${mins}m";
      }
    }

    // 2. Compute Real Monthly Punctuality
    String punctualityStr = "100%";
    final nowMonthRecords = allRecords.where((r) {
      return r.eventTimestamp.year == now.year &&
          r.eventTimestamp.month == now.month &&
          (r.workflowStep == WorkflowStep.officeCheckIn ||
              r.workflowStep == WorkflowStep.siteCheckIn);
    }).toList();

    if (nowMonthRecords.isNotEmpty) {
      int onTime = 0;
      for (final r in nowMonthRecords) {
        if (r.eventTimestamp.hour < 9 ||
            (r.eventTimestamp.hour == 9 && r.eventTimestamp.minute <= 15)) {
          onTime++;
        }
      }
      final pct = (onTime / nowMonthRecords.length) * 100;
      punctualityStr = "${pct.toStringAsFixed(0)}%";
    }

    final displaySiteName = activeSiteName ??
        (db.getOffices().isNotEmpty
            ? db.getOffices().first.name
            : (db.getWorkSites().isNotEmpty
                ? db.getWorkSites().first.siteName
                : 'Main Office'));

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Executive Welcome Header & Telemetry Pill
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'WELCOME BACK',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              userRole.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userName.isNotEmpty ? userName : 'Employee',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.wb_sunny_rounded,
                    color: Colors.amber.shade700,
                    size: 22,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 2. Geofence & Location Status Strip
            Row(
              children: [
                Expanded(
                  child: GeofenceStatusChip(
                    isInsideGeofence: isCheckedIn,
                    siteName: displaySiteName,
                    distanceMeters: isCheckedIn ? 0 : 0,
                  ),
                ),
                if (pendingSyncCount > 0) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onSyncPressed,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.amber.shade700.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.wifi_off_rounded,
                              size: 14, color: Colors.amber.shade800),
                          const SizedBox(width: 4),
                          Text(
                            '$pendingSyncCount Sync',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // 3. Hero Punch Action Button Card
            HeroPunchButton(
              isCheckedIn: isCheckedIn,
              isLoading: isLoading,
              onPressed: onPunchPressed,
              activeSiteName: activeSiteName,
            ),

            const SizedBox(height: 16),

            // 4. Real Executive KPI Grid (4 Metrics)
            Row(
              children: [
                Expanded(
                  child: MetricKpiWidget(
                    title: "Today's Work",
                    value: workDurationStr,
                    icon: Icons.timer_outlined,
                    iconColor: const Color(0xFF0F62FE),
                    badgeText: isCheckedIn ? 'Active Shift' : 'Offline',
                    badgeColor:
                        isCheckedIn ? const Color(0xFF059669) : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricKpiWidget(
                    title: 'Punches Today',
                    value: '${todayRecords.length}',
                    icon: Icons.fingerprint_rounded,
                    iconColor: const Color(0xFF8A3FFC),
                    badgeText: 'Telemetry',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: MetricKpiWidget(
                    title: 'Shift Schedule',
                    value: '09:00 - 18:00',
                    icon: Icons.schedule_rounded,
                    iconColor: const Color(0xFF0043CE),
                    badgeText: 'Standard',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricKpiWidget(
                    title: 'Monthly Punctuality',
                    value: punctualityStr,
                    icon: Icons.verified_rounded,
                    iconColor: const Color(0xFF059669),
                    badgeText: 'On-Time',
                    badgeColor: const Color(0xFF059669),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 5. Today's Timeline Stream (Real Database Records)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Today's Shift Timeline",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (todayRecords.isNotEmpty)
                  Text(
                    '${todayRecords.length} Event${todayRecords.length == 1 ? "" : "s"}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            if (todayRecords.isEmpty)
              EnterpriseCard(
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.event_available_outlined,
                        size: 36,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'No Punch Events Recorded Today',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap the punch button above to check in and record real-time shift events.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              EnterpriseCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: todayRecords.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final record = entry.value;
                    final isFirst = idx == 0;
                    final isLast = idx == todayRecords.length - 1;
                    final timeStr =
                        DateFormat('hh:mm a').format(record.eventTimestamp);

                    IconData icon;
                    Color color;
                    switch (record.workflowStep) {
                      case WorkflowStep.officeCheckIn:
                      case WorkflowStep.siteCheckIn:
                        icon = Icons.check_circle_rounded;
                        color = const Color(0xFF059669);
                        break;
                      case WorkflowStep.siteCheckOut:
                        icon = Icons.directions_car_rounded;
                        color = const Color(0xFF8A3FFC);
                        break;
                      case WorkflowStep.officeCheckOut:
                      case WorkflowStep.completed:
                        icon = Icons.exit_to_app_rounded;
                        color = const Color(0xFF0F62FE);
                        break;
                    }

                    final siteDetails =
                        record.siteName != null && record.siteName!.isNotEmpty
                            ? 'Site: ${record.siteName}'
                            : 'Office Punch';
                    final photoDetails =
                        record.photoPath != null ? ' • Photo Verified' : '';

                    return _buildTimelineItem(
                      context,
                      time: timeStr,
                      title: record.workflowStep.displayName,
                      subtitle: '$siteDetails$photoDetails',
                      icon: icon,
                      color: color,
                      isFirst: isFirst,
                      isLast: isLast,
                    );
                  }).toList(),
                ),
              ),

            const SizedBox(height: 20),

            // 6. AI Workforce Intelligence Card
            EnterpriseCard(
              isGlass: true,
              customBackgroundColor:
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI Workforce Intelligence',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isCheckedIn
                              ? 'Currently checked in at ${activeSiteName ?? "Office"}. Shift duration: $workDurationStr.'
                              : (todayRecords.isNotEmpty
                                  ? 'Shift recorded for today. Total events: ${todayRecords.length}.'
                                  : 'Ready to start your shift. Tap Punch In to begin recording real-time telemetry.'),
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 80), // Padding for Bottom Glass Nav Bar
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(
    BuildContext context, {
    required String time,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 65,
            child: Text(
              time,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.grey.withValues(alpha: 0.2),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
