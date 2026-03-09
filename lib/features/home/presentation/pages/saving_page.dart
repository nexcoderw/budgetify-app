import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_panel.dart';

class _SavingData {
  static const double totalSavings = 18650;
  static const double shortTerm = 6200;
  static const double longTerm = 9450;
  static const double emergency = 3000;
  static const double growthRate = 6.2;

  static const List<double> trend = [14300, 15040, 15820, 16510, 17600, 18650];
  static const List<String> trendLabels = [
    'Oct',
    'Nov',
    'Dec',
    'Jan',
    'Feb',
    'Mar',
  ];

  static const List<_SavingGoal> goals = [
    _SavingGoal(
      label: 'Emergency fund',
      target: 5000,
      current: 3000,
      icon: HugeIcons.strokeRoundedShield01,
      color: AppColors.primary,
    ),
    _SavingGoal(
      label: 'Travel 2026',
      target: 3500,
      current: 2200,
      icon: HugeIcons.strokeRoundedStars,
      color: Color(0xFF7EB8FF),
    ),
    _SavingGoal(
      label: 'Home down payment',
      target: 12000,
      current: 6400,
      icon: HugeIcons.strokeRoundedHome01,
      color: Color(0xFFFFB86C),
    ),
    _SavingGoal(
      label: 'Education',
      target: 8000,
      current: 5050,
      icon: HugeIcons.strokeRoundedBook02,
      color: AppColors.success,
    ),
  ];
}

class _SavingGoal {
  const _SavingGoal({
    required this.label,
    required this.target,
    required this.current,
    required this.icon,
    required this.color,
  });

  final String label;
  final double target;
  final double current;
  final dynamic icon;
  final Color color;
}

class SavingPage extends StatefulWidget {
  const SavingPage({super.key});

  @override
  State<SavingPage> createState() => _SavingPageState();
}

class _SavingPageState extends State<SavingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceCtrl;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  Animation<double> _fade(double start, double end) => CurvedAnimation(
    parent: _entranceCtrl,
    curve: Interval(start, end, curve: Curves.easeOut),
  );

  Animation<Offset> _slide(double start, double end) =>
      Tween<Offset>(begin: const Offset(0, 0.07), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _entranceCtrl,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Staggered(
          fade: _fade(0.0, 0.45),
          slide: _slide(0.0, 0.45),
          child: const _SavingHeader(),
        ),
        const SizedBox(height: 16),
        _Staggered(
          fade: _fade(0.12, 0.55),
          slide: _slide(0.12, 0.55),
          child: const _SavingHeroCard(),
        ),
        const SizedBox(height: 14),
        _Staggered(
          fade: _fade(0.24, 0.65),
          slide: _slide(0.24, 0.65),
          child: const _SavingTypeRow(),
        ),
        const SizedBox(height: 14),
        _Staggered(
          fade: _fade(0.36, 0.78),
          slide: _slide(0.36, 0.78),
          child: const _SavingTrendChart(),
        ),
        const SizedBox(height: 14),
        _Staggered(
          fade: _fade(0.50, 0.90),
          slide: _slide(0.50, 0.90),
          child: const _SavingGoalList(),
        ),
        const SizedBox(height: 8),
        _Staggered(
          fade: _fade(0.70, 1.0),
          slide: _slide(0.70, 1.0),
          child: const _FooterNote(),
        ),
      ],
    );
  }
}

class _Staggered extends StatelessWidget {
  const _Staggered({
    required this.fade,
    required this.slide,
    required this.child,
  });

