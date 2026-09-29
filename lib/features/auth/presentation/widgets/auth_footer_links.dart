import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_toast.dart';

class AuthFooterLinks extends StatelessWidget {
  const AuthFooterLinks({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _AuthFooterLink(
          label: 'T&T',
          onTap: () => _showPlaceholder(context, 'Terms & Conditions'),
        ),
        const SizedBox(width: 12),
        _AuthFooterLink(
          label: 'Privacy Policy',
          onTap: () => _showPlaceholder(context, 'Privacy Policy'),
        ),
        const SizedBox(width: 12),
        _AuthFooterLink(
          label: 'Contact Us',
          onTap: () => _showPlaceholder(context, 'Contact Us'),
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

class _AuthFooterLink extends StatelessWidget {
  const _AuthFooterLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
