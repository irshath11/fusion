import 'package:flutter/material.dart';

class GeofenceStatusChip extends StatelessWidget {
  final bool isInsideGeofence;
  final String siteName;
  final double? distanceMeters;

  const GeofenceStatusChip({
    super.key,
    required this.isInsideGeofence,
    required this.siteName,
    this.distanceMeters,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isInsideGeofence
        ? const Color(0xFF059669) // Emerald Green
        : const Color(0xFFD97706); // Amber Warning

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isInsideGeofence
                ? 'Inside Geofence: $siteName'
                : 'Outside Radius ($siteName${distanceMeters != null ? " ${distanceMeters!.toStringAsFixed(0)}m" : ""})',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
}
