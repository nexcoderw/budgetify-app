import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../expenses/data/models/expense_entry.dart';
import '../../data/models/todo_item.dart';
import '../todo_utils.dart';

class TodoExpenseDialog extends StatefulWidget {
  const TodoExpenseDialog({
    super.key,
    required this.entry,
    required this.categories,
    required this.onSubmit,
  });

  final TodoItem entry;
  final List<ExpenseCategoryOption> categories;
  final Future<void> Function({
    required double amount,
    required ExpenseCategory category,
    required String date,
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
  }

  @override
  void dispose() {
    _controller.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recurring = isRecurringTodo(widget.entry);
    final remainingDates = getRemainingOccurrenceDates(widget.entry);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.15),
                      Colors.white.withValues(alpha: 0.08),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 48,
                      offset: const Offset(0, 20),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
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
                                      : 'This records the expense and marks the todo as done.',
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
                          GestureDetector(
                            onTap: _isSubmitting
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.07),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                              ),
                              child: const Center(
                                child: HugeIcon(
                                  icon: HugeIcons.strokeRoundedCancel01,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
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
                            : (value) =>
                                  setState(() => _selectedCategory = value),
                        decoration: _inputDecoration(),
                        dropdownColor: AppColors.surfaceElevated,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
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
                                  child: Text(
                                    formatTodoDate(parseDateOnly(date)),
                                  ),
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
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ],
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
          ),
        ),
      ),
    );
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

    if (isRecurringTodo(widget.entry) &&
        widget.entry.remainingAmount != null &&
        amount > widget.entry.remainingAmount!) {
      setState(() {
        _errorText = 'Amount cannot exceed the remaining recurring budget.';
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
    final backgroundColor = isPrimary
        ? AppColors.primary.withValues(alpha: isDisabled ? 0.12 : 0.16)
        : Colors.white.withValues(alpha: 0.05);
    final borderColor = isPrimary
        ? AppColors.primary.withValues(alpha: isDisabled ? 0.16 : 0.24)
        : Colors.white.withValues(alpha: 0.12);
    final foregroundColor = isPrimary
        ? (isDisabled
              ? AppColors.primary.withValues(alpha: 0.55)
              : AppColors.primary)
        : (isDisabled
              ? AppColors.textSecondary.withValues(alpha: 0.45)
              : AppColors.textPrimary);

    return GestureDetector(
      onTap: isDisabled || isLoading ? null : () => onTap(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: backgroundColor,
          border: Border.all(color: borderColor),
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: foregroundColor,
                  ),
                ),
        ),
      ),
    );
  }
}
