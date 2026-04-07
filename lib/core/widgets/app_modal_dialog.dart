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
    this.height = 48,
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
    final child = isLoading
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              valueColor: AlwaysStoppedAnimation<Color>(
                isPrimary ? primaryForegroundColor : outlineForegroundColor,
              ),
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

    final button = isPrimary
        ? ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              minimumSize: Size(0, height),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
              backgroundColor: primaryColor.withValues(alpha: 0.16),
              foregroundColor: primaryForegroundColor,
              disabledBackgroundColor: primaryColor.withValues(alpha: 0.08),
              disabledForegroundColor: primaryForegroundColor.withValues(
                alpha: 0.55,
              ),
              elevation: 0,
              shadowColor: primaryColor.withValues(alpha: 0.18),
              side: BorderSide(color: primaryColor.withValues(alpha: 0.24)),
              shape: const StadiumBorder(),
            ),
            child: child,
          )
        : OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: Size(0, height),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
              foregroundColor: outlineForegroundColor,
              backgroundColor: Colors.white.withValues(alpha: 0.045),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
              shape: const StadiumBorder(),
            ),
            child: child,
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: button,
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
