import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../application/transaction_sms_matcher.dart';
import '../../../data/models/transaction_models.dart';
import '../transaction_manual_confirmation_sheet.dart';
import 'transaction_detail_frame.dart';

class SentTransactionDetailContent extends StatelessWidget {
  const SentTransactionDetailContent({
    super.key,
    required this.detail,
    required this.isCheckingStatus,
    required this.lastCheckedAt,
    required this.reconciliationMessage,
    required this.onCheckStatus,
    required this.onConfirmManually,
  });

  final TransactionDetail detail;
  final bool isCheckingStatus;
  final DateTime? lastCheckedAt;
  final String? reconciliationMessage;
  final VoidCallback onCheckStatus;
  final VoidCallback onConfirmManually;

  @override
  Widget build(BuildContext context) {
    final transaction = detail.transaction;

    final needsConfirmation = transactionNeedsConfirmation(transaction);

    final confirmationSource = _confirmationSource(detail);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TransactionDetailHeader(
            eyebrow: 'TRANSACTION',
            title: 'Transaction details',
            accentColor: AppColors.primary,
            trailing: _StatusBadge(transaction: transaction),
          ),
          const SizedBox(height: 24),
          _AmountSummary(transaction: transaction),
          if (isTransactionOpen(transaction)) ...[
            const SizedBox(height: 16),
            if (supportsIosManualTransactionConfirmation)
              _IosManualRecoveryCard(
                needsConfirmation: needsConfirmation,
                isSaving: isCheckingStatus,
                onConfirm: onConfirmManually,
              )
            else
              _TransactionRecoveryCard(
                needsConfirmation: needsConfirmation,
                isChecking: isCheckingStatus,
                lastCheckedAt: lastCheckedAt,
                message: reconciliationMessage,
                onCheck: onCheckStatus,
              ),
          ],
          const SizedBox(height: 16),
          _InformationCard(
            transaction: transaction,
            confirmationSource: confirmationSource,
          ),
          if (transaction.failureCode != null ||
              transaction.failureReason != null) ...[
            const SizedBox(height: 16),
            _FailureCard(transaction: transaction),
          ],
          const SizedBox(height: 28),
          Row(
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedTransactionHistory,
                size: 19,
                color: AppColors.primary,
              ),
              const SizedBox(width: 9),
              const Text(
                'Timeline',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${detail.events.length} events',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _TransactionTimeline(events: detail.events),
        ],
      ),
    );
  }
}

class _AmountSummary extends StatelessWidget {
  const _AmountSummary({required this.transaction});

  final PaymentTransaction transaction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedMoneySendSquare,
            size: 26,
            color: AppColors.primary,
          ),
          const SizedBox(height: 14),
          Text(
            '${_formatAmount(transaction.amount)} RWF',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            transaction.recipientDisplayName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _AmountMetric(
                  label: 'Fee',
                  value: '${_formatAmount(transaction.feeAmount)} RWF',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AmountMetric(
                  label: 'Total',
                  value: '${_formatAmount(transaction.totalAmount)} RWF',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IosManualRecoveryCard extends StatelessWidget {
  const _IosManualRecoveryCard({
    required this.needsConfirmation,
    required this.isSaving,
    required this.onConfirm,
  });

  final bool needsConfirmation;
  final bool isSaving;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final accent = needsConfirmation
        ? AppColors.primaryMuted
        : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedTransactionHistory,
                  size: 19,
                  strokeWidth: 1.8,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      needsConfirmation
                          ? 'Needs confirmation'
                          : 'Waiting for confirmation',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      needsConfirmation
                          ? 'Budgetify cannot automatically inspect MTN transaction SMS on iPhone. Confirm the result when you know whether the payment succeeded or failed.'
                          : 'After completing the MTN payment, you can record the result here.',
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Confirm payment result',
            icon: HugeIcons.strokeRoundedTransactionHistory,
            size: AppButtonSize.md,
            variant: AppButtonVariant.secondary,
            isLoading: isSaving,
            onPressed: isSaving ? null : onConfirm,
          ),
        ],
      ),
    );
  }
}

