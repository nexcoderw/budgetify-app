import '../../../../../core/models/created_by_summary.dart';
import '../../../../../features/auth/data/models/auth_user.dart';
import '../../../../../features/expenses/data/models/expense_entry.dart';
import '../../../../../features/income/data/models/income_entry.dart';
import '../../../../../features/loans/data/models/loan_entry.dart';
import '../../../../../features/partnerships/data/models/partnership_models.dart';
import '../../../../../features/savings/data/models/saving_entry.dart';
import '../../../../../features/todos/data/models/todo_item.dart';
import '../../../../../features/todos/presentation/todo_utils.dart';

class DashboardDailyPoint {
  const DashboardDailyPoint({
    required this.day,
    required this.income,
    required this.expense,
  });

  final int day;
  final double income;
  final double expense;

  double get total => income + expense;
}

class DashboardTopCategoryItem {
  const DashboardTopCategoryItem({
    required this.category,
    required this.label,
    required this.amount,
    required this.share,
  });

  final ExpenseCategory category;
  final String label;
  final double amount;
  final double share;
}

class DashboardTodoReserveItem {
  const DashboardTodoReserveItem({
    required this.id,
    required this.name,
    required this.frequency,
    required this.targetAmount,
    required this.usedAmount,
    required this.remainingAmount,
    required this.remainingOccurrences,
  });

  final String id;
  final String name;
  final TodoFrequency frequency;
  final double targetAmount;
  final double usedAmount;
  final double remainingAmount;
  final int remainingOccurrences;
}

class DashboardTodoReserveSummary {
  const DashboardTodoReserveSummary({
    required this.targetAmount,
    required this.usedAmount,
    required this.remainingAmount,
    required this.items,
  });

  final double targetAmount;
  final double usedAmount;
  final double remainingAmount;
  final List<DashboardTodoReserveItem> items;
}

class DashboardUpcomingTodoItem {
  const DashboardUpcomingTodoItem({
    required this.id,
    required this.name,
    required this.frequency,
    required this.amount,
  });

  final String id;
  final String name;
  final TodoFrequency frequency;
  final double amount;
}

class DashboardUpcomingTodoDay {
  const DashboardUpcomingTodoDay({
    required this.date,
    required this.items,
    required this.totalAmount,
  });

  final String date;
  final List<DashboardUpcomingTodoItem> items;
  final double totalAmount;
}

class DashboardMonthComparisonMetric {
  const DashboardMonthComparisonMetric({
    required this.label,
    required this.currentAmount,
    required this.previousAmount,
    required this.deltaAmount,
    required this.changePercentage,
    required this.isUp,
    required this.isPositive,
  });

  final String label;
  final double currentAmount;
  final double previousAmount;
  final double deltaAmount;
  final double changePercentage;
  final bool isUp;
  final bool isPositive;
}

class DashboardMonthComparisonSummary {
  const DashboardMonthComparisonSummary({
    required this.currentLabel,
    required this.previousLabel,
    required this.metrics,
  });

  final String currentLabel;
  final String previousLabel;
  final List<DashboardMonthComparisonMetric> metrics;
}

class DashboardPartnerActivityRecord {
  const DashboardPartnerActivityRecord({
    required this.type,
    required this.label,
    required this.amount,
    required this.date,
    required this.creator,
    required this.isUsd,
  });

  final String type;
  final String label;
  final double amount;
  final DateTime date;
  final CreatedBySummary creator;
  final bool isUsd;
}

