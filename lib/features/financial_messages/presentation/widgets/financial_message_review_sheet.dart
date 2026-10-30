import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dropdown.dart';
import '../../../../core/widgets/app_input.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../home/data/models/received_transaction_models.dart';
import '../../../home/presentation/widgets/record_received_money/received_date_sheet.dart';
import '../../../incomes/data/models/income.dart';
import '../../application/financial_message_import_service.dart';
import '../../data/models/financial_message_import.dart';

class FinancialMessageReviewSheet extends StatefulWidget {
  const FinancialMessageReviewSheet({
    super.key,
    required this.importId,
    required this.service,
  });

  final String importId;
  final FinancialMessageImportService service;

  @override
  State<FinancialMessageReviewSheet> createState() =>
      _FinancialMessageReviewSheetState();
}

class _FinancialMessageReviewSheetState
    extends State<FinancialMessageReviewSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _senderController = TextEditingController();
  final _numberController = TextEditingController();
  final _referenceController = TextEditingController();
  final _incomeLabelController = TextEditingController();
  final _noteController = TextEditingController();

  FinancialMessageImport? _item;
  ReceivedTransactionClassification _classification =
      ReceivedTransactionClassification.unclassified;
  IncomeCategory _incomeCategory = IncomeCategory.other;
  DateTime _occurredAt = DateTime.now();
  bool _createIncome = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _editable => _item?.status == FinancialMessageImportStatus.pending;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _amountController.dispose();
    _senderController.dispose();
    _numberController.dispose();
    _referenceController.dispose();
    _incomeLabelController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final item = await widget.service.detail(widget.importId);
      if (!mounted) {
        return;
      }
      _amountController.text = _wholeAmount(item.amount);
      _senderController.text = item.senderName ?? '';
      _numberController.text = item.senderIdentifier ?? '';
      _referenceController.text = item.providerReference ?? '';
      setState(() {
        _item = item;
        _occurredAt = item.occurredAt ?? item.messageReceivedAt;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = _message(error);
      });
    }
  }

  Future<void> _pickDate() async {
    final selected = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReceivedDateSheet(
        initialDate: _occurredAt,
        firstYear: 2000,
        lastDate: DateTime.now(),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _occurredAt = selected);
    }
  }

  Future<void> _confirm() async {
    if (!(_formKey.currentState?.validate() ?? false) || _saving) {
      return;
    }
    if (_senderController.text.trim().isEmpty &&
        _numberController.text.trim().isEmpty) {
      AppToast.error(
        context,
        title: 'Sender required',
        description: 'Add the sender name or phone number.',
      );
      return;
    }
    if (_createIncome && _incomeLabelController.text.trim().isEmpty) {
      AppToast.error(
        context,
        title: 'Income name required',
        description: 'Add a short name for this income.',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.service.update(
        id: widget.importId,
        amount: int.parse(_amountController.text),
        occurredAt: _occurredAt,
        senderName: _senderController.text,
        senderIdentifier: _numberController.text,
        providerReference: _referenceController.text,
      );
      await widget.service.confirm(
        id: widget.importId,
        classification: _classification,
        createIncome: _createIncome,
        note: _noteController.text,
        incomeCategory: _createIncome ? _incomeCategory : null,
        incomeLabel: _createIncome ? _incomeLabelController.text : null,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      AppToast.error(
        context,
        title: 'Could not record payment',
        description: _message(error),
      );
    }
  }

  Future<void> _dismiss() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Dismiss this message?'),
        content: const Text(
          'It will not become a transaction, and its private message text will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Dismiss',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.service.dismiss(widget.importId);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      AppToast.error(
        context,
        title: 'Could not dismiss message',
        description: _message(error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.62,
      maxChildSize: 0.96,
      builder: (context, controller) => DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _ErrorState(message: _error!, onRetry: () => unawaited(_load()))
            : _buildContent(controller),
      ),
    );
  }

  Widget _buildContent(ScrollController controller) {
    final item = _item!;
    return Form(
      key: _formKey,
      child: ListView(
        controller: controller,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            item.sourceLabel,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Review received payment',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 22),
          AppInput(
            controller: _amountController,
            label: 'Amount (RWF)',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            enabled: _editable && !_saving,
            validator: (value) => (int.tryParse(value ?? '') ?? 0) < 1
                ? 'Enter the received amount.'
                : null,
          ),
          const SizedBox(height: 14),
          AppInput(
            controller: _senderController,
            label: 'Sender name',
            enabled: _editable && !_saving,
          ),
          const SizedBox(height: 14),
          AppInput(
            controller: _numberController,
            label: 'Sender phone or account',
            keyboardType: TextInputType.phone,
            enabled: _editable && !_saving,
          ),
          const SizedBox(height: 14),
          AppInput(
            controller: _referenceController,
            label: 'Payment reference',
            enabled: _editable && !_saving,
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: _editable && !_saving ? () => unawaited(_pickDate()) : null,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 18),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_dateLabel(_occurredAt))),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          AppDropdown<ReceivedTransactionClassification>(
            tooltip: 'Payment classification',
            label: _classification.label,
            enabled: _editable && !_saving,
            isActive: true,
            onSelected: (value) {
              setState(() {
                _classification = value;
                if (value != ReceivedTransactionClassification.income) {
                  _createIncome = false;
                }
              });
            },
            items: [
              for (final value in ReceivedTransactionClassification.values)
                AppDropdownItem(
                  value: value,
                  label: value.label,
                  selected: value == _classification,
                ),
            ],
          ),
          if (_classification == ReceivedTransactionClassification.income) ...[
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Add to income',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Create an income record from this payment.',
                style: TextStyle(fontSize: 12),
              ),
              value: _createIncome,
              onChanged: _editable && !_saving
                  ? (value) => setState(() => _createIncome = value)
                  : null,
            ),
            if (_createIncome) ...[
              AppInput(
                controller: _incomeLabelController,
                label: 'Income name',
                enabled: !_saving,
              ),
              const SizedBox(height: 12),
              AppDropdown<IncomeCategory>(
                tooltip: 'Income category',
                label: _incomeCategory.label,
                enabled: !_saving,
                onSelected: (value) => setState(() => _incomeCategory = value),
                items: [
                  for (final value in IncomeCategory.values)
                    AppDropdownItem(
                      value: value,
                      label: value.label,
                      selected: value == _incomeCategory,
                    ),
                ],
              ),
            ],
          ],
          const SizedBox(height: 14),
          AppInput(
            controller: _noteController,
            label: 'Note (optional)',
            maxLines: 3,
            enabled: _editable && !_saving,
          ),
          if (item.rawMessage != null) ...[
            const SizedBox(height: 16),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'Original message',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              children: [
                SelectableText(
                  item.rawMessage!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ],
          if (_editable) ...[
            const SizedBox(height: 22),
            AppButton(
              label: 'Record payment',
              icon: HugeIcons.strokeRoundedMoneyReceiveCircle,
              isLoading: _saving,
              onPressed: _saving ? null : () => unawaited(_confirm()),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _saving ? null : () => unawaited(_dismiss()),
              child: const Text(
                'Dismiss message',
                style: TextStyle(color: AppColors.danger, fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

String _wholeAmount(String? value) => value?.split('.').first ?? '';

String _dateLabel(DateTime date) {
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

String _message(Object error) {
  if (error is ApiException) {
    return error.message;
  }
  return 'Please check your connection and try again.';
}
