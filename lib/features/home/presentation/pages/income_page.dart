import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/app_toast.dart';

// ── Mock data ─────────────────────────────────────────────────────────────────

class _IncomeData {
  static const double totalMonthly = 8450;
  static const double activeIncome = 6200;
  static const double passiveIncome = 2250;
  static const double growthRate = 4.3;

  static const List<double> trend = [5200, 6100, 7800, 6500, 8100, 8450];
  static const List<String> trendLabels = [
    'Oct',
    'Nov',
    'Dec',
    'Jan',
    'Feb',
    'Mar',
  ];

  static const List<_IncomeSource> sources = [
    _IncomeSource(
      label: 'Salary',
      amount: 5200,
      icon: HugeIcons.strokeRoundedBuilding03,
      color: AppColors.success,
    ),
    _IncomeSource(
      label: 'Freelance',
      amount: 1000,
      icon: HugeIcons.strokeRoundedLaptop,
      color: Color(0xFF7EB8FF),
    ),
    _IncomeSource(
      label: 'Dividends',
      amount: 750,
      icon: HugeIcons.strokeRoundedChartUp,
      color: AppColors.primary,
    ),
    _IncomeSource(
      label: 'Rental',
      amount: 500,
      icon: HugeIcons.strokeRoundedHome01,
      color: Color(0xFFC97BFF),
    ),
    _IncomeSource(
      label: 'Side hustle',
      amount: 1000,
      icon: HugeIcons.strokeRoundedStars,
      color: Color(0xFFFFB86C),
    ),
  ];
}

class _IncomeSource {
  const _IncomeSource({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String label;
  final double amount;
  final dynamic icon;
  final Color color;
}

// ── Page ──────────────────────────────────────────────────────────────────────

class IncomePage extends StatefulWidget {
  const IncomePage({super.key});

  @override
  State<IncomePage> createState() => _IncomePageState();
}

class _IncomePageState extends State<IncomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceCtrl;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
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
      Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
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
          child: _IncomeHeader(onAddIncome: _openAddIncomeDialog),
        ),
        const SizedBox(height: 16),

        _Staggered(
          fade: _fade(0.10, 0.55),
          slide: _slide(0.10, 0.55),
          child: const _IncomeHeroCard(),
        ),
        const SizedBox(height: 14),

        _Staggered(
          fade: _fade(0.22, 0.65),
          slide: _slide(0.22, 0.65),
          child: const _IncomeSourcesRow(),
        ),
        const SizedBox(height: 14),

        _Staggered(
          fade: _fade(0.35, 0.75),
          slide: _slide(0.35, 0.75),
          child: const _IncomeTrendChart(),
        ),
        const SizedBox(height: 14),

        _Staggered(
          fade: _fade(0.48, 0.88),
          slide: _slide(0.48, 0.88),
          child: const _IncomeStreamList(),
        ),
        const SizedBox(height: 8),

