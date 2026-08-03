import 'dart:ui';
import 'package:flutter/material.dart';
import '../design_system/app_shadows.dart';

class EnterpriseCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final bool isGlass;
  final Color? customBackgroundColor;

  const EnterpriseCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.isGlass = false,
    this.customBackgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = customBackgroundColor ??
        (isDark ? const Color(0xFF161B22) : Colors.white);
    final borderColor = isDark
        ? const Color(0xFF30363D)
        : const Color(0xFFE5E7EB);

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isGlass ? backgroundColor.withValues(alpha: 0.8) : backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: EnterpriseShadows.cardShadow(context),
      ),
      child: child,
    );

    if (isGlass) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: content,
        ),
      );
    }

    if (onTap != null) {
      return Padding(
        padding: margin,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: content,
          ),
        ),
      );
    }

    return Padding(
      padding: margin,
      child: content,
    );
  }
}
