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
    return Semantics(
      label: 'Loading overview',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: _DashboardSkeletonBlock(width: 100, height: 22),
            ),
            const SizedBox(height: 16),
            const Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _DashboardSkeletonBlock(width: 120, height: 44, radius: 999),
                _DashboardSkeletonBlock(width: 160, height: 11),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                const card = _DashboardSkeletonBlock(width: double.infinity, height: 126, radius: 22);
                if (constraints.maxWidth < 300 ||
                    MediaQuery.textScalerOf(context).scale(12) > 18) {
                  return const Column(children: [card, SizedBox(height: 12), card]);
                }
                return const Row(
                  children: [Expanded(child: card), SizedBox(width: 12), Expanded(child: card)],
                );
              },
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: _DashboardSkeletonBlock(width: 150, height: 11),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                const categories = _DashboardSkeletonBlock(width: double.infinity, height: 230, radius: 22);
                const methods = _DashboardSkeletonBlock(width: double.infinity, height: 310, radius: 22);
                if (constraints.maxWidth < 720) {
                  return const Column(children: [categories, SizedBox(height: 16), methods]);
                }
                return const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Expanded(child: categories), SizedBox(width: 16), Expanded(child: methods)],
                );
              },
            ),
          ],
        ),
      ),
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
