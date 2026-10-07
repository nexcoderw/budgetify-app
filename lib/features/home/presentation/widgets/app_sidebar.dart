import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/data/models/auth_user.dart';
import 'app_layout_section.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.user,
    required this.currentSection,
    required this.onSectionSelected,
    required this.onProfileTap,
    required this.onClose,
  });

  final AuthUser user;
  final AppLayoutSection currentSection;
  final ValueChanged<AppLayoutSection> onSectionSelected;
  final VoidCallback onProfileTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final shortcuts = bottomAppNavDestinations.where(
      (destination) => !defaultAppNavDestinations.any(
        (item) => item.section == destination.section,
      ),
    );

    return Drawer(
      width: math.min(320.0, MediaQuery.sizeOf(context).width * 0.86),
      semanticLabel: 'Navigation menu',
      backgroundColor: AppColors.backgroundSecondary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 12, 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Budgetify',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close menu',
                    onPressed: onClose,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final destination in defaultAppNavDestinations)
                    _destination(destination),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Divider(height: 1, color: AppColors.border),
                  ),
                  for (final destination in shortcuts)
                    _destination(destination),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
              child: ListTile(
                onTap: onProfileTap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: const Icon(
                  Icons.account_circle_outlined,
                  color: AppColors.primary,
                  size: 26,
                ),
                title: const Text(
                  'My profile',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _destination(AppNavDestination destination) {
    final selected = currentSection == destination.section;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        selected: selected,
        child: ListTile(
          selected: selected,
          selectedTileColor: AppColors.surfaceElevated,
          minTileHeight: 56,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          leading: HugeIcon(
            icon: destination.icon,
            size: 22,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
          title: Text(
            destination.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
          trailing: selected
              ? const Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: AppColors.primary,
                )
              : null,
          onTap: () => onSectionSelected(destination.section),
        ),
      ),
    );
  }
}
