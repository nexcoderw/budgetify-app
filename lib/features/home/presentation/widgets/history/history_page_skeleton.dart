import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';

class HistoryPageSkeleton extends StatelessWidget {
  const HistoryPageSkeleton({
    super.key,
    required this.compact,
    this.insights = false,
  });

  final bool compact;
  final bool insights;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: insights ? 'Loading category insights' : 'Loading transactions',
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: insights
                ? [
                    const Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 12,
                      children: [
                        _SkeletonBox(width: 90, height: 32, radius: 999),
                        _SkeletonBox(width: 84, height: 32, radius: 999),
                        _SkeletonBox(width: 90, height: 32, radius: 999),
                        _SkeletonBox(width: 80, height: 32, radius: 999),
                        _SkeletonBox(width: 72, height: 32, radius: 999),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.center,
                      child: _SkeletonBox(width: 180, height: 12),
                    ),
                    const SizedBox(height: 6),
                    const Align(
                      alignment: Alignment.center,
                      child: _SkeletonBox(width: 220, height: 10),
                    ),
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.center,
                      child: _SkeletonBox(width: 170, height: 28),
                    ),
                    const SizedBox(height: 28),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: AspectRatio(
                          aspectRatio: 1.8,
                          child: const ClipOval(
                            child: ColoredBox(color: AppColors.surfaceElevated),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    for (var index = 0; index < 4; index++) ...[
                      const _HistoryTileSkeleton(insights: true),
                      const SizedBox(height: 18),
                    ],
                  ]
                : [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: _SkeletonBox(width: 130, height: 18),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(compact ? 14 : 20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        children: [
                          for (var index = 0; index < 4; index++) ...[
                            if (index > 0) const SizedBox(height: 20),
                            const _HistoryTileSkeleton(),
                          ],
                        ],
                      ),
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}

class _HistoryTileSkeleton extends StatelessWidget {
  const _HistoryTileSkeleton({this.insights = false});
  final bool insights;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SkeletonBox(
          width: insights ? 10 : 42,
          height: insights ? 10 : 42,
          radius: insights ? 999 : 14,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SkeletonBox(width: double.infinity, height: 12),
              if (!insights) ...[
                const SizedBox(height: 8),
                const FractionallySizedBox(
                  widthFactor: 0.7,
                  alignment: Alignment.centerLeft,
                  child: _SkeletonBox(width: double.infinity, height: 9),
                ),
                const SizedBox(height: 8),
                const FractionallySizedBox(
                  widthFactor: 0.5,
                  alignment: Alignment.centerLeft,
                  child: _SkeletonBox(width: double.infinity, height: 9),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 20),
        const _SkeletonBox(width: 66, height: 12),
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
