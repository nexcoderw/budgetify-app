import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

// ── Domain models ────────────────────────────────────────────────────────────

class MonthlySnapshot {
  const MonthlySnapshot({
    required this.month,
    required this.year,
    required this.totalBalance,
    required this.income,
    required this.expenses,
    required this.dailySpending,
    required this.categories,
    required this.recentTransactions,
  });

  final int month;
  final int year;
  final double totalBalance;
  final double income;
  final double expenses;
  final List<double> dailySpending;
  final List<SpendingCategory> categories;
  final List<RecentTransaction> recentTransactions;

  double get savingsRate =>
      income > 0 ? ((income - expenses) / income * 100).clamp(0, 100) : 0;
}

class SpendingCategory {
  const SpendingCategory({
    required this.label,
    required this.amount,
    required this.total,
    required this.color,
    required this.icon,
  });

  final String label;
  final double amount;
  final double total;
  final Color color;
  final IconData icon;

  double get fraction => total > 0 ? (amount / total).clamp(0.0, 1.0) : 0;
}

class RecentTransaction {
  const RecentTransaction({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isIncome,
    required this.date,
    required this.icon,
    required this.iconColor,
  });

  final String title;
  final String subtitle;
  final double amount;
  final bool isIncome;
  final DateTime date;
  final IconData icon;
  final Color iconColor;
}

// ── Mock data factory ────────────────────────────────────────────────────────

class DashboardData {
  DashboardData._();

  static MonthlySnapshot forMonth(int month, int year) {
    // Deterministic but varied mock data per month
    final seed = month + year * 12;
    final variation = (seed % 7) * 0.08;

    final income = 4250.0 + seed % 5 * 120;
    final expenses = 2847.50 + seed % 9 * 80 + variation * income;

    final dailySpending = List<double>.generate(
      _daysInMonth(month, year),
      (i) => _dailyAmount(i, month, seed),
    );

    final totalSpent = dailySpending.fold(0.0, (a, b) => a + b);

    final categories = [
      SpendingCategory(
        label: 'Food & Drink',
        amount: totalSpent * 0.31,
        total: totalSpent,
        color: const Color(0xFFFFB347),
        icon: Icons.restaurant_rounded,
      ),
      SpendingCategory(
        label: 'Shopping',
        amount: totalSpent * 0.24,
        total: totalSpent,
        color: AppColors.primary,
        icon: Icons.shopping_bag_rounded,
      ),
      SpendingCategory(
        label: 'Transport',
        amount: totalSpent * 0.18,
        total: totalSpent,
        color: const Color(0xFF7EB8F7),
      icon: Icons.directions_car_rounded,
      ),
      SpendingCategory(
        label: 'Health',
        amount: totalSpent * 0.14,
        total: totalSpent,
        color: AppColors.success,
        icon: Icons.favorite_rounded,
      ),
      SpendingCategory(
        label: 'Entertainment',
        amount: totalSpent * 0.13,
        total: totalSpent,
        color: const Color(0xFFBD87F7),
        icon: Icons.movie_rounded,
      ),
    ];

    final now = DateTime.now();
    final recentTransactions = [
      RecentTransaction(
        title: 'Spotify Premium',
        subtitle: 'Entertainment',
        amount: 9.99,
        isIncome: false,
        date: now.subtract(const Duration(hours: 3)),
        icon: Icons.music_note_rounded,
        iconColor: const Color(0xFFBD87F7),
      ),
      RecentTransaction(
        title: 'Salary Deposit',
        subtitle: 'Income · Work',
        amount: income,
        isIncome: true,
        date: now.subtract(const Duration(days: 1)),
        icon: Icons.account_balance_rounded,
        iconColor: AppColors.success,
      ),
      RecentTransaction(
        title: 'Whole Foods Market',
        subtitle: 'Food & Drink',
        amount: 84.30,
        isIncome: false,
        date: now.subtract(const Duration(days: 2)),
        icon: Icons.local_grocery_store_rounded,
        iconColor: const Color(0xFFFFB347),
      ),
      RecentTransaction(
        title: 'Uber',
        subtitle: 'Transport',
        amount: 14.50,
        isIncome: false,
        date: now.subtract(const Duration(days: 3)),
        icon: Icons.directions_car_rounded,
        iconColor: const Color(0xFF7EB8F7),
      ),
      RecentTransaction(
        title: 'Amazon',
        subtitle: 'Shopping',
        amount: 127.89,
        isIncome: false,
        date: now.subtract(const Duration(days: 4)),
        icon: Icons.shopping_bag_rounded,
        iconColor: AppColors.primary,
      ),
    ];

    return MonthlySnapshot(
      month: month,
      year: year,
      totalBalance: 12340.75 + (income - expenses),
      income: income,
      expenses: expenses,
      dailySpending: dailySpending,
      categories: categories,
      recentTransactions: recentTransactions,
    );
  }

  static double _dailyAmount(int day, int month, int seed) {
    // Weekends spend more; midmonth spike
    const weekendBoost = 1.6;
    final weekday = (day + seed) % 7;
    final isWeekend = weekday == 0 || weekday == 6;
    final midMonthBoost = (day >= 12 && day <= 16) ? 1.4 : 1.0;
    final base = 60.0 + (day * 3 + seed * 2) % 80;
    return base * (isWeekend ? weekendBoost : 1.0) * midMonthBoost;
  }

  static int _daysInMonth(int month, int year) =>
      DateTime(year, month + 1, 0).day;
}
