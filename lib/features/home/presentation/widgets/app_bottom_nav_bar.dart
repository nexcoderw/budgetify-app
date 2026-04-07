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
        final isPhoneNav = maxWidth < 560;
        final isComfortable = maxWidth >= 900;

        Widget buildAnimatedItem(
          AppNavDestination destination, {
          bool expand = false,
          bool compact = false,
          bool showSelectedLabel = true,
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
              compact: compact,
              showSelectedLabel: showSelectedLabel,
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
                          compact: true,
                          showSelectedLabel: false,
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
                        compact: false,
                        showSelectedLabel: true,
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
    required this.compact,
    required this.showSelectedLabel,
    required this.onTap,
  });

  final AppNavDestination destination;
  final bool isSelected;
  final bool compact;
  final bool showSelectedLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = AnimatedScale(
      scale: isSelected ? 1.12 : 1.0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      child: HugeIcon(
        icon: destination.icon,
        size: compact ? 18 : 19,
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
          minHeight: compact ? 54 : 50,
          minWidth: compact ? 0 : 48,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 0 : (isSelected ? 16 : 13),
          vertical: compact ? 10 : 13,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(compact ? 20 : 26),
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
        child: compact
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(height: 7),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    width: isSelected ? 18 : 6,
                    height: 3,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: isSelected
                          ? AppColors.primary
                          : Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: isSelected && showSelectedLabel
                        ? Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: AnimatedOpacity(
                              opacity: 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Text(
                                destination.label,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
      ),
    );
  }
}
