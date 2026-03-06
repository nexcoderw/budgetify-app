import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../auth/data/models/auth_user.dart';

class AppNavbar extends StatelessWidget {
  const AppNavbar({
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
          _UserMenu(user: user, isLoggingOut: isLoggingOut, onLogout: onLogout),
        ],
      ),
    );
  }
}

class _UserMenu extends StatelessWidget {
  const _UserMenu({
    required this.user,
    required this.isLoggingOut,
    required this.onLogout,
  });

  final AuthUser user;
  final bool isLoggingOut;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final displayName = user.fullName ?? user.email;
    final isCompact = MediaQuery.sizeOf(context).width < 560;

    return PopupMenuButton<_UserMenuAction>(
      tooltip: 'Account menu',
      offset: const Offset(0, 12),
      color: AppColors.surfaceElevated.withValues(alpha: 0.96),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      onSelected: (value) {
        if (value == _UserMenuAction.logout) {
          onLogout?.call();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<_UserMenuAction>(
          value: _UserMenuAction.logout,
          enabled: !isLoggingOut,
          child: Row(
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedLogout03,
                size: 18,
                color: AppColors.textPrimary,
                strokeWidth: 1.8,
              ),
              const SizedBox(width: 10),
              Text(
                isLoggingOut ? 'Signing out...' : 'Logout',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
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
            if (!isCompact) ...[
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 190),
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
              const SizedBox(width: 8),
            ] else
              const SizedBox(width: 6),
            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowDown01,
              size: 16,
              color: Colors.white.withValues(alpha: 0.72),
              strokeWidth: 1.9,
            ),
          ],
        ),
      ),
    );
  }
}

enum _UserMenuAction { logout }
