import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_toast.dart';

class AuthFooterLinks extends StatelessWidget {
  const AuthFooterLinks({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        _FooterLink(
          label: 'Terms & Conditions',
          onTap: () => _showPlaceholder(context, 'Terms & Conditions'),
          style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
        ),
        const Text('•', style: TextStyle(color: AppColors.textPrimary)),
        _FooterLink(
          label: 'Privacy Policy',
          onTap: () => _showPlaceholder(context, 'Privacy Policy'),
          style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
        ),
        const Text('•', style: TextStyle(color: AppColors.textPrimary)),
        _FooterLink(
          label: 'Contact Us',
          onTap: () => _showPlaceholder(context, 'Contact Us'),
          style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
        ),
      ],
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

class _FooterLink extends StatelessWidget {
  const _FooterLink({
    required this.label,
    required this.onTap,
    required this.style,
  });

  final String label;
  final VoidCallback onTap;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      child: Text(label, style: style),
    );
  }
}
