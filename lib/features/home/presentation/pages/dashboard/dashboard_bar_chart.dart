import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

class DashboardBarChart extends StatefulWidget {
  const DashboardBarChart({
    super.key,
    required this.dailySpending,
    required this.month,
    required this.year,
  });

  final List<double> dailySpending;
  final int month;
  final int year;

  @override
  State<DashboardBarChart> createState() => _DashboardBarChartState();
}

class _DashboardBarChartState extends State<DashboardBarChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  int? _hoveredDay;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(DashboardBarChart old) {
    super.didUpdateWidget(old);
    if (old.month != widget.month || old.year != widget.year) {
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ChartHeader(
                month: widget.month,
                year: widget.year,
                dailySpending: widget.dailySpending,
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 120,
                child: GestureDetector(
                  onTapDown: (d) => _onTap(d.localPosition, context),
                  onTapUp: (_) => setState(() => _hoveredDay = null),
                  child: AnimatedBuilder(
                    animation: _anim,
                    builder: (context, _) => CustomPaint(
                      size: const Size(double.infinity, 120),
                      painter: _BarChartPainter(
                        values: widget.dailySpending,
                        progress: _anim.value,
                        highlightDay: _hoveredDay,
                        primaryColor: AppColors.primary,
                        accentColor: AppColors.primary.withValues(alpha: 0.35),
                        todayIndex: _todayIndex,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _WeekLabels(days: widget.dailySpending.length),
            ],
          ),
        ),
      ),
    );
  }

  int? get _todayIndex {
    final now = DateTime.now();
    if (now.month == widget.month && now.year == widget.year) {
      return now.day - 1;
    }
    return null;
  }

  void _onTap(Offset local, BuildContext context) {
    final barCount = widget.dailySpending.length;
    final width = context.size?.width ?? 0;
    if (width == 0 || barCount == 0) return;
    final barWidth = width / barCount;
    final idx = (local.dx / barWidth).floor().clamp(0, barCount - 1);
    setState(() => _hoveredDay = idx);
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _ChartHeader extends StatelessWidget {
  const _ChartHeader({
    required this.month,
    required this.year,
    required this.dailySpending,
  });

  final int month;
  final int year;
  final List<double> dailySpending;

  static const _months = [
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

  @override
  Widget build(BuildContext context) {
    final avg = dailySpending.isEmpty
        ? 0.0
        : dailySpending.fold(0.0, (a, b) => a + b) / dailySpending.length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Spending',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${_months[month - 1]} $year  ·  avg \$${avg.toStringAsFixed(0)}/day',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: AppColors.primary.withValues(alpha: 0.12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.22),
            ),
          ),
          child: const Text(
            'Monthly',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Week labels ───────────────────────────────────────────────────────────────

class _WeekLabels extends StatelessWidget {
  const _WeekLabels({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    // Show week markers: W1, W2, W3, W4
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(4, (i) {
        return Text(
          'W${i + 1}',
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        );
      }),
    );
  }
}

// ── CustomPainter ─────────────────────────────────────────────────────────────

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({
    required this.values,
    required this.progress,
    required this.highlightDay,
    required this.primaryColor,
    required this.accentColor,
    required this.todayIndex,
  });

  final List<double> values;
  final double progress;
  final int? highlightDay;
  final Color primaryColor;
  final Color accentColor;
  final int? todayIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final maxVal = values.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) return;

    final barCount = values.length;
    final totalBarWidth = size.width / barCount;
    final barPad = totalBarWidth * 0.22;
    final barW = totalBarWidth - barPad * 2;

    // Grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (int i = 1; i <= 3; i++) {
      final y = size.height * (1 - i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (int i = 0; i < barCount; i++) {
      final barH = (values[i] / maxVal) * size.height * progress;
      final x = i * totalBarWidth + barPad;
      final y = size.height - barH;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, y, barW, barH),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );

      final isHighlighted = highlightDay == i;
      final isToday = todayIndex == i;

      final barColor = isHighlighted
          ? primaryColor
          : isToday
          ? primaryColor.withValues(alpha: 0.85)
          : accentColor;

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            barColor.withValues(alpha: isHighlighted ? 1.0 : 0.9),
            barColor.withValues(alpha: isHighlighted ? 0.6 : 0.4),
          ],
        ).createShader(Rect.fromLTWH(x, y, barW, barH));

      canvas.drawRRect(rect, paint);

      // Today indicator dot
      if (isToday) {
        canvas.drawCircle(
          Offset(x + barW / 2, y - 5),
          2.5,
          Paint()..color = primaryColor,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.progress != progress ||
      old.highlightDay != highlightDay ||
      old.values != values;
}
