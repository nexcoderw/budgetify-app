import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../auth/data/models/auth_user.dart';

class AppNavbar extends StatelessWidget {
  const AppNavbar({super.key, required this.user, required this.onProfileTap});

  final AuthUser user;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 760;

    return GlassPanel(
      borderRadius: BorderRadius.circular(28),
      blur: 24,
      opacity: 0.12,
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 14 : 18,
        vertical: isCompact ? 14 : 16,
      ),
      child: Row(
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GlassPanel(
                  padding: const EdgeInsets.all(8),
                  blur: 18,
                  opacity: 0.1,
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset(
                    'assets/branding/logo_color.png',
                    width: 26,
                    height: 26,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Budgetify',
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: isCompact ? 22 : 24,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Clear financial tracking for everyday decisions.',
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _UserIdentity(user: user, onTap: onProfileTap),
        ],
      ),
    );
  }
}

class _UserIdentity extends StatelessWidget {
  const _UserIdentity({required this.user, required this.onTap});

  final AuthUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 560;
    final firstName = _resolveFirstName();
    final lastInitial = _resolveLastInitial();
    final displayName = lastInitial == null
        ? firstName
        : '$firstName $lastInitial.';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: GlassBadge(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 10 : 12,
          vertical: 8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              backgroundImage: user.avatarUrl == null
                  ? null
                  : NetworkImage(user.avatarUrl!),
              child: user.avatarUrl == null
                  ? const HugeIcon(
                      icon: HugeIcons.strokeRoundedUserCircle,
                      size: 16,
                      color: AppColors.textPrimary,
                      strokeWidth: 1.7,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isCompact ? 90 : 150),
              child: Text(
                displayName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolveFirstName() {
    final firstName = user.firstName?.trim();
    if (firstName != null && firstName.isNotEmpty) {
      return firstName;
    }

    final fullName = user.fullName?.trim();
    if (fullName != null && fullName.isNotEmpty) {
      return fullName.split(RegExp(r'\s+')).first;
    }

    return user.email.split('@').first;
  }

  String? _resolveLastInitial() {
    final lastName = user.lastName?.trim();
    if (lastName != null && lastName.isNotEmpty) {
      return lastName.substring(0, 1).toUpperCase();
    }

    final fullName = user.fullName?.trim();
    if (fullName == null || fullName.isEmpty) {
      return null;
    }

    final parts = fullName.split(RegExp(r'\s+'));
    if (parts.length < 2 || parts.last.isEmpty) {
      return null;
    }

    return parts.last.substring(0, 1).toUpperCase();
  }
}
