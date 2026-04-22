import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_modal_dialog.dart';
import '../../../expenses/data/models/expense_entry.dart';
import '../../data/models/todo_item.dart';
import '../todo_utils.dart';

class TodoExpenseDialog extends StatefulWidget {
  const TodoExpenseDialog({
    super.key,
    required this.entry,
    required this.categories,
    required this.onQuote,
    required this.onSubmit,
  });

  final TodoItem entry;
  final List<ExpenseCategoryOption> categories;
  final Future<MobileMoneyQuote> Function({
    required double amount,
    required ExpenseCurrency currency,
    required ExpenseMobileMoneyProvider mobileMoneyProvider,
    required ExpenseMobileMoneyChannel mobileMoneyChannel,
    ExpenseMobileMoneyNetwork? mobileMoneyNetwork,
  })
  onQuote;
  final Future<void> Function({
    required double amount,
    required ExpenseCategory category,
    required String date,
    required ExpensePaymentMethod paymentMethod,
    ExpenseMobileMoneyChannel? mobileMoneyChannel,
    ExpenseMobileMoneyProvider? mobileMoneyProvider,
    ExpenseMobileMoneyNetwork? mobileMoneyNetwork,
  })
  onSubmit;

  @override
  State<TodoExpenseDialog> createState() => _TodoExpenseDialogState();
}

