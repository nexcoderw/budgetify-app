import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/app_dropdown.dart';
import '../../../../../core/widgets/app_input.dart';
import '../../../data/models/transaction_history_models.dart';
import '../../../data/models/transaction_models.dart';
import '../record_received_money/received_date_sheet.dart';

enum _InsightsPeriod {
  thisMonth('This month'),
  thisWeek('This week'),
  lastMonth('Last month'),
  lastYear('Last year'),
  custom('Custom');

  const _InsightsPeriod(this.label);
  final String label;
}

class HistoryInsights extends StatefulWidget {
  const HistoryInsights({
    super.key,
    required this.transactions,
    required this.errorMessage,
    required this.onRetry,
  });

  final List<TransactionHistoryItem> transactions;
  final String? errorMessage;
  final VoidCallback onRetry;

  @override
  State<HistoryInsights> createState() => _HistoryInsightsState();
}

class _HistoryInsightsState extends State<HistoryInsights> {
  _InsightsPeriod _period = _InsightsPeriod.thisMonth;
  late DateTime _customFrom;
  late DateTime _customTo;
  final _fromController = TextEditingController();
  final _toController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _customFrom = DateTime(now.year, now.month);
    _customTo = DateTime(now.year, now.month, now.day);
    _syncDates();
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  void _syncDates() {
    _fromController.text = formatReceivedDate(_customFrom);
    _toController.text = formatReceivedDate(_customTo);
  }

  ({DateTime from, DateTime until}) _range(DateTime now) {
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return switch (_period) {
      _InsightsPeriod.thisMonth => (
        from: DateTime(now.year, now.month),
        until: tomorrow,
      ),
      _InsightsPeriod.thisWeek => (
        from: DateTime(now.year, now.month, now.day - now.weekday + 1),
        until: tomorrow,
      ),
      _InsightsPeriod.lastYear => (
        from: DateTime(now.year - 1),
        until: DateTime(now.year),
      ),
      _InsightsPeriod.lastMonth => (
        from: DateTime(now.year, now.month - 1),
        until: DateTime(now.year, now.month),
      ),
      _InsightsPeriod.custom => (
        from: _customFrom,
        until: DateTime(_customTo.year, _customTo.month, _customTo.day + 1),
      ),
    };
  }

