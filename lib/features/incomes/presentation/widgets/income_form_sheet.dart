import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dropdown.dart';
import '../../../../core/widgets/app_input.dart';
import '../../../home/presentation/widgets/record_received_money/received_date_sheet.dart';
import '../../application/income_service.dart';
import '../../data/models/income.dart';

class IncomeFormSheet extends StatefulWidget {
  const IncomeFormSheet({super.key, required this.service, this.record});
  final IncomeService service;
  final IncomeRecord? record;
  @override
  State<IncomeFormSheet> createState() => _IncomeFormSheetState();
}

class _IncomeFormSheetState extends State<IncomeFormSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _amount;
  final _dateText = TextEditingController();
  late DateTime _date;
  late IncomeCategory _category;
  bool _received = false;
  bool _saving = false;
  String? _error;
  late final String _requestId;
  bool get _locked => widget.record != null && !widget.record!.isExpected;

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.record?.label ?? '');
    _amount = TextEditingController(text: widget.record?.amount ?? '');
    _date = widget.record?.date ?? DateTime.now();
    _category = widget.record?.category ?? IncomeCategory.salary;
    _received = widget.record != null && !widget.record!.isExpected;
    _dateText.text = formatReceivedDate(_date);
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    _requestId =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  @override
  void dispose() {
    _label.dispose();
    _amount.dispose();
    _dateText.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReceivedDateSheet(
        initialDate: _date,
        firstYear: now.year - 10,
        lastDate: _received ? now : DateTime(now.year + 10, 12, 31),
      ),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _date = picked;
      _dateText.text = formatReceivedDate(picked);
    });
  }

  Future<void> _save() async {
    if (_saving || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.save({
        'label': _label.text.trim(),
        'category': _category.apiValue,
        if (!_locked) 'amount': int.parse(_amount.text),
        if (!_locked) 'date': _date.toUtc().toIso8601String(),
        if (widget.record == null) 'received': _received,
        if (widget.record == null) 'clientEventId': _requestId,
      }, id: widget.record?.id);
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is ApiException
            ? error.message
            : 'Could not save income. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: FractionallySizedBox(
      heightFactor: 0.9,
      child: Material(
        color: AppColors.backgroundSecondary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.record == null ? 'Add income' : 'Edit income',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close income form',
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    8,
                    24,
                    24 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.record == null) ...[
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final received in [false, true])
                                ChoiceChip(
                                  label: Text(
                                    received ? 'Already received' : 'Expected',
                                  ),
                                  selected: _received == received,
                                  onSelected: _saving
                                      ? null
                                      : (_) => setState(() {
                                          _received = received;
                                          if (received &&
                                              _date.isAfter(DateTime.now())) {
                                            _date = DateTime.now();
                                            _dateText.text = formatReceivedDate(
                                              _date,
                                            );
                                          }
                                        }),
                                  selectedColor: AppColors.primary,
                                  backgroundColor: AppColors.surface,
                                  labelStyle: TextStyle(
                                    fontSize: 12,
                                    color: _received == received
                                        ? AppColors.background
                                        : AppColors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                        AppInput(
                          controller: _label,
                          label: 'Income name',
                          hintText: 'Monthly salary',
                          maxLength: 120,
                          enabled: !_saving,
                          validator: (value) => (value?.trim().isEmpty ?? true)
                              ? 'Enter an income name.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        AppInput(
                          controller: _amount,
                          label: 'Amount (RWF)',
                          enabled: !_saving && !_locked,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          maxLength: 12,
                          validator: (value) {
                            if (_locked) return null;
                            final amount = int.tryParse(value ?? '');
                            return amount == null ||
                                    amount < 1 ||
                                    amount > 999999999999
                                ? 'Enter a positive whole RWF amount.'
                                : null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: AppDropdown<IncomeCategory>(
                            tooltip: 'Income category',
                            label: _category.label,
                            enabled: !_saving,
                            isActive: true,
                            items: [
                              for (final category in IncomeCategory.values)
                                AppDropdownItem(
                                  value: category,
                                  label: category.label,
                                  selected: _category == category,
                                ),
                            ],
                            onSelected: (category) =>
                                setState(() => _category = category),
                          ),
                        ),
                        const SizedBox(height: 16),
                        AppInput(
                          controller: _dateText,
                          label: _received ? 'Received date' : 'Expected date',
                          readOnly: true,
                          enabled: !_saving && !_locked,
                          onTap: _pickDate,
                          suffixIcon: const Icon(
                            Icons.calendar_today_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                        if (_locked) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Received amounts and dates are locked to keep your records consistent.',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.danger,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Center(
                          child: SizedBox(
                            width: 220,
                            child: AppButton(
                              label: 'Save income',
                              iconWidget: const Icon(Icons.check_rounded),
                              size: AppButtonSize.md,
                              isLoading: _saving,
                              onPressed: _saving ? null : _save,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
