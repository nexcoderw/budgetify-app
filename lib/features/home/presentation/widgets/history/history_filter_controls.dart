import 'package:flutter/material.dart';

import '../../../../../core/widgets/app_dropdown.dart';
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
    return Row(
      children: [
        Expanded(
          child: AppInput(
            controller: searchController,
            hintText: 'Search transactions',
            borderRadius: 999,
            textInputAction: TextInputAction.search,
            onChanged: onSearchChanged,
            onSubmitted: onSearchSubmitted,
          ),
        ),
        const SizedBox(width: 8),
        AppDropdown<Object>(
          tooltip: 'Filter transactions',
          icon: Icons.tune_rounded,
          isActive:
              direction != HistoryDirectionFilter.all ||
              status != HistoryStatusFilter.all ||
              method != HistoryMethodFilter.all,
          onSelected: (value) {
            if (value is HistoryDirectionFilter) {
              onDirectionSelected(value);
            } else if (value is HistoryStatusFilter) {
              onStatusSelected(value);
            } else if (value is HistoryMethodFilter) {
              onMethodSelected(value);
            }
          },
          items: [
            const AppDropdownItem<Object>.heading('Direction'),
            for (final value in HistoryDirectionFilter.values)
              AppDropdownItem<Object>(
                value: value,
                selected: direction == value,
                label: value.label,
              ),
            const AppDropdownItem<Object>.heading('Status'),
            for (final value in _availableStatuses)
              AppDropdownItem<Object>(
                value: value,
                selected: status == value,
                label: value.label,
              ),
            if (_showMethodFilter) ...[
              const AppDropdownItem<Object>.heading('Method'),
              for (final value in HistoryMethodFilter.values)
                AppDropdownItem<Object>(
                  value: value,
                  selected: method == value,
                  label: value.label,
                ),
            ],
          ],
        ),
      ],
    );
  }
}
