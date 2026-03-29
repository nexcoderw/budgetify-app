import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../income/application/income_service.dart';
import '../../../income/data/models/income_entry.dart';

extension _IncomeCategoryPresentation on IncomeCategory {
  dynamic get icon => switch (this) {
    IncomeCategory.salary => HugeIcons.strokeRoundedBuilding03,
    IncomeCategory.freelance => HugeIcons.strokeRoundedLaptop,
    IncomeCategory.dividends => HugeIcons.strokeRoundedChartUp,
    IncomeCategory.rental => HugeIcons.strokeRoundedHome01,
    IncomeCategory.sideHustle => HugeIcons.strokeRoundedStars,
    IncomeCategory.other => HugeIcons.strokeRoundedMoney01,
  };

  Color get color => switch (this) {
    IncomeCategory.salary => AppColors.success,
    IncomeCategory.freelance => const Color(0xFF7EB8FF),
    IncomeCategory.dividends => AppColors.primary,
    IncomeCategory.rental => const Color(0xFFC97BFF),
    IncomeCategory.sideHustle => const Color(0xFFFFB86C),
    IncomeCategory.other => const Color(0xFFFF9F9F),
  };
}

// ── RWF formatter ─────────────────────────────────────────────────────────────

String _rwf(double amount) {
  final formatted = amount
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  return 'RWF $formatted';
}

String _rwfCompact(double amount) {
  if (amount >= 1000000) {
    return 'RWF ${(amount / 1000000).toStringAsFixed(1)}M';
  }
  if (amount >= 1000) {
    return 'RWF ${(amount / 1000).toStringAsFixed(0)}k';
  }
  return _rwf(amount);
}

// ── Page ──────────────────────────────────────────────────────────────────────

class IncomePage extends StatefulWidget {
  const IncomePage({super.key, required this.incomeService});

  final IncomeService incomeService;

  @override
  State<IncomePage> createState() => _IncomePageState();
}