  Future<void> _chooseDate({required bool from}) async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    var firstYear = now.year - 10;
    for (final transaction in widget.transactions) {
      firstYear = math.min(firstYear, transaction.activityAt.toLocal().year);
    }
    final selected = await showModalBottomSheet<DateTime>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) => ReceivedDateSheet(
        initialDate: from ? _customFrom : _customTo,
        firstYear: firstYear,
        lastDate: now,
      ),
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      final date = DateTime(selected.year, selected.month, selected.day);
      if (from) {
        _customFrom = date;
      } else {
        _customTo = date;
      }
      _syncDates();
    });
  }

  static const _colors = [
    AppColors.primary,
    Color(0xFF7CAFA5),
    Color(0xFF819AC0),
    Color(0xFFC79B80),
    Color(0xFFA394BC),
    Color(0xFFB9BD82),
    Color(0xFF76A4B9),
    Color(0xFFC48792),
    Color(0xFFB59C65),
    Color(0xFF89AD84),
    Color(0xFF8C929E),
  ];

  String _amount(int value) => value.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );

  @override
  Widget build(BuildContext context) {
    final invalidRange = _period == _InsightsPeriod.custom &&
        _customFrom.isAfter(_customTo);
    final range = _range(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: AppDropdown<_InsightsPeriod>(
            tooltip: 'Choose insights period',
            label: _period.label,
            isActive: true,
            onSelected: (period) => setState(() => _period = period),
            items: [
              for (final period in _InsightsPeriod.values)
                AppDropdownItem(
                  value: period,
                  selected: _period == period,
                  label: period.label,
                ),
            ],
          ),
        ),
        if (_period == _InsightsPeriod.custom) ...[
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final fields = [
                AppInput(
                  controller: _fromController,
                  label: 'From date',
                  readOnly: true,
                  borderRadius: 28,
                  onTap: () => _chooseDate(from: true),
                  suffixIcon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.primary,
                  ),
                ),
                AppInput(
                  controller: _toController,
                  label: 'To date',
                  readOnly: true,
                  borderRadius: 28,
                  onTap: () => _chooseDate(from: false),
                  suffixIcon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.primary,
                  ),
                ),
              ];
              if (constraints.maxWidth < 420) {
                return Column(
                  children: [fields[0], const SizedBox(height: 12), fields[1]],
                );
              }
              return Row(
                children: [
                  Expanded(child: fields[0]),
                  const SizedBox(width: 12),
                  Expanded(child: fields[1]),
                ],
              );
            },
          ),
        ],
        const SizedBox(height: 20),
        if (invalidRange)
          const Text(
            'From date must be on or before To date.',
            style: TextStyle(color: AppColors.danger),
          )
        else
          _buildSummary(context, range.from, range.until),
      ],
    );
  }

  Widget _buildSummary(BuildContext context, DateTime from, DateTime until) {
    final error = widget.errorMessage;
    if (error != null) {
      return Column(
        children: [
          Text(error, style: const TextStyle(color: AppColors.textSecondary)),
          TextButton(onPressed: widget.onRetry, child: const Text('Try again')),
        ],
      );
    }

    final totals = <TransactionCategory, int>{};
    for (final transaction in widget.transactions) {
      final activityAt = transaction.activityAt.toLocal();
      if (!transaction.isSent ||
          transaction.status != TransactionStatus.completed ||
          transaction.currency != 'RWF' ||
          transaction.amount <= 0 ||
          activityAt.isBefore(from) ||
          !activityAt.isBefore(until)) {
        continue;
      }
      final category = transaction.category ?? TransactionCategory.other;
      totals.update(
        category,
        (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }
    final categories = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = categories.fold<int>(0, (sum, item) => sum + item.value);

    if (total == 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Text(
            'No completed payments in this period.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Spending by category',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${formatReceivedDate(from)} – '
          '${formatReceivedDate(DateTime(until.year, until.month, until.day - 1))}'
          '\nCompleted payments · Excludes fees',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        Text(
          '${_amount(total)} RWF',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AspectRatio(
              aspectRatio: 1.5,
              child: ExcludeSemantics(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _CategoryPiePainter(
                      amounts: categories.map((item) => item.value).toList(),
                      colors: [
                        for (final item in categories)
                          _colors[item.key.index % _colors.length],
                      ],
                      total: total,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final item in categories)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _colors[item.key.index % _colors.length],
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  fit: FlexFit.tight,
                  child: Text(
                    item.key.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  fit: FlexFit.tight,
                  child: Text(
                    '${_amount(item.value)} RWF',
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${(item.value / total * 100).toStringAsFixed(1)}%',
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CategoryPiePainter extends CustomPainter {
  const _CategoryPiePainter({
    required this.amounts,
    required this.colors,
    required this.total,
  });

  final List<int> amounts;
  final List<Color> colors;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 8);
    final radiusX = size.width * 0.43;
    final radiusY = radiusX * 0.57;
    final top = Rect.fromCenter(
      center: center,
      width: radiusX * 2,
      height: radiusY * 2,
    );
    final shadow = Rect.fromCenter(
      center: center + const Offset(0, 26),
      width: radiusX * 2,
      height: radiusY * 2,
    );
    canvas.drawOval(
      shadow,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    // Stacked elliptical sectors create depth without distorting category shares.
    for (var depth = 18; depth >= 0; depth--) {
      var angle = -math.pi / 2;
      for (var index = 0; index < amounts.length; index++) {
        final sweep = amounts[index] / total * math.pi * 2;
        final color = colors[index];
        final paint = Paint()
          ..color = depth == 0
              ? color
              : Color.lerp(color, Colors.black, 0.35)!;
        canvas.drawArc(
          top.shift(Offset(0, depth.toDouble())),
          angle,
          sweep,
          true,
          paint,
        );
        angle += sweep;
      }
    }
    var angle = -math.pi / 2;
    for (final amount in amounts) {
      canvas.drawLine(
        center,
        center + Offset(radiusX * math.cos(angle), radiusY * math.sin(angle)),
        Paint()
          ..color = AppColors.background.withValues(alpha: 0.4)
          ..strokeWidth = 1,
      );
      angle += amount / total * math.pi * 2;
    }
  }

  @override
  bool shouldRepaint(covariant _CategoryPiePainter oldDelegate) {
    return oldDelegate.total != total ||
        oldDelegate.amounts.toString() != amounts.toString() ||
        oldDelegate.colors.toString() != colors.toString();
  }
}
