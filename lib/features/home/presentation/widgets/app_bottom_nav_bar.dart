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
    final isCompact = MediaQuery.sizeOf(context).width < 900;

    return GlassPanel(
      borderRadius: BorderRadius.circular(32),
      blur: 30,
      opacity: 0.10,
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 6 : 8,
        vertical: isCompact ? 5 : 7,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: widget.destinations.map((destination) {
          final isSelected = destination.section == widget.currentSection;
          final pressCtrl = _pressControllers[destination.section]!;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: AnimatedBuilder(
              animation: pressCtrl,
              builder: (context, child) {
                final scale = 1.0 - pressCtrl.value * 0.07;
                return Transform.scale(scale: scale, child: child);
              },
              child: _NavItem(
                destination: destination,
                isSelected: isSelected,
                onTap: () => _handleTap(destination.section),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  final AppNavDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 13,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.12 : 1.0,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutBack,
              child: HugeIcon(
                icon: destination.icon,
                size: 19,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textSecondary.withValues(alpha: 0.8),
                strokeWidth: isSelected ? 1.6 : 1.9,
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: isSelected
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
