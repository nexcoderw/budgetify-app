import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

class HistoryPageSkeleton extends StatelessWidget {
  const HistoryPageSkeleton({
    super.key,
    required this.compact,
    required this.showSmsCard,
  });

  final bool compact;

  final bool showSmsCard;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SkeletonBox(width: 92, height: 10),
                      const SizedBox(height: 10),
                      _SkeletonBox(
                        width: compact ? 176 : 218,
                        height: compact ? 27 : 32,
                      ),
                      const SizedBox(height: 8),
                      const _SkeletonBox(width: 260, height: 12),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const _SkeletonBox(width: 46, height: 46, radius: 16),
              ],
            ),
            if (showSmsCard) ...[
              SizedBox(height: compact ? 16 : 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    _SkeletonBox(width: 42, height: 42, radius: 14),
                    SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SkeletonBox(width: 170, height: 12),
                          SizedBox(height: 8),
                          _SkeletonBox(width: double.infinity, height: 9),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: compact ? 22 : 28),
            const _SkeletonBox(width: double.infinity, height: 56, radius: 999),
            const SizedBox(height: 16),
            const Row(
              children: [
                _SkeletonBox(width: 48, height: 36, radius: 999),
                SizedBox(width: 7),
                _SkeletonBox(width: 58, height: 36, radius: 999),
                SizedBox(width: 7),
                _SkeletonBox(width: 82, height: 36, radius: 999),
              ],
            ),
            const SizedBox(height: 10),
            const Row(
              children: [
                _SkeletonBox(width: 90, height: 36, radius: 999),
                SizedBox(width: 7),
                _SkeletonBox(width: 72, height: 36, radius: 999),
                SizedBox(width: 7),
                _SkeletonBox(width: 88, height: 36, radius: 999),
              ],
            ),
            SizedBox(height: compact ? 22 : 28),
            const Row(
              children: [
                _SkeletonBox(width: 122, height: 18),
                Spacer(),
                _SkeletonBox(width: 50, height: 11),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(compact ? 22 : 26),
              ),
              child: const Column(
                children: [
                  _HistoryTileSkeleton(),
                  SizedBox(height: 18),
                  _HistoryTileSkeleton(),
                  SizedBox(height: 18),
                  _HistoryTileSkeleton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTileSkeleton extends StatelessWidget {
  const _HistoryTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _SkeletonBox(width: 44, height: 44, radius: 15),
        SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SkeletonBox(width: 135, height: 12),
              SizedBox(height: 7),
              _SkeletonBox(width: 180, height: 9),
              SizedBox(height: 7),
              _SkeletonBox(width: 58, height: 8),
            ],
          ),
        ),
        SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _SkeletonBox(width: 72, height: 13),
            SizedBox(height: 8),
            _SkeletonBox(width: 64, height: 20, radius: 999),
          ],
        ),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.width,
    required this.height,
    this.radius = 6,
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
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