class _IncomePageState extends State<IncomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  List<IncomeEntry> _entries = const [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..forward();
    _loadIncome();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  // ── Computed ─────────────────────────────────────────────────────────────────

  double get _total => _entries.fold(0, (sum, e) => sum + e.amount);

  double get _activeTotal => _entries
      .where(
        (e) =>
            e.category == IncomeCategory.salary ||
            e.category == IncomeCategory.freelance ||
            e.category == IncomeCategory.sideHustle,
      )
      .fold(0, (sum, e) => sum + e.amount);

  double get _passiveTotal => _entries
      .where(
        (e) =>
            e.category == IncomeCategory.dividends ||
            e.category == IncomeCategory.rental ||
            e.category == IncomeCategory.other,
      )
      .fold(0, (sum, e) => sum + e.amount);

  // ── CRUD ──────────────────────────────────────────────────────────────────────

  Future<void> _openAddDialog() async {
    final entry = await showDialog<IncomeEntry>(
      context: context,
      builder: (_) => _IncomeFormDialog(
        entry: null,
        onSubmit:
            ({
              required String label,
              required double amount,
              required IncomeCategory category,
              required DateTime date,
            }) {
              return widget.incomeService.createIncome(
                label: label,
                amount: amount,
                category: category,
                date: date,
              );
            },
      ),
    );

    if (entry == null || !mounted) {
      return;
    }

    setState(() {
      _entries = _sortedEntries(<IncomeEntry>[entry, ..._entries]);
      _loadError = null;
    });

    AppToast.success(
      context,
      title: 'Income added',
      description: '${entry.label} was saved to your income records.',
    );
  }

  Future<void> _openEditDialog(IncomeEntry entry) async {
    final updated = await showDialog<IncomeEntry>(
      context: context,
      builder: (_) => _IncomeFormDialog(
        entry: entry,
        onSubmit:
            ({
              required String label,
              required double amount,
              required IncomeCategory category,
              required DateTime date,
            }) {
              return widget.incomeService.updateIncome(
                incomeId: entry.id,
                label: label,
                amount: amount,
                category: category,
                date: date,
              );
            },
      ),
    );

    if (updated == null || !mounted) {
      return;
    }

    setState(() {
      final nextEntries = _entries
          .map((current) => current.id == updated.id ? updated : current)
          .toList(growable: false);
      _entries = _sortedEntries(nextEntries);
      _loadError = null;
    });

    AppToast.success(
      context,
      title: 'Income updated',
      description: '${updated.label} was updated successfully.',
    );
  }

  Future<void> _confirmDelete(IncomeEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteConfirmDialog(label: entry.label),
    );
    if (confirmed == true) {
      try {
        await widget.incomeService.deleteIncome(entry.id);

        if (!mounted) {
          return;
        }

        setState(() {
          _entries = _entries
              .where((current) => current.id != entry.id)
              .toList(growable: false);
        });

        AppToast.success(
          context,
          title: 'Income removed',
          description: '${entry.label} was removed from your records.',
        );
      } catch (error) {
        if (!mounted) {
          return;
        }

        AppToast.error(
          context,
          title: 'Unable to delete income',
          description: _readableError(error),
        );
      }
    }
  }

  Future<void> _loadIncome() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final entries = await widget.incomeService.listIncome();

      if (!mounted) {
        return;
      }

      setState(() {
        _entries = _sortedEntries(entries);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = _readableError(error);
      setState(() {
        _entries = const [];
        _isLoading = false;
        _loadError = message;
      });

      AppToast.error(
        context,
        title: 'Unable to load income',
        description: message,
      );
    }
  }

  List<IncomeEntry> _sortedEntries(List<IncomeEntry> entries) {
    final sorted = entries.toList(growable: false);
    sorted.sort((left, right) {
      final byDate = right.date.compareTo(left.date);
      if (byDate != 0) {
        return byDate;
      }

      return right.createdAt.compareTo(left.createdAt);
    });

    return sorted;
  }

  String _readableError(Object error) {
    final message = error.toString().trim();

    if (message.startsWith('Exception: ')) {
      return message.replaceFirst('Exception: ', '');
    }

    if (message.startsWith('StateError: ')) {
      return message.replaceFirst('StateError: ', '');
    }

    return message;
  }

  // ── Animation helpers ─────────────────────────────────────────────────────────

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
    if (_isLoading) {
      return _IncomePageLoading(fade: _fade, slide: _slide);
    }

    final total = _total;
    final activeTotal = _activeTotal;
    final passiveTotal = _passiveTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Staggered(
          fade: _fade(0.0, 0.45),
          slide: _slide(0.0, 0.45),
          child: _IncomeHeader(
            total: total,
            entryCount: _entries.length,
            onAdd: _openAddDialog,
          ),
        ),
        const SizedBox(height: 14),

        _Staggered(
          fade: _fade(0.12, 0.55),
          slide: _slide(0.12, 0.55),
          child: _BreakdownRow(
            activeTotal: activeTotal,
            passiveTotal: passiveTotal,
            total: total,
          ),
        ),
        const SizedBox(height: 14),

        _Staggered(
          fade: _fade(0.26, 0.68),
          slide: _slide(0.26, 0.68),
          child: _CategoryBars(entries: _entries, total: total),
        ),
        const SizedBox(height: 14),

        _Staggered(
          fade: _fade(0.40, 0.82),
          slide: _slide(0.40, 0.82),
          child: _EntryList(
            entries: _entries,
            total: total,
            loadError: _loadError,
            onRetry: _loadIncome,
            onEdit: _openEditDialog,
            onDelete: _confirmDelete,
          ),
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

class _IncomePageLoading extends StatelessWidget {
  const _IncomePageLoading({required this.fade, required this.slide});

  final Animation<double> Function(double, double) fade;
  final Animation<Offset> Function(double, double) slide;

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Staggered(
            fade: fade(0.0, 0.45),
            slide: slide(0.0, 0.45),
            child: _LoadingPanel(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBox(width: 138, height: 24, radius: 999),
                  SizedBox(height: 22),
                  SkeletonBox(width: 180, height: 32, radius: 18),
                  SizedBox(height: 12),
                  SkeletonBox(height: 12, radius: 12),
                  SizedBox(height: 8),
                  SkeletonBox(width: 240, height: 12, radius: 12),
                  SizedBox(height: 26),
                  SkeletonBox(width: 220, height: 42, radius: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _Staggered(
            fade: fade(0.12, 0.55),
            slide: slide(0.12, 0.55),
            child: Row(
              children: const [
                Expanded(
                  child: _LoadingPanel(
                    padding: EdgeInsets.all(20),
                    child: _LoadingMetricCard(),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _LoadingPanel(
                    padding: EdgeInsets.all(20),
                    child: _LoadingMetricCard(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Staggered(
            fade: fade(0.26, 0.68),
            slide: slide(0.26, 0.68),
            child: const _LoadingPanel(
              padding: EdgeInsets.all(24),
              child: _LoadingCategoryPanel(),
            ),
          ),
          const SizedBox(height: 14),
          _Staggered(
            fade: fade(0.40, 0.82),
            slide: slide(0.40, 0.82),
            child: const _LoadingPanel(
              padding: EdgeInsets.all(24),
              child: _LoadingEntriesPanel(),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel({required this.padding, required this.child});

  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: padding,
      borderRadius: BorderRadius.circular(28),
      blur: 24,
      opacity: 0.12,
      child: child,
    );
  }
}

class _LoadingMetricCard extends StatelessWidget {
  const _LoadingMetricCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        SkeletonBox(width: 72, height: 12, radius: 12),
        SizedBox(height: 16),
        SkeletonBox(width: 118, height: 26, radius: 16),
        SizedBox(height: 8),
        SkeletonBox(width: 150, height: 10, radius: 12),
        SizedBox(height: 14),
        SkeletonBox(height: 4, radius: 999),
        SizedBox(height: 10),
        SkeletonBox(width: 96, height: 10, radius: 12),
      ],
    );
  }
}

class _LoadingCategoryPanel extends StatelessWidget {
  const _LoadingCategoryPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        SkeletonBox(width: 120, height: 16, radius: 12),
        SizedBox(height: 24),
        SkeletonBox(height: 16, radius: 14),
        SizedBox(height: 16),
        SkeletonBox(height: 16, radius: 14),
        SizedBox(height: 16),
        SkeletonBox(height: 16, radius: 14),
      ],
    );
  }
}

class _LoadingEntriesPanel extends StatelessWidget {
  const _LoadingEntriesPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        Row(
          children: [
            SkeletonBox(width: 120, height: 16, radius: 12),
            Spacer(),
            SkeletonBox(width: 74, height: 12, radius: 12),
          ],
        ),
        SizedBox(height: 20),
        _LoadingEntryRow(),
        SizedBox(height: 14),
        _LoadingEntryRow(),
        SizedBox(height: 14),
        _LoadingEntryRow(),
      ],
    );
  }
}

class _LoadingEntryRow extends StatelessWidget {
  const _LoadingEntryRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        SkeletonBox(width: 40, height: 40, radius: 999),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 150, height: 14, radius: 12),
              SizedBox(height: 8),
              SkeletonBox(width: 88, height: 11, radius: 12),
            ],
          ),
        ),
        SizedBox(width: 12),
        SkeletonBox(width: 84, height: 14, radius: 12),
      ],
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

