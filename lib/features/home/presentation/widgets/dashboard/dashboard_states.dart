import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../../core/theme/app_colors.dart';

class DashboardRefreshErrorBanner extends StatelessWidget {
  const DashboardRefreshErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$message Showing the last loaded analytics.',
        style: const TextStyle(
          fontSize: 9,
          height: 1.45,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class DashboardError extends StatelessWidget {
  const DashboardError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedDashboardSquare02,
              size: 30,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 14),
            const Text(
              'Analytics unavailable',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _DashboardSkeletonBlock(width: 86, height: 10),
        const SizedBox(height: 10),
        const _DashboardSkeletonBlock(width: 220, height: 30),
        const SizedBox(height: 8),
        const _DashboardSkeletonBlock(width: 150, height: 11),
        const SizedBox(height: 22),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Row(
            children: [
              for (var index = 0; index < 4; index++) ...[
                if (index > 0) const SizedBox(width: 8),
                const _DashboardSkeletonBlock(
                  width: 74,
                  height: 34,
                  radius: 999,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        const _DashboardSkeletonBlock(
          width: double.infinity,
          height: 286,
          radius: 28,
        ),
        const SizedBox(height: 16),
        const _DashboardSkeletonBlock(
          width: double.infinity,
          height: 180,
          radius: 24,
        ),
        const SizedBox(height: 16),
        const _DashboardSkeletonBlock(
          width: double.infinity,
          height: 220,
          radius: 24,
        ),
        const SizedBox(height: 16),
        const _DashboardSkeletonBlock(
          width: double.infinity,
          height: 180,
          radius: 24,
        ),
      ],
    );
  }
}

class _DashboardSkeletonBlock extends StatelessWidget {
  const _DashboardSkeletonBlock({
    required this.width,
    required this.height,
    this.radius = 10,
  });

  final double width;

  final double height;

  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
