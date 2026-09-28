import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';

enum _TransactionFilter {
  all,
  sent,
  received,
}

enum _TransactionDirection {
  sent,
  received,
}

enum _TransactionStatus {
  completed,
  pending,
}

class _TransactionRecord {
  const _TransactionRecord({
    required this.id,
    required this.name,
    required this.phone,
    required this.amount,
    required this.direction,
    required this.status,
    required this.date,
  });

  final String id;
  final String name;
  final String phone;
  final int amount;
  final _TransactionDirection direction;
  final _TransactionStatus status;
  final DateTime date;
}

final _transactions = <_TransactionRecord>[
  _TransactionRecord(
    id: 'TXN-001',
    name: 'Patrick Mugisha',
    phone: '0788 214 560',
    amount: 45000,
    direction: _TransactionDirection.sent,
    status: _TransactionStatus.completed,
    date: DateTime(2026, 9, 28, 13, 42),
  ),
  _TransactionRecord(
    id: 'TXN-002',
    name: 'Alice Uwase',
    phone: '0791 420 118',
    amount: 120000,
    direction: _TransactionDirection.received,
    status: _TransactionStatus.completed,
    date: DateTime(2026, 9, 28, 10, 18),
  ),
  _TransactionRecord(
    id: 'TXN-003',
    name: 'Eric Niyonzima',
    phone: '0783 605 901',
    amount: 18500,
    direction: _TransactionDirection.sent,
    status: _TransactionStatus.completed,
    date: DateTime(2026, 9, 27, 18, 5),
  ),
  _TransactionRecord(
    id: 'TXN-004',
    name: 'Diane Mukamana',
    phone: '0722 410 783',
    amount: 75000,
    direction: _TransactionDirection.received,
    status: _TransactionStatus.completed,
    date: DateTime(2026, 9, 27, 12, 34),
  ),
  _TransactionRecord(
    id: 'TXN-005',
    name: 'Kevin Habimana',
    phone: '0788 934 210',
    amount: 32500,
    direction: _TransactionDirection.sent,
    status: _TransactionStatus.pending,
    date: DateTime(2026, 9, 26, 16, 21),
  ),
  _TransactionRecord(
    id: 'TXN-006',
    name: 'Sarah Uwera',
    phone: '0790 117 354',
    amount: 200000,
    direction: _TransactionDirection.received,
    status: _TransactionStatus.completed,
    date: DateTime(2026, 9, 26, 9, 48),
  ),
  _TransactionRecord(
    id: 'TXN-007',
    name: 'Jean Claude',
    phone: '0782 520 440',
    amount: 25000,
    direction: _TransactionDirection.sent,
    status: _TransactionStatus.completed,
    date: DateTime(2026, 9, 25, 14, 15),
  ),
  _TransactionRecord(
    id: 'TXN-008',
    name: 'Grace Ingabire',
    phone: '0728 311 995',
    amount: 60000,
    direction: _TransactionDirection.received,
    status: _TransactionStatus.completed,
    date: DateTime(2026, 9, 25, 8, 30),
  ),
];

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  _TransactionFilter _filter = _TransactionFilter.all;

  List<_TransactionRecord> get _filteredTransactions {
    return switch (_filter) {
      _TransactionFilter.all => _transactions,
      _TransactionFilter.sent => _transactions
          .where(
            (transaction) =>
                transaction.direction == _TransactionDirection.sent,
          )
          .toList(growable: false),
      _TransactionFilter.received => _transactions
          .where(
            (transaction) =>
                transaction.direction == _TransactionDirection.received,
          )
          .toList(growable: false),
    };
  }

  int get _totalSent {
    return _transactions
        .where(
          (transaction) =>
              transaction.direction == _TransactionDirection.sent,
        )
        .fold(
          0,
          (total, transaction) => total + transaction.amount,
        );
  }

  int get _totalReceived {
    return _transactions
        .where(
          (transaction) =>
              transaction.direction == _TransactionDirection.received,
        )
        .fold(
          0,
          (total, transaction) => total + transaction.amount,
        );
  }

  void _selectFilter(_TransactionFilter filter) {
    if (_filter == filter) {
      return;
    }

    setState(() {
      _filter = filter;
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 700;

    final transactions = _filteredTransactions;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 0 : 4,
        vertical: isCompact ? 4 : 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HistoryHeader(
            compact: isCompact,
          ),
          SizedBox(
            height: isCompact ? 24 : 30,
          ),
          _SummarySection(
            totalSent: _totalSent,
            totalReceived: _totalReceived,
            compact: isCompact,
          ),
          SizedBox(
            height: isCompact ? 26 : 32,
          ),
          _HistoryToolbar(
            selectedFilter: _filter,
            transactionCount: transactions.length,
            onFilterSelected: _selectFilter,
            compact: isCompact,
          ),
          SizedBox(
            height: isCompact ? 18 : 22,
          ),
          AnimatedSwitcher(
            duration: const Duration(
              milliseconds: 180,
            ),
            child: _TransactionHistory(
              key: ValueKey(_filter),
              transactions: transactions,
              compact: isCompact,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({
    required this.compact,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TRANSACTIONS',
                style: TextStyle(
                  fontSize: 10,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: AppColors.primary.withValues(
                    alpha: 0.92,
                  ),
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              Text(
                'Money history',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(
                      fontSize: compact ? 26 : 32,
                      height: 1.05,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.9,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(
                height: 8,
              ),
              const Text(
                'Keep track of money you have sent and received.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(
              16,
            ),
          ),
          alignment: Alignment.center,
          child: const HugeIcon(
            icon: HugeIcons.strokeRoundedTransactionHistory,
            size: 21,
            strokeWidth: 1.8,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({
    required this.totalSent,
    required this.totalReceived,
    required this.compact,
  });

  final int totalSent;
  final int totalReceived;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: 'Money sent',
            amount: totalSent,
            icon: HugeIcons.strokeRoundedMoneySendSquare,
            accent: AppColors.danger,
            compact: compact,
          ),
        ),
        SizedBox(
          width: compact ? 10 : 14,
        ),
        Expanded(
          child: _SummaryCard(
            label: 'Money received',
            amount: totalReceived,
            icon: HugeIcons.strokeRoundedMoneyReceiveCircle,
            accent: AppColors.success,
            compact: compact,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.accent,
    required this.compact,
  });

  final String label;
  final int amount;
  final dynamic icon;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(
        compact ? 16 : 20,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(
          compact ? 22 : 26,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: compact ? 36 : 40,
                height: compact ? 36 : 40,
                decoration: BoxDecoration(
                  color: accent.withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(
                    13,
                  ),
                ),
                alignment: Alignment.center,
                child: HugeIcon(
                  icon: icon,
                  size: 18,
                  strokeWidth: 1.8,
                  color: accent,
                ),
              ),
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent,
                ),
              ),
            ],
          ),
          SizedBox(
            height: compact ? 18 : 22,
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(
            height: 6,
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${_formatAmount(amount)} RWF',
              style: TextStyle(
                fontSize: compact ? 18 : 21,
                height: 1,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryToolbar extends StatelessWidget {
  const _HistoryToolbar({
    required this.selectedFilter,
    required this.transactionCount,
    required this.onFilterSelected,
    required this.compact,
  });

  final _TransactionFilter selectedFilter;
  final int transactionCount;
  final ValueChanged<_TransactionFilter> onFilterSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HistoryTitle(
            transactionCount: transactionCount,
          ),
          const SizedBox(
            height: 14,
          ),
          _TransactionFilters(
            selectedFilter: selectedFilter,
            onFilterSelected: onFilterSelected,
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _HistoryTitle(
            transactionCount: transactionCount,
          ),
        ),
        _TransactionFilters(
          selectedFilter: selectedFilter,
          onFilterSelected: onFilterSelected,
        ),
      ],
    );
  }
}

class _HistoryTitle extends StatelessWidget {
  const _HistoryTitle({
    required this.transactionCount,
  });

  final int transactionCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent activity',
          style: TextStyle(
            fontSize: 17,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(
          height: 5,
        ),
        Text(
          '$transactionCount ${transactionCount == 1 ? 'transaction' : 'transactions'}',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _TransactionFilters extends StatelessWidget {
  const _TransactionFilters({
    required this.selectedFilter,
    required this.onFilterSelected,
  });

  final _TransactionFilter selectedFilter;
  final ValueChanged<_TransactionFilter> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(
        4,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(
          999,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FilterItem(
            label: 'All',
            selected: selectedFilter == _TransactionFilter.all,
            onTap: () {
              onFilterSelected(
                _TransactionFilter.all,
              );
            },
          ),
          _FilterItem(
            label: 'Sent',
            selected: selectedFilter == _TransactionFilter.sent,
            onTap: () {
              onFilterSelected(
                _TransactionFilter.sent,
              );
            },
          ),
          _FilterItem(
            label: 'Received',
            selected: selectedFilter == _TransactionFilter.received,
            onTap: () {
              onFilterSelected(
                _TransactionFilter.received,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FilterItem extends StatelessWidget {
  const _FilterItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label transactions',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(
            999,
          ),
          child: AnimatedContainer(
            duration: const Duration(
              milliseconds: 160,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(
                999,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                height: 1,
                fontWeight: FontWeight.w700,
                color: selected
                    ? AppColors.background
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TransactionHistory extends StatelessWidget {
  const _TransactionHistory({
    super.key,
    required this.transactions,
    required this.compact,
  });

  final List<_TransactionRecord> transactions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const _EmptyHistory();
    }

    final grouped = <DateTime, List<_TransactionRecord>>{};

    for (final transaction in transactions) {
      final date = DateTime(
        transaction.date.year,
        transaction.date.month,
        transaction.date.day,
      );

      grouped.putIfAbsent(
        date,
        () => [],
      );

      grouped[date]!.add(
        transaction,
      );
    }

    return Column(
      children: [
        for (final entry in grouped.entries) ...[
          _DateGroup(
            date: entry.key,
            transactions: entry.value,
            compact: compact,
          ),
          if (entry.key != grouped.keys.last)
            SizedBox(
              height: compact ? 22 : 26,
            ),
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
  });

  final DateTime date;
  final List<_TransactionRecord> transactions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _formatDate(date),
          style: const TextStyle(
            fontSize: 10,
            height: 1,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(
          height: 10,
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(
              compact ? 22 : 26,
            ),
          ),
          child: Column(
            children: [
              for (
                var index = 0;
                index < transactions.length;
                index++
              ) ...[
                _TransactionTile(
                  transaction: transactions[index],
                  compact: compact,
                ),
                if (index < transactions.length - 1)
                  Padding(
                    padding: EdgeInsets.only(
                      left: compact ? 66 : 74,
                    ),
                    child: Container(
                      height: 1,
                      color: Colors.white.withValues(
                        alpha: 0.045,
                      ),
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
  });

  final _TransactionRecord transaction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isReceived =
        transaction.direction == _TransactionDirection.received;

    final accent =
        isReceived ? AppColors.success : AppColors.danger;

    final icon = isReceived
        ? HugeIcons.strokeRoundedMoneyReceiveCircle
        : HugeIcons.strokeRoundedMoneySendSquare;

    final direction =
        isReceived ? 'Received from' : 'Sent to';

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 18,
        vertical: compact ? 14 : 16,
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 42 : 46,
            height: compact ? 42 : 46,
            decoration: BoxDecoration(
              color: accent.withValues(
                alpha: 0.11,
              ),
              borderRadius: BorderRadius.circular(
                15,
              ),
            ),
            alignment: Alignment.center,
            child: HugeIcon(
              icon: icon,
              size: 19,
              strokeWidth: 1.8,
              color: accent,
            ),
          ),
          SizedBox(
            width: compact ? 12 : 14,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(
                  height: 5,
                ),
                Text(
                  '$direction ${transaction.phone}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(
                  height: 5,
                ),
                Text(
                  _formatTime(transaction.date),
                  style: TextStyle(
                    fontSize: 9,
                    height: 1,
                    color: AppColors.textSecondary.withValues(
                      alpha: 0.72,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isReceived ? '+' : '-'}${_formatAmount(transaction.amount)}',
                style: TextStyle(
                  fontSize: compact ? 13 : 14,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.25,
                  color: accent,
                ),
              ),
              const SizedBox(
                height: 3,
              ),
              const Text(
                'RWF',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(
                height: 7,
              ),
              _StatusBadge(
                status: transaction.status,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.status,
  });

  final _TransactionStatus status;

  @override
  Widget build(BuildContext context) {
    final isCompleted =
        status == _TransactionStatus.completed;

    final color = isCompleted
        ? AppColors.success
        : AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.10,
        ),
        borderRadius: BorderRadius.circular(
          999,
        ),
      ),
      child: Text(
        isCompleted ? 'Completed' : 'Pending',
        style: TextStyle(
          fontSize: 8,
          height: 1,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 46,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(
          26,
        ),
      ),
      child: const Column(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedTransactionHistory,
            size: 30,
            strokeWidth: 1.7,
            color: AppColors.textSecondary,
          ),
          SizedBox(
            height: 16,
          ),
          Text(
            'No transactions found',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(
            height: 6,
          ),
          Text(
            'Try another transaction filter.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatAmount(int amount) {
  final value = amount.toString();
  final buffer = StringBuffer();

  for (var index = 0; index < value.length; index++) {
    final remaining = value.length - index;

    buffer.write(
      value[index],
    );

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

  final minute = date.minute.toString().padLeft(
        2,
        '0',
      );

  final period =
      date.hour >= 12 ? 'PM' : 'AM';

  return '$hour:$minute $period';
}