class _TodoExpenseDialogState extends State<TodoExpenseDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final TextEditingController _amountCtrl;
  late ExpenseCategory? _selectedCategory;
  late String _selectedDate;
  ExpensePaymentMethod _paymentMethod = ExpensePaymentMethod.cash;
  ExpenseMobileMoneyProvider _mobileMoneyProvider =
      ExpenseMobileMoneyProvider.mtnRwanda;
  ExpenseMobileMoneyChannel _mobileMoneyChannel =
      ExpenseMobileMoneyChannel.merchantCode;
  ExpenseMobileMoneyNetwork? _mobileMoneyNetwork =
      ExpenseMobileMoneyNetwork.onNet;
  Timer? _quoteDebounce;
  MobileMoneyQuote? _quote;
  bool _quoteLoading = false;
  String? _quoteError;
  int _quoteRequestId = 0;
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _scale = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _amountCtrl = TextEditingController(
      text: getSuggestedTodoExpenseAmount(widget.entry).toStringAsFixed(0),
    );
    _selectedCategory = resolveDefaultTodoExpenseCategory(widget.categories);
    _selectedDate =
        isRecurringTodo(widget.entry) &&
            getRemainingOccurrenceDates(widget.entry).isNotEmpty
        ? getRemainingOccurrenceDates(widget.entry).first
        : getTodayDateValue();
    _amountCtrl.addListener(_scheduleMobileMoneyQuote);
  }

  @override
  void dispose() {
    _quoteDebounce?.cancel();
    _amountCtrl.removeListener(_scheduleMobileMoneyQuote);
    _controller.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  bool get _isMobileMoney => _paymentMethod == ExpensePaymentMethod.mobileMoney;

  bool get _needsMobileMoneyNetwork =>
      _isMobileMoney &&
      _mobileMoneyChannel == ExpenseMobileMoneyChannel.p2pTransfer;

  double? get _parsedAmount {
    final amount = double.tryParse(_amountCtrl.text.trim());
    return amount == null || amount <= 0 ? null : amount;
  }

  double get _plannedAmount => getSuggestedTodoExpenseAmount(widget.entry);

  double? get _chargedAmount {
    final amount = _parsedAmount;
    if (amount == null) {
      return null;
    }

    return _isMobileMoney ? _quote?.totalAmountRwf : amount;
  }

  @override
  Widget build(BuildContext context) {
    final recurring = isRecurringTodo(widget.entry);
    final remainingDates = getRemainingOccurrenceDates(widget.entry);
    final amount = _parsedAmount;
    final chargedAmount = _chargedAmount;
    final varianceAmount = chargedAmount == null
        ? null
        : chargedAmount - _plannedAmount;

    return AppModalDialog(
      maxWidth: 620,
      padding: const EdgeInsets.all(28),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.16),
                      ),
                      child: const Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedMoneySendSquare,
                          size: 18,
                          color: AppColors.primary,
                          strokeWidth: 1.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Record expense',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            recurring
                                ? 'This records the expense and deducts it from the recurring todo budget.'
                                : 'This records the expense and moves the todo to recorded status.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppModalCloseButton(
                      onTap: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const _GradientDivider(color: AppColors.primary),
                const SizedBox(height: 18),
                _SummaryCard(
                  title: widget.entry.name,
                  frequencyLabel: formatTodoFrequencyLabel(
                    widget.entry.frequency,
                  ),
                  value: _rwf(widget.entry.price),
                  detail: recurring
                      ? 'Remaining ${_rwf(widget.entry.remainingAmount ?? 0)}'
                      : 'One-time item',
                ),
                const SizedBox(height: 18),
                _FieldLabel(label: 'Expense category'),
                const SizedBox(height: 8),
                DropdownButtonFormField<ExpenseCategory>(
                  initialValue: _selectedCategory,
                  items: widget.categories
                      .map(
                        (option) => DropdownMenuItem<ExpenseCategory>(
                          value: option.value,
                          child: Text(option.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _isSubmitting
                      ? null
                      : (value) => setState(() => _selectedCategory = value),
                  decoration: _inputDecoration(),
                  dropdownColor: AppColors.surfaceElevated,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                _FieldLabel(label: 'Payment method'),
                const SizedBox(height: 8),
                _OptionWrap(
                  children: ExpensePaymentMethod.values
                      .map(
                        (method) => _OptionPill(
                          label: method.displayName,
                          selected: _paymentMethod == method,
                          onTap: _isSubmitting
                              ? null
                              : () => _selectPaymentMethod(method),
                        ),
                      )
                      .toList(growable: false),
                ),
                if (_isMobileMoney) ...[
                  const SizedBox(height: 16),
                  _FieldLabel(label: 'Mobile money provider'),
                  const SizedBox(height: 8),
                  _OptionWrap(
                    children: ExpenseMobileMoneyProvider.values
                        .map(
                          (provider) => _OptionPill(
                            label: provider.displayName,
                            selected: _mobileMoneyProvider == provider,
                            onTap: _isSubmitting
                                ? null
                                : () => _selectMobileMoneyProvider(provider),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 14),
                  _FieldLabel(label: 'Transfer type'),
                  const SizedBox(height: 8),
                  _OptionWrap(
                    children: ExpenseMobileMoneyChannel.values
                        .map(
                          (channel) => _OptionPill(
                            label: channel.displayName,
                            selected: _mobileMoneyChannel == channel,
                            onTap: _isSubmitting
                                ? null
                                : () => _selectMobileMoneyChannel(channel),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  if (_needsMobileMoneyNetwork) ...[
                    const SizedBox(height: 14),
                    _FieldLabel(label: 'Network'),
                    const SizedBox(height: 8),
                    _OptionWrap(
                      children: ExpenseMobileMoneyNetwork.values
                          .map(
                            (network) => _OptionPill(
                              label: network.displayName,
                              selected: _mobileMoneyNetwork == network,
                              onTap: _isSubmitting
                                  ? null
                                  : () => _selectMobileMoneyNetwork(network),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                if (recurring) ...[
                  _FieldLabel(label: 'Occurrence date'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: remainingDates.contains(_selectedDate)
                        ? _selectedDate
                        : (remainingDates.isEmpty
                              ? null
                              : remainingDates.first),
                    items: remainingDates
                        .map(
                          (date) => DropdownMenuItem<String>(
                            value: date,
                            child: Text(formatTodoDate(parseDateOnly(date))),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _isSubmitting
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _selectedDate = value);
                            }
                          },
                    decoration: _inputDecoration(),
                    dropdownColor: AppColors.surfaceElevated,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ] else ...[
                  _FieldLabel(label: 'Expense date'),
                  const SizedBox(height: 8),
                  _DateButton(
                    value: _selectedDate,
                    onTap: _isSubmitting ? null : _pickDate,
                  ),
                ],
                const SizedBox(height: 16),
                _FieldLabel(label: 'Amount in RWF'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}$'),
                    ),
                  ],
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                  decoration: _inputDecoration(hint: '125000'),
                ),
                if (recurring) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Default amount is split from the remaining budget across the remaining occurrences. You can change it before saving.',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.45,
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _QuotePanel(
                  amount: amount,
                  chargedAmount: chargedAmount,
                  feeAmount: _isMobileMoney ? _quote?.feeAmountRwf : 0,
                  isMobileMoney: _isMobileMoney,
                  plannedAmount: _plannedAmount,
                  quoteError: _quoteError,
                  quoteLoading: _quoteLoading,
                  varianceAmount: varianceAmount,
                  rwf: _rwf,
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _errorText!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.danger,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _DialogButton(
                        label: 'Cancel',
                        isPrimary: false,
                        isDisabled: _isSubmitting,
                        onTap: () async {
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DialogButton(
                        label: 'Record expense',
                        isPrimary: true,
                        isLoading: _isSubmitting,
                        onTap: _submit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectPaymentMethod(ExpensePaymentMethod method) {
    setState(() {
      _paymentMethod = method;
      if (method != ExpensePaymentMethod.mobileMoney) {
        _quote = null;
        _quoteError = null;
        _quoteLoading = false;
      }
    });
    _scheduleMobileMoneyQuote();
  }

  void _selectMobileMoneyProvider(ExpenseMobileMoneyProvider provider) {
    setState(() => _mobileMoneyProvider = provider);
    _scheduleMobileMoneyQuote();
  }

  void _selectMobileMoneyChannel(ExpenseMobileMoneyChannel channel) {
    setState(() {
      _mobileMoneyChannel = channel;
      _mobileMoneyNetwork = channel == ExpenseMobileMoneyChannel.p2pTransfer
          ? (_mobileMoneyNetwork ?? ExpenseMobileMoneyNetwork.onNet)
          : null;
    });
    _scheduleMobileMoneyQuote();
  }

  void _selectMobileMoneyNetwork(ExpenseMobileMoneyNetwork network) {
    setState(() => _mobileMoneyNetwork = network);
    _scheduleMobileMoneyQuote();
  }

  void _scheduleMobileMoneyQuote() {
    _quoteDebounce?.cancel();
    final amount = _parsedAmount;

    if (!_isMobileMoney) {
      _quoteRequestId++;
      if (mounted) {
        setState(() {
          _quote = null;
          _quoteError = null;
          _quoteLoading = false;
        });
      }
      return;
    }

    if (amount == null ||
        (_needsMobileMoneyNetwork && _mobileMoneyNetwork == null)) {
      _quoteRequestId++;
      if (mounted) {
        setState(() {
          _quote = null;
          _quoteError = null;
          _quoteLoading = false;
        });
      }
      return;
    }

    final requestId = ++_quoteRequestId;
    setState(() {
      _quote = null;
      _quoteError = null;
      _quoteLoading = true;
    });

    _quoteDebounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final quote = await widget.onQuote(
          amount: amount,
          currency: ExpenseCurrency.rwf,
          mobileMoneyProvider: _mobileMoneyProvider,
          mobileMoneyChannel: _mobileMoneyChannel,
          mobileMoneyNetwork:
              _mobileMoneyChannel == ExpenseMobileMoneyChannel.p2pTransfer
              ? _mobileMoneyNetwork
              : null,
        );

        if (!mounted || requestId != _quoteRequestId) {
          return;
        }

        setState(() {
          _quote = quote;
          _quoteError = null;
          _quoteLoading = false;
        });
      } catch (error) {
        if (!mounted || requestId != _quoteRequestId) {
          return;
        }

        setState(() {
          _quote = null;
          _quoteError = _readableError(error);
          _quoteLoading = false;
        });
      }
    });
  }

  Future<void> _pickDate() async {
    final initialDate = DateTime.tryParse(_selectedDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            onPrimary: AppColors.background,
            surface: AppColors.surfaceElevated,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );

    if (picked == null) {
      return;
    }

    setState(() => _selectedDate = formatDateOnly(picked));
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (_selectedCategory == null || amount == null || amount <= 0) {
      setState(() {
        _errorText = 'Choose a category and enter an amount greater than zero.';
      });
      return;
    }

    if (_isMobileMoney && (_quoteLoading || _quote == null)) {
      setState(() {
        _errorText =
            _quoteError ?? 'Wait for the mobile money fee quote before saving.';
      });
      return;
    }

    final chargedAmount = _isMobileMoney ? _quote!.totalAmountRwf : amount;

    if (isRecurringTodo(widget.entry) &&
        widget.entry.remainingAmount != null &&
        chargedAmount > widget.entry.remainingAmount!) {
      setState(() {
        _errorText =
            'Total charged amount cannot exceed the remaining recurring budget.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await widget.onSubmit(
        amount: amount,
        category: _selectedCategory!,
        date: _selectedDate,
        paymentMethod: _paymentMethod,
        mobileMoneyChannel: _isMobileMoney ? _mobileMoneyChannel : null,
        mobileMoneyProvider: _isMobileMoney ? _mobileMoneyProvider : null,
        mobileMoneyNetwork:
            _isMobileMoney &&
                _mobileMoneyChannel == ExpenseMobileMoneyChannel.p2pTransfer
            ? _mobileMoneyNetwork
            : null,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
        _errorText = _readableError(error);
      });
    }
  }

  String _readableError(Object error) {
    final message = error.toString().trim();
    if (message.startsWith('Exception: ')) {
      return message.replaceFirst('Exception: ', '');
    }
    if (message.startsWith('StateError: ')) {
      return message.replaceFirst('StateError: ', '');
    }
    return message;
  }

  String _rwf(double amount) {
    final formatted = amount
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return 'RWF $formatted';
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 13,
        color: AppColors.textSecondary.withValues(alpha: 0.45),
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.42),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _OptionWrap extends StatelessWidget {
  const _OptionWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: children);
  }
}

class _OptionPill extends StatelessWidget {
  const _OptionPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected
              ? AppColors.primary.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.42)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _QuotePanel extends StatelessWidget {
  const _QuotePanel({
    required this.amount,
    required this.chargedAmount,
    required this.feeAmount,
    required this.isMobileMoney,
    required this.plannedAmount,
    required this.quoteError,
    required this.quoteLoading,
    required this.rwf,
    required this.varianceAmount,
  });

  final double? amount;
  final double? chargedAmount;
  final double? feeAmount;
  final bool isMobileMoney;
  final double plannedAmount;
  final String? quoteError;
  final bool quoteLoading;
  final String Function(double amount) rwf;
  final double? varianceAmount;

  @override
  Widget build(BuildContext context) {
    final feeLabel = isMobileMoney
        ? quoteLoading
              ? 'Calculating...'
              : feeAmount == null
              ? 'Waiting'
              : rwf(feeAmount!)
        : rwf(0);
    final totalLabel = quoteLoading
        ? 'Calculating...'
        : chargedAmount == null
        ? 'Enter amount'
        : rwf(chargedAmount!);
    final varianceLabel = quoteLoading
        ? 'Calculating...'
        : varianceAmount == null
        ? 'Enter amount'
        : rwf(varianceAmount!);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Charge preview',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.primary.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MoneyStat(
                label: 'Base',
                value: amount == null ? 'Enter amount' : rwf(amount!),
              ),
              _MoneyStat(label: 'Fee', value: feeLabel),
              _MoneyStat(
                label: 'Charged',
                value: totalLabel,
                valueColor: AppColors.primary,
              ),
              _MoneyStat(label: 'Plan', value: rwf(plannedAmount)),
              _MoneyStat(
                label: 'Variance',
                value: varianceLabel,
                valueColor: (varianceAmount ?? 0) > 0
                    ? AppColors.danger
                    : (varianceAmount ?? 0) < 0
                    ? AppColors.success
                    : AppColors.textPrimary,
              ),
            ],
          ),
          if (quoteError != null) ...[
            const SizedBox(height: 10),
            Text(
              quoteError!,
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                color: AppColors.danger,
              ),
            ),
          ],
          if (isMobileMoney && quoteError == null) ...[
            const SizedBox(height: 10),
            Text(
              'Mobile money saves the fee and charged total with the todo recording.',
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: AppColors.textSecondary.withValues(alpha: 0.72),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MoneyStat extends StatelessWidget {
  const _MoneyStat({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 118),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.black.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.frequencyLabel,
    required this.value,
    required this.detail,
  });

  final String title;
  final String frequencyLabel;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            frequencyLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.primary.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({required this.value, this.onTap});

  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedCalendar03,
              size: 16,
              color: AppColors.textSecondary,
              strokeWidth: 1.8,
            ),
            const SizedBox(width: 10),
            Text(
              formatTodoDate(parseDateOnly(value)),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientDivider extends StatelessWidget {
  const _GradientDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            color.withValues(alpha: 0.45),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.onTap,
    required this.isPrimary,
    this.isLoading = false,
    this.isDisabled = false,
  });

  final String label;
  final Future<void> Function() onTap;
  final bool isPrimary;
  final bool isLoading;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = isPrimary
        ? (isDisabled
              ? AppColors.primary.withValues(alpha: 0.55)
              : AppColors.primary)
        : (isDisabled
              ? AppColors.textSecondary.withValues(alpha: 0.45)
              : AppColors.textPrimary);

    return GestureDetector(
      onTap: isDisabled || isLoading ? null : () => onTap(),
      child: AppModalActionButton(
        label: label,
        isPrimary: isPrimary,
        isLoading: isLoading,
        onPressed: isDisabled || isLoading ? null : () => onTap(),
        primaryColor: AppColors.primary,
        primaryForegroundColor: AppColors.background,
        outlineForegroundColor: foregroundColor,
      ),
    );
  }
}
