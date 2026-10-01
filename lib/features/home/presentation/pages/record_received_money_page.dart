import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../application/received_transaction_service.dart';
import '../widgets/record_received_money/received_date_sheet.dart';
import '../widgets/record_received_money/record_received_money_form.dart';
import '../widgets/record_received_money/record_received_money_top_bar.dart';
import '../widgets/record_received_money/record_received_money_validation.dart';

bool get supportsManualReceivedPaymentEntry {
  return !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
}

class RecordReceivedMoneyPage extends StatefulWidget {
  const RecordReceivedMoneyPage({super.key, this.receivedTransactionService});

  final ReceivedTransactionService? receivedTransactionService;

  @override
  State<RecordReceivedMoneyPage> createState() =>
      _RecordReceivedMoneyPageState();
}

class _RecordReceivedMoneyPageState extends State<RecordReceivedMoneyPage> {
  final _formKey = GlobalKey<FormState>();

  final _amountController = TextEditingController();

  final _senderNameController = TextEditingController();

  final _senderIdentifierController = TextEditingController();

  final _providerReferenceController = TextEditingController();

  final _receivedDateController = TextEditingController();

  late final ReceivedTransactionService _receivedTransactionService;

  late final String _clientEventId;

  late DateTime _occurredAt;

  bool _isSaving = false;

  String? _senderError;

  @override
  void initState() {
    super.initState();

    _receivedTransactionService =
        widget.receivedTransactionService ??
        ReceivedTransactionService.createDefault();

    _clientEventId = _createClientEventId();

    _occurredAt = DateTime.now();

    _syncReceivedDate();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _senderNameController.dispose();
    _senderIdentifierController.dispose();
    _providerReferenceController.dispose();
    _receivedDateController.dispose();

    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) {
      return;
    }

    FocusScope.of(context).unfocus();

    final valid = _formKey.currentState?.validate() ?? false;

    final senderName = _senderNameController.text.trim();

    final senderIdentifier = _senderIdentifierController.text.trim();

    if (senderName.isEmpty && senderIdentifier.isEmpty) {
      setState(() {
        _senderError = 'Enter the sender name or sender number.';
      });

      return;
    }

    if (!valid) {
      return;
    }

    setState(() {
      _senderError = null;
      _isSaving = true;
    });

    final amount = int.parse(_amountController.text.trim());

    final providerReference = _providerReferenceController.text.trim();

    try {
      await _receivedTransactionService.recordManual(
        clientEventId: _clientEventId,
        amount: amount,
        occurredAt: _occurredAt,
        senderIdentifier: senderIdentifier.isEmpty ? null : senderIdentifier,
        senderName: senderName.isEmpty ? null : senderName,
        providerReference: providerReference.isEmpty ? null : providerReference,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Could not save received money',
        description: error.message,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Could not save received money',
        description:
            'Budgetify could not record this '
            'received payment. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _chooseReceivedDate() async {
    FocusScope.of(context).unfocus();

    final now = DateTime.now();

    final selectedDate = await showModalBottomSheet<DateTime>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) {
        return ReceivedDateSheet(
          initialDate: _occurredAt,
          firstYear: now.year - 10,
          lastDate: now,
        );
      },
    );

    if (!mounted || selectedDate == null) {
      return;
    }

    final currentTime = _occurredAt;

    setState(() {
      _occurredAt = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        currentTime.hour,
        currentTime.minute,
        currentTime.second,
        currentTime.millisecond,
        currentTime.microsecond,
      );

      _syncReceivedDate();
    });
  }

  void _syncReceivedDate() {
    _receivedDateController.text = formatReceivedDate(_occurredAt);
  }

  void _clearSenderError() {
    if (_senderError == null) {
      return;
    }

    setState(() {
      _senderError = null;
    });
  }

  String _createClientEventId() {
    final random = Random.secure();

    final entropy = List<int>.generate(16, (_) => random.nextInt(256)).map((
      value,
    ) {
      return value.toRadixString(16).padLeft(2, '0');
    }).join();

    return 'manual-received-'
        '${DateTime.now().microsecondsSinceEpoch}-'
        '$entropy';
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 420;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RecordReceivedMoneyTopBar(
                    onBack: _isSaving
                        ? null
                        : () {
                            Navigator.of(context).pop();
                          },
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: RecordReceivedMoneyForm(
                      formKey: _formKey,
                      amountController: _amountController,
                      senderNameController: _senderNameController,
                      senderIdentifierController: _senderIdentifierController,
                      providerReferenceController: _providerReferenceController,
                      receivedDateController: _receivedDateController,
                      compact: compact,
                      isSaving: _isSaving,
                      senderError: _senderError,
                      amountValidator: validateReceivedAmount,
                      senderIdentifierValidator:
                          validateReceivedSenderIdentifier,
                      providerReferenceValidator:
                          validateReceivedProviderReference,
                      onSenderChanged: _clearSenderError,
                      onChooseReceivedDate: () {
                        _chooseReceivedDate();
                      },
                      onSubmit: () {
                        _submit();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
