import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/app_toast.dart';
import '../../../../../core/widgets/glass_panel.dart';
import '../../../../../core/widgets/skeleton_loader.dart';
import '../../../../../features/auth/data/models/auth_user.dart';
import '../../../../../features/expenses/application/expense_service.dart';
import '../../../../../features/expenses/data/models/expense_entry.dart';
import '../../../../../features/income/application/income_service.dart';
import '../../../../../features/income/data/models/income_entry.dart';
import '../../../../../features/loans/application/loan_service.dart';
import '../../../../../features/loans/data/models/loan_entry.dart';
import '../../../../../features/partnerships/application/partnership_service.dart';
import '../../../../../features/partnerships/data/models/partnership_models.dart';
import '../../../../../features/savings/application/saving_service.dart';
import '../../../../../features/savings/data/models/saving_entry.dart';
import '../../../../../features/todos/application/todo_service.dart';
import '../../../../../features/todos/data/models/todo_item.dart';
import '../../../../../features/todos/presentation/todo_utils.dart';
import 'dashboard_header.dart';
import 'dashboard_utils.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.user,
    required this.incomeService,
    required this.expenseService,
    required this.savingService,
    required this.loanService,
    required this.todoService,
    required this.partnershipService,
  });

  final AuthUser user;
  final IncomeService incomeService;
  final ExpenseService expenseService;
  final SavingService savingService;
  final LoanService loanService;
  final TodoService todoService;
  final PartnershipService partnershipService;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceCtrl;

  late int _selectedMonth;
  late int _selectedYear;

  List<IncomeEntry> _allIncome = const <IncomeEntry>[];
  List<ExpenseEntry> _allExpenses = const <ExpenseEntry>[];
  List<SavingEntry> _allSavings = const <SavingEntry>[];
  List<LoanEntry> _allLoans = const <LoanEntry>[];
  List<TodoItem> _allTodos = const <TodoItem>[];
  List<ExpenseCategoryOption> _expenseCategories =
      const <ExpenseCategoryOption>[];
  Partnership? _partnership;

  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _loadDashboard();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  List<IncomeEntry> get _monthlyIncome => filterEntriesByMonth(
    _allIncome,
    (entry) => entry.date,
    _selectedMonth,
    _selectedYear,
  );

  List<ExpenseEntry> get _monthlyExpenses => filterEntriesByMonth(
    _allExpenses,
    (entry) => entry.date,
    _selectedMonth,
    _selectedYear,
  );

  List<SavingEntry> get _monthlySavings => filterEntriesByMonth(
    _allSavings,
    (entry) => entry.date,
    _selectedMonth,
    _selectedYear,
  );

  List<LoanEntry> get _monthlyLoans => filterEntriesByMonth(
    _allLoans,
    (entry) => entry.date,
    _selectedMonth,
    _selectedYear,
  );

  bool get _canGoToNextMonth {
    final now = DateTime.now();
    return _selectedYear < now.year ||
        (_selectedYear == now.year && _selectedMonth < now.month);
  }

  double get _monthlyIncomeAmount => sumIncomeAmounts(_monthlyIncome);

  double get _monthlyExpenseAmount => sumExpenseAmounts(_monthlyExpenses);

  double get _monthlyNetFlow => _monthlyIncomeAmount - _monthlyExpenseAmount;

  double get _allTimeSavingsAmount =>
      sumSavingAmounts(_allSavings, stillHaveOnly: true);

  double get _allTimeMoneyLeft =>
      sumIncomeAmounts(_allIncome) -
      sumExpenseAmounts(_allExpenses) -
      _allTimeSavingsAmount;

  double get _pendingTodoAmount => sumTodoAmounts(_allTodos, pendingOnly: true);

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        widget.incomeService.listIncome(),
        widget.expenseService.listExpenses(),
        widget.savingService.listSavings(),
        widget.loanService.listLoans(),
        widget.todoService.listTodos(),
        widget.expenseService.listExpenseCategories().catchError((_) {
          return <ExpenseCategoryOption>[];
        }),
        widget.partnershipService.getMyPartnership().catchError((_) {
          return null;
        }),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _allIncome = (results[0] as List<dynamic>).cast<IncomeEntry>();
        _allExpenses = (results[1] as List<dynamic>).cast<ExpenseEntry>();
        _allSavings = (results[2] as List<dynamic>).cast<SavingEntry>();
        _allLoans = (results[3] as List<dynamic>).cast<LoanEntry>();
        _allTodos = (results[4] as List<dynamic>).cast<TodoItem>();
        _expenseCategories = (results[5] as List<dynamic>)
            .cast<ExpenseCategoryOption>();
        _partnership = results[6] as Partnership?;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = _readableError(error);
      setState(() {
        _isLoading = false;
        _loadError = message;
      });

      AppToast.error(
        context,
        title: 'Unable to load dashboard',
        description: message,
      );
    }
  }

  void _goToPreviousMonth() {
    setState(() {
      if (_selectedMonth == 1) {
        _selectedMonth = 12;
        _selectedYear -= 1;
      } else {
        _selectedMonth -= 1;
      }
    });
  }

  void _goToNextMonth() {
    if (!_canGoToNextMonth) {
      return;
    }

    setState(() {
      if (_selectedMonth == 12) {
        _selectedMonth = 1;
        _selectedYear += 1;
      } else {
        _selectedMonth += 1;
      }
    });
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
    if (_isLoading) {
      return _DashboardLoadingState(fade: _fade, slide: _slide);
    }

    if (_loadError != null) {
      return _DashboardErrorState(
        message: _loadError!,
        onRetry: _loadDashboard,
      );
    }

    final dailyPoints = buildDailyMovementPoints(
      income: _monthlyIncome,
      expenses: _monthlyExpenses,
      month: _selectedMonth,
      year: _selectedYear,
    );
    final topCategories = buildTopSpendingCategories(
      expenses: _monthlyExpenses,
      categoryOptions: _expenseCategories,
    );
    final pendingIncomeEntries =
        _monthlyIncome.where((entry) => !entry.received).toList(growable: false)
          ..sort((left, right) => right.amount.compareTo(left.amount));
    final monthComparison = buildMonthComparisonSummary(
      allIncome: _allIncome,
      allExpenses: _allExpenses,
      month: _selectedMonth,
      year: _selectedYear,
    );
    final todoReserveSummary = buildDashboardTodoReserveSummary(_allTodos);
    final upcomingTodoDays = buildUpcomingTodoSchedule(_allTodos);
    final partnerActivitySummary = buildPartnerActivitySummary(
      currentUser: widget.user,
      partnership: _partnership,
      income: _monthlyIncome,
      expenses: _monthlyExpenses,
      savings: _monthlySavings,
      loans: _monthlyLoans,
    );
    final loansOverview = buildLoanOverview(_monthlyLoans);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1080;

        final mainColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Staggered(
              fade: _fade(0.00, 0.42),
              slide: _slide(0.00, 0.42),
              child: DashboardHeader(
                user: widget.user,
                month: _selectedMonth,
                year: _selectedYear,
                canGoNextMonth: _canGoToNextMonth,
                onPrevMonth: _goToPreviousMonth,
                onNextMonth: _goToNextMonth,
              ),
            ),
            const SizedBox(height: 14),
            _Staggered(
              fade: _fade(0.08, 0.50),
              slide: _slide(0.08, 0.50),
              child: _SummaryGrid(
                cards: <_SummaryCardData>[
                  _SummaryCardData(
                    label: 'Total income',
                    compactValue: _rwfCompact(_monthlyIncomeAmount),
                    fullValue: _rwf(_monthlyIncomeAmount),
                    description:
                        'Received in ${formatDashboardMonthLabel(_selectedMonth)} $_selectedYear',
                    tone: _SummaryTone.income,
                  ),
                  _SummaryCardData(
                    label: 'Total expense',
                    compactValue: _rwfCompact(_monthlyExpenseAmount),
                    fullValue: _rwf(_monthlyExpenseAmount),
                    description:
                        'Recorded in ${formatDashboardMonthLabel(_selectedMonth)} $_selectedYear',
                    tone: _SummaryTone.expense,
                  ),
                  _SummaryCardData(
                    label: 'Net flow this month',
                    compactValue: _rwfCompact(_monthlyNetFlow),
                    fullValue: _rwf(_monthlyNetFlow),
                    description:
                        'Income minus expense for ${formatDashboardMonthLabel(_selectedMonth)} $_selectedYear',
                    tone: _monthlyNetFlow >= 0
                        ? _SummaryTone.income
                        : _SummaryTone.expense,
                  ),
                  _SummaryCardData(
                    label: 'Current savings balance',
                    compactValue: _rwfCompact(_allTimeSavingsAmount),
                    fullValue: _rwf(_allTimeSavingsAmount),
                    description:
                        'Ledger-backed money currently parked in savings',
                    tone: _SummaryTone.saving,
                  ),
                  _SummaryCardData(
                    label: 'Available money now',
                    compactValue: _rwfCompact(_allTimeMoneyLeft),
                    fullValue: _rwf(_allTimeMoneyLeft),
                    description:
                        'Income minus expenses and current savings balance',
                    tone: _allTimeMoneyLeft >= 0
                        ? _SummaryTone.income
                        : _SummaryTone.expense,
                  ),
                  _SummaryCardData(
                    label: 'Todo amount',
                    compactValue: _rwfCompact(_pendingTodoAmount),
                    fullValue: _rwf(_pendingTodoAmount),
                    description: 'All todo prices that are still not done',
                    tone: _SummaryTone.todo,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _Staggered(
              fade: _fade(0.16, 0.60),
              slide: _slide(0.16, 0.60),
              child: _DailyMovementSection(
                points: dailyPoints,
                month: _selectedMonth,
                year: _selectedYear,
              ),
            ),
            const SizedBox(height: 14),
            _Staggered(
              fade: _fade(0.24, 0.68),
              slide: _slide(0.24, 0.68),
              child: _TopSpendingCategoriesSection(
                items: topCategories,
                month: _selectedMonth,
                year: _selectedYear,
              ),
            ),
            const SizedBox(height: 14),
            _Staggered(
              fade: _fade(0.32, 0.76),
              slide: _slide(0.32, 0.76),
              child: _UpcomingTodoScheduleSection(days: upcomingTodoDays),
            ),
            if (partnerActivitySummary != null) ...[
              const SizedBox(height: 14),
              _Staggered(
                fade: _fade(0.40, 0.84),
                slide: _slide(0.40, 0.84),
                child: _PartnerActivitySection(summary: partnerActivitySummary),
              ),
            ],
          ],
        );

        final sideColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Staggered(
              fade: _fade(0.18, 0.62),
              slide: _slide(0.18, 0.62),
              child: _SavingsRateSection(
                incomeAmount: _monthlyIncomeAmount,
                expenseAmount: _monthlyExpenseAmount,
                month: _selectedMonth,
                year: _selectedYear,
              ),
            ),
            const SizedBox(height: 14),
            _Staggered(
              fade: _fade(0.26, 0.70),
              slide: _slide(0.26, 0.70),
              child: _PendingIncomeSection(entries: pendingIncomeEntries),
            ),
            const SizedBox(height: 14),
            _Staggered(
              fade: _fade(0.34, 0.78),
              slide: _slide(0.34, 0.78),
              child: _MonthComparisonSection(summary: monthComparison),
            ),
            const SizedBox(height: 14),
            _Staggered(
              fade: _fade(0.42, 0.86),
              slide: _slide(0.42, 0.86),
              child: _TodoReserveSection(summary: todoReserveSummary),
            ),
            const SizedBox(height: 14),
            _Staggered(
              fade: _fade(0.50, 0.94),
              slide: _slide(0.50, 0.94),
              child: _LoanOverviewSection(
                overview: loansOverview,
                month: _selectedMonth,
                year: _selectedYear,
              ),
            ),
          ],
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 12, child: mainColumn),
              const SizedBox(width: 14),
              Expanded(flex: 8, child: sideColumn),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [mainColumn, const SizedBox(height: 14), sideColumn],
        );
      },
    );
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

