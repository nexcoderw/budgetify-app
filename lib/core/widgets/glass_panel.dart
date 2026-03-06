import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = const BorderRadius.all(Radius.circular(32)),
    this.blur = 24,
    this.opacity = 0.14,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius borderRadius;
  final double blur;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: opacity + 0.07),
                Colors.white.withValues(alpha: opacity),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 32,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(24),
            child: child,
          ),
        ),
      ),
    );
  }
}

class GlassBadge extends StatelessWidget {
  const GlassBadge({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      blur: 18,
      opacity: 0.1,
      borderRadius: BorderRadius.circular(999),
      padding: padding,
      child: DefaultTextStyle.merge(
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        child: child,
      ),
    );
  }
}
