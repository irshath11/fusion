import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/app_theme.dart';

/// Modern glassmorphic surface container with backdrop blur, dual gradient borders,
/// subtle ambient glow, and theme-adaptive styling.
class AppGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final double blurAmount;
  final Color? customBorderColor;
  final Color? customBackgroundColor;
  final LinearGradient? customGradient;
  final VoidCallback? onTap;

  const AppGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius,
    this.blurAmount = 10.0,
    this.customBorderColor,
    this.customBackgroundColor,
    this.customGradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = AppTheme.currentColors;
    final radius = borderRadius ?? palette.cardRadius;

    final borderColor = customBorderColor ??
        (isDark
            ? palette.cardBorderDark.withValues(alpha: 0.7)
            : palette.cardBorderLight.withValues(alpha: 0.9));

    final bgColor = customBackgroundColor ??
        (isDark
            ? palette.surfaceDark.withValues(alpha: 0.65)
            : Colors.white.withValues(alpha: 0.75));

    final gradient = customGradient ??
        (isDark ? palette.cardGradientDark : palette.cardGradientLight);

    Widget content = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.35)
                : palette.accentGlow.withValues(alpha: 0.15),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: gradient,
              color: bgColor,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: borderColor,
                width: isDark ? 1.2 : 1.0,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: content,
      );
    }

    return content;
  }
}
