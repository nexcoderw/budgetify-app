import 'dart:math';

import 'package:flutter/cupertino.dart';
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

  Future<void> _chooseReceivedDate() async {
    FocusScope.of(context).unfocus();

    final selectedDate = await showModalBottomSheet<DateTime>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) {
        return _ReceivedDateSheet(
          initialDate: _occurredAt,
          firstYear: DateTime.now().year - 10,
          lastDate: DateTime.now(),
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
    _receivedDateController.text = _formatLongDate(_occurredAt);
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
                  _TopBar(
                    onBack: _isSaving
                        ? null
                        : () {
                            Navigator.of(context).pop();
                          },
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        compact ? 2 : 10,
                        0,
                        compact ? 2 : 10,
                        12,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Record received money',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    fontSize: compact ? 24 : 26,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.7,
                                    color: AppColors.textPrimary,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Add a payment you received manually.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.55,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 28),
                            AppInput(
                              controller: _amountController,
                              hintText: 'Amount received',
                              leadingIcon:
                                  HugeIcons.strokeRoundedMoneyReceiveCircle,
                              borderRadius: 28,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: _validateAmount,
                              suffixIcon: const Padding(
                                padding: EdgeInsets.only(right: 18),
                                child: Center(
                                  widthFactor: 1,
                                  child: Text(
                                    'RWF',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            AppInput(
                              controller: _senderNameController,
                              hintText: 'Sender name',
                              borderRadius: 28,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              maxLength: 120,
                              onChanged: (_) {
                                _clearSenderError();
                              },
                            ),
                            const SizedBox(height: 12),
                            AppInput(
                              controller: _senderIdentifierController,
                              hintText: 'Sender phone number',
                              borderRadius: 28,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9+\s()-]'),
                                ),
                              ],
                              maxLength: 35,
                              validator: _validateSenderIdentifier,
                              onChanged: (_) {
                                _clearSenderError();
                              },
                            ),
                            if (_senderError != null) ...[
                              const SizedBox(height: 7),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Text(
                                  _senderError!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.danger,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            AppInput(
                              controller: _providerReferenceController,
                              hintText: 'Transaction reference (optional)',
                              leadingIcon:
                                  HugeIcons.strokeRoundedTransactionHistory,
                              borderRadius: 28,
                              textInputAction: TextInputAction.next,
                              maxLength: 128,
                              validator: _validateProviderReference,
                            ),
                            const SizedBox(height: 12),
                            AppInput(
                              controller: _receivedDateController,
                              hintText: 'Received date',
                              leadingIcon:
                                  HugeIcons.strokeRoundedTransactionHistory,
                              borderRadius: 28,
                              readOnly: true,
                              onTap: _isSaving
                                  ? null
                                  : () {
                                      _chooseReceivedDate();
                                    },
                              suffixIcon: Padding(
                                padding: const EdgeInsets.only(right: 14),
                                child: Center(
                                  widthFactor: 1,
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.09,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 20,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 1),
                                  child: HugeIcon(
                                    icon: HugeIcons
                                        .strokeRoundedTransactionHistory,
                                    size: 15,
                                    strokeWidth: 1.7,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    'This entry is manually reported and is not an independent MTN confirmation.',
                                    style: TextStyle(
                                      fontSize: 10,
                                      height: 1.5,
                                      color: AppColors.textSecondary.withValues(
                                        alpha: 0.82,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 26),
                            AppButton(
                              label: 'Save received money',
                              icon: HugeIcons.strokeRoundedMoneyReceiveCircle,
                              size: AppButtonSize.lg,
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
                ],
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

    final entropy = List<int>.generate(16, (_) => random.nextInt(256)).map((
      value,
    ) {
      return value.toRadixString(16).padLeft(2, '0');
    }).join();

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
            child: SizedBox.square(
              dimension: 44,
              child: Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowLeft01,
                  size: 19,
                  strokeWidth: 1.9,
                  color: onBack == null
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReceivedDateSheet extends StatefulWidget {
  const _ReceivedDateSheet({
    required this.initialDate,
    required this.firstYear,
    required this.lastDate,
  });

  final DateTime initialDate;
  final int firstYear;
  final DateTime lastDate;

  @override
  State<_ReceivedDateSheet> createState() => _ReceivedDateSheetState();
}

class _ReceivedDateSheetState extends State<_ReceivedDateSheet> {
  static const double _itemExtent = 46;

  static const List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  late int _day;
  late int _month;
  late int _year;

  late final FixedExtentScrollController _dayController;
  late final FixedExtentScrollController _monthController;
  late final FixedExtentScrollController _yearController;

  int get _numberOfDays {
    return _daysInMonth(_year, _month);
  }

  @override
  void initState() {
    super.initState();

    final initial = _clampInitialDate(widget.initialDate);

    _day = initial.day;
    _month = initial.month;
    _year = initial.year;

    _dayController = FixedExtentScrollController(initialItem: _day - 1);

    _monthController = FixedExtentScrollController(initialItem: _month - 1);

    _yearController = FixedExtentScrollController(
      initialItem: _year - widget.firstYear,
    );
  }

  @override
  void dispose() {
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();

    super.dispose();
  }

  DateTime _clampInitialDate(DateTime date) {
    final firstDate = DateTime(widget.firstYear, 1, 1);

    final lastDate = _dateOnly(widget.lastDate);

    final candidate = _dateOnly(date);

    if (candidate.isBefore(firstDate)) {
      return firstDate;
    }

    if (candidate.isAfter(lastDate)) {
      return lastDate;
    }

    return candidate;
  }

  void _onDayChanged(int index) {
    setState(() {
      _day = index + 1;
    });

    _keepSelectionWithinAllowedDate();
  }

  void _onMonthChanged(int index) {
    setState(() {
      _month = index + 1;

      _day = min(_day, _numberOfDays);
    });

    _syncDayController();

    _keepSelectionWithinAllowedDate();
  }

  void _onYearChanged(int index) {
    setState(() {
      _year = widget.firstYear + index;

      _day = min(_day, _numberOfDays);
    });

    _syncDayController();

    _keepSelectionWithinAllowedDate();
  }

  void _keepSelectionWithinAllowedDate() {
    final candidate = DateTime(_year, _month, _day);

    final maximumDate = _dateOnly(widget.lastDate);

    if (!candidate.isAfter(maximumDate)) {
      return;
    }

    setState(() {
      _day = maximumDate.day;
      _month = maximumDate.month;
      _year = maximumDate.year;
    });

    _syncControllers();
  }

  void _syncDayController() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_dayController.hasClients) {
        return;
      }

      _dayController.jumpToItem(_day - 1);
    });
  }

  void _syncControllers() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_dayController.hasClients) {
        _dayController.jumpToItem(_day - 1);
      }

      if (_monthController.hasClients) {
        _monthController.jumpToItem(_month - 1);
      }

      if (_yearController.hasClients) {
        _yearController.jumpToItem(_year - widget.firstYear);
      }
    });
  }

  void _selectToday() {
    final today = _dateOnly(widget.lastDate);

    setState(() {
      _day = today.day;
      _month = today.month;
      _year = today.year;
    });

    _syncControllers();
  }

  DateTime get _selectedDate {
    return DateTime(_year, _month, _day);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 640),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        decoration: const BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Received date',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Choose the day, month and year.',
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _selectToday,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size(64, 44),
                  ),
                  child: const Text(
                    'Today',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            Container(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.7),
                ),
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Expanded(flex: 3, child: _PickerLabel(text: 'DAY')),
                      Expanded(flex: 5, child: _PickerLabel(text: 'MONTH')),
                      Expanded(flex: 4, child: _PickerLabel(text: 'YEAR')),
                    ],
                  ),

                  const SizedBox(height: 8),

                  SizedBox(
                    height: 156,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: 2,
                          right: 2,
                          child: IgnorePointer(
                            child: Container(
                              height: _itemExtent,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: CupertinoPicker.builder(
                                scrollController: _dayController,
                                itemExtent: _itemExtent,
                                diameterRatio: 1.55,
                                squeeze: 1.02,
                                useMagnifier: false,
                                selectionOverlay: const SizedBox.shrink(),
                                childCount: _numberOfDays,
                                onSelectedItemChanged: _onDayChanged,
                                itemBuilder: (_, index) {
                                  return _PickerText(text: '${index + 1}');
                                },
                              ),
                            ),

                            Expanded(
                              flex: 5,
                              child: CupertinoPicker(
                                scrollController: _monthController,
                                itemExtent: _itemExtent,
                                diameterRatio: 1.55,
                                squeeze: 1.02,
                                useMagnifier: false,
                                selectionOverlay: const SizedBox.shrink(),
                                onSelectedItemChanged: _onMonthChanged,
                                children: [
                                  for (final month in _months)
                                    _PickerText(text: month),
                                ],
                              ),
                            ),

                            Expanded(
                              flex: 4,
                              child: CupertinoPicker.builder(
                                scrollController: _yearController,
                                itemExtent: _itemExtent,
                                diameterRatio: 1.55,
                                squeeze: 1.02,
                                useMagnifier: false,
                                selectionOverlay: const SizedBox.shrink(),
                                childCount:
                                    widget.lastDate.year - widget.firstYear + 1,
                                onSelectedItemChanged: _onYearChanged,
                                itemBuilder: (_, index) {
                                  return _PickerText(
                                    text: '${widget.firstYear + index}',
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Text(
              _formatLongDate(_selectedDate),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 20),

            AppButton(
              label: 'Use this date',
              icon: HugeIcons.strokeRoundedTransactionHistory,
              onPressed: () {
                Navigator.of(context).pop(_selectedDate);
              },
            ),

            const SizedBox(height: 8),

            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                minimumSize: const Size(double.infinity, 44),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerLabel extends StatelessWidget {
  const _PickerLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 8,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _PickerText extends StatelessWidget {
  const _PickerText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.fade,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

int _daysInMonth(int year, int month) {
  final beginningOfNextMonth = month == 12
      ? DateTime(year + 1, 1, 1)
      : DateTime(year, month + 1, 1);

  return beginningOfNextMonth.subtract(const Duration(days: 1)).day;
}

String _formatLongDate(DateTime value) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  return '${value.day} ${months[value.month - 1]} ${value.year}';
}