        _Staggered(
          fade: _fade(0.65, 1.0),
          slide: _slide(0.65, 1.0),
          child: const _FooterNote(),
        ),
      ],
    );
  }

  Future<void> _openAddIncomeDialog() async {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String type = 'Active';
    String frequency = 'Monthly';
    DateTime? nextPayout;
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return Form(
                      key: formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Add income',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  tooltip: 'Close',
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.close, size: 18),
                                  color: AppColors.textSecondary,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _FormField(
                              label: 'Source name',
                              controller: nameCtrl,
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Required'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            _FormField(
                              label: 'Amount',
                              controller: amountCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Required';
                                }
                                final value = double.tryParse(v);
                                if (value == null || value <= 0) {
                                  return 'Enter a valid amount';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _DropdownField(
                                    label: 'Type',
                                    value: type,
                                    items: const ['Active', 'Passive'],
                                    onChanged: (v) =>
                                        setState(() => type = v ?? type),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _DropdownField(
                                    label: 'Frequency',
                                    value: frequency,
                                    items: const [
                                      'One-time',
                                      'Weekly',
                                      'Biweekly',
                                      'Monthly',
                                      'Quarterly',
                                      'Annual',
                                    ],
                                    onChanged: (v) => setState(
                                      () => frequency = v ?? frequency,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _FormField(
                              label: 'Category',
                              controller: categoryCtrl,
                              hintText: 'e.g., Salary, Freelance, Dividends',
                            ),
                            const SizedBox(height: 12),
                            _DateField(
                              label: 'Next expected payout',
                              value: nextPayout,
                              onPick: () async {
                                final now = DateTime.now();
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: now,
                                  firstDate: now.subtract(
                                    const Duration(days: 365),
                                  ),
                                  lastDate: now.add(
                                    const Duration(days: 365 * 2),
                                  ),
                                );
                                if (picked != null) {
                                  setState(() => nextPayout = picked);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            _FormField(
                              label: 'Notes',
                              controller: notesCtrl,
                              maxLines: 3,
                              hintText: 'Add context, payment terms, or links',
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      side: BorderSide(
                                        color: Colors.white.withValues(
                                          alpha: 0.18,
                                        ),
                                      ),
                                      shape: const StadiumBorder(),
                                    ),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (!formKey.currentState!.validate()) {
                                        return;
                                      }
                                      Navigator.pop(context);
                                      AppToast.success(
                                        context,
                                        title: 'Income added',
                                        description:
                                            'We will sync this entry into your analytics soon.',
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      backgroundColor: AppColors.success,
                                      foregroundColor: AppColors.background,
                                      shape: const StadiumBorder(),
                                    ),
                                    child: const Text(
                                      'Save income',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Staggered wrapper ─────────────────────────────────────────────────────────

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

class _IncomeHeader extends StatelessWidget {
  const _IncomeHeader({required this.onAddIncome});

  final VoidCallback onAddIncome;

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
                      icon: HugeIcons.strokeRoundedMoneyReceiveCircle,
                      size: 16,
                      color: AppColors.success,
                      strokeWidth: 1.8,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Income workspace',
                      style: TextStyle(fontSize: 12, color: AppColors.success),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onAddIncome,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedAddSquare,
                  size: 16,
                  color: AppColors.textPrimary,
                  strokeWidth: 2,
                ),
                label: const Text(
                  'Add income',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _GrowthBadge(rate: _IncomeData.growthRate),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Income',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: isCompact ? 26 : 32,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Track salaries, side income, and recurring inflows in one calm workspace.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 13,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 22),
          const Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricChip(
                icon: HugeIcons.strokeRoundedArrowDown01,
                label: 'Recurring inflows',
                value: '5 active',
                color: AppColors.success,
              ),
              _MetricChip(
                icon: HugeIcons.strokeRoundedChartUp,
                label: 'Month-over-month',
                value: '+4.3%',
                color: AppColors.success,
              ),
              _MetricChip(
                icon: HugeIcons.strokeRoundedCalendar03,
                label: 'Next payout',
                value: 'Mar 15',
                color: AppColors.primary,
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

class _IncomeHeroCard extends StatefulWidget {
  const _IncomeHeroCard();

  @override
  State<_IncomeHeroCard> createState() => _IncomeHeroCardState();
}

class _IncomeHeroCardState extends State<_IncomeHeroCard>
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
                  Colors.white.withValues(alpha: 0.07),
                  AppColors.success.withValues(alpha: 0.05),
                ],
                stops: [0.0, _shimmerCtrl.value, 1.0],
              ),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.28),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.10),
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
                          icon: HugeIcons.strokeRoundedMoneyReceiveCircle,
                          size: 18,
                          color: AppColors.success,
                          strokeWidth: 1.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Total Income',
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
                  value: _IncomeData.totalMonthly,
                  prefix: r'$',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Across ${_IncomeData.sources.length} income sources',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 20),
                _GradientDivider(color: AppColors.success),
                const SizedBox(height: 18),
                const _IncomeProgressBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IncomeProgressBar extends StatefulWidget {
  const _IncomeProgressBar();

  @override
  State<_IncomeProgressBar> createState() => _IncomeProgressBarState();
}

class _IncomeProgressBarState extends State<_IncomeProgressBar>
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
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _ctrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const activeRatio = _IncomeData.activeIncome / _IncomeData.totalMonthly;
    const passiveRatio = _IncomeData.passiveIncome / _IncomeData.totalMonthly;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _SourceLegend(
              color: AppColors.success,
              label: 'Active',
              amount: _IncomeData.activeIncome,
            ),
            const Spacer(),
            _SourceLegend(
              color: const Color(0xFF7EB8FF),
              label: 'Passive',
              amount: _IncomeData.passiveIncome,
            ),
          ],
        ),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: _anim,
          builder: (context, _) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    Expanded(
                      flex: (activeRatio * _anim.value * 1000).round(),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.success, Color(0xFF4DB87A)],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      flex: (passiveRatio * _anim.value * 1000).round().clamp(
                        1,
                        1000,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF7EB8FF).withValues(alpha: 0.75),
                              const Color(0xFF7EB8FF),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: (1000 - (_anim.value * 1000).round()).clamp(0, 999),
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

class _SourceLegend extends StatelessWidget {
  const _SourceLegend({
    required this.color,
    required this.label,
    required this.amount,
  });

  final Color color;
  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    final formatted =
        '\$${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';

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
          '$label  $formatted',
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

// ── Sources row (Active / Passive) ────────────────────────────────────────────

class _IncomeSourcesRow extends StatelessWidget {
  const _IncomeSourcesRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _IncomeTypeCard(
            label: 'Active Income',
            sublabel: 'Salary & freelance',
            amount: _IncomeData.activeIncome,
            icon: HugeIcons.strokeRoundedBriefcase01,
            accentColor: AppColors.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _IncomeTypeCard(
            label: 'Passive Income',
            sublabel: 'Dividends & rental',
            amount: _IncomeData.passiveIncome,
            icon: HugeIcons.strokeRoundedChartUp,
            accentColor: const Color(0xFF7EB8FF),
          ),
        ),
      ],
    );
  }
}

class _IncomeTypeCard extends StatefulWidget {
  const _IncomeTypeCard({
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
  State<_IncomeTypeCard> createState() => _IncomeTypeCardState();
}

class _IncomeTypeCardState extends State<_IncomeTypeCard>
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

class _IncomeTrendChart extends StatefulWidget {
  const _IncomeTrendChart();

  @override
  State<_IncomeTrendChart> createState() => _IncomeTrendChartState();
}

class _IncomeTrendChartState extends State<_IncomeTrendChart>
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
      if (mounted) {
        _ctrl.forward();
      }
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
                'Income',
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
              data: _IncomeData.trend,
              labels: _IncomeData.trendLabels,
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

// ── Stream list ───────────────────────────────────────────────────────────────

class _IncomeStreamList extends StatelessWidget {
  const _IncomeStreamList();

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
                'Income streams',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${_IncomeData.sources.length} sources',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...List.generate(_IncomeData.sources.length, (i) {
            return _StreamRow(
              source: _IncomeData.sources[i],
              total: _IncomeData.totalMonthly,
              index: i,
              isLast: i == _IncomeData.sources.length - 1,
            );
          }),
        ],
      ),
    );
  }
}

