import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dropdown.dart';
import '../../../../core/widgets/app_input.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../home/presentation/widgets/record_received_money/received_date_sheet.dart';
import '../../application/income_service.dart';
import '../../data/models/income.dart';
import '../widgets/income_form_sheet.dart';
import '../widgets/income_payment_sheet.dart';

class IncomePage extends StatefulWidget {
  const IncomePage({super.key, this.service, this.onChanged});
  final IncomeService? service;
  final VoidCallback? onChanged;
  @override
  State<IncomePage> createState() => _IncomePageState();
}

class _IncomePageState extends State<IncomePage> {
  late final IncomeService _service;
  final _search = TextEditingController();
  final List<IncomeRecord> _items = [];
  IncomePageResult? _result;
  String? _status;
  String? _error;
  Timer? _debounce;
  int _generation = 0;
  int _page = 0;
  bool _loading = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? IncomeService.createDefault();
    unawaited(_load());
  }

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (more && (_loading || !(_result?.hasNextPage ?? false))) return;
    final generation = ++_generation;
    final page = more ? _page + 1 : 1;
    setState(() {
      _loading = true;
      _error = null;
      if (!more) {
        _items.clear();
        _result = null;
      }
    });
    try {
      final result = await _service.list(
        page: page,
        status: _status,
        search: _search.text,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _result = result;
        _items.addAll(result.items);
        _page = page;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = _message(error));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  String _message(Object error) => error is ApiException
      ? error.message
      : 'Could not load income. Check your connection and try again.';

  Future<void> _form([IncomeRecord? income]) async {
    if (_busy) return;
    setState(() => _busy = true);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => IncomeFormSheet(service: _service, record: income),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved == true) {
      widget.onChanged?.call();
      await _load();
    }
  }

  Future<void> _action(IncomeRecord income, String action) async {
    if (_busy) return;
    if (action == 'edit') {
      await _form(income);
      return;
    }
    setState(() => _busy = true);
    try {
      var changed = false;
      if (action == 'link') {
        changed =
            await showModalBottomSheet<bool>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              isDismissible: false,
              enableDrag: false,
              backgroundColor: Colors.transparent,
              builder: (_) =>
                  IncomePaymentSheet(service: _service, income: income),
            ) ==
            true;
      } else if (action == 'receive') {
        final now = DateTime.now();
        final date = await showModalBottomSheet<DateTime>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (_) => ReceivedDateSheet(
            initialDate: now,
            firstYear: now.year - 10,
            lastDate: now,
          ),
        );
        if (date != null) {
          await _service.receive(income.id, date);
          changed = true;
        }
      } else if (action == 'archive') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text(
              'Archive income?',
              style: TextStyle(fontSize: 17),
            ),
            content: const Text(
              'This removes it from income totals. A linked payment stays in History and cannot be linked twice.',
              style: TextStyle(fontSize: 12),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text(
                  'Archive',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await _service.archive(income.id);
          changed = true;
        }
      }
      if (!mounted) return;
      if (changed) {
        widget.onChanged?.call();
        AppToast.success(context, title: 'Income updated');
        await _load();
      }
    } catch (error) {
      if (mounted) {
        AppToast.error(
          context,
          title: 'Could not update income',
          description: _message(error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Income',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          AppDropdown<String>(
            tooltip: 'Income actions',
            enabled: !_busy,
            items: const [
              AppDropdownItem(
                value: 'add',
                label: 'Add income',
                icon: Icons.add_rounded,
              ),
              AppDropdownItem(
                value: 'refresh',
                label: 'Refresh',
                icon: Icons.refresh_rounded,
              ),
            ],
            onSelected: (action) {
              if (action == 'add') {
                unawaited(_form());
              } else {
                _debounce?.cancel();
                unawaited(_load());
              }
            },
          ),
        ],
      ),
      const SizedBox(height: 8),
      const Text(
        'Plan what is coming. Track what has arrived.',
        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 20),
      if (_loading && _result == null)
        const _IncomeSkeleton()
      else if (_result != null) ...[
        Row(
          children: [
            Expanded(
              child: _IncomeTotal(
                label: 'Received',
                amount: _result!.receivedAmount,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _IncomeTotal(
                label: 'Expected',
                amount: _result!.expectedAmount,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'All dates · Expected income is not counted as received',
          style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
      const SizedBox(height: 20),
      AppInput(
        controller: _search,
        hintText: 'Search income',
        maxLength: 120,
        borderRadius: 999,
        onChanged: (_) {
          _debounce?.cancel();
          _debounce = Timer(
            const Duration(milliseconds: 350),
            () => unawaited(_load()),
          );
        },
        textInputAction: TextInputAction.search,
        onSubmitted: (_) {
          _debounce?.cancel();
          unawaited(_load());
        },
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final status in <String?>[
            null,
            'EXPECTED',
            'RECEIVED',
            'REVERSED',
          ])
            ChoiceChip(
              label: Text(
                status == null
                    ? 'All'
                    : status == 'EXPECTED'
                    ? 'Expected'
                    : status == 'RECEIVED'
                    ? 'Received'
                    : 'Reversed',
              ),
              selected: _status == status,
              showCheckmark: false,
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.primary,
              side: BorderSide.none,
              labelStyle: TextStyle(
                fontSize: 11,
                color: _status == status
                    ? AppColors.background
                    : AppColors.textSecondary,
              ),
              onSelected: _busy
                  ? null
                  : (_) {
                      if (_status == status) return;
                      _debounce?.cancel();
                      setState(() => _status = status);
                      unawaited(_load());
                    },
            ),
        ],
      ),
      const SizedBox(height: 16),
      if (_loading && _items.isEmpty)
        for (var index = 0; index < 3; index++) ...[
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 10),
        ],
      if (_error != null) ...[
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.danger),
        ),
        TextButton(
          onPressed: () => _load(more: _items.isNotEmpty),
          child: const Text('Try again'),
        ),
      ],
      if (!_loading && _error == null && _items.isEmpty) ...[
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.south_west_rounded,
                size: 26,
                color: AppColors.primary,
              ),
              const SizedBox(height: 12),
              const Text(
                'No income records here',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Add expected income or money already received.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 180,
                child: AppButton(
                  label: 'Add income',
                  iconWidget: const Icon(Icons.add_rounded),
                  size: AppButtonSize.sm,
                  onPressed: _busy ? null : () => _form(),
                ),
              ),
            ],
          ),
        ),
      ],
      for (final income in _items) ...[
        _IncomeTile(
          income: income,
          enabled: !_busy,
          onAction: (action) => unawaited(_action(income, action)),
        ),
        const SizedBox(height: 10),
      ],
      if (_loading && _items.isNotEmpty)
        const Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2,
            ),
          ),
        ),
      if (!_loading && (_result?.hasNextPage ?? false))
        TextButton(
          onPressed: () => _load(more: true),
          child: const Text('Load more income'),
        ),
    ],
  );
}