class _IncomeHeader extends StatefulWidget {
  const _IncomeHeader({
    required this.total,
    required this.entryCount,
    required this.onAdd,
  });

  final double total;
  final int entryCount;
  final VoidCallback onAdd;

  @override
  State<_IncomeHeader> createState() => _IncomeHeaderState();
}

class _IncomeHeaderState extends State<_IncomeHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 760;

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: AnimatedBuilder(
          animation: _shimmer,
          builder: (context, _) => Container(
            padding: EdgeInsets.all(isCompact ? 22 : 28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.success.withValues(alpha: 0.15),
                  Colors.white.withValues(alpha: 0.07),
                  AppColors.success.withValues(alpha: 0.04),
                ],
                stops: [0.0, _shimmer.value, 1.0],
              ),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.30),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.10),
                  blurRadius: 48,
                  offset: const Offset(0, 20),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GlassBadge(
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                HugeIcon(
                                  icon:
                                      HugeIcons.strokeRoundedMoneyReceiveCircle,
                                  size: 15,
                                  color: AppColors.success,
                                  strokeWidth: 1.8,
                                ),
                                SizedBox(width: 7),
                                Text(
                                  'Income workspace',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Income',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontSize: isCompact ? 26 : 30,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Track and manage all your income sources in one place.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.55,
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.85,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    _AddButton(onTap: widget.onAdd),
                  ],
                ),
                const SizedBox(height: 22),
                _GradientDivider(color: AppColors.success),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total this month',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.7,
                              ),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _AnimatedCounter(
                            value: widget.total,
                            style: TextStyle(
                              fontSize: isCompact ? 30 : 36,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: -1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: AppColors.success.withValues(alpha: 0.12),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.22),
                        ),
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
                          const SizedBox(width: 5),
                          Text(
                            '${widget.entryCount} sources',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatefulWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.success.withValues(alpha: 0.18),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.success.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedAdd01,
              size: 20,
              color: AppColors.success,
              strokeWidth: 2,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Breakdown row (Active / Passive) ──────────────────────────────────────────

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.activeTotal,
    required this.passiveTotal,
    required this.total,
  });

  final double activeTotal;
  final double passiveTotal;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TypeCard(
            label: 'Active',
            sublabel: 'Salary, freelance, side hustle',
            amount: activeTotal,
            percentage: total > 0 ? activeTotal / total * 100 : 0,
            icon: HugeIcons.strokeRoundedBriefcase01,
            accentColor: AppColors.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TypeCard(
            label: 'Passive',
            sublabel: 'Dividends, rental, other',
            amount: passiveTotal,
            percentage: total > 0 ? passiveTotal / total * 100 : 0,
            icon: HugeIcons.strokeRoundedCoins01,
            accentColor: const Color(0xFF7EB8FF),
          ),
        ),
      ],
    );
  }
}

