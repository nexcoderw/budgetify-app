import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/app_colors.dart';

class AppModalDialog extends StatelessWidget {
  const AppModalDialog({
    super.key,
    required this.child,
    this.maxWidth = 520,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 18,
    this.insetPadding = const EdgeInsets.symmetric(
      horizontal: 18,
      vertical: 24,
    ),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;
  final double borderRadius;
  final EdgeInsets insetPadding;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      backgroundColor: Colors.transparent,
      insetPadding: insetPadding,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            padding: padding,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class AppModalCloseButton extends StatelessWidget {
  const AppModalCloseButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Close',
      onPressed: onTap,
      icon: const HugeIcon(
        icon: HugeIcons.strokeRoundedCancel01,
        size: 18,
        color: AppColors.textSecondary,
        strokeWidth: 1.9,
      ),
      splashRadius: 18,
      style: IconButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        backgroundColor: Colors.white.withValues(alpha: 0.04),
        shape: const CircleBorder(),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
      ),
    );
  }
}

class AppModalActionButton extends StatelessWidget {
  const AppModalActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isPrimary = false,
    this.isLoading = false,
    this.primaryColor = AppColors.primary,
    this.primaryForegroundColor = AppColors.background,
    this.outlineForegroundColor = AppColors.textPrimary,
    this.leading,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isLoading;
  final Color primaryColor;
  final Color primaryForegroundColor;
  final Color outlineForegroundColor;
  final Widget? leading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final effectivePrimaryForeground =
        primaryForegroundColor.toARGB32() == Colors.white.toARGB32() ||
            primaryForegroundColor.toARGB32() ==
                AppColors.background.toARGB32()
        ? primaryColor
        : primaryForegroundColor;
    final foregroundColor = isPrimary
        ? effectivePrimaryForeground
        : outlineForegroundColor;
    final isEnabled = onPressed != null && !isLoading;

    final child = isLoading
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 8)],
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          );

    final topAlpha = isEnabled
        ? (isPrimary ? 0.34 : 0.26)
        : (isPrimary ? 0.18 : 0.14);
    final bottomAlpha = isEnabled
        ? (isPrimary ? 0.18 : 0.12)
        : (isPrimary ? 0.10 : 0.08);
    final borderAlpha = isEnabled ? (isPrimary ? 0.34 : 0.24) : 0.16;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: isEnabled ? 1 : 0.72,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: topAlpha),
                  Colors.white.withValues(alpha: bottomAlpha),
                ],
              ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Colors.white.withValues(alpha: borderAlpha),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.10),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: primaryColor.withValues(
                    alpha: isPrimary ? 0.12 : 0.05,
                  ),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: height * 0.55,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.28),
                            Colors.white.withValues(alpha: 0.02),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isEnabled ? onPressed : null,
                    borderRadius: BorderRadius.circular(999),
                    splashColor: foregroundColor.withValues(alpha: 0.08),
                    highlightColor: foregroundColor.withValues(alpha: 0.03),
                    child: SizedBox(
                      height: height,
                      child: Center(
                        child: IconTheme(
                          data: IconThemeData(color: foregroundColor),
                          child: DefaultTextStyle.merge(
                            style: TextStyle(color: foregroundColor),
                            child: child,
                          ),
                        ),
                      ),
                    ),
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

class AppModalOverlay extends StatelessWidget {
  const AppModalOverlay({
    super.key,
    required this.child,
    this.onDismiss,
    this.dismissible = true,
  });

  final Widget child;
  final VoidCallback? onDismiss;
  final bool dismissible;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: dismissible ? onDismiss : null,
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.56)),
            ),
          ),
          Center(child: child),
        ],
      ),
    );
  }
}