class _DashboardLoadingState extends StatelessWidget {
  const _DashboardLoadingState({required this.fade, required this.slide});

  final Animation<double> Function(double, double) fade;
  final Animation<Offset> Function(double, double) slide;

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1080;

          final mainColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Staggered(
                fade: fade(0.00, 0.42),
                slide: slide(0.00, 0.42),
                child: const _LoadingDashboardHeader(),
              ),
              const SizedBox(height: 14),
              _Staggered(
                fade: fade(0.08, 0.50),
                slide: slide(0.08, 0.50),
                child: const _LoadingSummaryGrid(),
              ),
              const SizedBox(height: 14),
              _Staggered(
                fade: fade(0.16, 0.60),
                slide: slide(0.16, 0.60),
                child: const _LoadingDailyMovementSection(),
              ),
              const SizedBox(height: 14),
              _Staggered(
                fade: fade(0.24, 0.68),
                slide: slide(0.24, 0.68),
                child: const _LoadingTopCategoriesSection(),
              ),
              const SizedBox(height: 14),
              _Staggered(
                fade: fade(0.32, 0.76),
                slide: slide(0.32, 0.76),
                child: const _LoadingUpcomingTodoScheduleSection(),
              ),
              const SizedBox(height: 14),
              _Staggered(
                fade: fade(0.40, 0.84),
                slide: slide(0.40, 0.84),
                child: const _LoadingPartnerActivitySection(),
              ),
            ],
          );

          final sideColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Staggered(
                fade: fade(0.18, 0.62),
                slide: slide(0.18, 0.62),
                child: const _LoadingSavingsRateSection(),
              ),
              const SizedBox(height: 14),
              _Staggered(
                fade: fade(0.26, 0.70),
                slide: slide(0.26, 0.70),
                child: const _LoadingPendingIncomeSection(),
              ),
              const SizedBox(height: 14),
              _Staggered(
                fade: fade(0.34, 0.78),
                slide: slide(0.34, 0.78),
                child: const _LoadingMonthComparisonSection(),
              ),
              const SizedBox(height: 14),
              _Staggered(
                fade: fade(0.42, 0.86),
                slide: slide(0.42, 0.86),
                child: const _LoadingTodoReserveSection(),
              ),
              const SizedBox(height: 14),
              _Staggered(
                fade: fade(0.50, 0.94),
                slide: slide(0.50, 0.94),
                child: const _LoadingLoanOverviewSection(),
              ),
            ],
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 12, child: mainColumn),
                const SizedBox(width: 14),
                Expanded(flex: 8, child: sideColumn),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [mainColumn, const SizedBox(height: 14), sideColumn],
          );
        },
      ),
    );
  }
}

