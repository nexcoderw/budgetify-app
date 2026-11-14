import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/app_dropdown.dart';
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Overview',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            IconButton(
              tooltip: isLoading ? 'Refreshing overview' : 'Refresh overview',
              onPressed: isLoading ? null : onRefresh,
              icon: isLoading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : const Icon(
                      Icons.refresh_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppDropdown<TransactionAnalyticsPeriodPreset>(
              tooltip: 'Choose overview period',
              label: selectedPeriod.label,
              isActive: true,
              onSelected: onPeriodSelected,
              items: [
                for (final period in const [
                  TransactionAnalyticsPeriodPreset.thisMonth,
                  TransactionAnalyticsPeriodPreset.sevenDays,
                  TransactionAnalyticsPeriodPreset.thirtyDays,
                  TransactionAnalyticsPeriodPreset.thisYear,
                ])
                  AppDropdownItem(
                    value: period,
                    label: period.label,
                    selected: selectedPeriod == period,
                  ),
              ],
            ),
            Text(
              formatDashboardPeriodRange(period),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
