import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../application/transaction_analytics_period.dart';
import '../../../data/models/transaction_analytics_models.dart';
import 'dashboard_formatters.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.selectedPeriod,
    required this.period,
    required this.isLoading,
    required this.onPeriodSelected,
    required this.onRefresh,
  });

  final TransactionAnalyticsPeriodPreset selectedPeriod;

  final TransactionAnalyticsPeriod period;

  final bool isLoading;

  final ValueChanged<TransactionAnalyticsPeriodPreset> onPeriodSelected;

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DASHBOARD',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 7),
                  Text(
                    'Your money activity',
                    style: TextStyle(
                      fontSize: 27,
                      height: 1.08,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: isLoading ? null : onRefresh,
              child: Text(isLoading ? 'Refreshing...' : 'Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          formatDashboardPeriodRange(period),
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              for (
                var index = 0;
                index < TransactionAnalyticsPeriodPreset.values.length;
                index++
              ) ...[
                if (index > 0) const SizedBox(width: 8),
                _DashboardPeriodChip(
                  period: TransactionAnalyticsPeriodPreset.values[index],
                  selected:
                      TransactionAnalyticsPeriodPreset.values[index] ==
                      selectedPeriod,
                  onTap: onPeriodSelected,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DashboardPeriodChip extends StatelessWidget {
  const _DashboardPeriodChip({
    required this.period,
    required this.selected,
    required this.onTap,
  });

  final TransactionAnalyticsPeriodPreset period;

  final bool selected;

  final ValueChanged<TransactionAnalyticsPeriodPreset> onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: period.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            onTap(period);
          },
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.16)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.32)
                    : AppColors.border,
              ),
            ),
            child: Text(
              period.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
