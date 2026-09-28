import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';

class ProfileTopBar extends StatelessWidget {
  const ProfileTopBar({
    super.key,
    required this.isLoggingOut,
    required this.onBack,
    required this.onLogout,
  });

  final bool isLoggingOut;
  final VoidCallback onBack;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TopBarAction(
          tooltip: 'Back',
          icon: HugeIcons.strokeRoundedArrowLeft01,
          onPressed: onBack,
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.7,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Manage your personal details',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        _TopBarAction(
          tooltip: 'Log out',
          icon: HugeIcons.strokeRoundedPower,
          color: AppColors.danger,
          isLoading: isLoggingOut,
          onPressed: onLogout,
        ),
      ],
    );
  }
}

class _TopBarAction extends StatelessWidget {
  const _TopBarAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color = AppColors.textPrimary,
    this.isLoading = false,
  });

  final String tooltip;
  final dynamic icon;
  final VoidCallback? onPressed;
  final Color color;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null && !isLoading,
      label: isLoading ? '$tooltip, loading' : tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: isLoading ? null : onPressed,
            customBorder: const CircleBorder(),
            child: Ink(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: isLoading
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: color,
                        ),
                      )
                    : HugeIcon(
                        icon: icon,
                        size: 20,
                        color: color,
                        strokeWidth: 1.9,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
