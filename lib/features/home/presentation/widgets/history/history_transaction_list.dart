import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../data/models/transaction_history_models.dart';
import '../../../data/models/transaction_models.dart';

class HistoryTransactionList extends StatelessWidget {
  const HistoryTransactionList({
    super.key,
    required this.transactions,
    required this.compact,
    required this.onTap,
  });

  final List<TransactionHistoryItem> transactions;

  final bool compact;

  final ValueChanged<TransactionHistoryItem> onTap;

  @override
  Widget build(BuildContext context) {
    final grouped = <DateTime, List<TransactionHistoryItem>>{};

    for (final transaction in transactions) {
      final local = transaction.activityAt.toLocal();

      final date = DateTime(local.year, local.month, local.day);

      grouped.putIfAbsent(date, () => []);

      grouped[date]!.add(transaction);
    }

    final entries = grouped.entries.toList(growable: false);

    return Column(
      children: [
        for (var index = 0; index < entries.length; index++) ...[
          _DateGroup(
            date: entries[index].key,
            transactions: entries[index].value,
            compact: compact,
            onTap: onTap,
          ),
          if (index < entries.length - 1) SizedBox(height: compact ? 22 : 26),
        ],
      ],
    );
  }
}

class _DateGroup extends StatelessWidget {
  const _DateGroup({
    required this.date,
    required this.transactions,
    required this.compact,
    required this.onTap,
  });

  final DateTime date;

  final List<TransactionHistoryItem> transactions;

  final bool compact;

  final ValueChanged<TransactionHistoryItem> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _formatDate(date),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(compact ? 22 : 26),
          ),
          child: Column(
            children: [
              for (var index = 0; index < transactions.length; index++) ...[
                _TransactionTile(
                  transaction: transactions[index],
                  compact: compact,
                  onTap: () {
                    onTap(transactions[index]);
                  },
                ),
                if (index < transactions.length - 1)
                  Padding(
                    padding: EdgeInsets.only(left: compact ? 66 : 74),
                    child: Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.045),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.compact,
    required this.onTap,
  });

  final TransactionHistoryItem transaction;

  final bool compact;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final received = transaction.isReceived;

    final accent = _transactionStatusColor(transaction);

    final local = transaction.activityAt.toLocal();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 18,
            vertical: compact ? 14 : 16,
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 42 : 46,
                height: compact ? 42 : 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: HugeIcon(
                  icon: received
                      ? HugeIcons.strokeRoundedMoneyReceiveCircle
                      : HugeIcons.strokeRoundedMoneySendSquare,
                  size: 19,
                  strokeWidth: 1.8,
                  color: accent,
                ),
              ),
              SizedBox(width: compact ? 12 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.counterpartyDisplayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _subtitleForTransaction(transaction),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _formatTime(local),
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.textSecondary.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${received ? '+' : '-'}${_formatAmount(transaction.amount)}',
                    style: TextStyle(
                      fontSize: compact ? 13 : 14,
                      fontWeight: FontWeight.w800,
                      color: received
                          ? AppColors.success
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    transaction.currency,
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 7),
                  _StatusBadge(transaction: transaction),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.transaction});

  final TransactionHistoryItem transaction;

  @override
  Widget build(BuildContext context) {
    final needsConfirmation = transaction.needsConfirmation();

    final color = _transactionStatusColor(transaction);

    final label = needsConfirmation
        ? 'Needs confirmation'
        : transaction.status.label;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

String _subtitleForTransaction(TransactionHistoryItem transaction) {
  final identifier = transaction.counterpartyIdentifier?.trim();

  final prefix = transaction.isReceived ? 'Received' : transaction.methodLabel;

  if (identifier == null || identifier.isEmpty) {
    return prefix;
  }

  return '$prefix • $identifier';
}

Color _transactionStatusColor(TransactionHistoryItem transaction) {
  if (transaction.needsConfirmation()) {
    return AppColors.primaryMuted;
  }

  return switch (transaction.status) {
    TransactionStatus.completed =>
      transaction.isReceived ? AppColors.success : AppColors.primary,

    TransactionStatus.failed ||
    TransactionStatus.cancelled ||
    TransactionStatus.reversed => AppColors.danger,

    TransactionStatus.processing => AppColors.primary,

    TransactionStatus.pending => AppColors.textSecondary,
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

String _formatDate(DateTime date) {
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

  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _formatTime(DateTime date) {
  final hour = date.hour == 0
      ? 12
      : date.hour > 12
      ? date.hour - 12
      : date.hour;

  final minute = date.minute.toString().padLeft(2, '0');

  final period = date.hour >= 12 ? 'PM' : 'AM';

  return '$hour:$minute $period';
}