class _IncomeTotal extends StatelessWidget {
  const _IncomeTotal({
    required this.label,
    required this.amount,
    required this.color,
  });
  final String label;
  final String amount;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: color)),
        const SizedBox(height: 14),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatIncomeAmount(amount),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'RWF',
          style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}

class _IncomeTile extends StatelessWidget {
  const _IncomeTile({
    required this.income,
    required this.enabled,
    required this.onAction,
  });
  final IncomeRecord income;
  final bool enabled;
  final ValueChanged<String> onAction;
  @override
  Widget build(BuildContext context) {
    final color = income.isExpected
        ? AppColors.primary
        : income.status == 'REVERSED'
        ? AppColors.danger
        : AppColors.success;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  income.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${income.category.label} · ${formatReceivedDate(income.date)}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${formatIncomeAmount(income.amount)} RWF',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        income.isExpected
                            ? 'Expected'
                            : income.status == 'REVERSED'
                            ? 'Reversed'
                            : 'Received',
                        style: TextStyle(fontSize: 10, color: color),
                      ),
                    ),
                    if (income.paymentReference != null)
                      Text(
                        'Linked payment',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          AppDropdown<String>(
            tooltip: 'Actions for ${income.label}',
            enabled: enabled,
            onSelected: onAction,
            items: [
              const AppDropdownItem(
                value: 'edit',
                label: 'Edit details',
                icon: Icons.edit_outlined,
              ),
              if (income.isExpected)
                const AppDropdownItem(
                  value: 'receive',
                  label: 'Mark as received',
                  icon: Icons.check_rounded,
                ),
              if (income.receivedTransactionId == null)
                const AppDropdownItem(
                  value: 'link',
                  label: 'Link received payment',
                  icon: Icons.link_rounded,
                ),
              const AppDropdownItem(
                value: 'archive',
                label: 'Archive income',
                icon: Icons.archive_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IncomeSkeleton extends StatelessWidget {
  const _IncomeSkeleton();
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading income',
    child: ExcludeSemantics(
      child: Column(
        children: [
          Row(
            children: [
              for (var index = 0; index < 2; index++) ...[
                if (index > 0) const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 104,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  );
}