class DashboardPartnerPersonSummary {
  const DashboardPartnerPersonSummary({
    required this.id,
    required this.displayName,
    required this.avatarUrl,
    required this.isCurrentUser,
    required this.entryCount,
    required this.rwfTotal,
    required this.usdTotal,
    required this.latestRecord,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final bool isCurrentUser;
  final int entryCount;
  final double rwfTotal;
  final double usdTotal;
  final DashboardPartnerActivityRecord? latestRecord;
}

class DashboardPartnerActivitySummary {
  const DashboardPartnerActivitySummary({
    required this.currentUser,
    required this.partner,
    required this.latestRecords,
  });

  final DashboardPartnerPersonSummary? currentUser;
  final DashboardPartnerPersonSummary? partner;
  final List<DashboardPartnerActivityRecord> latestRecords;
}

class DashboardLoanOverview {
  const DashboardLoanOverview({
    required this.totalCount,
    required this.paidCount,
    required this.unpaidCount,
    required this.totalAmount,
    required this.unpaidAmount,
  });

  final int totalCount;
  final int paidCount;
  final int unpaidCount;
  final double totalAmount;
  final double unpaidAmount;
}

const List<String> dashboardMonthLabels = <String>[
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

String formatDashboardMonthLabel(int month) => dashboardMonthLabels[month - 1];

int getDashboardDaysInMonth(int month, int year) =>
    DateTime(year, month + 1, 0).day;

List<T> filterEntriesByMonth<T>(
  List<T> entries,
  DateTime Function(T entry) resolveDate,
  int month,
  int year,
) {
  return entries
      .where((entry) {
        final date = resolveDate(entry);
        return date.month == month && date.year == year;
      })
      .toList(growable: false);
}

double sumIncomeAmounts(List<IncomeEntry> entries) =>
    entries.fold(0, (sum, entry) => sum + entry.amount);

double sumExpenseAmounts(List<ExpenseEntry> entries) =>
    entries.fold(0, (sum, entry) => sum + entry.amount);

double sumSavingAmounts(
  List<SavingEntry> entries, {
  bool stillHaveOnly = false,
}) {
  return entries
      .where((entry) => !stillHaveOnly || entry.currentBalanceRwf > 0)
      .fold(
        0,
        (sum, entry) =>
            sum +
            (stillHaveOnly ? entry.currentBalanceRwf : entry.totalDepositedRwf),
      );
}

double sumTodoAmounts(List<TodoItem> entries, {bool pendingOnly = false}) {
  return entries
      .where((entry) => !pendingOnly || !entry.done)
      .fold(0, (sum, entry) => sum + entry.price);
}

List<DashboardDailyPoint> buildDailyMovementPoints({
  required List<IncomeEntry> income,
  required List<ExpenseEntry> expenses,
  required int month,
  required int year,
}) {
  final points = List<DashboardDailyPoint>.generate(
    getDashboardDaysInMonth(month, year),
    (index) => DashboardDailyPoint(day: index + 1, income: 0, expense: 0),
    growable: false,
  );

  final incomeBuckets = List<double>.filled(points.length, 0);
  final expenseBuckets = List<double>.filled(points.length, 0);

  for (final entry in income) {
    if (entry.date.month != month || entry.date.year != year) {
      continue;
    }
    incomeBuckets[entry.date.day - 1] += entry.amount;
  }

  for (final entry in expenses) {
    if (entry.date.month != month || entry.date.year != year) {
      continue;
    }
    expenseBuckets[entry.date.day - 1] += entry.amount;
  }

  return List<DashboardDailyPoint>.generate(
    points.length,
    (index) => DashboardDailyPoint(
      day: index + 1,
      income: incomeBuckets[index],
      expense: expenseBuckets[index],
    ),
    growable: false,
  );
}

List<DashboardTopCategoryItem> buildTopSpendingCategories({
  required List<ExpenseEntry> expenses,
  required List<ExpenseCategoryOption> categoryOptions,
}) {
  final totals = <ExpenseCategory, double>{};
  final labelLookup = <ExpenseCategory, String>{
    for (final option in categoryOptions) option.value: option.label,
  };

  for (final entry in expenses) {
    totals.update(
      entry.category,
      (value) => value + entry.amount,
      ifAbsent: () => entry.amount,
    );
  }

  final totalAmount = totals.values.fold(0.0, (sum, amount) => sum + amount);
  final items =
      totals.entries
          .map(
            (entry) => DashboardTopCategoryItem(
              category: entry.key,
              label: labelLookup[entry.key] ?? entry.key.displayName,
              amount: entry.value,
              share: totalAmount > 0 ? entry.value / totalAmount : 0,
            ),
          )
          .toList(growable: false)
        ..sort((left, right) => right.amount.compareTo(left.amount));

  return items;
}

DashboardTodoReserveSummary buildDashboardTodoReserveSummary(
  List<TodoItem> todos,
) {
  final items =
      todos
          .where(
            (entry) =>
                !entry.done &&
                (entry.frequency == TodoFrequency.weekly ||
                    entry.frequency == TodoFrequency.monthly),
          )
          .map((entry) {
            final targetAmount = entry.price;
            final remainingAmount = entry.remainingAmount ?? entry.price;
            final usedAmount = (targetAmount - remainingAmount).clamp(
              0,
              targetAmount,
            );
            final remainingOccurrences = getRemainingOccurrenceDates(
              entry,
            ).length;

            return DashboardTodoReserveItem(
              id: entry.id,
              name: entry.name,
              frequency: entry.frequency,
              targetAmount: targetAmount,
              usedAmount: usedAmount.toDouble(),
              remainingAmount: remainingAmount,
              remainingOccurrences: remainingOccurrences,
            );
          })
          .where((entry) => entry.remainingAmount > 0)
          .toList(growable: false)
        ..sort((left, right) {
          final occurrenceCompare = right.remainingOccurrences.compareTo(
            left.remainingOccurrences,
          );
          if (occurrenceCompare != 0) {
            return occurrenceCompare;
          }

          return right.remainingAmount.compareTo(left.remainingAmount);
        });

  final targetAmount = items.fold(0.0, (sum, item) => sum + item.targetAmount);
  final usedAmount = items.fold(0.0, (sum, item) => sum + item.usedAmount);
  final remainingAmount = items.fold(
    0.0,
    (sum, item) => sum + item.remainingAmount,
  );

  return DashboardTodoReserveSummary(
    targetAmount: targetAmount,
    usedAmount: usedAmount,
    remainingAmount: remainingAmount,
    items: items,
  );
}

List<DashboardUpcomingTodoDay> buildUpcomingTodoSchedule(List<TodoItem> todos) {
  final today = DateTime.now();
  final normalizedToday = DateTime(today.year, today.month, today.day);
  final nextSevenDays = List<String>.generate(
    7,
    (index) => formatDateOnly(normalizedToday.add(Duration(days: index))),
    growable: false,
  );
  final dayMap = <String, List<DashboardUpcomingTodoItem>>{
    for (final value in nextSevenDays) value: <DashboardUpcomingTodoItem>[],
  };

  for (final entry in todos.where((todo) => !todo.done)) {
    final remainingDates = getRemainingOccurrenceDates(entry);
    if (remainingDates.isEmpty) {
      continue;
    }

    final amount = _resolveUpcomingTodoOccurrenceAmount(entry, remainingDates);
    for (final date in remainingDates) {
      if (!dayMap.containsKey(date)) {
        continue;
      }

      dayMap[date]!.add(
        DashboardUpcomingTodoItem(
          id: entry.id,
          name: entry.name,
          frequency: entry.frequency,
          amount: amount,
        ),
      );
    }
  }

  return nextSevenDays
      .map((date) {
        final items = dayMap[date]!
          ..sort((left, right) => right.amount.compareTo(left.amount));
        final totalAmount = items.fold(0.0, (sum, item) => sum + item.amount);
        return DashboardUpcomingTodoDay(
          date: date,
          items: List<DashboardUpcomingTodoItem>.from(items, growable: false),
          totalAmount: totalAmount,
        );
      })
      .toList(growable: false);
}

DashboardMonthComparisonSummary buildMonthComparisonSummary({
  required List<IncomeEntry> allIncome,
  required List<ExpenseEntry> allExpenses,
  required int month,
  required int year,
}) {
  final previousMonth = month == 1 ? 12 : month - 1;
  final previousYear = month == 1 ? year - 1 : year;

  final currentIncome = sumIncomeAmounts(
    filterEntriesByMonth(allIncome, (entry) => entry.date, month, year),
  );
  final previousIncome = sumIncomeAmounts(
    filterEntriesByMonth(
      allIncome,
      (entry) => entry.date,
      previousMonth,
      previousYear,
    ),
  );
  final currentExpenses = sumExpenseAmounts(
    filterEntriesByMonth(allExpenses, (entry) => entry.date, month, year),
  );
  final previousExpenses = sumExpenseAmounts(
    filterEntriesByMonth(
      allExpenses,
      (entry) => entry.date,
      previousMonth,
      previousYear,
    ),
  );

  final currentNetFlow = currentIncome - currentExpenses;
  final previousNetFlow = previousIncome - previousExpenses;

  return DashboardMonthComparisonSummary(
    currentLabel: '${formatDashboardMonthLabel(month)} $year',
    previousLabel: '${formatDashboardMonthLabel(previousMonth)} $previousYear',
    metrics: <DashboardMonthComparisonMetric>[
      _createMonthComparisonMetric(
        label: 'Income',
        currentAmount: currentIncome,
        previousAmount: previousIncome,
      ),
      _createMonthComparisonMetric(
        label: 'Expense',
        currentAmount: currentExpenses,
        previousAmount: previousExpenses,
      ),
      _createMonthComparisonMetric(
        label: 'Net flow',
        currentAmount: currentNetFlow,
        previousAmount: previousNetFlow,
      ),
    ],
  );
}

DashboardPartnerActivitySummary? buildPartnerActivitySummary({
  required AuthUser currentUser,
  required Partnership? partnership,
  required List<IncomeEntry> income,
  required List<ExpenseEntry> expenses,
  required List<SavingEntry> savings,
  required List<LoanEntry> loans,
}) {
  if (partnership == null || partnership.status != PartnershipStatus.accepted) {
    return null;
  }

  final acceptedPartner = partnership.owner.id == currentUser.id
      ? partnership.partner
      : partnership.owner;
  if (acceptedPartner == null) {
    return null;
  }

  final records = <DashboardPartnerActivityRecord>[
    ...income
        .where((entry) => entry.createdBy != null)
        .map(
          (entry) => DashboardPartnerActivityRecord(
            type: 'income',
            label: entry.label,
            amount: entry.amount,
            date: entry.date,
            creator: entry.createdBy!,
            isUsd: false,
          ),
        ),
    ...expenses
        .where((entry) => entry.createdBy != null)
        .map(
          (entry) => DashboardPartnerActivityRecord(
            type: 'expense',
            label: entry.label,
            amount: entry.amount,
            date: entry.date,
            creator: entry.createdBy!,
            isUsd: false,
          ),
        ),
    ...savings
        .where((entry) => entry.createdBy != null)
        .map(
          (entry) => DashboardPartnerActivityRecord(
            type: 'saving',
            label: entry.label,
            amount: entry.amount,
            date: entry.date,
            creator: entry.createdBy!,
            isUsd: true,
          ),
        ),
    ...loans
        .where((entry) => entry.createdBy != null)
        .map(
          (entry) => DashboardPartnerActivityRecord(
            type: 'loan',
            label: entry.label,
            amount: entry.amount,
            date: entry.date,
            creator: entry.createdBy!,
            isUsd: false,
          ),
        ),
  ]..sort((left, right) => right.date.compareTo(left.date));

  DashboardPartnerPersonSummary? summarizePerson({
    required String id,
    required String displayName,
    required String? avatarUrl,
    required bool isCurrentUser,
  }) {
    final personRecords = records
        .where((record) => record.creator.id == id)
        .toList(growable: false);
    if (personRecords.isEmpty) {
      return DashboardPartnerPersonSummary(
        id: id,
        displayName: displayName,
        avatarUrl: avatarUrl,
        isCurrentUser: isCurrentUser,
        entryCount: 0,
        rwfTotal: 0,
        usdTotal: 0,
        latestRecord: null,
      );
    }

    return DashboardPartnerPersonSummary(
      id: id,
      displayName: displayName,
      avatarUrl: avatarUrl,
      isCurrentUser: isCurrentUser,
      entryCount: personRecords.length,
      rwfTotal: personRecords
          .where((record) => !record.isUsd)
          .fold(0.0, (sum, record) => sum + record.amount),
      usdTotal: personRecords
          .where((record) => record.isUsd)
          .fold(0.0, (sum, record) => sum + record.amount),
      latestRecord: personRecords.first,
    );
  }

  return DashboardPartnerActivitySummary(
    currentUser: summarizePerson(
      id: currentUser.id,
      displayName: _displayAuthUserName(currentUser),
      avatarUrl: currentUser.avatarUrl,
      isCurrentUser: true,
    ),
    partner: summarizePerson(
      id: acceptedPartner.id,
      displayName: _displayPartnerName(acceptedPartner),
      avatarUrl: acceptedPartner.avatarUrl,
      isCurrentUser: false,
    ),
    latestRecords: records.take(6).toList(growable: false),
  );
}

DashboardLoanOverview buildLoanOverview(List<LoanEntry> loans) {
  final paidCount = loans.where((entry) => entry.paid).length;
  final unpaidCount = loans.length - paidCount;
  final totalAmount = loans.fold(0.0, (sum, entry) => sum + entry.amount);
  final unpaidAmount = loans
      .where((entry) => !entry.paid)
      .fold(0.0, (sum, entry) => sum + entry.amount);

  return DashboardLoanOverview(
    totalCount: loans.length,
    paidCount: paidCount,
    unpaidCount: unpaidCount,
    totalAmount: totalAmount,
    unpaidAmount: unpaidAmount,
  );
}

DashboardMonthComparisonMetric _createMonthComparisonMetric({
  required String label,
  required double currentAmount,
  required double previousAmount,
}) {
  final deltaAmount = currentAmount - previousAmount;
  final changePercentage = previousAmount == 0
      ? (currentAmount == 0 ? 0 : 100)
      : (deltaAmount / previousAmount) * 100;
  final isUp = deltaAmount >= 0;
  final isPositive = label == 'Expense' ? !isUp : isUp;

  return DashboardMonthComparisonMetric(
    label: label,
    currentAmount: currentAmount,
    previousAmount: previousAmount,
    deltaAmount: deltaAmount,
    changePercentage: changePercentage.abs().toDouble(),
    isUp: isUp,
    isPositive: isPositive,
  );
}

double _resolveUpcomingTodoOccurrenceAmount(
  TodoItem entry,
  List<String> remainingDates,
) {
  if (!isRecurringTodo(entry)) {
    return entry.price;
  }

  final remainingAmount = entry.remainingAmount ?? entry.price;
  if (remainingDates.isEmpty) {
    return remainingAmount;
  }

  return remainingAmount / remainingDates.length;
}

String displayCreatedByName(CreatedBySummary? creator) {
  if (creator == null) {
    return 'Partner';
  }

  final composed = [
    creator.firstName?.trim(),
    creator.lastName?.trim(),
  ].whereType<String>().where((value) => value.isNotEmpty).join(' ');

  return composed.isEmpty ? 'Partner' : composed;
}

String _displayAuthUserName(AuthUser user) {
  final fullName = user.fullName?.trim();
  if (fullName != null && fullName.isNotEmpty) {
    return fullName;
  }

  final composed = [
    user.firstName?.trim(),
    user.lastName?.trim(),
  ].whereType<String>().where((value) => value.isNotEmpty).join(' ');

  return composed.isEmpty ? user.email.split('@').first : composed;
}

String _displayPartnerName(PartnerUser user) {
  final fullName = user.fullName?.trim();
  if (fullName != null && fullName.isNotEmpty) {
    return fullName;
  }

  final composed = [
    user.firstName?.trim(),
    user.lastName?.trim(),
  ].whereType<String>().where((value) => value.isNotEmpty).join(' ');

  return composed.isEmpty ? user.email.split('@').first : composed;
}
