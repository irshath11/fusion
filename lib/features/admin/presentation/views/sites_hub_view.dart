import 'package:flutter/material.dart';
import '../../../../core/widgets/enterprise_card.dart';
import '../../../../core/widgets/geofence_status_chip.dart';
import '../../../../database/local_database_service.dart';

class SitesHubView extends StatelessWidget {
  const SitesHubView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final db = LocalDatabaseService();
    final offices = db.getOffices();
    final workSites = db.getWorkSites();
    final totalSitesCount = offices.length + workSites.length;
    final activeSiteName = db.getActiveSiteNameToday();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Work Sites & Geofences'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map Overview Banner
            EnterpriseCard(
              padding: EdgeInsets.zero,
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primaryContainer,
                      theme.colorScheme.surfaceContainerHighest,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map_rounded,
                        size: 44, color: theme.colorScheme.primary),
                    const SizedBox(height: 8),
                    const Text(
                      'Geofenced Locations',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$totalSitesCount Registered Location${totalSitesCount == 1 ? "" : "s"}',
                      style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Assigned Work Sites & Offices',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                if (totalSitesCount > 0)
                  Text(
                    '$totalSitesCount Total',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            if (totalSitesCount == 0)
              EnterpriseCard(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.business_outlined,
                        size: 40,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'No Work Sites Registered',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Offices and project sites configured by your admin will be displayed here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            for (final office in offices)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildSiteTile(
                  context,
                  name: office.name,
                  address: office.address.isNotEmpty
                      ? office.address
                      : 'Main Office Facility',
                  radius: '${office.geofenceRadiusMeters}m Radius',
                  type: 'Office',
                  isCurrent: activeSiteName == office.name,
                ),
              ),

            for (final site in workSites)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildSiteTile(
                  context,
                  name: site.siteName,
                  address: site.address.isNotEmpty
                      ? site.address
                      : 'Field Project Location',
                  radius: '${site.radiusMeters}m Radius',
                  type: 'Work Site',
                  isCurrent: activeSiteName == site.siteName,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSiteTile(
    BuildContext context, {
    required String name,
    required String address,
    required String radius,
    required String type,
    required bool isCurrent,
  }) {
    return EnterpriseCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCurrent
                  ? const Color(0xFF059669).withValues(alpha: 0.12)
                  : const Color(0xFF0F62FE).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCurrent ? Icons.location_on_rounded : Icons.business_rounded,
              color: isCurrent
                  ? const Color(0xFF059669)
                  : const Color(0xFF0F62FE),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      const GeofenceStatusChip(
                        isInsideGeofence: true,
                        siteName: 'Active',
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  address,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.radar_rounded,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      '$type • $radius',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
