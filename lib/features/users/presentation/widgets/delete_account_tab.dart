import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';

class DeleteAccountTab extends StatelessWidget {
  const DeleteAccountTab({
    super.key,
    required this.scheduledFor,
    required this.enabled,
    required this.isDeleting,
    required this.onDelete,
  });

  final DateTime? scheduledFor;
  final bool enabled;
  final bool isDeleting;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isScheduled = scheduledFor != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _DeleteIcon(),
          const SizedBox(height: 20),
          const Text(
            'Delete your account',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              height: 1.15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isScheduled
                ? 'Your deletion request is already scheduled. Signing in '
                    'again during the grace period will cancel it.'
                : 'Your account will remain recoverable for 30 days. After '
                    'that grace period, it will be permanently deleted.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: 240,
              child: AppButton(
                label: isScheduled
                    ? 'Deletion scheduled'
                    : 'Delete my account',
                icon: HugeIcons.strokeRoundedDelete02,
                variant: AppButtonVariant.ghost,
                isLoading: isDeleting,
                onPressed: enabled && !isScheduled ? onDelete : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteIcon extends StatelessWidget {
  const _DeleteIcon();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.danger.withValues(alpha: 0.12),
        ),
        child: const Center(
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedDelete02,
            size: 22,
            color: AppColors.danger,
            strokeWidth: 1.9,
          ),
        ),
      ),
    );
  }
}
