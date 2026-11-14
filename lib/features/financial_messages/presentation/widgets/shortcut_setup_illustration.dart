import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Illustrative setup screens with fictional data, never live credentials.
class ShortcutSetupIllustration extends StatelessWidget {
  const ShortcutSetupIllustration({
    super.key,
    required this.stage,
    required this.provider,
  });

  final int stage;
  final String provider;

  @override
  Widget build(BuildContext context) {
    final (title, icon, lines) = switch (stage) {
      0 => (
        'Apple Shortcuts',
        Icons.bolt_rounded,
        ['Ingengo payment import', 'Add Shortcut'],
      ),
      1 => (
        'Connect to Ingengo',
        Icons.lock_outline_rounded,
        ['Private key: ••••••••', 'Import address: paste from Ingengo'],
      ),
      2 => (
        'When a message arrives',
        Icons.sms_outlined,
        ['From: your $provider sender', 'Run: Ingengo payment import'],
      ),
      _ => (
        'Payment messages',
        Icons.mark_email_read_outlined,
        [
          'Example SMS from $provider',
          'You received 5,000 RWF from Alex.',
          'To review → Confirm or dismiss',
        ],
      ),
    };

    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 260);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.surfaceElevated, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'ILLUSTRATED EXAMPLE',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: duration,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.08),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Column(
                  key: ValueKey((stage, provider)),
                  children: [
                    Icon(icon, color: AppColors.primary, size: 32),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final line in lines)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          line,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, height: 1.4),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Your iPhone may look a little different.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
