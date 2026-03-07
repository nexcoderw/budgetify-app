import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/data/models/auth_user.dart';
import '../widgets/section_elements.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.user,
    required this.isLoggingOut,
    required this.onLogout,
  });

  final AuthUser user;
  final bool isLoggingOut;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 760;

    return SectionPanel(
      badgeLabel: 'Account profile',
      badgeIcon: HugeIcons.strokeRoundedUserCircle,
      title: user.fullName ?? 'Budgetify user',
      description:
          'Review the signed-in account, verification status, and current session information.',
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            CircleAvatar(
              radius: isCompact ? 26 : 30,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              backgroundImage: user.avatarUrl == null
                  ? null
                  : NetworkImage(user.avatarUrl!),
              child: user.avatarUrl == null
                  ? const HugeIcon(
                      icon: HugeIcons.strokeRoundedUserCircle,
                      size: 22,
                      color: AppColors.textPrimary,
                      strokeWidth: 1.8,
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.email,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.status,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SectionMetricChip(
              icon: HugeIcons.strokeRoundedCheckmarkBadge02,
              label: 'Account status',
              value: user.status,
            ),
            SectionMetricChip(
              icon: HugeIcons.strokeRoundedShield01,
              label: 'Email verification',
              value: user.isEmailVerified ? 'Verified' : 'Pending',
            ),
            SectionMetricChip(
              icon: HugeIcons.strokeRoundedClock01,
              label: 'Last activity',
              value: user.lastLoginAt == null ? 'Unavailable' : 'Recorded',
            ),
          ],
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            height: 46,
            child: OutlinedButton(
              onPressed: onLogout,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                backgroundColor: Colors.white.withValues(alpha: 0.04),
                shape: const StadiumBorder(),
              ),
              child: Text(
                isLoggingOut ? 'Signing out...' : 'Logout',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
