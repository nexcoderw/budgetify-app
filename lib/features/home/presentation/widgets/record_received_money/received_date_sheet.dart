import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/app_button.dart';

class ReceivedDateSheet extends StatefulWidget {
  const ReceivedDateSheet({
    super.key,
    required this.initialDate,
    required this.firstYear,
    required this.lastDate,
  });

  final DateTime initialDate;
  final int firstYear;
  final DateTime lastDate;

  @override
  State<ReceivedDateSheet> createState() => _ReceivedDateSheetState();
}

class _ReceivedDateSheetState extends State<ReceivedDateSheet> {
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

  DateTime get _selectedDate {
    return DateTime(_year, _month, _day);
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
              formatReceivedDate(_selectedDate),
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

String formatReceivedDate(DateTime value) {
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

  return '${value.day} '
      '${months[value.month - 1]} '
      '${value.year}';
}
