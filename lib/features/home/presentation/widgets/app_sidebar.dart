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
    return Drawer(
      width: math.min(300.0, MediaQuery.sizeOf(context).width * 0.86),
      semanticLabel: 'Navigation menu',
      backgroundColor: AppColors.backgroundSecondary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 24),
              child: Row(
                children: [
                  Image.asset(
                    'assets/branding/png/tight/logo-color-beige-512.png',
                    width: 30,
                    height: 30,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 26,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Budgetify',
                      style: TextStyle(
                        fontSize: 18,
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
                      size: 19,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                children: [
                  _sectionLabel('Overview'),
                  for (final destination in defaultAppNavDestinations.where(
                    (item) => item.section == AppLayoutSection.dashboard,
                  ))
                    _destination(destination),
                  const SizedBox(height: 20),
                  _sectionLabel('Money management'),
                  for (final destination in defaultAppNavDestinations.where(
                    (item) => item.section != AppLayoutSection.dashboard,
                  ))
                    _destination(destination),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              child: ListTile(
                onTap: onProfileTap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: const Icon(
                  Icons.account_circle_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
                title: const Text(
                  'My profile',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
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

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
    ),
  );

  Widget _destination(AppNavDestination destination) {
    final selected = currentSection == destination.section;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        selected: selected,
        child: ListTile(
          selected: selected,
          selectedTileColor: AppColors.primary.withValues(alpha: 0.1),
          minTileHeight: 48,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          leading: HugeIcon(
            icon: destination.icon,
            size: 20,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
          title: Text(
            destination.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
          trailing: selected
              ? const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: AppColors.primary,
                )
              : const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
          onTap: () => onSectionSelected(destination.section),
        ),
      ),
    );
  }
}
