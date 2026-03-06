import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

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
        ),
        const Text('•', style: TextStyle(color: AppColors.textSecondary)),
        _FooterLink(
          label: 'Privacy Policy',
          onTap: () => _showPlaceholder(context, 'Privacy Policy'),
        ),
        const Text('•', style: TextStyle(color: AppColors.textSecondary)),
        _FooterLink(
          label: 'Contact Us',
          onTap: () => _showPlaceholder(context, 'Contact Us'),
        ),
      ],
    );
  }

  void _showPlaceholder(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$label content can be connected once those pages are ready.',
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(onPressed: onTap, child: Text(label));
  }
}