class _StreamRow extends StatefulWidget {
  const _StreamRow({
    required this.source,
    required this.total,
    required this.index,
    required this.isLast,
  });

  final _IncomeSource source;
  final double total;
  final int index;
  final bool isLast;

  @override
  State<_StreamRow> createState() => _StreamRowState();
}

class _StreamRowState extends State<_StreamRow>
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
    Future.delayed(Duration(milliseconds: 100 + widget.index * 80), () {
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
    final ratio = widget.source.amount / widget.total;
    final formatted =
        '\$${widget.source.amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';
    final percent = (ratio * 100).toStringAsFixed(1);

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
                  color: widget.source.color.withValues(alpha: 0.14),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: widget.source.icon,
                    size: 18,
                    color: widget.source.color,
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
                          widget.source.label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          formatted,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: widget.source.color,
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
                                          widget.source.color,
                                          widget.source.color.withValues(
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
                      '$percent% of total',
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

// ── Dialog form fields ───────────────────────────────────────────────────────

class _FormField extends StatelessWidget {
  const _FormField({
    required this.label,
    required this.controller,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
    this.hintText,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.04),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.success.withValues(alpha: 0.5),
                width: 1.4,
              ),
            ),
          ),
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textSecondary,
                size: 18,
              ),
              onChanged: onChanged,
              items: items
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? 'Pick a date'
        : '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        OutlinedButton(
          onPressed: onPick,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.white.withValues(alpha: 0.04),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                text,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Animated counter ──────────────────────────────────────────────────────────

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

// ── Gradient divider ──────────────────────────────────────────────────────────

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
