import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/glass_panel.dart';
import '../../../data/models/transaction_analytics_models.dart';
import 'dashboard_formatters.dart';

class DashboardSummarySection extends StatelessWidget {
  const DashboardSummarySection({super.key, required this.analytics});

  final TransactionAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final summary = analytics.summary;
    final comparison = analytics.comparison;

    return GlassPanel(
      blur: 22,
      opacity: 0.07,
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 900
              ? 5
              : constraints.maxWidth >= 720
              ? 4
              : 2;

          const gap = 10.0;

          final width =
              (constraints.maxWidth - (gap * (columns - 1))) / columns;

          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              SizedBox(
                width: width,
                child: _DashboardSummaryMetric(
                  label: 'Received',
                  value:
                      '${formatDashboardAmount(summary.receivedAmount)} '
                      '${analytics.currency}',
                  icon: HugeIcons.strokeRoundedMoneyReceiveCircle,
                  comparisonText: formatDashboardComparison(
                    comparison.receivedAmountChangePercentage,
                  ),
                ),
              ),
              SizedBox(
                width: width,
                child: _DashboardSummaryMetric(
                  label: 'Sent',
                  value:
                      '${formatDashboardAmount(summary.sentAmount)} '
                      '${analytics.currency}',
                  icon: HugeIcons.strokeRoundedMoneySendSquare,
                  comparisonText: formatDashboardComparison(
                    comparison.sentAmountChangePercentage,
                  ),
                ),
              ),
              SizedBox(
                width: width,
                child: _DashboardSummaryMetric(
                  label: 'Fees',
                  value:
                      '${formatDashboardAmount(summary.feesPaid)} '
                      '${analytics.currency}',
                  icon: HugeIcons.strokeRoundedWallet02,
                  comparisonText: formatDashboardComparison(
                    comparison.feesPaidChangePercentage,
                  ),
                ),
              ),
              SizedBox(
                width: width,
                child: _DashboardSummaryMetric(
                  label: 'Money out',
                  value:
                      '${formatDashboardAmount(summary.totalDebited)} '
                      '${analytics.currency}',
                  icon: HugeIcons.strokeRoundedMoneySendSquare,
                  comparisonText: formatDashboardComparison(
                    comparison.totalDebitedChangePercentage,
                  ),
                ),
              ),
              SizedBox(
                width: width,
                child: _DashboardSummaryMetric(
                  label: 'Net movement',
                  value:
                      '${formatDashboardSignedAmount(summary.netCashMovement)} '
                      '${analytics.currency}',
                  icon: HugeIcons.strokeRoundedTransactionHistory,
                  comparisonText: formatDashboardNetComparison(
                    comparison.netCashMovementChange,
                    analytics.currency,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardSummaryMetric extends StatelessWidget {
  const _DashboardSummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.comparisonText,
  });

  final String label;

  final String value;

  final List<List<dynamic>> icon;

  final String comparisonText;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 126),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.055)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: HugeIcon(
                  icon: icon,
                  size: 16,
                  strokeWidth: 1.8,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.35,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            comparisonText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 8,
              height: 1.3,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
