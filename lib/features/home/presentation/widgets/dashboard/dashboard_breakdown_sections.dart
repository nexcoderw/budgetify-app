import 'package:flutter/material.dart';

import '../../../data/models/transaction_analytics_models.dart';
import 'dashboard_section_card.dart';

class DashboardReceivedClassificationSection extends StatelessWidget {
  const DashboardReceivedClassificationSection({
    super.key,
    required this.classifications,
    required this.currency,
  });

  final List<ReceivedTransactionClassificationAnalytics> classifications;

  final String currency;

  @override
  Widget build(BuildContext context) {
    return DashboardSectionCard(
      title: 'Received money classification',
      subtitle: 'What completed incoming payments currently represent',
      child: classifications.isEmpty
          ? const DashboardEmptyBreakdown(
              message: 'No completed received payments in this period.',
            )
          : Column(
              children: [
                for (
                  var index = 0;
                  index < classifications.length;
                  index++
                ) ...[
                  if (index > 0) const SizedBox(height: 14),
                  DashboardBreakdownRow(
                    label: classifications[index].classification.label,
                    amount: classifications[index].receivedAmount,
                    currency: currency,
                    transactions: classifications[index].transactions,
                    percentage: classifications[index].percentage,
                  ),
                ],
              ],
            ),
    );
  }
}

class DashboardCategorySection extends StatelessWidget {
  const DashboardCategorySection({
    super.key,
    required this.categories,
    required this.currency,
  });

  final List<TransactionCategoryAnalytics> categories;

  final String currency;

  @override
  Widget build(BuildContext context) {
    return DashboardSectionCard(
      title: 'Outgoing spending by category',
      subtitle: 'Completed sent transfer principal only',
      child: categories.isEmpty
          ? const DashboardEmptyBreakdown(
              message: 'No completed outgoing payments to categorize yet.',
            )
          : Column(
              children: [
                for (var index = 0; index < categories.length; index++) ...[
                  if (index > 0) const SizedBox(height: 14),
                  DashboardBreakdownRow(
                    label: categories[index].category.label,
                    amount: categories[index].sentAmount,
                    currency: currency,
                    transactions: categories[index].transactions,
                    percentage: categories[index].percentage,
                  ),
                ],
              ],
            ),
    );
  }
}

class DashboardTransferTypeSection extends StatelessWidget {
  const DashboardTransferTypeSection({
    super.key,
    required this.transferTypes,
    required this.currency,
  });

  final List<TransactionTransferTypeAnalytics> transferTypes;

  final String currency;

  @override
  Widget build(BuildContext context) {
    return DashboardSectionCard(
      title: 'Outgoing payment methods',
      subtitle: 'How completed transfers were sent',
      child: transferTypes.isEmpty
          ? const DashboardEmptyBreakdown(
              message: 'No completed outgoing payment methods to show yet.',
            )
          : Column(
              children: [
                for (var index = 0; index < transferTypes.length; index++) ...[
                  if (index > 0) const SizedBox(height: 14),
                  DashboardBreakdownRow(
                    label: transferTypes[index].transferType.label,
                    amount: transferTypes[index].sentAmount,
                    currency: currency,
                    transactions: transferTypes[index].transactions,
                    percentage: transferTypes[index].percentage,
                  ),
                ],
              ],
            ),
    );
  }
}
