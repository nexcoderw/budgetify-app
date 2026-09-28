import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/data/models/auth_user.dart';

class AppNavbar extends StatelessWidget {
  const AppNavbar({
    super.key,
    required this.user,
    required this.onProfileTap,
    this.onMenuTap,
    this.onNotificationTap,
  });

  final AuthUser user;
  final VoidCallback onProfileTap;
  final VoidCallback? onMenuTap;
  final VoidCallback? onNotificationTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _NavbarAction(
          tooltip: 'Menu',
          icon: HugeIcons.strokeRoundedMenu01,
          onTap: onMenuTap,
        ),
        const Spacer(),
        _NavbarAction(
          tooltip: 'Notifications',
          icon: HugeIcons.strokeRoundedNotification02,
          onTap: onNotificationTap,
        ),
        const SizedBox(width: 10),
        _UserAvatar(user: user, onTap: onProfileTap),
      ],
    );
  }
}

class _NavbarAction extends StatelessWidget {
  const _NavbarAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final dynamic icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: const Color(0xFF111923).withValues(alpha: 0.9),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Center(
                child: HugeIcon(
                  icon: icon,
                  size: 21,
                  color: AppColors.textPrimary,
                  strokeWidth: 1.8,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.user, required this.onTap});

  final AuthUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user.avatarUrl?.trim();
    final initials = _resolveInitials();

    return Semantics(
      button: true,
      label: 'Open profile',
      child: Tooltip(
        message: 'Profile',
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Ink(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.18),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.42),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipOval(
                child: avatarUrl == null || avatarUrl.isEmpty
                    ? _InitialsAvatar(initials: initials)
                    : Image.network(
                        avatarUrl,
                        width: 46,
                        height: 46,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _InitialsAvatar(initials: initials),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _resolveInitials() {
    final firstName = user.firstName?.trim();
    final lastName = user.lastName?.trim();

    if (firstName != null && firstName.isNotEmpty) {
      final firstInitial = _firstCharacter(firstName);
      if (lastName != null && lastName.isNotEmpty) {
        return '$firstInitial${_firstCharacter(lastName)}'.toUpperCase();
      }
      return firstInitial.toUpperCase();
    }

    final fullName = user.fullName?.trim();
    if (fullName != null && fullName.isNotEmpty) {
      final parts = fullName
          .split(RegExp(r'\s+'))
          .where((part) => part.isNotEmpty)
          .toList(growable: false);
      if (parts.length > 1) {
        return '${_firstCharacter(parts.first)}${_firstCharacter(parts.last)}'
            .toUpperCase();
      }
      return _firstCharacter(parts.first).toUpperCase();
    }

    final emailName = user.email.split('@').first.trim();
    return emailName.isEmpty ? '?' : _firstCharacter(emailName).toUpperCase();
  }

  String _firstCharacter(String value) {
    return String.fromCharCode(value.runes.first);
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.primary.withValues(alpha: 0.12),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