  final Animation<double> fade;
  final Animation<Offset> slide;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _SavingHeader extends StatelessWidget {
  const _SavingHeader();

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 760;

    return GlassPanel(
      padding: EdgeInsets.all(isCompact ? 22 : 30),
      borderRadius: BorderRadius.circular(34),
      blur: 28,
      opacity: 0.14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GlassBadge(
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedPiggyBank,
                      size: 16,
                      color: AppColors.success,
                      strokeWidth: 1.8,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Saving workspace',
                      style: TextStyle(fontSize: 12, color: AppColors.success),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _GrowthBadge(rate: _SavingData.growthRate),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Saving',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: isCompact ? 26 : 32,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Organize goals and watch your progress toward short and long-term plans.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 13,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 22),
          const Row(
            children: [
              Expanded(
                child: _MetricChip(
                  icon: HugeIcons.strokeRoundedTarget02,
                  label: 'Goals',
                  value: '4 active',
                  color: AppColors.success,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _MetricChip(
                  icon: HugeIcons.strokeRoundedCalendar03,
                  label: 'Next milestone',
                  value: 'Mar 18',
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _MetricChip(
                  icon: HugeIcons.strokeRoundedChartUp,
                  label: 'Growth rate',
                  value: '+6.2% MoM',
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final dynamic icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: BorderRadius.circular(24),
      blur: 18,
      opacity: 0.1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 160),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.14),
              ),
              child: Center(
                child: HugeIcon(
                  icon: icon,
                  size: 18,
                  color: color,
                  strokeWidth: 1.8,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GrowthBadge extends StatelessWidget {
  const _GrowthBadge({required this.rate});

  final double rate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: AppColors.success.withValues(alpha: 0.12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowUpRight01,
            size: 12,
            color: AppColors.success,
            strokeWidth: 2,
          ),
          const SizedBox(width: 4),
          Text(
            '+${rate.toStringAsFixed(1)}% MoM',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero card ─────────────────────────────────────────────────────────────────

class _SavingHeroCard extends StatefulWidget {
  const _SavingHeroCard();

  @override
  State<_SavingHeroCard> createState() => _SavingHeroCardState();
}

class _SavingHeroCardState extends State<_SavingHeroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: AnimatedBuilder(
          animation: _shimmerCtrl,
          builder: (context, _) => Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.success.withValues(alpha: 0.13),
                  Colors.white.withValues(alpha: 0.06),
                  AppColors.success.withValues(alpha: 0.05),
                ],
                stops: [0.0, _shimmerCtrl.value, 1.0],
              ),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.28),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.12),
                  blurRadius: 48,
                  offset: const Offset(0, 18),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.success.withValues(alpha: 0.18),
                      ),
                      child: const Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedPiggyBank,
                          size: 18,
                          color: AppColors.success,
                          strokeWidth: 1.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Total Savings',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: AppColors.success.withValues(alpha: 0.12),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Text(
                        'March 2026',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const _AnimatedCounter(
                  value: _SavingData.totalSavings,
                  prefix: r'$',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -1.4,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Across active saving goals',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 20),
                const _GradientDivider(color: AppColors.success),
                const SizedBox(height: 18),
                const _SavingBreakdownBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SavingBreakdownBar extends StatefulWidget {
  const _SavingBreakdownBar();

  @override
  State<_SavingBreakdownBar> createState() => _SavingBreakdownBarState();
}

class _SavingBreakdownBarState extends State<_SavingBreakdownBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const shortRatio = _SavingData.shortTerm / _SavingData.totalSavings;
    const longRatio = _SavingData.longTerm / _SavingData.totalSavings;
    const emergencyRatio = _SavingData.emergency / _SavingData.totalSavings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            _Legend(color: AppColors.success, label: 'Short term'),
            Spacer(),
            _Legend(color: AppColors.primary, label: 'Long term'),
            Spacer(),
            _Legend(color: Color(0xFF7EB8FF), label: 'Emergency'),
          ],
        ),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: _anim,
          builder: (context, _) {
            final fill = _anim.value;
            return ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    Expanded(
                      flex: (shortRatio * fill * 1000).round(),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.success,
                              AppColors.success.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      flex: (longRatio * fill * 1000).round(),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0.8),
                              AppColors.primary,
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      flex: (emergencyRatio * fill * 1000).round(),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF7EB8FF).withValues(alpha: 0.8),
                              const Color(0xFF7EB8FF),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: (1000 - (fill * 1000).round()).clamp(0, 999),
                      child: Container(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Type cards ───────────────────────────────────────────────────────────────

class _SavingTypeRow extends StatelessWidget {
  const _SavingTypeRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _SavingTypeCard(
            label: 'Short term',
            sublabel: 'Trips, gifts, gear',
            amount: _SavingData.shortTerm,
            icon: HugeIcons.strokeRoundedStars,
            accentColor: AppColors.success,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _SavingTypeCard(
            label: 'Long term',
            sublabel: 'Home, education, investments',
            amount: _SavingData.longTerm,
            icon: HugeIcons.strokeRoundedHome01,
            accentColor: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

class _SavingTypeCard extends StatefulWidget {
  const _SavingTypeCard({
    required this.label,
    required this.sublabel,
    required this.amount,
    required this.icon,
    required this.accentColor,
  });

  final String label;
  final String sublabel;
  final double amount;
  final dynamic icon;
  final Color accentColor;

  @override
  State<_SavingTypeCard> createState() => _SavingTypeCardState();
}

class _SavingTypeCardState extends State<_SavingTypeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _format(double v) {
    if (v >= 1000) return '\$${(v / 1000).toStringAsFixed(1)}k';
    return '\$${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.accentColor.withValues(alpha: 0.11),
                    Colors.white.withValues(alpha: 0.05),
                  ],
                ),
                border: Border.all(
                  color: widget.accentColor.withValues(alpha: 0.24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.accentColor.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          widget.label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.9,
                            ),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.accentColor.withValues(alpha: 0.15),
                        ),
                        child: Center(
                          child: HugeIcon(
                            icon: widget.icon,
                            size: 14,
                            color: widget.accentColor,
                            strokeWidth: 1.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AnimatedBuilder(
                    animation: _anim,
                    builder: (context, _) {
                      final v = _anim.value * widget.amount;
                      return Text(
                        _format(v),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: widget.accentColor,
                          letterSpacing: -0.6,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.sublabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
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

// ── Trend chart ───────────────────────────────────────────────────────────────

class _SavingTrendChart extends StatefulWidget {
  const _SavingTrendChart();

  @override
  State<_SavingTrendChart> createState() => _SavingTrendChartState();
}

class _SavingTrendChartState extends State<_SavingTrendChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 760;

    return GlassPanel(
      padding: EdgeInsets.all(isCompact ? 20 : 26),
      borderRadius: BorderRadius.circular(28),
      blur: 24,
      opacity: 0.12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success.withValues(alpha: 0.14),
                ),
                child: const Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedBarChart,
                    size: 16,
                    color: AppColors.success,
                    strokeWidth: 1.8,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                '6-month trend',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                'Savings',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          AnimatedBuilder(
            animation: _anim,
            builder: (context, _) => _TrendBars(
              progress: _anim.value,
              data: _SavingData.trend,
              labels: _SavingData.trendLabels,
              isCompact: isCompact,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendBars extends StatelessWidget {
  const _TrendBars({
    required this.progress,
    required this.data,
    required this.labels,
    required this.isCompact,
  });

  final double progress;
  final List<double> data;
  final List<String> labels;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final maxVal = data.reduce(math.max);
    final barHeight = isCompact ? 100.0 : 130.0;
    final lastIndex = data.length - 1;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(data.length, (i) {
        final ratio = data[i] / maxVal;
        final isActive = i == lastIndex;
        final animatedRatio = ratio * progress;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (isActive)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '\$${(data[i] / 1000).toStringAsFixed(1)}k',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 18),
                Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      height: barHeight,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        height: barHeight * animatedRatio,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: isActive
                                ? [
                                    AppColors.success,
                                    AppColors.success.withValues(alpha: 0.65),
                                  ]
                                : [
                                    AppColors.success.withValues(alpha: 0.35),
                                    AppColors.success.withValues(alpha: 0.18),
                                  ],
                          ),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: AppColors.success.withValues(
                                      alpha: 0.25,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, -4),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 11,
                    color: isActive
                        ? AppColors.success
                        : AppColors.textSecondary.withValues(alpha: 0.55),
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ── Goal list ────────────────────────────────────────────────────────────────

class _SavingGoalList extends StatelessWidget {
  const _SavingGoalList();

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 760;

    return GlassPanel(
      padding: EdgeInsets.all(isCompact ? 20 : 26),
      borderRadius: BorderRadius.circular(28),
      blur: 24,
      opacity: 0.12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.14),
                ),
                child: const Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedListView,
                    size: 16,
                    color: AppColors.primary,
                    strokeWidth: 1.8,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Saving goals',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${_SavingData.goals.length} goals',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...List.generate(_SavingData.goals.length, (i) {
            return _GoalRow(
              goal: _SavingData.goals[i],
              index: i,
              isLast: i == _SavingData.goals.length - 1,
            );
          }),
        ],
      ),
    );
  }
}

class _GoalRow extends StatefulWidget {
  const _GoalRow({
    required this.goal,
    required this.index,
    required this.isLast,
  });

  final _SavingGoal goal;
  final int index;
  final bool isLast;

  @override
  State<_GoalRow> createState() => _GoalRowState();
}

class _GoalRowState extends State<_GoalRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    Future.delayed(Duration(milliseconds: 120 + widget.index * 80), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ratio = (widget.goal.current / widget.goal.target).clamp(0.0, 1.0);
    final percent = (ratio * 100).toStringAsFixed(1);
    final formattedCurrent =
        '\$${widget.goal.current.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';
    final formattedTarget =
        '\$${widget.goal.target.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.goal.color.withValues(alpha: 0.14),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: widget.goal.icon,
                    size: 18,
                    color: widget.goal.color,
                    strokeWidth: 1.8,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.goal.label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$formattedCurrent / $formattedTarget',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: widget.goal.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    AnimatedBuilder(
                      animation: _anim,
                      builder: (context, _) {
                        final fill = ratio * _anim.value;
                        final rest = (1 - ratio) * _anim.value;
                        final pending = 1 - _anim.value;

                        return ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            height: 4,
                            child: Row(
                              children: [
                                Flexible(
                                  flex: (fill * 1000).round(),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          widget.goal.color,
                                          widget.goal.color.withValues(
                                            alpha: 0.6,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Flexible(
                                  flex: (rest * 1000).round().clamp(1, 1000),
                                  child: Container(
                                    color: Colors.white.withValues(alpha: 0.06),
                                  ),
                                ),
                                Flexible(
                                  flex: (pending * 1000).round().clamp(0, 999),
                                  child: Container(
                                    color: Colors.white.withValues(alpha: 0.06),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$percent% of goal',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!widget.isLast)
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.07),
                  Colors.transparent,
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Animated counter & divider ───────────────────────────────────────────────

class _AnimatedCounter extends StatefulWidget {
  const _AnimatedCounter({
    required this.value,
    required this.style,
    this.prefix = '',
  });

  final double value;
  final TextStyle style;
  final String prefix;

  @override
  State<_AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<_AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final v = _anim.value * widget.value;
        final formatted =
            '${widget.prefix}${v.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+\.)'), (m) => '${m[1]},')}';
        return Text(formatted, style: widget.style);
      },
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
            color.withValues(alpha: 0.25),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

// ── Footer ────────────────────────────────────────────────────────────────────

class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text(
          'Data is illustrative · Real sync coming soon',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary.withValues(alpha: 0.45),
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}