class _LoadingDashboardHeader extends StatelessWidget {
  const _LoadingDashboardHeader();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 560;
        final greeting = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SkeletonBox(width: 220, height: 28, radius: 16),
            SizedBox(height: 8),
            SkeletonBox(width: 198, height: 13, radius: 12),
          ],
        );

        final navigator = Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SkeletonBox(width: 30, height: 30, radius: 10),
              SizedBox(width: 8),
              SkeletonBox(width: 74, height: 14, radius: 12),
              SizedBox(width: 8),
              SkeletonBox(width: 30, height: 30, radius: 10),
            ],
          ),
        );

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [greeting, const SizedBox(height: 12), navigator],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: greeting),
            const SizedBox(width: 12),
            navigator,
          ],
        );
      },
    );
  }
}

class _LoadingSummaryGrid extends StatelessWidget {
  const _LoadingSummaryGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1080
            ? 3
            : (constraints.maxWidth >= 680 ? 2 : 1);
        final spacing = 12.0;
        final width = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(
            6,
            (_) => SizedBox(width: width, child: const _LoadingSummaryCard()),
          ),
        );
      },
    );
  }
}

class _LoadingSummaryCard extends StatelessWidget {
  const _LoadingSummaryCard();

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      borderRadius: BorderRadius.circular(24),
      blur: 22,
      opacity: 0.12,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonBox(width: 30, height: 30, radius: 999),
              Spacer(),
              SkeletonBox(width: 72, height: 10, radius: 999),
            ],
          ),
          SizedBox(height: 14),
          SkeletonBox(width: 92, height: 11, radius: 10),
          SizedBox(height: 8),
          SkeletonBox(width: 138, height: 24, radius: 14),
          SizedBox(height: 12),
          SkeletonBox(height: 11, radius: 10),
          SizedBox(height: 6),
          SkeletonBox(width: 170, height: 11, radius: 10),
        ],
      ),
    );
  }
}

class _LoadingSectionShell extends StatelessWidget {
  const _LoadingSectionShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(22),
      borderRadius: BorderRadius.circular(28),
      blur: 24,
      opacity: 0.12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              SkeletonBox(width: 34, height: 34, radius: 999),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 132, height: 15, radius: 10),
                    SizedBox(height: 6),
                    SkeletonBox(height: 11, radius: 10),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _LoadingMetricPill extends StatelessWidget {
  const _LoadingMetricPill({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(width: 58, height: 10, radius: 10),
          const SizedBox(height: 8),
          SkeletonBox(width: width, height: 13, radius: 12),
        ],
      ),
    );
  }
}

class _LoadingDetailPair extends StatelessWidget {
  const _LoadingDetailPair();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBox(width: 50, height: 10, radius: 10),
        SizedBox(height: 5),
        SkeletonBox(width: 86, height: 12, radius: 10),
      ],
    );
  }
}

class _LoadingLedgerRow extends StatelessWidget {
  const _LoadingLedgerRow({this.leadingCircle = false});

  final bool leadingCircle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          if (leadingCircle) ...[
            const SkeletonBox(width: 30, height: 30, radius: 999),
            const SizedBox(width: 10),
          ],
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 126, height: 12, radius: 10),
                SizedBox(height: 6),
                SkeletonBox(width: 94, height: 10, radius: 10),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const SkeletonBox(width: 68, height: 12, radius: 10),
        ],
      ),
    );
  }
}

class _LoadingDailyMovementSection extends StatelessWidget {
  const _LoadingDailyMovementSection();

