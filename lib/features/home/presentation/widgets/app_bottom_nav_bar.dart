import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_panel.dart';
import 'app_layout_section.dart';

class AppBottomNavBar extends StatefulWidget {
  const AppBottomNavBar({
    super.key,
    required this.currentSection,
    required this.destinations,
    required this.onSectionSelected,
  });

  final AppLayoutSection currentSection;
  final List<AppNavDestination> destinations;
  final ValueChanged<AppLayoutSection> onSectionSelected;

  @override
  State<AppBottomNavBar> createState() => _AppBottomNavBarState();
}

class _AppBottomNavBarState extends State<AppBottomNavBar>
    with TickerProviderStateMixin {
  final Map<AppLayoutSection, AnimationController> _pressControllers = {};

  @override
  void initState() {
    super.initState();
    for (final dest in widget.destinations) {
      _pressControllers[dest.section] = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 100),
        reverseDuration: const Duration(milliseconds: 500),
      );
    }
  }

  @override
  void dispose() {
    for (final ctrl in _pressControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _handleTap(AppLayoutSection section) {
    if (section == widget.currentSection) return;
    final ctrl = _pressControllers[section];
    if (ctrl != null) {
      ctrl.forward().then((_) => ctrl.animateBack(0, curve: Curves.elasticOut));
    }
    widget.onSectionSelected(section);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final isPhoneNav = maxWidth < 640;
        final isTinyPhone = maxWidth < 390;
        final isComfortable = maxWidth >= 900;

        Widget buildAnimatedItem(
          AppNavDestination destination, {
          bool expand = false,
          bool stacked = false,
          bool dense = false,
        }) {
          final isSelected = destination.section == widget.currentSection;
          final pressCtrl = _pressControllers[destination.section]!;

          final child = AnimatedBuilder(
            animation: pressCtrl,
            builder: (context, child) {
              final scale = 1.0 - pressCtrl.value * 0.07;
              return Transform.scale(scale: scale, child: child);
            },
            child: _NavItem(
              destination: destination,
              isSelected: isSelected,
              stacked: stacked,
              dense: dense,
              onTap: () => _handleTap(destination.section),
            ),
          );

          if (!expand) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: child,
            );
          }

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: child,
            ),
          );
        }

        final navContent = isPhoneNav
            ? SizedBox(
                width: double.infinity,
                child: Row(
                  children: widget.destinations
                      .map(
                        (destination) => buildAnimatedItem(
                          destination,
                          expand: true,
                          stacked: true,
                          dense: isTinyPhone,
                        ),
                      )
                      .toList(growable: false),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: widget.destinations
                    .map(
                      (destination) => buildAnimatedItem(
                        destination,
                        stacked: false,
                        dense: false,
                      ),
                    )
                    .toList(growable: false),
              );

        return GlassPanel(
          borderRadius: BorderRadius.circular(isPhoneNav ? 28 : 32),
          blur: 30,
          opacity: 0.10,
          padding: EdgeInsets.symmetric(
            horizontal: isPhoneNav ? 4 : (isComfortable ? 10 : 8),
            vertical: isPhoneNav ? 7 : 11,
          ),
          child: navContent,
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.isSelected,
    required this.stacked,
    required this.dense,
    required this.onTap,
  });

  final AppNavDestination destination;
  final bool isSelected;
  final bool stacked;
  final bool dense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconSize = stacked
        ? (dense ? 17.0 : 18.0)
        : (isSelected ? 19.0 : 18.0);
    final labelColor = isSelected
        ? AppColors.textPrimary
        : AppColors.textSecondary.withValues(alpha: stacked ? 0.88 : 0.8);

    final icon = AnimatedScale(
      scale: isSelected ? 1.12 : 1.0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      child: HugeIcon(
        icon: destination.icon,
        size: iconSize,
        color: isSelected
            ? AppColors.primary
            : AppColors.textSecondary.withValues(alpha: 0.8),
        strokeWidth: isSelected ? 1.6 : 1.9,
      ),
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        constraints: BoxConstraints(
          minHeight: stacked ? (dense ? 58 : 62) : 50,
          minWidth: stacked ? 0 : 52,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: stacked ? (dense ? 4 : 6) : (isSelected ? 16 : 13),
          vertical: stacked ? (dense ? 8 : 9) : 13,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(stacked ? 20 : 26),
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.17)
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.32)
                : Colors.transparent,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.22),
                    blurRadius: 16,
                    spreadRadius: -2,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: stacked
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  SizedBox(height: dense ? 5 : 6),
                  Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: dense ? 9 : 10,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: labelColor,
                      height: 1.1,
                      letterSpacing: dense ? -0.1 : 0,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(width: 8),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: labelColor,
                      letterSpacing: 0.1,
                    ),
                    child: Text(destination.label),
                  ),
                ],
              ),
      ),
    );
  }
}
