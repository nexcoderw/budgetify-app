import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/app_input.dart';
import '../../../data/models/transaction_history_models.dart';
import '../../../data/models/transaction_models.dart';

enum HistoryDirectionFilter {
  all(direction: null, label: 'All'),
  sent(direction: TransactionHistoryDirection.sent, label: 'Sent'),
  received(direction: TransactionHistoryDirection.received, label: 'Received');

  const HistoryDirectionFilter({required this.direction, required this.label});

  final TransactionHistoryDirection? direction;

  final String label;
}

enum HistoryStatusFilter {
  all(status: null, label: 'All statuses'),
  pending(status: TransactionStatus.pending, label: 'Pending'),
  processing(status: TransactionStatus.processing, label: 'Processing'),
  completed(status: TransactionStatus.completed, label: 'Completed'),
  failed(status: TransactionStatus.failed, label: 'Failed'),
  cancelled(status: TransactionStatus.cancelled, label: 'Cancelled'),
  reversed(status: TransactionStatus.reversed, label: 'Reversed');

  const HistoryStatusFilter({required this.status, required this.label});

  final TransactionStatus? status;

  final String label;

  bool get supportsReceivedHistory {
    return this == HistoryStatusFilter.all ||
        this == HistoryStatusFilter.completed ||
        this == HistoryStatusFilter.reversed;
  }
}

enum HistoryMethodFilter {
  all(transferType: null, label: 'All methods'),
  momo(transferType: TransactionTransferType.momoToMomo, label: 'MTN MoMo'),
  ekash(transferType: TransactionTransferType.momoToEkash, label: 'eKash'),
  momoPay(transferType: TransactionTransferType.momoPay, label: 'MoMo Pay');

  const HistoryMethodFilter({required this.transferType, required this.label});

  final TransactionTransferType? transferType;

  final String label;
}

class HistoryFilterControls extends StatelessWidget {
  const HistoryFilterControls({
    super.key,
    required this.searchController,
    required this.direction,
    required this.status,
    required this.method,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onDirectionSelected,
    required this.onStatusSelected,
    required this.onMethodSelected,
  });

  final TextEditingController searchController;

  final HistoryDirectionFilter direction;

  final HistoryStatusFilter status;

  final HistoryMethodFilter method;

  final ValueChanged<String> onSearchChanged;

  final ValueChanged<String> onSearchSubmitted;

  final ValueChanged<HistoryDirectionFilter> onDirectionSelected;

  final ValueChanged<HistoryStatusFilter> onStatusSelected;

  final ValueChanged<HistoryMethodFilter> onMethodSelected;

  List<HistoryStatusFilter> get _availableStatuses {
    if (direction == HistoryDirectionFilter.received) {
      return const [
        HistoryStatusFilter.all,
        HistoryStatusFilter.completed,
        HistoryStatusFilter.reversed,
      ];
    }

    return HistoryStatusFilter.values;
  }

  bool get _showMethodFilter {
    return direction == HistoryDirectionFilter.sent;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppInput(
          controller: searchController,
          hintText: 'Search sender, recipient or reference',
          borderRadius: 999,
          textInputAction: TextInputAction.search,
          onChanged: onSearchChanged,
          onSubmitted: onSearchSubmitted,
        ),
        const SizedBox(height: 16),
        _FilterScroller<HistoryDirectionFilter>(
          values: HistoryDirectionFilter.values,
          selected: direction,
          labelBuilder: (filter) => filter.label,
          onSelected: onDirectionSelected,
        ),
        const SizedBox(height: 10),
        _FilterScroller<HistoryStatusFilter>(
          values: _availableStatuses,
          selected: status,
          labelBuilder: (filter) => filter.label,
          onSelected: onStatusSelected,
        ),
        if (_showMethodFilter) ...[
          const SizedBox(height: 10),
          _FilterScroller<HistoryMethodFilter>(
            values: HistoryMethodFilter.values,
            selected: method,
            labelBuilder: (filter) => filter.label,
            onSelected: onMethodSelected,
          ),
        ],
      ],
    );
  }
}

class _FilterScroller<T> extends StatelessWidget {
  const _FilterScroller({
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.onSelected,
  });

  final List<T> values;

  final T selected;

  final String Function(T value) labelBuilder;

  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < values.length; index++) ...[
            if (index > 0) const SizedBox(width: 7),
            _FilterPill(
              label: labelBuilder(values[index]),
              selected: values[index] == selected,
              onTap: () {
                onSelected(values[index]);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
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
      label: '$label filter',
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.13)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
