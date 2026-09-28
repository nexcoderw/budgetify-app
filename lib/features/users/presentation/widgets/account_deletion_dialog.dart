import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_modal_dialog.dart';

Future<bool?> showAccountDeletionDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AppModalDialog(
        maxWidth: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _DangerIcon(),
                const Spacer(),
                AppModalCloseButton(
                  onTap: () => Navigator.of(dialogContext).pop(false),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Text(
              'Delete your account?',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                height: 1.15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your account will be scheduled for deletion in 30 days. '
              'Signing in again during that period will cancel the request.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: AppModalActionButton(
                    label: 'Keep account',
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppModalActionButton(
                    label: 'Delete account',
                    isPrimary: true,
                    primaryColor: AppColors.danger,
                    primaryForegroundColor: AppColors.textPrimary,
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

class _DangerIcon extends StatelessWidget {
  const _DangerIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.danger.withValues(alpha: 0.12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.26)),
      ),
      child: const Center(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedAlertCircle,
          size: 21,
          color: AppColors.danger,
          strokeWidth: 1.9,
        ),
      ),
    );
  }
}