class _TransactionRecoveryCard extends StatelessWidget {
  const _TransactionRecoveryCard({
    required this.needsConfirmation,
    required this.isChecking,
    required this.lastCheckedAt,
    required this.message,
    required this.onCheck,
  });

  final bool needsConfirmation;
  final bool isChecking;
  final DateTime? lastCheckedAt;
  final String? message;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    final accent = needsConfirmation
        ? AppColors.primaryMuted
        : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedTransactionHistory,
                  size: 19,
                  strokeWidth: 1.8,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      needsConfirmation
                          ? 'Needs confirmation'
                          : 'Waiting for confirmation',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      needsConfirmation
                          ? 'Budgetify has not found matching MTN SMS evidence yet. This does not mean the payment failed.'
                          : 'Budgetify will keep this transaction open until matching MTN SMS evidence is found.',
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (message != null) ...[
            const SizedBox(height: 14),
            Text(
              message!,
              style: const TextStyle(
                fontSize: 10,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (lastCheckedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Last checked ${_formatDateTime(lastCheckedAt!.toLocal())}',
              style: TextStyle(
                fontSize: 9,
                color: AppColors.textSecondary.withValues(alpha: 0.72),
              ),
            ),
          ],
          const SizedBox(height: 16),
          AppButton(
            label: 'Check transaction status',
            icon: HugeIcons.strokeRoundedTransactionHistory,
            size: AppButtonSize.sm,
            variant: AppButtonVariant.secondary,
            isLoading: isChecking,
            onPressed: isChecking ? null : onCheck,
          ),
        ],
      ),
    );
  }
}

class _AmountMetric extends StatelessWidget {
  const _AmountMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({
    required this.transaction,
    required this.confirmationSource,
  });

  final PaymentTransaction transaction;
  final String? confirmationSource;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          _DetailRow(label: 'Recipient', value: transaction.receiverIdentifier),
          const _DetailDivider(),
          _DetailRow(label: 'Method', value: transaction.transferType.label),
          const _DetailDivider(),
          _DetailRow(label: 'Category', value: transaction.category.label),
          const _DetailDivider(),
          _DetailRow(label: 'Reference', value: transaction.reference),
          if (confirmationSource != null) ...[
            const _DetailDivider(),
            _DetailRow(label: 'Result source', value: confirmationSource!),
          ],
          if (transaction.providerReference != null) ...[
            const _DetailDivider(),
            _DetailRow(
              label: 'Provider reference',
              value: transaction.providerReference!,
            ),
          ],
          const _DetailDivider(),
          _DetailRow(
            label: 'Created',
            value: _formatDateTime(transaction.createdAt.toLocal()),
          ),
          if (transaction.processedAt != null) ...[
            const _DetailDivider(),
            _DetailRow(
              label: 'Processing',
              value: _formatDateTime(transaction.processedAt!.toLocal()),
            ),
          ],
          if (transaction.completedAt != null) ...[
            const _DetailDivider(),
            _DetailRow(
              label: 'Completed',
              value: _formatDateTime(transaction.completedAt!.toLocal()),
            ),
          ],
          if (transaction.failedAt != null) ...[
            const _DetailDivider(),
            _DetailRow(
              label: 'Failed',
              value: _formatDateTime(transaction.failedAt!.toLocal()),
            ),
          ],
          if (transaction.cancelledAt != null) ...[
            const _DetailDivider(),
            _DetailRow(
              label: 'Cancelled',
              value: _formatDateTime(transaction.cancelledAt!.toLocal()),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailDivider extends StatelessWidget {
  const _DetailDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Container(height: 1, color: Colors.white.withValues(alpha: 0.045)),
    );
  }
}

class _FailureCard extends StatelessWidget {
  const _FailureCard({required this.transaction});

