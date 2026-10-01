import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../data/models/transaction_analytics_models.dart';
import 'dashboard_section_card.dart';

class DashboardStatusSection extends StatelessWidget {
  const DashboardStatusSection({super.key, required this.summary});

  final TransactionAnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    return DashboardSectionCard(
      title: 'Money activity status',
      subtitle: 'Current sent and received transaction states for this period',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _DashboardStatusMetric(
            label: 'Sent completed',
            value: summary.completedTransactions,
            color: AppColors.success,
          ),
          _DashboardStatusMetric(
            label: 'Received',
            value: summary.receivedTransactions,
            color: AppColors.success,
          ),
          _DashboardStatusMetric(
            label: 'Needs confirmation',
            value: summary.needsConfirmation,
            color: AppColors.primary,
            detail:
                '${summary.pendingTransactions} pending • '
                '${summary.processingTransactions} processing',
          ),
          _DashboardStatusMetric(
            label: 'Sent failed',
            value: summary.failedTransactions,
            color: AppColors.danger,
          ),
          _DashboardStatusMetric(
            label: 'Sent cancelled',
            value: summary.cancelledTransactions,
            color: AppColors.textSecondary,
          ),
          _DashboardStatusMetric(
            label: 'Sent reversed',
            value: summary.reversedTransactions,
            color: AppColors.primaryMuted,
          ),
          _DashboardStatusMetric(
            label: 'Received reversed',
            value: summary.receivedReversedTransactions,
            color: AppColors.primaryMuted,
          ),
        ],
      ),
    );
  }
}

class DashboardReceivedEvidenceSection extends StatelessWidget {
  const DashboardReceivedEvidenceSection({super.key, required this.evidence});

  final ReceivedTransactionAnalyticsEvidence evidence;

  @override
  Widget build(BuildContext context) {
    if (evidence.total == 0) {
      return const DashboardSectionCard(
        title: 'Received payment evidence',
        subtitle: 'How completed received payments were recorded',
        child: DashboardEmptyBreakdown(
          message: 'No completed received-payment evidence in this period.',
        ),
      );
    }

    return DashboardSectionCard(
      title: 'Received payment evidence',
      subtitle: 'How completed received payments were recorded',
      child: Column(
        children: [
          DashboardCountRow(
            label: 'MTN SMS evidence',
            value: evidence.smsEvidence,
          ),
          const SizedBox(height: 10),
          DashboardCountRow(
            label: 'Provider API evidence',
            value: evidence.providerApiEvidence,
          ),
          const SizedBox(height: 10),
          DashboardCountRow(
            label: 'Manual entry',
            value: evidence.manualEntries,
          ),
          if (evidence.smsEvidence > 0) ...[
            const SizedBox(height: 16),
            const DashboardEvidenceNotice(
              message:
                  'MTN SMS evidence is parsed on the device. '
                  'It is not independent provider API verification.',
            ),
          ],
        ],
      ),
    );
  }
}

class DashboardOutgoingConfirmationSection extends StatelessWidget {
  const DashboardOutgoingConfirmationSection({
    super.key,
    required this.confirmation,
  });

  final TransactionAnalyticsConfirmation confirmation;

  @override
  Widget build(BuildContext context) {
    final total = confirmation.total;

    return DashboardSectionCard(
      title: 'Outgoing completion evidence',
      subtitle: 'How completed sent payments were established',
      child: total == 0
          ? const DashboardEmptyBreakdown(
              message: 'No completed outgoing transactions in this period.',
            )
          : Column(
              children: [
                DashboardCountRow(
                  label: 'MTN SMS evidence',
                  value: confirmation.smsEvidence,
                ),
                const SizedBox(height: 10),
                DashboardCountRow(
                  label: 'Provider API confirmed',
                  value: confirmation.providerApiConfirmed,
                ),
                const SizedBox(height: 10),
                DashboardCountRow(
                  label: 'Manually confirmed',
                  value: confirmation.manuallyConfirmed,
                ),
                if (confirmation.unclassified > 0) ...[
                  const SizedBox(height: 10),
                  DashboardCountRow(
                    label: 'Unclassified',
                    value: confirmation.unclassified,
                  ),
                ],
                if (confirmation.smsEvidence > 0) ...[
                  const SizedBox(height: 16),
                  const DashboardEvidenceNotice(
                    message:
                        'SMS evidence is parsed from MTN '
                        'transaction messages on the device. '
                        'It is not independent provider API '
                        'verification.',
                  ),
                ],
              ],
            ),
    );
  }
}

class _DashboardStatusMetric extends StatelessWidget {
  const _DashboardStatusMetric({
    required this.label,
    required this.value,
    required this.color,
    this.detail,
  });

  final String label;

  final int value;

  final Color color;

  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(
              detail!,
              style: const TextStyle(
                fontSize: 7.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
