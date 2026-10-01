import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/app_button.dart';

class ContactsPermissionPrompt extends StatelessWidget {
  const ContactsPermissionPrompt({
    super.key,
    required this.onAllow,
  });

  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.contacts_outlined,
                size: 34,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Find people faster',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                height: 1.15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: const Text(
                'Allow Budgetify to show names and phone numbers from your device. Choose full contact access when your phone asks.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.55,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.035),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 16,
                    color: AppColors.success,
                  ),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Contacts stay on your device',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: AppButton(
                label: 'Allow contacts',
                iconWidget: const Icon(
                  Icons.contacts_outlined,
                  color: AppColors.background,
                ),
                size: AppButtonSize.md,
                onPressed: onAllow,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ContactsUnavailable extends StatelessWidget {
  const ContactsUnavailable({
    super.key,
    required this.onRetry,
  });

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceElevated,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.contact_page_outlined,
                size: 29,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Contacts are unavailable',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: const Text(
                'Try contact access again, or enter a phone number, bank account, or MoMo code above.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: AppButton(
                label: 'Try again',
                iconWidget: const Icon(
                  Icons.refresh_rounded,
                  color: AppColors.background,
                ),
                size: AppButtonSize.sm,
                onPressed: onRetry,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoadingContacts extends StatelessWidget {
  const LoadingContacts({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: 14),
          Text(
            'Loading contacts...',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class NoContactResults extends StatelessWidget {
  const NoContactResults({
    super.key,
    required this.isSearching,
    required this.onRefresh,
  });

  final bool isSearching;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.person_search_outlined,
            size: 30,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 10),
          Text(
            isSearching ? 'No recipient found' : 'No contacts available',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            isSearching
                ? 'Try another name, phone, account, or MoMo code.'
                : 'Allow full contact access, then refresh this list.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          if (!isSearching && onRefresh != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                onRefresh?.call();
              },
              icon: const Icon(
                Icons.refresh_rounded,
                size: 18,
              ),
              label: const Text('Refresh contacts'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: const Size(44, 44),
              ),
            ),
          ],
        ],
      ),
    );
  }
}