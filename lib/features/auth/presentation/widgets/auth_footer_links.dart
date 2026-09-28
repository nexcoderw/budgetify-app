import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_toast.dart';

class AuthFooterLinks extends StatelessWidget {
  const AuthFooterLinks({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          AppButton(
            label: 'Terms & Conditions',
            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
            size: AppButtonSize.sm,
            variant: AppButtonVariant.ghost,
            fullWidth: false,
            onPressed: () => _showPlaceholder(context, 'Terms & Conditions'),
          ),
          AppButton(
            label: 'Privacy Policy',
            icon: HugeIcons.strokeRoundedUserCircle,
            size: AppButtonSize.sm,
            variant: AppButtonVariant.ghost,
            fullWidth: false,
            onPressed: () => _showPlaceholder(context, 'Privacy Policy'),
          ),
          AppButton(
            label: 'Contact Us',
            icon: HugeIcons.strokeRoundedMail01,
            size: AppButtonSize.sm,
            variant: AppButtonVariant.ghost,
            fullWidth: false,
            onPressed: () => _showPlaceholder(context, 'Contact Us'),
          ),
        ],
      ),
    );
  }

  void _showPlaceholder(BuildContext context, String label) {
    AppToast.info(
      context,
      title: label,
      description:
          '$label content can be connected once those pages are ready.',
    );
  }
}