  final PaymentTransaction transaction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Transaction issue',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.danger,
            ),
          ),
          if (transaction.failureCode != null) ...[
            const SizedBox(height: 7),
            Text(
              transaction.failureCode!,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          if (transaction.failureReason != null) ...[
            const SizedBox(height: 5),
            Text(
              transaction.failureReason!,
              style: const TextStyle(
                fontSize: 11,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TransactionTimeline extends StatelessWidget {
  const _TransactionTimeline({required this.events});

  final List<TransactionEventRecord> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'No lifecycle events recorded.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          for (var index = 0; index < events.length; index++)
            _TimelineItem(
              event: events[index],
              isLast: index == events.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.event, required this.isLast});

  final TransactionEventRecord event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = event.toStatus == null
        ? AppColors.primary
        : _statusColor(event.toStatus!);

    final transition = event.fromStatus == null
        ? event.toStatus?.label
        : '${event.fromStatus!.label} → ${event.toStatus?.label ?? 'Unknown'}';

    final isManualConfirmation =
        event.type == TransactionEventType.statusChanged &&
        event.source == TransactionEventSource.mobileApp;

    final eventTitle = isManualConfirmation
        ? 'Manual confirmation'
        : event.type.label;

    final sourceLabel = isManualConfirmation
        ? 'Reported in Budgetify'
        : event.source.label;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          child: Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              if (!isLast)
                Container(width: 1, height: 62, color: AppColors.border),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eventTitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [sourceLabel, ?transition].join(' • '),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _formatDateTime(event.occurredAt.toLocal()),
                  style: TextStyle(
                    fontSize: 9,
                    color: AppColors.textSecondary.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.transaction});

  final PaymentTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final needsConfirmation = transactionNeedsConfirmation(transaction);

    final color = needsConfirmation
        ? AppColors.primaryMuted
        : _statusColor(transaction.status);

    final label = needsConfirmation
        ? 'Needs confirmation'
        : transaction.status.label;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

String? _confirmationSource(TransactionDetail detail) {
  final status = detail.transaction.status;

  if (status != TransactionStatus.completed &&
      status != TransactionStatus.failed &&
      status != TransactionStatus.cancelled) {
    return null;
  }

  for (final event in detail.events.reversed) {
    if (event.toStatus != status) {
      continue;
    }

    if (event.type == TransactionEventType.providerResultReceived &&
        event.source == TransactionEventSource.providerSms) {
      return 'MTN SMS evidence';
    }

    if (event.type == TransactionEventType.providerResultReceived &&
        event.source == TransactionEventSource.providerApi) {
      return 'Provider API result';
    }

    if (event.type == TransactionEventType.statusChanged &&
        event.source == TransactionEventSource.mobileApp) {
      return 'Manually reported';
    }
  }

  return null;
}

Color _statusColor(TransactionStatus status) {
  return switch (status) {
    TransactionStatus.completed => AppColors.success,
    TransactionStatus.failed || TransactionStatus.cancelled => AppColors.danger,
    TransactionStatus.processing => AppColors.primary,
    TransactionStatus.pending => AppColors.textSecondary,
    TransactionStatus.reversed => AppColors.primaryMuted,
  };
}

String _formatAmount(int amount) {
  final value = amount.toString();
  final buffer = StringBuffer();

  for (var index = 0; index < value.length; index++) {
    final remaining = value.length - index;

    buffer.write(value[index]);

    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }

  return buffer.toString();
}

String _formatDateTime(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final hour = date.hour == 0
      ? 12
      : date.hour > 12
      ? date.hour - 12
      : date.hour;

  final minute = date.minute.toString().padLeft(2, '0');

  final period = date.hour >= 12 ? 'PM' : 'AM';

  return '${date.day} ${months[date.month - 1]} ${date.year} • '
      '$hour:$minute $period';
}
