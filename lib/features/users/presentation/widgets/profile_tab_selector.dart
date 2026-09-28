import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';

enum ProfileTab { profile, deleteAccount }

class ProfileTabSelector extends StatelessWidget {
  const ProfileTabSelector({
    super.key,
    required this.selectedTab,
    required this.onSelected,
  });

  final ProfileTab selectedTab;
  final ValueChanged<ProfileTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ProfileTabButton(
              label: 'Profile',
              icon: HugeIcons.strokeRoundedUser02,
              isSelected: selectedTab == ProfileTab.profile,
              onPressed: () => onSelected(ProfileTab.profile),
            ),
          ),
          Expanded(
            child: _ProfileTabButton(
              label: 'Delete account',
              icon: HugeIcons.strokeRoundedDelete02,
              isSelected: selectedTab == ProfileTab.deleteAccount,
              isDanger: true,
              onPressed: () => onSelected(ProfileTab.deleteAccount),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTabButton extends StatelessWidget {
  const _ProfileTabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onPressed,
    this.isDanger = false,
  });

  final String label;
  final dynamic icon;
  final bool isSelected;
  final VoidCallback onPressed;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final selectedColor = isDanger ? AppColors.danger : AppColors.primary;
    final foregroundColor = isSelected
        ? selectedColor
        : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: 48,
            decoration: BoxDecoration(
              color: isSelected
                  ? selectedColor.withValues(alpha: 0.11)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                HugeIcon(
                  icon: icon,
                  size: 17,
                  color: foregroundColor,
                  strokeWidth: 1.9,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foregroundColor,
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
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