class _TypeCard extends StatefulWidget {
  const _TypeCard({
    required this.label,
    required this.sublabel,
    required this.amount,
    required this.percentage,
    required this.icon,
    required this.accentColor,
  });

  final String label;
  final String sublabel;
  final double amount;
  final double percentage;
  final dynamic icon;
  final Color accentColor;

  @override
  State<_TypeCard> createState() => _TypeCardState();
}

class _TypeCardState extends State<_TypeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_TypeCard old) {
    super.didUpdateWidget(old);
    if (old.amount != widget.amount) {
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
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 130),
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
                    color: widget.accentColor.withValues(alpha: 0.07),
                    blurRadius: 18,
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
                        _rwfCompact(v),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: widget.accentColor,
                          letterSpacing: -0.4,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.sublabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 10),
                  AnimatedBuilder(
                    animation: _anim,
                    builder: (context, _) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: SizedBox(
                          height: 3,
                          child: LinearProgressIndicator(
                            value: (widget.percentage / 100) * _anim.value,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.08,
                            ),
                            valueColor: AlwaysStoppedAnimation(
                              widget.accentColor,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 5),
                  AnimatedBuilder(
                    animation: _anim,
                    builder: (context, _) {
                      final pct = widget.percentage * _anim.value;
                      return Text(
                        '${pct.toStringAsFixed(0)}% of total',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: widget.accentColor.withValues(alpha: 0.7),
                        ),
                      );
                    },
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

// ── Category bars ─────────────────────────────────────────────────────────────

class _CategoryBars extends StatelessWidget {
  const _CategoryBars({required this.entries, required this.total});

  final List<IncomeEntry> entries;
  final double total;

  Map<IncomeCategory, double> get _byCategory {
    final map = <IncomeCategory, double>{};
    for (final e in entries) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return Map.fromEntries(
      map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 760;
    final byCategory = _byCategory;

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
                    icon: HugeIcons.strokeRoundedBarChart,
                    size: 16,
                    color: AppColors.primary,
                    strokeWidth: 1.8,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'By category',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          if (byCategory.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: _EmptyHint(
                message: 'Add income entries to see category breakdown.',
              ),
            )
          else ...[
            const SizedBox(height: 20),
            for (final entry in byCategory.entries)
              _CategoryBar(
                category: entry.key,
                amount: entry.value,
                total: total,
              ),
          ],
        ],
      ),
    );
  }
}

