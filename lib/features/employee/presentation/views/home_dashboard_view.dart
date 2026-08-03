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
  final VoidCallback? onSiteCheckInPressed;
  final bool isFirstSiteCheckIn;
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
    this.onSiteCheckInPressed,
    this.isFirstSiteCheckIn = true,
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

    // 1. Compute Working Time purely from First Office Check-In to Final Day Check-Out
    String workDurationStr = "00h 00m";
    String regularStr = "00h 00m";
    String otStr = "00h 00m";

    final officeInIndex = todayRecords.indexWhere(
      (r) => r.workflowStep == WorkflowStep.officeCheckIn,
    );

    if (officeInIndex != -1) {
      final firstOfficeIn = todayRecords[officeInIndex];
      final officeOutMatches = todayRecords.where(
        (r) => r.workflowStep == WorkflowStep.officeCheckOut,
      );

      final DateTime endTime = officeOutMatches.isNotEmpty
          ? officeOutMatches.last.eventTimestamp
          : (isCheckedIn ? DateTime.now() : todayRecords.last.eventTimestamp);

      final diff = endTime.difference(firstOfficeIn.eventTimestamp);
      if (!diff.isNegative) {
        final hours = diff.inHours.toString().padLeft(2, '0');
        final mins = (diff.inMinutes % 60).toString().padLeft(2, '0');
        workDurationStr = "${hours}h ${mins}m";

        final totalMins = diff.inMinutes;
        final regMins = totalMins > 480 ? 480 : totalMins;
        final otMins = totalMins > 480 ? totalMins - 480 : 0;

        final regH = (regMins ~/ 60).toString().padLeft(2, '0');
        final regM = (regMins % 60).toString().padLeft(2, '0');
        regularStr = "${regH}h ${regM}m";

        final otH = (otMins ~/ 60).toString().padLeft(2, '0');
        final otM = (otMins % 60).toString().padLeft(2, '0');
        otStr = "${otH}h ${otM}m";
      }
    }

    // 2. Compute Dynamic Shift & Real Monthly Punctuality
    final user = db.currentUser;
    final empId = user?.id ?? user?.firebaseUid;
    final activeShift = db.getShiftForEmployee(empId, now);

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
        final recordShift = db.getShiftForEmployee(empId, r.eventTimestamp);
        if (recordShift.isOnTime(r.eventTimestamp)) {
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
                const SizedBox(width: 8),
                InkWell(
                  onTap: onSyncPressed,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: pendingSyncCount > 0
                          ? Colors.amber.shade700.withValues(alpha: 0.15)
                          : const Color(0xFF059669).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: pendingSyncCount > 0
                            ? Colors.amber.shade700.withValues(alpha: 0.4)
                            : const Color(0xFF059669).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          pendingSyncCount > 0
                              ? Icons.wifi_off_rounded
                              : Icons.cloud_done_rounded,
                          size: 14,
                          color: pendingSyncCount > 0
                              ? Colors.amber.shade800
                              : const Color(0xFF059669),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          pendingSyncCount > 0
                              ? '$pendingSyncCount Pending Sync'
                              : 'Cloud Synced',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: pendingSyncCount > 0
                                ? Colors.amber.shade800
                                : const Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 3. Hero Punch Action Button Card
            HeroPunchButton(
              isCheckedIn: isCheckedIn,
              isLoading: isLoading,
              onPressed: onPunchPressed,
              onSiteCheckInPressed: onSiteCheckInPressed,
              activeSiteName: activeSiteName,
              isFirstSiteCheckIn: isFirstSiteCheckIn,
            ),

            const SizedBox(height: 16),

            // 4. Executive KPI Grid (4 Metrics: Total Work, OT, Shift Schedule 24h, Punctuality)
            Row(
              children: [
                Expanded(
                  child: MetricKpiWidget(
                    title: "Total Work",
                    value: workDurationStr,
                    icon: Icons.timer_outlined,
                    iconColor: const Color(0xFF0F62FE),
                    badgeText: 'Reg: $regularStr',
                    badgeColor: const Color(0xFF0F62FE),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricKpiWidget(
                    title: 'Overtime (OT)',
                    value: otStr,
                    icon: Icons.more_time_rounded,
                    iconColor: const Color(0xFFD97706),
                    badgeText: '8h+ Extra',
                    badgeColor: const Color(0xFFD97706),
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
                    value: activeShift.displayTimeRange,
                    icon: activeShift.isNightShift
                        ? Icons.nights_stay_rounded
                        : Icons.schedule_rounded,
                    iconColor: activeShift.isNightShift
                        ? const Color(0xFF7C3AED)
                        : const Color(0xFF0043CE),
                    badgeText: '${activeShift.name.split('(').first.trim()} (24h)',
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
