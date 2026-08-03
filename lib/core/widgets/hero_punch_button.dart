import 'package:flutter/material.dart';

class HeroPunchButton extends StatefulWidget {
  final bool isCheckedIn;
  final bool isLoading;
  final VoidCallback onPressed;
  final VoidCallback? onSiteCheckInPressed;
  final String? activeSiteName;
  final bool isFirstSiteCheckIn;

  const HeroPunchButton({
    super.key,
    required this.isCheckedIn,
    this.isLoading = false,
    required this.onPressed,
    this.onSiteCheckInPressed,
    this.activeSiteName,
    this.isFirstSiteCheckIn = true,
  });

  @override
  State<HeroPunchButton> createState() => _HeroPunchButtonState();
}

class _HeroPunchButtonState extends State<HeroPunchButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonColor = widget.isCheckedIn
        ? const Color(0xFFDC2626) // Enterprise Red Check-Out
        : const Color(0xFF0F62FE); // Enterprise Blue Check-In

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: buttonColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: buttonColor.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: buttonColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.isCheckedIn
                      ? Icons.logout_rounded
                      : Icons.touch_app_rounded,
                  color: buttonColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isCheckedIn ? 'CURRENTLY ON DUTY' : 'READY FOR SHIFT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: buttonColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.isCheckedIn
                          ? 'Checked in at ${widget.activeSiteName ?? "Work Site"}'
                          : 'Tap below to initiate geo-verified check in',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          if (!widget.isCheckedIn) ...[
            // Start of day: Initial Office Check-In (Requires Photo)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: buttonColor.withValues(
                            alpha: 0.2 + (_pulseController.value * 0.15)),
                        blurRadius: 16 + (_pulseController.value * 8),
                        spreadRadius: _pulseController.value * 2,
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: widget.isLoading ? null : widget.onPressed,
                  icon: widget.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt_rounded,
                          size: 20,
                        ),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.isLoading
                          ? 'PROCESSING GEO-PUNCH...'
                          : 'CAPTURE PHOTO & OFFICE CHECK IN',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ] else ...[
            // On Duty: 1. SITE CHECK IN Button (Top)
            if (widget.onSiteCheckInPressed != null) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    side: BorderSide(
                        color: theme.colorScheme.primary.withValues(alpha: 0.5),
                        width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed:
                      widget.isLoading ? null : widget.onSiteCheckInPressed,
                  icon: Icon(
                    widget.isFirstSiteCheckIn
                        ? Icons.camera_alt_rounded
                        : Icons.add_location_alt_rounded,
                    size: 20,
                  ),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.isFirstSiteCheckIn
                          ? 'CAPTURE PHOTO & SITE CHECK IN'
                          : 'SITE CHECK IN',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // On Duty: 2. FINAL CHECK OUT Button (Placed Below Site Check In Button - Requires Photo)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: buttonColor.withValues(
                            alpha: 0.2 + (_pulseController.value * 0.15)),
                        blurRadius: 16 + (_pulseController.value * 8),
                        spreadRadius: _pulseController.value * 2,
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor, // Red
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: widget.isLoading ? null : widget.onPressed,
                  icon: widget.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt_rounded,
                          size: 20,
                        ),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.isLoading
                          ? 'PROCESSING...'
                          : 'CAPTURE PHOTO & FINAL CHECK OUT',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