class _CategoryBar extends StatefulWidget {
  const _CategoryBar({
    required this.category,
    required this.amount,
    required this.total,
  });

  final IncomeCategory category;
  final double amount;
  final double total;

  @override
  State<_CategoryBar> createState() => _CategoryBarState();
}

class _CategoryBarState extends State<_CategoryBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_CategoryBar old) {
    super.didUpdateWidget(old);
    if (old.amount != widget.amount || old.total != widget.total) {
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
    final ratio = widget.total > 0 ? widget.amount / widget.total : 0.0;
    final color = widget.category.color;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.14),
            ),
            child: Center(
              child: HugeIcon(
                icon: widget.category.icon,
                size: 14,
                color: color,
                strokeWidth: 1.8,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.category.displayName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _rwfCompact(widget.amount),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                AnimatedBuilder(
                  animation: _anim,
                  builder: (context, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: SizedBox(
                      height: 4,
                      child: Row(
                        children: [
                          Expanded(
                            flex: (ratio * _anim.value * 1000).round(),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [color, color.withValues(alpha: 0.6)],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: ((1 - ratio * _anim.value) * 1000)
                                .round()
                                .clamp(1, 1000),
                            child: Container(
                              color: Colors.white.withValues(alpha: 0.06),
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
        ],
      ),
    );
  }
}

// ── Entry list ────────────────────────────────────────────────────────────────

class _EntryList extends StatelessWidget {
  const _EntryList({
    required this.entries,
    required this.total,
    required this.loadError,
    required this.onRetry,
    required this.onEdit,
    required this.onDelete,
  });

  final List<IncomeEntry> entries;
  final double total;
  final String? loadError;
  final Future<void> Function() onRetry;
  final void Function(IncomeEntry) onEdit;
  final void Function(IncomeEntry) onDelete;

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
                    icon: HugeIcons.strokeRoundedListView,
                    size: 16,
                    color: AppColors.success,
                    strokeWidth: 1.8,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'All entries',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${entries.length} records',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (loadError != null && entries.isEmpty)
            _LoadErrorHint(message: loadError!, onRetry: onRetry)
          else if (entries.isEmpty)
            _EmptyHint(message: 'No income entries yet. Tap + to add one.')
          else
            ...List.generate(entries.length, (i) {
              return _EntryRow(
                entry: entries[i],
                total: total,
                isLast: i == entries.length - 1,
                index: i,
                onEdit: onEdit,
                onDelete: onDelete,
              );
            }),
        ],
      ),
    );
  }
}

