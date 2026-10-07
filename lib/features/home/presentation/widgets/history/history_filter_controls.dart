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
        PopupMenuButton<Object>(
          tooltip: 'Filter transactions',
          icon: Icon(
            Icons.tune_rounded,
            color: direction != HistoryDirectionFilter.all ||
                    status != HistoryStatusFilter.all ||
                    method != HistoryMethodFilter.all
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
          onSelected: (value) {
            if (value is HistoryDirectionFilter) {
              onDirectionSelected(value);
            } else if (value is HistoryStatusFilter) {
              onStatusSelected(value);
            } else if (value is HistoryMethodFilter) {
              onMethodSelected(value);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem<Object>(
              enabled: false,
              child: Text('Direction'),
            ),
            for (final value in HistoryDirectionFilter.values)
              CheckedPopupMenuItem<Object>(
                value: value,
                checked: direction == value,
                child: Text(value.label),
              ),
            const PopupMenuDivider(),
            const PopupMenuItem<Object>(
              enabled: false,
              child: Text('Status'),
            ),
            for (final value in _availableStatuses)
              CheckedPopupMenuItem<Object>(
                value: value,
                checked: status == value,
                child: Text(value.label),
              ),
            if (_showMethodFilter) ...[
              const PopupMenuDivider(),
              const PopupMenuItem<Object>(
                enabled: false,
                child: Text('Method'),
              ),
              for (final value in HistoryMethodFilter.values)
                CheckedPopupMenuItem<Object>(
                  value: value,
                  checked: method == value,
                  child: Text(value.label),
                ),
            ],
          ],
        ),
      ],
    );
  }
}
