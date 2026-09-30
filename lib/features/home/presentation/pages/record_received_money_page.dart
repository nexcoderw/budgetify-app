import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_input.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../application/received_transaction_service.dart';

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
  static const int _maximumAmount = 10_000_000;

  final _formKey = GlobalKey<FormState>();

  final _amountController = TextEditingController();

  final _senderNameController = TextEditingController();

  final _senderIdentifierController = TextEditingController();

  final _providerReferenceController = TextEditingController();

  late final ReceivedTransactionService _receivedTransactionService;

  late final String _clientEventId;

  DateTime _occurredAt = DateTime.now();

  bool _isSaving = false;

  String? _senderError;

  @override
  void initState() {
    super.initState();

    _receivedTransactionService =
        widget.receivedTransactionService ??
        ReceivedTransactionService.createDefault();

    _clientEventId = _createClientEventId();
  }

  @override
  void dispose() {
    _amountController.dispose();

    _senderNameController.dispose();

    _senderIdentifierController.dispose();

    _providerReferenceController.dispose();

    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) {
      return;
    }

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

    final amount = int.parse(_amountController.text);

    try {
      await _receivedTransactionService.recordManual(
        clientEventId: _clientEventId,
        amount: amount,
        occurredAt: _occurredAt,
        senderIdentifier: senderIdentifier.isEmpty ? null : senderIdentifier,
        senderName: senderName.isEmpty ? null : senderName,
        providerReference: _providerReferenceController.text.trim().isEmpty
            ? null
            : _providerReferenceController.text.trim(),
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
            'Budgetify could not record this received payment. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _chooseOccurredAt() async {
    final now = DateTime.now();

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(now.year - 10),
      lastDate: now.add(const Duration(days: 1)),
    );

    if (!mounted || selectedDate == null) {
      return;
    }

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );

    if (!mounted || selectedTime == null) {
      return;
    }

    final candidate = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    if (candidate.isAfter(now.add(const Duration(minutes: 5)))) {
      AppToast.error(
        context,
        title: 'Invalid received time',
        description: 'The received-payment time cannot be in the future.',
      );

      return;
    }

    setState(() {
      _occurredAt = candidate;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TopBar(
                      onBack: _isSaving
                          ? null
                          : () {
                              Navigator.of(context).pop();
                            },
                    ),
                    const SizedBox(height: 26),
                    const Text(
                      'RECEIVED MONEY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Record received money',
                      style: TextStyle(
                        fontSize: 28,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 9),
                    const Text(
                      'Use this when Budgetify cannot read the MTN transaction message automatically.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'This payment will be stored as manually reported evidence. Budgetify will not describe it as MTN-verified.',
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    AppInput(
                      controller: _amountController,
                      label: 'Amount (RWF)',
                      hintText: '25000',
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: _validateAmount,
                    ),
                    const SizedBox(height: 14),
                    AppInput(
                      controller: _senderNameController,
                      label: 'Sender name',
                      hintText: 'Jean Claude',
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      maxLength: 120,
                      onChanged: (_) => _clearSenderError(),
                    ),
                    const SizedBox(height: 14),
                    AppInput(
                      controller: _senderIdentifierController,
                      label: 'Sender number',
                      hintText: '0788123456',
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9+\s()-]'),
                        ),
                      ],
                      maxLength: 35,
                      validator: _validateSenderIdentifier,
                      onChanged: (_) => _clearSenderError(),
                    ),
                    if (_senderError != null) ...[
                      const SizedBox(height: 7),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          _senderError!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    AppInput(
                      controller: _providerReferenceController,
                      label: 'Transaction reference (optional)',
                      hintText: 'Financial transaction ID',
                      textInputAction: TextInputAction.done,
                      maxLength: 128,
                      validator: _validateProviderReference,
                    ),
                    const SizedBox(height: 18),
                    _OccurredAtCard(
                      occurredAt: _occurredAt,
                      onTap: _isSaving
                          ? null
                          : () {
                              _chooseOccurredAt();
                            },
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Save received money',
                      icon: HugeIcons.strokeRoundedMoneyReceiveCircle,
                      isLoading: _isSaving,
                      onPressed: _isSaving
                          ? null
                          : () {
                              _submit();
                            },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _validateAmount(String? value) {
    final amount = int.tryParse(value?.trim() ?? '');

    if (amount == null || amount <= 0) {
      return 'Enter a valid amount.';
    }

    if (amount > _maximumAmount) {
      return 'Amount cannot exceed 10,000,000 RWF.';
    }

    return null;
  }

  String? _validateSenderIdentifier(String? value) {
    final raw = value?.trim() ?? '';

    if (raw.isEmpty) {
      return null;
    }

    final compact = raw.replaceAll(RegExp(r'[\s()-]'), '');

    if (!RegExp(r'^\+?\d{3,34}$').hasMatch(compact)) {
      return 'Enter a valid sender number.';
    }

    return null;
  }

  String? _validateProviderReference(String? value) {
    final reference = value?.trim() ?? '';

    if (reference.isEmpty) {
      return null;
    }

    if (reference.length < 3) {
      return 'Reference is too short.';
    }

    if (!RegExp(r'^[A-Za-z0-9._:/-]+$').hasMatch(reference)) {
      return 'Reference contains unsupported characters.';
    }

    return null;
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

    final entropy = List<int>.generate(
      16,
      (_) => random.nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();

    return 'manual-received-${DateTime.now().microsecondsSinceEpoch}-$entropy';
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Tooltip(
        message: 'Back',
        child: Material(
          color: AppColors.surfaceElevated,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onBack,
            customBorder: const CircleBorder(),
            child: const SizedBox.square(
              dimension: 44,
              child: Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowLeft01,
                  size: 19,
                  strokeWidth: 1.9,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OccurredAtCard extends StatelessWidget {
  const _OccurredAtCard({required this.occurredAt, required this.onTap});

  final DateTime occurredAt;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const HugeIcon(
                  icon: HugeIcons.strokeRoundedTransactionHistory,
                  size: 19,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Received on',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _formatDateTime(occurredAt),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Change',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: onTap == null
                      ? AppColors.textSecondary
                      : AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  String two(int number) {
    return number.toString().padLeft(2, '0');
  }

  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}
