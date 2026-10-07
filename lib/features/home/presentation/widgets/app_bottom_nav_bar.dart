import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import 'app_layout_section.dart';

class AppBottomNavBar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Primary navigation',
      child: Center(
        child: Container(
          width: 260,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.surfaceElevated, AppColors.backgroundSecondary],
            ),
            border: Border.all(color: AppColors.border),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            child: Row(
              children: [
                for (final destination in destinations)
                  Expanded(
                    child: _NavigationItem(
                      destination: destination,
                      selected: currentSection == destination.section,
                      onTap: () {
                        if (currentSection != destination.section) {
                          onSectionSelected(destination.section);
                        }
                      },
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

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AppNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? AppColors.background
        : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: Tooltip(
        message: destination.label,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HugeIcon(
                    icon: destination.icon,
                    size: 19,
                    color: foreground,
                    strokeWidth: 1.8,
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