  @override
  Widget build(BuildContext context) {
    return _LoadingSectionShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _LoadingMetricPill(width: 90),
              _LoadingMetricPill(width: 84),
              _LoadingMetricPill(width: 92),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Row(
              children: [
                Expanded(child: _LoadingDetailPair()),
                SizedBox(width: 12),
                Expanded(child: _LoadingDetailPair()),
                SizedBox(width: 12),
                Expanded(child: _LoadingDetailPair()),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(14, (index) {
                final incomeHeight = 40.0 + ((index % 5) * 10);
                final expenseHeight = 32.0 + (((index + 2) % 5) * 11);

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: index == 13 ? 0 : 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          height: 96,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              SkeletonBox(
                                width: 5,
                                height: incomeHeight,
                                radius: 999,
                              ),
                              const SizedBox(width: 3),
                              SkeletonBox(
                                width: 5,
                                height: expenseHeight,
                                radius: 999,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const SkeletonBox(width: 12, height: 10, radius: 10),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingTopCategoriesSection extends StatelessWidget {
  const _LoadingTopCategoriesSection();

  @override
  Widget build(BuildContext context) {
    return _LoadingSectionShell(
      child: Column(
        children: List.generate(
          4,
          (index) => Padding(
            padding: EdgeInsets.only(bottom: index == 3 ? 0 : 12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Colors.white.withValues(alpha: 0.04),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SkeletonBox(width: 30, height: 30, radius: 999),
                      SizedBox(width: 10),
                      Expanded(
                        child: SkeletonBox(width: 120, height: 12, radius: 10),
                      ),
                      SizedBox(width: 10),
                      SkeletonBox(width: 56, height: 12, radius: 10),
                    ],
                  ),
                  SizedBox(height: 10),
                  SkeletonBox(height: 6, radius: 999),
                  SizedBox(height: 8),
                  SkeletonBox(width: 118, height: 11, radius: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingUpcomingTodoScheduleSection extends StatelessWidget {
  const _LoadingUpcomingTodoScheduleSection();

  @override
  Widget build(BuildContext context) {
    return _LoadingSectionShell(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 980
              ? 4
              : (constraints.maxWidth >= 640 ? 2 : 1);
          final spacing = 10.0;
          final width = columns == 1
              ? constraints.maxWidth
              : (constraints.maxWidth - (spacing * (columns - 1))) / columns;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: List.generate(
              7,
              (_) => SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: Colors.white.withValues(alpha: 0.04),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SkeletonBox(width: 58, height: 12, radius: 10),
                          Spacer(),
                          SkeletonBox(width: 46, height: 11, radius: 10),
                        ],
                      ),
                      SizedBox(height: 10),
                      SkeletonBox(height: 11, radius: 10),
                      SizedBox(height: 8),
                      SkeletonBox(width: 110, height: 11, radius: 10),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LoadingSavingsRateSection extends StatelessWidget {
  const _LoadingSavingsRateSection();

  @override
  Widget build(BuildContext context) {
    return _LoadingSectionShell(
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _LoadingMetricPill(width: 72)),
              SizedBox(width: 10),
              Expanded(child: _LoadingMetricPill(width: 84)),
            ],
          ),
          SizedBox(height: 16),
          SkeletonBox(height: 8, radius: 999),
          SizedBox(height: 12),
          SkeletonBox(height: 11, radius: 10),
          SizedBox(height: 6),
          SkeletonBox(width: 210, height: 11, radius: 10),
        ],
      ),
    );
  }
}

class _LoadingPendingIncomeSection extends StatelessWidget {
  const _LoadingPendingIncomeSection();

  @override
  Widget build(BuildContext context) {
    return _LoadingSectionShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _LoadingMetricPill(width: 96),
          const SizedBox(height: 14),
          ...List.generate(
            4,
            (index) => Padding(
              padding: EdgeInsets.only(bottom: index == 3 ? 0 : 10),
              child: const _LoadingLedgerRow(),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingMonthComparisonSection extends StatelessWidget {
  const _LoadingMonthComparisonSection();

  @override
  Widget build(BuildContext context) {
    return _LoadingSectionShell(
      child: Column(
        children: List.generate(
          3,
          (index) => Padding(
            padding: EdgeInsets.only(bottom: index == 2 ? 0 : 12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Colors.white.withValues(alpha: 0.04),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SkeletonBox(width: 88, height: 13, radius: 10),
                      Spacer(),
                      SkeletonBox(width: 62, height: 11, radius: 10),
                    ],
                  ),
                  SizedBox(height: 8),
                  SkeletonBox(width: 108, height: 13, radius: 10),
                  SizedBox(height: 5),
                  SkeletonBox(width: 128, height: 11, radius: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingTodoReserveSection extends StatelessWidget {
  const _LoadingTodoReserveSection();

  @override
  Widget build(BuildContext context) {
    return _LoadingSectionShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _LoadingMetricPill(width: 86),
              _LoadingMetricPill(width: 64),
              _LoadingMetricPill(width: 82),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(
            3,
            (index) => Padding(
              padding: EdgeInsets.only(bottom: index == 2 ? 0 : 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Colors.white.withValues(alpha: 0.04),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SkeletonBox(
                            width: 118,
                            height: 12,
                            radius: 10,
                          ),
                        ),
                        SizedBox(width: 10),
                        SkeletonBox(width: 64, height: 24, radius: 999),
                      ],
                    ),
                    SizedBox(height: 8),
                    SkeletonBox(width: 132, height: 11, radius: 10),
                    SizedBox(height: 10),
                    SkeletonBox(height: 6, radius: 999),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _LoadingDetailPair()),
                        SizedBox(width: 12),
                        Expanded(child: _LoadingDetailPair()),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingLoanOverviewSection extends StatelessWidget {
  const _LoadingLoanOverviewSection();

  @override
  Widget build(BuildContext context) {
    return _LoadingSectionShell(
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _LoadingMetricPill(width: 40),
              _LoadingMetricPill(width: 40),
              _LoadingMetricPill(width: 40),
            ],
          ),
          SizedBox(height: 14),
          _LoadingDetailPair(),
          SizedBox(height: 8),
          _LoadingDetailPair(),
        ],
      ),
    );
  }
}

class _LoadingPartnerActivitySection extends StatelessWidget {
  const _LoadingPartnerActivitySection();

  @override
  Widget build(BuildContext context) {
    return _LoadingSectionShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 620) {
                return const Column(
                  children: [
                    _LoadingPartnerPersonCard(),
                    SizedBox(height: 10),
                    _LoadingPartnerPersonCard(),
                  ],
                );
              }

              return const Row(
                children: [
                  Expanded(child: _LoadingPartnerPersonCard()),
                  SizedBox(width: 10),
                  Expanded(child: _LoadingPartnerPersonCard()),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          const SkeletonBox(width: 116, height: 12, radius: 10),
          const SizedBox(height: 10),
          ...List.generate(
            3,
            (index) => Padding(
              padding: EdgeInsets.only(bottom: index == 2 ? 0 : 10),
              child: const _LoadingLedgerRow(leadingCircle: true),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingPartnerPersonCard extends StatelessWidget {
  const _LoadingPartnerPersonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonBox(width: 36, height: 36, radius: 999),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 108, height: 12, radius: 10),
                    SizedBox(height: 5),
                    SkeletonBox(width: 54, height: 10, radius: 10),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _LoadingDetailPair()),
              SizedBox(width: 10),
              Expanded(child: _LoadingDetailPair()),
            ],
          ),
          SizedBox(height: 8),
          _LoadingDetailPair(),
        ],
      ),
    );
  }
}

class _DashboardErrorState extends StatelessWidget {
  const _DashboardErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(30),
      blur: 24,
      opacity: 0.12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Could not load your dashboard',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: AppColors.textSecondary.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 18),
          _InlineActionButton(
            label: 'Try again',
            icon: HugeIcons.strokeRoundedRefresh,
            color: AppColors.primary,
            onTap: onRetry,
          ),
        ],
      ),
    );
  }
}

enum _SummaryTone { income, expense, saving, todo }

class _SummaryCardData {
  const _SummaryCardData({
    required this.label,
    required this.compactValue,
    required this.fullValue,
    required this.description,
    required this.tone,
  });

  final String label;
  final String compactValue;
  final String fullValue;
  final String description;
  final _SummaryTone tone;
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.cards});

  final List<_SummaryCardData> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1080
            ? 3
            : (constraints.maxWidth >= 640 ? 2 : 1);
        final spacing = 12.0;
        final width = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map(
                (card) => SizedBox(
                  width: width,
                  child: _SummaryCard(card: card),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _SummaryCard extends StatefulWidget {
  const _SummaryCard({required this.card});

  final _SummaryCardData card;

  @override
  State<_SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<_SummaryCard> {
  bool _showFullValue = false;

  @override
  Widget build(BuildContext context) {
    final accent = switch (widget.card.tone) {
      _SummaryTone.income => AppColors.success,
      _SummaryTone.expense => AppColors.danger,
      _SummaryTone.saving => const Color(0xFF7EB8FF),
      _SummaryTone.todo => const Color(0xFFFFC972),
    };

    return GestureDetector(
      onTap: () => setState(() => _showFullValue = !_showFullValue),
      child: GlassPanel(
        padding: const EdgeInsets.all(18),
        borderRadius: BorderRadius.circular(24),
        blur: 22,
        opacity: 0.12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.15),
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: switch (widget.card.tone) {
                        _SummaryTone.income =>
                          HugeIcons.strokeRoundedArrowUpRight01,
                        _SummaryTone.expense =>
                          HugeIcons.strokeRoundedArrowDownLeft01,
                        _SummaryTone.saving => HugeIcons.strokeRoundedPiggyBank,
                        _SummaryTone.todo => HugeIcons.strokeRoundedTaskDaily01,
                      },
                      size: 15,
                      color: accent,
                      strokeWidth: 1.8,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Tap to ${_showFullValue ? 'compact' : 'expand'}',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              widget.card.label,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary.withValues(alpha: 0.68),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _showFullValue ? widget.card.fullValue : widget.card.compactValue,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: accent,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.card.description,
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: AppColors.textSecondary.withValues(alpha: 0.74),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({
    required this.title,
    required this.subtitle,
    required this.child,
    this.icon,
    this.accentColor = AppColors.primary,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final dynamic icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(22),
      borderRadius: BorderRadius.circular(28),
      blur: 24,
      opacity: 0.12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null)
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor.withValues(alpha: 0.14),
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: icon,
                      size: 16,
                      color: accentColor,
                      strokeWidth: 1.8,
                    ),
                  ),
                ),
              if (icon != null) const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.5,
                        color: AppColors.textSecondary.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.value,
    this.accentColor = AppColors.primary,
  });

  final String label;
  final String value;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyMovementSection extends StatefulWidget {
  const _DailyMovementSection({
    required this.points,
    required this.month,
    required this.year,
  });

  final List<DashboardDailyPoint> points;
  final int month;
  final int year;

  @override
  State<_DailyMovementSection> createState() => _DailyMovementSectionState();
}

class _DailyMovementSectionState extends State<_DailyMovementSection> {
  int? _focusedDay;

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final peakPoint = points.isEmpty
        ? null
        : points.reduce(
            (left, right) => right.total > left.total ? right : left,
          );
    final averageIncome = points.isEmpty
        ? 0.0
        : points.fold(0.0, (sum, entry) => sum + entry.income) / points.length;
    final averageExpense = points.isEmpty
        ? 0.0
        : points.fold(0.0, (sum, entry) => sum + entry.expense) / points.length;
    final activePoint = _focusedDay == null || _focusedDay! >= points.length
        ? peakPoint
        : points[_focusedDay!];
    final maxTotal = points.fold<double>(
      0,
      (currentMax, entry) => math.max(currentMax, entry.total),
    );

    return _SectionShell(
      title: 'Monthly movement',
      subtitle:
          'Daily income and expense movement for ${formatDashboardMonthLabel(widget.month)} ${widget.year}.',
      icon: HugeIcons.strokeRoundedChartHistogram,
      accentColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricPill(
                label: 'Peak day',
                value: peakPoint == null
                    ? 'No activity'
                    : '${formatDashboardMonthLabel(widget.month).substring(0, 3)} ${peakPoint.day}',
                accentColor: AppColors.primary,
              ),
              _MetricPill(
                label: 'Avg income/day',
                value: _rwfCompact(averageIncome),
                accentColor: AppColors.success,
              ),
              _MetricPill(
                label: 'Avg expense/day',
                value: _rwfCompact(averageExpense),
                accentColor: AppColors.danger,
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (activePoint != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Colors.white.withValues(alpha: 0.04),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _DetailPair(
                      label: 'Focused day',
                      value:
                          '${formatDashboardMonthLabel(widget.month).substring(0, 3)} ${activePoint.day}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DetailPair(
                      label: 'Income',
                      value: _rwf(activePoint.income),
                      accentColor: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DetailPair(
                      label: 'Expense',
                      value: _rwf(activePoint.expense),
                      accentColor: AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: points.length,
              separatorBuilder: (context, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final point = points[index];
                final isActive =
                    _focusedDay == index ||
                    (_focusedDay == null && peakPoint?.day == point.day);
                final incomeHeight = maxTotal == 0
                    ? 0
                    : (point.income / maxTotal) * 92;
                final expenseHeight = maxTotal == 0
                    ? 0
                    : (point.expense / maxTotal) * 92;

                return GestureDetector(
                  onTap: () => setState(() => _focusedDay = index),
                  child: Container(
                    width: 20,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: isActive
                          ? Colors.white.withValues(alpha: 0.07)
                          : Colors.transparent,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          height: 96,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 240),
                                width: 5,
                                height: incomeHeight
                                    .clamp(4.0, 92.0)
                                    .toDouble(),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: AppColors.success,
                                ),
                              ),
                              const SizedBox(width: 3),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 240),
                                width: 5,
                                height: expenseHeight
                                    .clamp(4.0, 92.0)
                                    .toDouble(),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: AppColors.danger,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${point.day}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isActive
                                ? AppColors.textPrimary
                                : AppColors.textSecondary.withValues(
                                    alpha: 0.6,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TopSpendingCategoriesSection extends StatelessWidget {
  const _TopSpendingCategoriesSection({
    required this.items,
    required this.month,
    required this.year,
  });

  final List<DashboardTopCategoryItem> items;
  final int month;
  final int year;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'Top spending categories',
      subtitle:
          'The categories taking the biggest share in ${formatDashboardMonthLabel(month)} $year.',
      icon: HugeIcons.strokeRoundedPieChart01,
      accentColor: AppColors.danger,
      child: items.isEmpty
          ? _EmptySectionCopy(message: 'No expense records yet for this month.')
          : Column(
              children: items
                  .take(5)
                  .map((item) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: item == items.take(5).last ? 0 : 12,
                      ),
                      child: _CategoryRow(item: item),
                    );
                  })
                  .toList(growable: false),
            ),
    );
  }
}

class _UpcomingTodoScheduleSection extends StatelessWidget {
  const _UpcomingTodoScheduleSection({required this.days});

  final List<DashboardUpcomingTodoDay> days;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'Upcoming todo schedule',
      subtitle:
          'The next 7 days of todo commitments that still have to be recorded.',
      icon: HugeIcons.strokeRoundedCalendar03,
      accentColor: const Color(0xFFFFC972),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 980
              ? 4
              : (constraints.maxWidth >= 640 ? 2 : 1);
          final spacing = 10.0;
          final width = columns == 1
              ? constraints.maxWidth
              : (constraints.maxWidth - (spacing * (columns - 1))) / columns;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: days
                .map(
                  (day) => SizedBox(
                    width: width,
                    child: _UpcomingDayCard(day: day),
                  ),
                )
                .toList(growable: false),
          );
        },
      ),
    );
  }
}

class _SavingsRateSection extends StatelessWidget {
  const _SavingsRateSection({
    required this.incomeAmount,
    required this.expenseAmount,
    required this.month,
    required this.year,
  });

  final double incomeAmount;
  final double expenseAmount;
  final int month;
  final int year;

  @override
  Widget build(BuildContext context) {
    final spendingRate = incomeAmount > 0
        ? (expenseAmount / incomeAmount) * 100
        : 0.0;
    final remainingAmount = incomeAmount - expenseAmount;
    final remainingRate = incomeAmount > 0
        ? (remainingAmount / incomeAmount) * 100
        : 0.0;
    final overspent = remainingAmount < 0;

    return _SectionShell(
      title: overspent ? 'Overspent this month' : 'Savings rate',
      subtitle:
          'How much of ${formatDashboardMonthLabel(month)} $year income has already been used.',
      icon: HugeIcons.strokeRoundedPiggyBank,
      accentColor: const Color(0xFF7EB8FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricPill(
                  label: 'Spent rate',
                  value: '${spendingRate.toStringAsFixed(0)}%',
                  accentColor: AppColors.danger,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricPill(
                  label: overspent ? 'Over by' : 'Left to save',
                  value: overspent
                      ? _rwf(remainingAmount.abs())
                      : _rwf(math.max(remainingAmount, 0)),
                  accentColor: overspent
                      ? AppColors.danger
                      : const Color(0xFF7EB8FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: incomeAmount <= 0
                  ? 0
                  : (expenseAmount / incomeAmount).clamp(0.0, 1.0),
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                overspent ? AppColors.danger : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            overspent
                ? 'Spending moved past the income received in this month.'
                : '${math.max(remainingRate, 0).toStringAsFixed(0)}% of the month’s received income is still available to save or keep aside.',
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: AppColors.textSecondary.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingIncomeSection extends StatelessWidget {
  const _PendingIncomeSection({required this.entries});

  final List<IncomeEntry> entries;

  @override
  Widget build(BuildContext context) {
    final pendingAmount = entries.fold(0.0, (sum, entry) => sum + entry.amount);

    return _SectionShell(
      title: 'Pending income',
      subtitle: 'Income not yet marked as received for the selected month.',
      icon: HugeIcons.strokeRoundedMoneyReceiveSquare,
      accentColor: AppColors.success,
      child: entries.isEmpty
          ? _EmptySectionCopy(
              message:
                  'Everything expected this month is already marked as received.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MetricPill(
                  label: 'Pending amount',
                  value: _rwfCompact(pendingAmount),
                  accentColor: AppColors.success,
                ),
                const SizedBox(height: 14),
                ...entries
                    .take(4)
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _LedgerRow(
                          title: entry.label,
                          subtitle: _formatShortDate(entry.date),
                          value: _rwfCompact(entry.amount),
                          accentColor: AppColors.success,
                        ),
                      ),
                    ),
              ],
            ),
    );
  }
}

class _MonthComparisonSection extends StatelessWidget {
  const _MonthComparisonSection({required this.summary});

  final DashboardMonthComparisonSummary summary;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'Month comparison',
      subtitle: '${summary.currentLabel} against ${summary.previousLabel}.',
      icon: HugeIcons.strokeRoundedArrowDataTransferDiagonal,
      accentColor: AppColors.primary,
      child: Column(
        children: summary.metrics
            .map(
              (metric) => Padding(
                padding: EdgeInsets.only(
                  bottom: metric == summary.metrics.last ? 0 : 12,
                ),
                child: _ComparisonCard(metric: metric),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _TodoReserveSection extends StatelessWidget {
  const _TodoReserveSection({required this.summary});

  final DashboardTodoReserveSummary summary;

  @override
  Widget build(BuildContext context) {
    final items = summary.items.take(4).toList(growable: false);

    return _SectionShell(
      title: 'Todo adviser',
      subtitle:
          'Keep this money safe because your weekly and monthly todo plans still need it.',
      icon: HugeIcons.strokeRoundedTaskDone02,
      accentColor: const Color(0xFFFFC972),
      child: summary.items.isEmpty
          ? _EmptySectionCopy(
              message:
                  'No active weekly or monthly todo reserve needs attention right now.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _MetricPill(
                      label: 'Reserve target',
                      value: _rwfCompact(summary.targetAmount),
                      accentColor: const Color(0xFFFFC972),
                    ),
                    _MetricPill(
                      label: 'Used',
                      value: _rwfCompact(summary.usedAmount),
                      accentColor: AppColors.danger,
                    ),
                    _MetricPill(
                      label: 'Remaining',
                      value: _rwfCompact(summary.remainingAmount),
                      accentColor: AppColors.success,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...items.map(
                  (item) => Padding(
                    padding: EdgeInsets.only(
                      bottom: item == items.last ? 0 : 10,
                    ),
                    child: _ReserveRow(item: item),
                  ),
                ),
              ],
            ),
    );
  }
}

class _LoanOverviewSection extends StatelessWidget {
  const _LoanOverviewSection({
    required this.overview,
    required this.month,
    required this.year,
  });

  final DashboardLoanOverview overview;
  final int month;
  final int year;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'Loans overview',
      subtitle: 'Loan status for ${formatDashboardMonthLabel(month)} $year.',
      icon: HugeIcons.strokeRoundedWallet03,
      accentColor: const Color(0xFFFFB86C),
      child: overview.totalCount == 0
          ? _EmptySectionCopy(
              message: 'No loan records were found for this month.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _MetricPill(
                      label: 'Total',
                      value: '${overview.totalCount}',
                      accentColor: const Color(0xFFFFB86C),
                    ),
                    _MetricPill(
                      label: 'Paid',
                      value: '${overview.paidCount}',
                      accentColor: AppColors.success,
                    ),
                    _MetricPill(
                      label: 'Unpaid',
                      value: '${overview.unpaidCount}',
                      accentColor: AppColors.danger,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _DetailPair(
                  label: 'Loan amount tracked',
                  value: _rwf(overview.totalAmount),
                  accentColor: const Color(0xFFFFB86C),
                ),
                const SizedBox(height: 6),
                _DetailPair(
                  label: 'Still unpaid',
                  value: _rwf(overview.unpaidAmount),
                  accentColor: AppColors.danger,
                ),
              ],
            ),
    );
  }
}

class _PartnerActivitySection extends StatelessWidget {
  const _PartnerActivitySection({required this.summary});

  final DashboardPartnerActivitySummary summary;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'Partner activity',
      subtitle: 'Who added what this month inside the shared workspace.',
      icon: HugeIcons.strokeRoundedUserMultiple,
      accentColor: AppColors.success,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stack = constraints.maxWidth < 620;
              if (stack) {
                return Column(
                  children: [
                    if (summary.currentUser != null)
                      _PartnerPersonCard(person: summary.currentUser!),
                    if (summary.currentUser != null && summary.partner != null)
                      const SizedBox(height: 10),
                    if (summary.partner != null)
                      _PartnerPersonCard(person: summary.partner!),
                  ],
                );
              }

              return Row(
                children: [
                  if (summary.currentUser != null)
                    Expanded(
                      child: _PartnerPersonCard(person: summary.currentUser!),
                    ),
                  if (summary.currentUser != null && summary.partner != null)
                    const SizedBox(width: 10),
                  if (summary.partner != null)
                    Expanded(
                      child: _PartnerPersonCard(person: summary.partner!),
                    ),
                ],
              );
            },
          ),
          if (summary.latestRecords.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Latest shared activity',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 10),
            ...summary.latestRecords.map(
              (record) => Padding(
                padding: EdgeInsets.only(
                  bottom: record == summary.latestRecords.last ? 0 : 10,
                ),
                child: _PartnerActivityRow(record: record),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.item});

  final DashboardTopCategoryItem item;

  @override
  Widget build(BuildContext context) {
    final color = _expenseCategoryColor(item.category);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.16),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: _expenseCategoryIcon(item.category),
                    size: 15,
                    color: color,
                    strokeWidth: 1.8,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                _rwfCompact(item.amount),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: item.share.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(item.share * 100).toStringAsFixed(0)}% of monthly spend',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary.withValues(alpha: 0.68),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingDayCard extends StatelessWidget {
  const _UpcomingDayCard({required this.day});

  final DashboardUpcomingTodoDay day;

  @override
  Widget build(BuildContext context) {
    final parsedDate = parseDateOnly(day.date);
    final today = DateTime.now();
    final isToday =
        parsedDate.year == today.year &&
        parsedDate.month == today.month &&
        parsedDate.day == today.day;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: isToday
              ? AppColors.primary.withValues(alpha: 0.24)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isToday ? 'Today' : formatTodoDate(parsedDate),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isToday ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                _rwfCompact(day.totalAmount),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (day.items.isEmpty)
            Text(
              'No planned todo spending',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary.withValues(alpha: 0.72),
              ),
            )
          else
            ...day.items
                .take(3)
                .map(
                  (item) => Padding(
                    padding: EdgeInsets.only(
                      bottom: item == day.items.take(3).last ? 0 : 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _rwfCompact(item.amount),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary.withValues(
                              alpha: 0.92,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.metric});

  final DashboardMonthComparisonMetric metric;

  @override
  Widget build(BuildContext context) {
    final accent = metric.isPositive ? AppColors.success : AppColors.danger;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                metric.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${metric.isUp ? 'Up' : 'Down'} ${metric.changePercentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _rwf(metric.currentAmount),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Previous: ${_rwf(metric.previousAmount)}',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReserveRow extends StatelessWidget {
  const _ReserveRow({required this.item});

  final DashboardTodoReserveItem item;

  @override
  Widget build(BuildContext context) {
    final progress = item.targetAmount <= 0
        ? 0.0
        : (item.usedAmount / item.targetAmount).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Colors.white.withValues(alpha: 0.05),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: Text(
                  formatTodoFrequencyLabel(item.frequency),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary.withValues(alpha: 0.78),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${item.remainingOccurrences} occurrence${item.remainingOccurrences == 1 ? '' : 's'} left',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DetailPair(
                  label: 'Used',
                  value: _rwfCompact(item.usedAmount),
                  accentColor: AppColors.danger,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DetailPair(
                  label: 'Remaining',
                  value: _rwfCompact(item.remainingAmount),
                  accentColor: AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PartnerPersonCard extends StatelessWidget {
  const _PartnerPersonCard({required this.person});

  final DashboardPartnerPersonSummary person;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                backgroundImage: person.avatarUrl == null
                    ? null
                    : NetworkImage(person.avatarUrl!),
                child: person.avatarUrl == null
                    ? Text(
                        _initials(person.displayName),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.displayName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      person.isCurrentUser ? 'You' : 'Partner',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DetailPair(
                  label: 'Entries',
                  value: '${person.entryCount}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DetailPair(
                  label: 'RWF',
                  value: _rwfCompact(person.rwfTotal),
                  accentColor: AppColors.success,
                ),
              ),
            ],
          ),
          if (person.usdTotal > 0) ...[
            const SizedBox(height: 8),
            _DetailPair(
              label: 'USD savings',
              value: _usdCompact(person.usdTotal),
              accentColor: const Color(0xFF7EB8FF),
            ),
          ],
        ],
      ),
    );
  }
}

class _PartnerActivityRow extends StatelessWidget {
  const _PartnerActivityRow({required this.record});

  final DashboardPartnerActivityRecord record;

  @override
  Widget build(BuildContext context) {
    final accent = switch (record.type) {
      'income' => AppColors.success,
      'expense' => AppColors.danger,
      'saving' => const Color(0xFF7EB8FF),
      'loan' => const Color(0xFFFFB86C),
      _ => AppColors.primary,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.16),
            ),
            child: Center(
              child: HugeIcon(
                icon: switch (record.type) {
                  'income' => HugeIcons.strokeRoundedMoneyReceiveCircle,
                  'expense' => HugeIcons.strokeRoundedWallet02,
                  'saving' => HugeIcons.strokeRoundedPiggyBank,
                  'loan' => HugeIcons.strokeRoundedWallet03,
                  _ => HugeIcons.strokeRoundedTaskDaily01,
                },
                size: 14,
                color: accent,
                strokeWidth: 1.8,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Added by ${displayCreatedByName(record.creator)} · ${_formatShortDate(record.date)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary.withValues(alpha: 0.66),
                  ),
                ),
              ],
            ),
          ),
          Text(
            record.isUsd
                ? _usdCompact(record.amount)
                : _rwfCompact(record.amount),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySectionCopy extends StatelessWidget {
  const _EmptySectionCopy({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: TextStyle(
        fontSize: 12,
        height: 1.6,
        color: AppColors.textSecondary.withValues(alpha: 0.76),
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.accentColor,
  });

  final String title;
  final String subtitle;
  final String value;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary.withValues(alpha: 0.66),
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailPair extends StatelessWidget {
  const _DetailPair({
    required this.label,
    required this.value,
    this.accentColor = AppColors.textPrimary,
  });

  final String label;
  final String value;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary.withValues(alpha: 0.58),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: accentColor,
          ),
        ),
      ],
    );
  }
}

class _InlineActionButton extends StatelessWidget {
  const _InlineActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final dynamic icon;
  final Color color;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: color.withValues(alpha: 0.15),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(icon: icon, size: 16, color: color, strokeWidth: 1.8),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatShortDate(DateTime value) {
  return '${formatDashboardMonthLabel(value.month).substring(0, 3)} ${value.day}';
}

String _rwf(double amount) {
  final absolute = amount.abs();
  final formatted = absolute
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'),
        (match) => '${match[1]},',
      );
  final prefix = amount < 0 ? '-RWF ' : 'RWF ';
  return '$prefix$formatted';
}

String _rwfCompact(double amount) {
  final absolute = amount.abs();
  final prefix = amount < 0 ? '-RWF ' : 'RWF ';

  if (absolute >= 1000000) {
    return '$prefix${(absolute / 1000000).toStringAsFixed(1)}M';
  }
  if (absolute >= 1000) {
    return '$prefix${(absolute / 1000).toStringAsFixed(0)}k';
  }
  return _rwf(amount);
}

String _usd(double amount) {
  final absolute = amount.abs();
  final formatted = absolute
      .toStringAsFixed(2)
      .replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+\.)'),
        (match) => '${match[1]},',
      );
  return amount < 0 ? '-USD $formatted' : 'USD $formatted';
}

String _usdCompact(double amount) {
  final absolute = amount.abs();
  final prefix = amount < 0 ? '-USD ' : 'USD ';

  if (absolute >= 1000000) {
    return '$prefix${(absolute / 1000000).toStringAsFixed(1)}M';
  }
  if (absolute >= 1000) {
    return '$prefix${(absolute / 1000).toStringAsFixed(1)}k';
  }
  return _usd(amount);
}

dynamic _expenseCategoryIcon(ExpenseCategory category) => switch (category) {
  ExpenseCategory.foodDining => HugeIcons.strokeRoundedRestaurant01,
  ExpenseCategory.transport => HugeIcons.strokeRoundedCar01,
  ExpenseCategory.housing => HugeIcons.strokeRoundedHome01,
  ExpenseCategory.loan => HugeIcons.strokeRoundedWallet03,
  ExpenseCategory.utilities => HugeIcons.strokeRoundedPlug01,
  ExpenseCategory.airtime => HugeIcons.strokeRoundedSmartPhone01,
  ExpenseCategory.healthcare => HugeIcons.strokeRoundedShield01,
  ExpenseCategory.education => HugeIcons.strokeRoundedBook02,
  ExpenseCategory.schoolFees => HugeIcons.strokeRoundedMortarboard02,
  ExpenseCategory.parentSibling => HugeIcons.strokeRoundedUserGroup,
  ExpenseCategory.entertainment => HugeIcons.strokeRoundedGameController01,
  ExpenseCategory.shopping => HugeIcons.strokeRoundedShoppingBag01,
  ExpenseCategory.personalCare => HugeIcons.strokeRoundedSparkles,
  ExpenseCategory.travel => HugeIcons.strokeRoundedAirplane01,
  ExpenseCategory.savings => HugeIcons.strokeRoundedPiggyBank,
  ExpenseCategory.other => HugeIcons.strokeRoundedMoreHorizontalCircle01,
};

Color _expenseCategoryColor(ExpenseCategory category) => switch (category) {
  ExpenseCategory.foodDining => const Color(0xFFFFA86B),
  ExpenseCategory.transport => const Color(0xFF7EB8FF),
  ExpenseCategory.housing => AppColors.primary,
  ExpenseCategory.loan => const Color(0xFFFF8E8E),
  ExpenseCategory.utilities => const Color(0xFF7AD7C3),
  ExpenseCategory.airtime => const Color(0xFF58D6FF),
  ExpenseCategory.healthcare => AppColors.success,
  ExpenseCategory.education => const Color(0xFFC79BFF),
  ExpenseCategory.schoolFees => const Color(0xFF9C8CFF),
  ExpenseCategory.parentSibling => const Color(0xFFFFB26B),
  ExpenseCategory.entertainment => const Color(0xFFFF7AB6),
  ExpenseCategory.shopping => const Color(0xFFFFD36E),
  ExpenseCategory.personalCare => const Color(0xFFA5E06E),
  ExpenseCategory.travel => const Color(0xFF8FD4FF),
  ExpenseCategory.savings => const Color(0xFF6FCF97),
  ExpenseCategory.other => AppColors.textSecondary,
};

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);

  if (parts.isEmpty) {
    return 'B';
  }

  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }

  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}
