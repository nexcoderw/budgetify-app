import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/app_colors.dart';

enum AppButtonSize { sm, md, lg }

enum AppButtonVariant { primary, secondary, ghost }

class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconWidget,
    this.size = AppButtonSize.md,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.fullWidth = true,
    this.semanticLabel,
  }) : assert(
         (icon != null) != (iconWidget != null),
         'AppButton requires exactly one icon source.',
       );

  final String label;
  final VoidCallback? onPressed;
  final dynamic icon;
  final Widget? iconWidget;
  final AppButtonSize size;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool fullWidth;
  final String? semanticLabel;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loadingController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _syncLoadingAnimation();
  }

  @override
  void didUpdateWidget(covariant AppButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoading != widget.isLoading) {
      _syncLoadingAnimation();
    }
  }

  @override
  void dispose() {
    _loadingController.dispose();
    super.dispose();
  }

  void _syncLoadingAnimation() {
    if (widget.isLoading) {
      _loadingController.repeat();
      return;
    }

    _loadingController
      ..stop()
      ..value = 0;
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _ButtonMetrics.fromSize(widget.size);
    final palette = _ButtonPalette.fromVariant(
      widget.variant,
      enabled: widget.onPressed != null,
    );
    final isInteractive = widget.onPressed != null && !widget.isLoading;
    final button = AnimatedScale(
      scale: _isPressed ? 0.975 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: widget.onPressed == null ? 0.5 : 1,
        duration: const Duration(milliseconds: 180),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: palette.gradient,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: palette.borderColor),
            boxShadow: widget.variant == AppButtonVariant.ghost
                ? null
                : [
                    BoxShadow(
                      color: palette.glowColor,
                      blurRadius: _isPressed ? 10 : 22,
                      spreadRadius: -8,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 9),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isInteractive ? widget.onPressed : null,
              onHighlightChanged: (isHighlighted) {
                if (_isPressed == isHighlighted) {
                  return;
                }
                setState(() => _isPressed = isHighlighted);
              },
              borderRadius: BorderRadius.circular(999),
              splashColor: palette.foreground.withValues(alpha: 0.10),
              highlightColor: palette.foreground.withValues(alpha: 0.04),
              child: SizedBox(
                height: metrics.height,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: metrics.padding),
                  child: Center(
                    child: widget.isLoading
                        ? _TransferPulseLoader(
                            controller: _loadingController,
                            size: metrics.loaderSize,
                            color: palette.foreground,
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildIcon(metrics, palette.foreground),
                              SizedBox(width: metrics.gap),
                              Text(
                                widget.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'DMSans',
                                  fontSize: metrics.fontSize,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.1,
                                  color: palette.foreground,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: isInteractive,
      label: widget.isLoading
          ? '${widget.semanticLabel ?? widget.label}, loading'
          : widget.semanticLabel ?? widget.label,
      child: ExcludeSemantics(
        child: widget.fullWidth
            ? SizedBox(width: double.infinity, child: button)
            : button,
      ),
    );
  }

  Widget _buildIcon(_ButtonMetrics metrics, Color color) {
    final customIcon = widget.iconWidget;
    if (customIcon != null) {
      return SizedBox.square(dimension: metrics.iconSize, child: customIcon);
    }

    return HugeIcon(
      icon: widget.icon,
      size: metrics.iconSize,
      color: color,
      strokeWidth: 1.9,
    );
  }
}

class _TransferPulseLoader extends StatelessWidget {
  const _TransferPulseLoader({
    super.key,
    required this.controller,
    required this.size,
    required this.color,
  });

  final AnimationController controller;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return SizedBox.square(
      dimension: size,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return Transform.rotate(
            angle: disableAnimations ? 0 : controller.value * math.pi * 2,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withValues(alpha: 0.24),
                      width: 1.4,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: size * 0.34,
                    height: size * 0.34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.48),
                          blurRadius: 7,
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: size * 0.20,
                  height: size * 0.20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.74),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ButtonMetrics {
  const _ButtonMetrics({
    required this.height,
    required this.padding,
    required this.iconSize,
    required this.loaderSize,
    required this.fontSize,
    required this.gap,
  });

  factory _ButtonMetrics.fromSize(AppButtonSize size) {
    return switch (size) {
      AppButtonSize.sm => const _ButtonMetrics(
        height: 44,
        padding: 16,
        iconSize: 16,
        loaderSize: 18,
        fontSize: 12,
        gap: 8,
      ),
      AppButtonSize.md => const _ButtonMetrics(
        height: 52,
        padding: 20,
        iconSize: 18,
        loaderSize: 22,
        fontSize: 14,
        gap: 10,
      ),
      AppButtonSize.lg => const _ButtonMetrics(
        height: 60,
        padding: 24,
        iconSize: 20,
        loaderSize: 26,
        fontSize: 15,
        gap: 12,
      ),
    };
  }

  final double height;
  final double padding;
  final double iconSize;
  final double loaderSize;
  final double fontSize;
  final double gap;
}

class _ButtonPalette {
  const _ButtonPalette({
    required this.gradient,
    required this.foreground,
    required this.borderColor,
    required this.glowColor,
  });

  factory _ButtonPalette.fromVariant(
    AppButtonVariant variant, {
    required bool enabled,
  }) {
    final disabledAlpha = enabled ? 1.0 : 0.62;

    return switch (variant) {
      AppButtonVariant.primary => _ButtonPalette(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: disabledAlpha),
            const Color(0xFFA79D7B).withValues(alpha: disabledAlpha),
          ],
        ),
        foreground: AppColors.background,
        borderColor: Colors.white.withValues(alpha: 0.22),
        glowColor: const Color(0xFF31506E).withValues(alpha: 0.46),
      ),
      AppButtonVariant.secondary => _ButtonPalette(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceElevated.withValues(alpha: disabledAlpha),
            const Color(0xFF111923).withValues(alpha: disabledAlpha),
          ],
        ),
        foreground: AppColors.textPrimary,
        borderColor: AppColors.primary.withValues(alpha: 0.26),
        glowColor: const Color(0xFF31506E).withValues(alpha: 0.34),
      ),
      AppButtonVariant.ghost => _ButtonPalette(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: enabled ? 0.07 : 0.03),
            Colors.white.withValues(alpha: enabled ? 0.025 : 0.015),
          ],
        ),
        foreground: AppColors.textSecondary,
        borderColor: Colors.white.withValues(alpha: 0.10),
        glowColor: Colors.transparent,
      ),
    };
  }

  final Gradient gradient;
  final Color foreground;
  final Color borderColor;
  final Color glowColor;
}
