import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

enum AppButtonVariant { primary, secondary, outline, success, danger }

class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final AppButtonVariant variant;
  final double height;
  final double? width;
  final Gradient? gradient;
  final double borderRadius;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.variant = AppButtonVariant.primary,
    this.height = 52.0,
    this.width,
    this.gradient,
    this.borderRadius = 14.0,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    Color bg;
    Color fg;
    Border? border;
    Gradient? effGradient = widget.gradient;

    switch (widget.variant) {
      case AppButtonVariant.primary:
        bg = widget.backgroundColor ?? AppColors.primary;
        fg = widget.textColor ?? Colors.white;
        effGradient ??= AppColors.primaryGradient;
        break;
      case AppButtonVariant.success:
        bg = widget.backgroundColor ?? AppColors.success;
        fg = widget.textColor ?? Colors.white;
        effGradient ??= AppColors.successGradient;
        break;
      case AppButtonVariant.danger:
        bg = widget.backgroundColor ?? AppColors.error;
        fg = widget.textColor ?? Colors.white;
        break;
      case AppButtonVariant.secondary:
        bg = isDark ? AppColors.surfaceDarkElevated : AppColors.surfaceLightElevated;
        fg = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
        border = Border.all(
          color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight,
          width: 0.8,
        );
        effGradient = null;
        break;
      case AppButtonVariant.outline:
        bg = Colors.transparent;
        fg = widget.textColor ?? (isDark ? AppColors.primaryLight : AppColors.primary);
        border = Border.all(
          color: isDark ? AppColors.primaryLight : AppColors.primary,
          width: 1.2,
        );
        effGradient = null;
        break;
    }

    if (!isEnabled) {
      bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
      fg = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
      effGradient = null;
      border = null;
    }

    return GestureDetector(
      onTapDown: isEnabled ? (_) => _controller.forward() : null,
      onTapUp: isEnabled
          ? (_) {
              _controller.reverse();
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          width: widget.width ?? double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            color: effGradient == null ? bg : null,
            gradient: effGradient,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: border,
            boxShadow: isEnabled && (widget.variant == AppButtonVariant.primary || widget.variant == AppButtonVariant.success)
                ? [
                    BoxShadow(
                      color: (effGradient != null ? AppColors.primary : bg)
                          .withValues(alpha: isDark ? 0.35 : 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(fg),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 18, color: fg),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.text,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: fg,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
