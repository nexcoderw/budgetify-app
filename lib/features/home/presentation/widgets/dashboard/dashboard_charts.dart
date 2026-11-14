import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../data/models/transaction_analytics_models.dart';
import 'dashboard_formatters.dart';

class DashboardCharts extends StatelessWidget {
  const DashboardCharts({super.key, required this.analytics});

  final TransactionAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final categories =
        analytics.categories
            .where((item) => item.totalDebited > 0 && item.transactions > 0)
            .toList()
          ..sort((a, b) => b.totalDebited.compareTo(a.totalDebited));
    final methods =
        analytics.transferTypes.where((item) => item.transactions > 0).toList()
          ..sort((a, b) => b.transactions.compareTo(a.transactions));
    final categoryTotal = categories.fold<int>(
      0,
      (sum, item) => sum + item.totalDebited,
    );
    final count = methods.fold<int>(0, (sum, item) => sum + item.transactions);
    final categoryChart = _ChartCard(
      title: 'Where money went',
      subtitle: 'Outgoing payments, including fees',
      child: categories.isEmpty
          ? const _EmptyChart('No completed outgoing payments in this period.')
          : Column(
              children: [
                for (var index = 0; index < categories.length; index++) ...[
                  if (index > 0) const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          categories[index].category.label,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          '${formatDashboardAmount(categories[index].totalDebited)} ${analytics.currency}',
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    label:
                        '${categories[index].category.label}: ${formatDashboardPercentage(categories[index].totalDebited / categoryTotal * 100)} of spending',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: categories[index].totalDebited / categoryTotal,
                        minHeight: 7,
                        color: AppColors.primary,
                        backgroundColor: AppColors.surfaceElevated,
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
    final methodsChart = _ChartCard(
      title: 'Payment methods',
      subtitle: 'Completed outgoing transfers',
      child: methods.isEmpty
          ? const _EmptyChart(
              'Payment methods appear after a completed transfer.',
            )
          : Column(
              children: [
                Center(
                  child: SizedBox.square(
                    dimension: 140,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: ExcludeSemantics(
                            child: CustomPaint(
                              painter: _MethodDonutPainter(
                                counts: methods
                                    .map((item) => item.transactions)
                                    .toList(),
                                colors: methods
                                    .map(
                                      (item) =>
                                          _methodColor(item.transferType.index),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$count',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Text(
                              'transfers',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                for (final method in methods)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: _methodColor(method.transferType.index),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            method.transferType.label,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '${method.transactions} · ${formatDashboardPercentage(method.transactions / count * 100)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [categoryChart, const SizedBox(height: 16), methodsChart],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: categoryChart),
            const SizedBox(width: 16),
            Expanded(child: methodsChart),
          ],
        );
      },
    );
  }
}

Color _methodColor(int index) =>
    const [AppColors.primary, Color(0xFF7CAFA5), Color(0xFF819AC0)][index % 3];

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 10,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        child,
      ],
    ),
  );
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 11,
        height: 1.5,
        color: AppColors.textSecondary,
      ),
    ),
  );
}

class _MethodDonutPainter extends CustomPainter {
  const _MethodDonutPainter({required this.counts, required this.colors});
  final List<int> counts;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = counts.fold<int>(0, (sum, count) => sum + count);
    if (total <= 0) return;
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.width - 20,
      height: size.height - 20,
    );
    var angle = -math.pi / 2;
    for (var index = 0; index < counts.length; index++) {
      final sweep = counts[index] / total * math.pi * 2;
      canvas.drawArc(
        rect,
        angle,
        sweep,
        false,
        Paint()
          ..color = colors[index]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14,
      );
      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _MethodDonutPainter oldDelegate) =>
      oldDelegate.counts.toString() != counts.toString() ||
      oldDelegate.colors.toString() != colors.toString();
}