class _EntryRow extends StatefulWidget {
  const _EntryRow({
    required this.entry,
    required this.total,
    required this.isLast,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  final IncomeEntry entry;
  final double total;
  final bool isLast;
  final int index;
  final void Function(IncomeEntry) onEdit;
  final void Function(IncomeEntry) onDelete;

  @override
  State<_EntryRow> createState() => _EntryRowState();
}

class _EntryRowState extends State<_EntryRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    Future.delayed(Duration(milliseconds: 60 + widget.index * 60), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) {
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
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.entry.category.color;

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) => FadeTransition(
        opacity: _anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.04, 0),
            end: Offset.zero,
          ).animate(_anim),
          child: child,
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.14),
                      border: Border.all(color: color.withValues(alpha: 0.22)),
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: widget.entry.category.icon,
                        size: 18,
                        color: color,
                        strokeWidth: 1.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.entry.label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.entry.category.displayName,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.65,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _rwfCompact(widget.entry.amount),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowDown01,
                          size: 12,
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                          strokeWidth: 2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expandable detail row
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.white.withValues(alpha: 0.04),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _DetailItem(
                                  label: 'Amount',
                                  value: _rwf(widget.entry.amount),
                                ),
                                const SizedBox(height: 4),
                                _DetailItem(
                                  label: 'Date',
                                  value: _formatDate(widget.entry.date),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              _ActionIcon(
                                icon: HugeIcons.strokeRoundedPencil,
                                color: const Color(0xFF7EB8FF),
                                tooltip: 'Edit',
                                onTap: () => widget.onEdit(widget.entry),
                              ),
                              const SizedBox(width: 8),
                              _ActionIcon(
                                icon: HugeIcons.strokeRoundedDelete01,
                                color: AppColors.danger,
                                tooltip: 'Delete',
                                onTap: () => widget.onDelete(widget.entry),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
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
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary.withValues(alpha: 0.6),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ActionIcon extends StatefulWidget {
  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final dynamic icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_ActionIcon> createState() => _ActionIconState();
}

class _ActionIconState extends State<_ActionIcon> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: 0.12),
            border: Border.all(color: widget.color.withValues(alpha: 0.2)),
          ),
          child: Center(
            child: HugeIcon(
              icon: widget.icon,
              size: 15,
              color: widget.color,
              strokeWidth: 1.8,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Form dialog (Add / Edit) ──────────────────────────────────────────────────

class _IncomeFormDialog extends StatefulWidget {
  const _IncomeFormDialog({required this.entry, required this.onSubmit});

  final IncomeEntry? entry;
  final Future<IncomeEntry> Function({
    required String label,
    required double amount,
    required IncomeCategory category,
    required DateTime date,
  })
  onSubmit;

  @override
  State<_IncomeFormDialog> createState() => _IncomeFormDialogState();
}

class _IncomeFormDialogState extends State<_IncomeFormDialog>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _labelCtrl;
  late final TextEditingController _amountCtrl;
  late IncomeCategory _category;
  late DateTime _date;
  late final AnimationController _animCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.entry?.label ?? '');
    _amountCtrl = TextEditingController(
      text: widget.entry?.amount.toStringAsFixed(0) ?? '',
    );
    _category = widget.entry?.category ?? IncomeCategory.salary;
    _date = widget.entry?.date ?? DateTime.now();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _scaleAnim = Tween<double>(
      begin: 0.90,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _amountCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    if (_isSubmitting) {
      return;
    }

    final latestSelectableDate = DateTime.now().add(
      const Duration(days: 365 * 10),
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: latestSelectableDate,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.success,
            onPrimary: AppColors.background,
            surface: AppColors.surfaceElevated,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) return;

    setState(() => _isSubmitting = true);

    try {
      final result = await widget.onSubmit(
        label: _labelCtrl.text.trim(),
        amount: amount,
        category: _category,
        date: _date,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: _isEditing ? 'Unable to update income' : 'Unable to add income',
        description: _readableError(error),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _readableError(Object error) {
    final message = error.toString().trim();

    if (message.startsWith('Exception: ')) {
      return message.replaceFirst('Exception: ', '');
    }

    if (message.startsWith('StateError: ')) {
      return message.replaceFirst('StateError: ', '');
    }

    return message;
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 600;
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
    final dateLabel = '${months[_date.month - 1]} ${_date.day}, ${_date.year}';

    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: isCompact ? 16 : 40,
            vertical: 24,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 460),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.15),
                      Colors.white.withValues(alpha: 0.08),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.08),
                      blurRadius: 48,
                      offset: const Offset(0, 20),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Dialog header
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.success.withValues(
                                  alpha: 0.16,
                                ),
                              ),
                              child: Center(
                                child: HugeIcon(
                                  icon: _isEditing
                                      ? HugeIcons.strokeRoundedPencil
                                      : HugeIcons.strokeRoundedMoneyAdd01,
                                  size: 18,
                                  color: AppColors.success,
                                  strokeWidth: 1.8,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isEditing ? 'Edit income' : 'Add income',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    _isEditing
                                        ? 'Update the details below'
                                        : 'Fill in the details below',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: _isSubmitting
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.07),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Center(
                                  child: HugeIcon(
                                    icon: HugeIcons.strokeRoundedCancel01,
                                    size: 14,
                                    color: AppColors.textSecondary,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _GradientDivider(color: AppColors.success),
                        const SizedBox(height: 24),

                        // Source label
                        _FieldLabel(label: 'Source name'),
                        const SizedBox(height: 8),
                        _GlassField(
                          controller: _labelCtrl,
                          hint: 'e.g. Monthly Salary',
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Please enter a source name'
                              : null,
                        ),
                        const SizedBox(height: 18),

                        // Amount
                        _FieldLabel(label: 'Amount (RWF)'),
                        const SizedBox(height: 8),
                        _GlassField(
                          controller: _amountCtrl,
                          hint: 'e.g. 450000',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          prefixText: 'RWF ',
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter an amount';
                            }
                            final n = double.tryParse(v.replaceAll(',', ''));
                            if (n == null || n <= 0) {
                              return 'Enter a valid amount';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

                        // Category
                        _FieldLabel(label: 'Category'),
                        const SizedBox(height: 8),
                        _CategoryPicker(
                          selected: _category,
                          onChanged: (c) => setState(() => _category = c),
                        ),
                        const SizedBox(height: 18),

                        // Date
                        _FieldLabel(label: 'Date'),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _pickDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: Colors.white.withValues(alpha: 0.06),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Row(
                              children: [
                                HugeIcon(
                                  icon: HugeIcons.strokeRoundedCalendar03,
                                  size: 16,
                                  color: AppColors.textSecondary.withValues(
                                    alpha: 0.7,
                                  ),
                                  strokeWidth: 1.8,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  dateLabel,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                HugeIcon(
                                  icon: HugeIcons.strokeRoundedArrowDown01,
                                  size: 14,
                                  color: AppColors.textSecondary.withValues(
                                    alpha: 0.5,
                                  ),
                                  strokeWidth: 1.8,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: _DialogButton(
                                label: 'Cancel',
                                isPrimary: false,
                                isDisabled: _isSubmitting,
                                onTap: () async {
                                  Navigator.of(context).pop();
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _DialogButton(
                                label: _isEditing
                                    ? 'Save changes'
                                    : 'Add income',
                                isPrimary: true,
                                isLoading: _isSubmitting,
                                onTap: _submit,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Category picker ───────────────────────────────────────────────────────────

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.selected, required this.onChanged});

  final IncomeCategory selected;
  final void Function(IncomeCategory) onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: IncomeCategory.values.map((cat) {
        final isSelected = cat == selected;
        final color = cat.color;
        return GestureDetector(
          onTap: () => onChanged(cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isSelected
                  ? color.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: isSelected
                    ? color.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(
                  icon: cat.icon,
                  size: 13,
                  color: isSelected ? color : AppColors.textSecondary,
                  strokeWidth: 1.8,
                ),
                const SizedBox(width: 6),
                Text(
                  cat.displayName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? color : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Delete confirm dialog ─────────────────────────────────────────────────────

class _DeleteConfirmDialog extends StatefulWidget {
  const _DeleteConfirmDialog({required this.label});
  final String label;

  @override
  State<_DeleteConfirmDialog> createState() => _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends State<_DeleteConfirmDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scaleAnim = Tween<double>(
      begin: 0.88,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 40,
            vertical: 24,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 380),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.14),
                      Colors.white.withValues(alpha: 0.08),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.danger.withValues(alpha: 0.08),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.danger.withValues(alpha: 0.14),
                        border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedDelete01,
                          size: 24,
                          color: AppColors.danger,
                          strokeWidth: 1.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Remove income entry?',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '"${widget.label}" will be permanently removed from your records.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.55,
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _DialogButton(
                            label: 'Keep it',
                            isPrimary: false,
                            onTap: () async {
                              Navigator.of(context).pop(false);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DialogButton(
                            label: 'Delete',
                            isPrimary: true,
                            isDanger: true,
                            onTap: () async {
                              Navigator.of(context).pop(true);
                            },
                          ),
                        ),
                      ],
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
}

// ── Shared dialog widgets ─────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary.withValues(alpha: 0.9),
        letterSpacing: 0.2,
      ),
    );
  }
}

class _GlassField extends StatelessWidget {
  const _GlassField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.prefixText,
    this.validator,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? prefixText;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(
        fontSize: 13,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        prefixText: prefixText,
        prefixStyle: const TextStyle(
          fontSize: 13,
          color: AppColors.success,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary.withValues(alpha: 0.4),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.success.withValues(alpha: 0.5),
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.danger.withValues(alpha: 0.5),
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.danger.withValues(alpha: 0.7),
          ),
        ),
        errorStyle: const TextStyle(fontSize: 11, color: AppColors.danger),
      ),
    );
  }
}

class _DialogButton extends StatefulWidget {
  const _DialogButton({
    required this.label,
    required this.isPrimary,
    required this.onTap,
    this.isDanger = false,
    this.isLoading = false,
    this.isDisabled = false,
  });

  final String label;
  final bool isPrimary;
  final bool isDanger;
  final bool isLoading;
  final bool isDisabled;
  final Future<void> Function() onTap;

  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.isDanger ? AppColors.danger : AppColors.success;
    final isInteractive = !widget.isLoading && !widget.isDisabled;

    return GestureDetector(
      onTapDown: isInteractive ? (_) => setState(() => _pressed = true) : null,
      onTapUp: isInteractive
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap();
            }
          : null,
      onTapCancel: isInteractive
          ? () => setState(() => _pressed = false)
          : null,
      child: AnimatedScale(
        scale: _pressed && isInteractive ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: widget.isPrimary
                ? accent.withValues(alpha: isInteractive ? 0.18 : 0.10)
                : Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: widget.isPrimary
                  ? accent.withValues(alpha: isInteractive ? 0.4 : 0.2)
                  : Colors.white.withValues(alpha: 0.1),
            ),
            boxShadow: widget.isPrimary && isInteractive
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.14),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: widget.isLoading
                  ? SizedBox(
                      key: const ValueKey('dialog-button-loading'),
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.isPrimary ? accent : AppColors.textSecondary,
                        ),
                      ),
                    )
                  : Text(
                      widget.label,
                      key: ValueKey<String>(widget.label),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: widget.isPrimary
                            ? accent
                            : AppColors.textSecondary.withValues(
                                alpha: isInteractive ? 1 : 0.55,
                              ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Animated counter ──────────────────────────────────────────────────────────

class _AnimatedCounter extends StatefulWidget {
  const _AnimatedCounter({required this.value, required this.style});
  final double value;
  final TextStyle style;

  @override
  State<_AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<_AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  double _previous = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_AnimatedCounter old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _previous = old.value;
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
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final v = _previous + _anim.value * (widget.value - _previous);
        return Text(_rwf(v), style: widget.style);
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
            color.withValues(alpha: 0.22),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

// ── Empty hint ────────────────────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedMoneyReceiveCircle,
            size: 36,
            color: AppColors.textSecondary.withValues(alpha: 0.25),
            strokeWidth: 1.5,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary.withValues(alpha: 0.45),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadErrorHint extends StatelessWidget {
  const _LoadErrorHint({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedAlert02,
            size: 34,
            color: AppColors.danger.withValues(alpha: 0.75),
            strokeWidth: 1.6,
          ),
          const SizedBox(height: 14),
          Text(
            'Income sync is temporarily unavailable',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary.withValues(alpha: 0.75),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 18),
          _RetryButton(onTap: onRetry),
        ],
      ),
    );
  }
}

class _RetryButton extends StatefulWidget {
  const _RetryButton({required this.onTap});

  final Future<void> Function() onTap;

  @override
  State<_RetryButton> createState() => _RetryButtonState();
}

class _RetryButtonState extends State<_RetryButton> {
  bool _pressed = false;
  bool _isLoading = false;

  Future<void> _handleTap() async {
    if (_isLoading) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      await widget.onTap();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _isLoading ? null : (_) => setState(() => _pressed = true),
      onTapUp: _isLoading
          ? null
          : (_) {
              setState(() => _pressed = false);
              _handleTap();
            },
      onTapCancel: _isLoading ? null : () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: AppColors.success.withValues(alpha: 0.14),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.28),
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _isLoading
                ? const SizedBox(
                    key: ValueKey('retry-loading'),
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.success,
                      ),
                    ),
                  )
                : const Text(
                    'Retry sync',
                    key: ValueKey('retry-label'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
          ),
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
          'Live income sync · secured to your account session',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary.withValues(alpha: 0.4),
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}
