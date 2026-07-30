import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../database/local_database_service.dart';

class LiveTrackingMapScreen extends StatelessWidget {
  const LiveTrackingMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = LocalDatabaseService();
    final activeCount = db.getEmployees().where((e) => e.isActive).length;
    final officeCount = db.getOffices().length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Field Workforce Map'),
      ),
      body: Stack(
        children: [
          // Simulated Map Rendering Container
          Container(
            color: const Color(0xFFE5E7EB),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                        )
                      ],
                    ),
                    child: const Icon(Icons.map_rounded, size: 72, color: AppColors.primary),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Interactive Live GPS Geofence Map',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tracking $activeCount Active Employees across $officeCount Offices',
                    style: const TextStyle(color: AppColors.textSecondaryLight),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildLegendItem(Colors.blue, 'Main Office (200m)'),
                    _buildLegendItem(Colors.green, 'Employee Pin'),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        CircleAvatar(radius: 6, backgroundColor: color),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
