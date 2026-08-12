import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import 'animated_widgets.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
      child: isVisible
          ? Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2A1C0A)
                    : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: isDark ? 0.4 : 0.6),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  PulsingStatusDot(color: AppColors.warning, size: 7),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Offline Queue: $pendingCount unsynced record${pendingCount > 1 ? 's' : ''}',
                      style: GoogleFonts.plusJakartaSans(
                        color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  BouncingButton(
                    onTap: isSyncing ? null : onSyncPressed,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF451A03) : AppColors.warning,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSyncing)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.8,
                                color: Colors.white,
                              ),
                            )
                          else
                            const Icon(
                              Icons.sync_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                          const SizedBox(width: 6),
                          Text(
                            isSyncing ? 'Syncing...' : 'Sync Cloud',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox(width: double.infinity, height: 0),
    );
  }
}
