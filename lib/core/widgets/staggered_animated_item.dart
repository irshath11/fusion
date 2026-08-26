import 'package:flutter/material.dart';

/// Staggered fade + slide entrance animation wrapper for list items and grid cards.
class StaggeredAnimatedItem extends StatelessWidget {
  final int index;
  final Widget child;
  final Duration baseDuration;
  final double slideOffset;
  final Axis direction;

  const StaggeredAnimatedItem({
    super.key,
    required this.index,
    required this.child,
    this.baseDuration = const Duration(milliseconds: 350),
    this.slideOffset = 24.0,
    this.direction = Axis.vertical,
  });

  @override
  Widget build(BuildContext context) {
    // Cap index multiplier to avoid excessively long delays for items far down the list
    final effectiveIndex = index.clamp(0, 12);
    final delayMs = (effectiveIndex * 50);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: baseDuration + Duration(milliseconds: delayMs),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        final opacity = value.clamp(0.0, 1.0);
        final offset = (1.0 - value) * slideOffset;

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: direction == Axis.vertical
                ? Offset(0, offset)
                : Offset(offset, 0),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
