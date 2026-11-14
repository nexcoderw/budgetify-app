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
import '../widgets/income_period_filter.dart';

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
  bool _refreshFailed = false;
  bool _refreshing = false;
  IncomePeriod _period = IncomePeriod.thisMonth;
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? IncomeService.createDefault();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month);
    _to = DateTime(now.year, now.month + 1, 0);
    unawaited(_load());
  }

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false, bool refresh = false}) async {
    if (more &&
        (_loading ||
            (_debounce?.isActive ?? false) ||
            !(_result?.hasNextPage ?? false))) {
      return;
    }
    final generation = ++_generation;
    final page = more ? _page + 1 : 1;
    setState(() {
      _loading = true;
      _error = null;
      _refreshFailed = false;
      _refreshing = refresh;
      if (!more && !refresh) {
        _items.clear();
        _result = null;
      }
    });
    try {
      final result = await _service.list(
        page: page,
        status: _status,
        search: _search.text,
        from: _from,
        to: DateTime(
          _to.year,
          _to.month,
          _to.day + 1,
        ).subtract(const Duration(milliseconds: 1)),
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _result = result;
        if (!more) {
          _items.clear();
        }
        _items.addAll(result.items);
        _page = page;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = _message(error);
          _refreshFailed = refresh;
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    if (_busy || _loading) {
      return;
    }
    _debounce?.cancel();
    await _load(refresh: true);
  }

  void _selectPeriod(IncomePeriod period) {
    if (_period == period) {
      return;
    }
    FocusScope.of(context).unfocus();
    _debounce?.cancel();
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - now.weekday + 1);
    setState(() {
      _period = period;
      switch (period) {
        case IncomePeriod.thisMonth:
          _from = DateTime(now.year, now.month);
          _to = DateTime(now.year, now.month + 1, 0);
        case IncomePeriod.lastWeek:
          _from = DateTime(monday.year, monday.month, monday.day - 7);
          _to = DateTime(monday.year, monday.month, monday.day - 1);
        case IncomePeriod.lastMonth:
          _from = DateTime(now.year, now.month - 1);
          _to = DateTime(now.year, now.month, 0);
        case IncomePeriod.custom:
          break;
      }
    });
    unawaited(_load());
  }

  void _selectDate(bool isFrom, DateTime date) {
    _debounce?.cancel();
    setState(() {
      if (isFrom) {
        _from = date;
        if (_to.isBefore(date)) {
          _to = date;
        }
      } else {
        _to = date;
        if (_from.isAfter(date)) {
          _from = date;
        }
      }
    });
    unawaited(_load());
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
  Widget build(BuildContext context) => RefreshIndicator.adaptive(
    onRefresh: _refresh,
    color: AppColors.primary,
    backgroundColor: AppColors.surface,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 20),
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
            const SizedBox(width: 12),
            Flexible(
              child: AppButton(
                label: 'Add income',
                iconWidget: const Icon(Icons.add_rounded),
                size: AppButtonSize.sm,
                fullWidth: false,
                onPressed: _busy ? null : () => _form(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        IncomePeriodFilter(
          period: _period,
          from: _from,
          to: _to,
          enabled: !_busy,
          onPeriodSelected: _selectPeriod,
          onDateSelected: _selectDate,
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
            'Received and expected income for this period',
            textAlign: TextAlign.center,
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
            _generation++;
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
          alignment: WrapAlignment.center,
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
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
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
            const _IncomeRecordSkeleton(),
            const SizedBox(height: 10),
          ],
        if (_error != null) ...[
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.danger),
          ),
          TextButton(
            onPressed: () => _load(
              more: !_refreshFailed && _items.isNotEmpty,
              refresh: _refreshFailed,
            ),
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
                  'No income in this view',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Try another period or status, or add income using the button above.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: AppColors.textSecondary,
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
        if (_loading && !_refreshing && _items.isNotEmpty)
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
    ),
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
        Row(
          children: [
            Icon(
              label == 'Received'
                  ? Icons.south_west_rounded
                  : Icons.schedule_rounded,
              size: 15,
              color: color,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3, right: 12),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                switch (income.category) {
                  IncomeCategory.salary => Icons.work_outline_rounded,
                  IncomeCategory.freelance => Icons.laptop_mac_rounded,
                  IncomeCategory.dividends => Icons.trending_up_rounded,
                  IncomeCategory.rental => Icons.home_outlined,
                  IncomeCategory.sideHustle => Icons.storefront_outlined,
                  IncomeCategory.loanRecovery =>
                    Icons.assignment_return_outlined,
                  IncomeCategory.other => Icons.south_west_rounded,
                },
                size: 18,
                color: AppColors.primary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  income.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  income.category.label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
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
                      const Tooltip(
                        message: 'Linked to a received payment',
                        child: Icon(
                          Icons.link_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${income.isExpected ? 'Expected' : 'Received'} ${formatReceivedDate(income.date)}',
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
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
                    height: 114,
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

class _IncomeRecordSkeleton extends StatelessWidget {
  const _IncomeRecordSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading income record',
    child: ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final width in [0.65, 0.4, 0.8, 0.45]) ...[
                    FractionallySizedBox(
                      widthFactor: width,
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
