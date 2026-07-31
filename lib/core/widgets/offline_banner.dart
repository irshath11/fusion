import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class OfflineBanner extends StatelessWidget {
  final int pendingCount;
  final bool isSyncing;
  final VoidCallback onSyncPressed;

  const OfflineBanner({
    super.key,
    required this.pendingCount,
    this.isSyncing = false,
    required this.onSyncPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bool isVisible = pendingCount > 0;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: isVisible ? 1.0 : 0.0,
        child: isVisible
            ? Container(
                width: double.infinity,
                color: AppColors.warning.withValues(alpha: 0.95),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: isSyncing ? null : onSyncPressed,
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: isSyncing
                            ? const SizedBox(
                                key: ValueKey('sync_spinner'),
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.sync_rounded, key: ValueKey('sync_icon'), size: 14),
                      ),
                      label: Text(
                        isSyncing ? 'Syncing...' : 'Sync Now',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox(width: double.infinity, height: 0),
      ),
    );
  }
}
