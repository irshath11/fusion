import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class OfflineBanner extends StatelessWidget {
  final int pendingCount;
  final VoidCallback onSyncPressed;

  const OfflineBanner({
    super.key,
    required this.pendingCount,
    required this.onSyncPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (pendingCount <= 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: AppColors.warning.withOpacity(0.9),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.black87, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Offline Mode: $pendingCount pending sync record${pendingCount > 1 ? 's' : ''}',
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: onSyncPressed,
            icon: const Icon(Icons.sync_rounded, size: 14),
            label: const Text('Sync Now', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
