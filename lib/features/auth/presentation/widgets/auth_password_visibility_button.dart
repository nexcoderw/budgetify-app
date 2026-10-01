import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';

class AuthPasswordVisibilityButton extends StatelessWidget {
  const AuthPasswordVisibilityButton({
    super.key,
    required this.isObscured,
    required this.onPressed,
  });

  final bool isObscured;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: isObscured ? 'Show password' : 'Hide password',
      icon: HugeIcon(
        icon: isObscured
            ? HugeIcons.strokeRoundedView
            : HugeIcons.strokeRoundedViewOff,
        size: 18,
        color: AppColors.textSecondary,
        strokeWidth: 1.8,
      ),
    );
  }
}
