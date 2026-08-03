import 'package:flutter/material.dart';
import '../../../../core/widgets/enterprise_card.dart';
import '../../../../core/widgets/metric_kpi_widget.dart';

class SyncCenterView extends StatelessWidget {
  final int pendingCount;
  final bool isSyncing;
  final VoidCallback onForceSyncPressed;

  const SyncCenterView({
    super.key,
    required this.pendingCount,
    required this.isSyncing,
    required this.onForceSyncPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync & Edge Storage Center'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sync Progress Gauge Card
            EnterpriseCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CLOUD SYNC STATUS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: Color(0xFF0F62FE),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pendingCount > 0
                                ? '$pendingCount Records Pending'
                                : 'All Data Synchronized',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: pendingCount > 0
                              ? Colors.amber.shade700.withValues(alpha: 0.15)
                              : const Color(0xFF059669).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          pendingCount > 0
                              ? Icons.cloud_off_rounded
                              : Icons.cloud_done_rounded,
                          color: pendingCount > 0
                              ? Colors.amber.shade800
                              : const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F62FE),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: isSyncing ? null : onForceSyncPressed,
                      icon: isSyncing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.sync_rounded),
                      label: Text(
                        isSyncing
                            ? 'SYNCHRONIZING EDGE QUEUE...'
                            : 'FORCE SYNC QUEUE NOW',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: MetricKpiWidget(
                    title: 'Pending Punches',
                    value: '$pendingCount',
                    icon: Icons.fingerprint_rounded,
                    iconColor: Colors.amber.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: MetricKpiWidget(
                    title: 'Unsynced Photos',
                    value: '0',
                    icon: Icons.photo_camera_rounded,
                    iconColor: Color(0xFF8A3FFC),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            const Text(
              'Edge Buffer Queue Inspection',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            if (pendingCount == 0)
              EnterpriseCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: const [
                        Icon(Icons.check_circle_outline_rounded,
                            size: 40, color: Color(0xFF059669)),
                        SizedBox(height: 8),
                        Text(
                          'No Unsynced Local Records',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Your offline buffer is clean and synced to Supabase cloud.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              EnterpriseCard(
                child: ListTile(
                  leading: const Icon(Icons.offline_pin_rounded,
                      color: Colors.amber),
                  title: Text('$pendingCount Attendance Punch Queued'),
                  subtitle: const Text('Recorded locally while offline'),
                  trailing: TextButton(
                    onPressed: onForceSyncPressed,
                    child: const Text('Push'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
