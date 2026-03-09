import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../features/auth/data/models/auth_user.dart';
import 'dashboard_bar_chart.dart';
import 'dashboard_balance_card.dart';
import 'dashboard_cashflow_row.dart';
import 'dashboard_category_list.dart';
import 'dashboard_data.dart';
import 'dashboard_header.dart';
import 'dashboard_transactions.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.user});

  final AuthUser user;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _entranceCtrl;
  late int _month;
  late int _year;
  late MonthlySnapshot _snapshot;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = now.month;
    _year = now.year;
    _snapshot = DashboardData.forMonth(_month, _year);

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

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

  void _prevMonth() {
    setState(() {
      if (_month == 1) {
        _month = 12;
        _year -= 1;
      } else {
        _month -= 1;
      }
      _snapshot = DashboardData.forMonth(_month, _year);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_year > now.year || (_year == now.year && _month >= now.month)) return;
    setState(() {
      if (_month == 12) {
        _month = 1;
        _year += 1;
      } else {
        _month += 1;
      }
      _snapshot = DashboardData.forMonth(_month, _year);
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        _Staggered(
          fade: _fade(0.0, 0.45),
          slide: _slide(0.0, 0.45),
          child: DashboardHeader(
            user: widget.user,
            month: _month,
            year: _year,
            onPrevMonth: _prevMonth,
            onNextMonth: _nextMonth,
          ),
        ),
        const SizedBox(height: 20),

        // Balance hero
        _Staggered(
          fade: _fade(0.10, 0.55),
          slide: _slide(0.10, 0.55),
          child: DashboardBalanceCard(
            totalBalance: _snapshot.totalBalance,
            savingsRate: _snapshot.savingsRate,
            month: _month,
            year: _year,
          ),
        ),
        const SizedBox(height: 14),

        // Cash flow row
        _Staggered(
          fade: _fade(0.22, 0.62),
          slide: _slide(0.22, 0.62),
          child: DashboardCashflowRow(
            income: _snapshot.income,
            expenses: _snapshot.expenses,
          ),
        ),
        const SizedBox(height: 14),

        // Bar chart
        _Staggered(
          fade: _fade(0.35, 0.72),
          slide: _slide(0.35, 0.72),
          child: DashboardBarChart(
            dailySpending: _snapshot.dailySpending,
            month: _month,
            year: _year,
          ),
        ),
        const SizedBox(height: 14),

        // Categories
        _Staggered(
          fade: _fade(0.48, 0.84),
          slide: _slide(0.48, 0.84),
          child: DashboardCategoryList(categories: _snapshot.categories),
        ),
        const SizedBox(height: 14),

        // Transactions
        _Staggered(
          fade: _fade(0.60, 1.00),
          slide: _slide(0.60, 1.00),
          child: DashboardTransactions(transactions: _snapshot.recentTransactions),
        ),

        const SizedBox(height: 8),
        _Staggered(
          fade: _fade(0.70, 1.00),
          slide: _slide(0.70, 1.00),
          child: const _FooterNote(),
        ),
      ],
    );
  }
}

// ── Staggered entrance wrapper ────────────────────────────────────────────────

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

// ── Footer note ───────────────────────────────────────────────────────────────

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
