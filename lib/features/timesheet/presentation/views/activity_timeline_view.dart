import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/enterprise_card.dart';
import '../../../../database/local_database_service.dart';
import '../../../../core/constants/app_enums.dart';

class ActivityTimelineView extends StatelessWidget {
  const ActivityTimelineView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final db = LocalDatabaseService();
    final records = db.getAttendanceRecords().reversed.toList(); // Newest first

    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-Time Activity Audit'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Audit Telemetry Feed',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              if (records.isNotEmpty)
                Text(
                  '${records.length} Total Event${records.length == 1 ? "" : "s"}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (records.isEmpty)
            EnterpriseCard(
              padding:
                  const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.history_toggle_off_rounded,
                      size: 44,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No Telemetry Events Logged',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Recorded check-ins, check-outs, and geofence telemetry will be logged here in real time.',
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
              padding: EdgeInsets.zero,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: records.length,
                separatorBuilder: (ctx, idx) => const Divider(height: 1),
                itemBuilder: (ctx, idx) {
                  final record = records[idx];
                  final timeStr = DateFormat('MMM d, hh:mm a')
                      .format(record.eventTimestamp);

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
                          : 'Office Location';
                  final syncTag =
                      record.syncStatus == SyncStatus.synced ? 'Synced' : 'Offline Pending';

                  return _buildActivityTile(
                    context,
                    time: timeStr,
                    title: record.workflowStep.displayName,
                    subtitle:
                        '$siteDetails • $syncTag${record.photoPath != null ? " • Photo Proof" : ""}',
                    icon: icon,
                    iconColor: color,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityTile(
    BuildContext context, {
    required String time,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: Text(time,
          style: const TextStyle(fontSize: 11, color: Colors.grey)),
    );
  }
}
