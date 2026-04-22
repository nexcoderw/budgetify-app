import 'todo_item.dart';

class TodoSummaryLatestItem {
  const TodoSummaryLatestItem({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  factory TodoSummaryLatestItem.fromJson(Map<String, dynamic> json) {
    return TodoSummaryLatestItem(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    );
  }

  final String id;
  final String name;
  final DateTime createdAt;
}

class TodoSummary {
  const TodoSummary({
    required this.totalCount,
    required this.openCount,
    required this.completedCount,
    required this.recurringCount,
    required this.topPriorityCount,
    required this.withImagesCount,
    required this.completionPercentage,
    required this.imageCoveragePercentage,
    required this.plannedTotal,
    required this.openPlannedTotal,
    required this.remainingRecurringBudgetTotal,
    required this.recordedCount,
    required this.recordedTotalAmount,
    required this.overdueCount,
    required this.next7DaysScheduledAmount,
    required this.next30DaysScheduledAmount,
    required this.latestTodo,
  });

  factory TodoSummary.fromJson(Map<String, dynamic> json) {
    return TodoSummary(
      totalCount: (json['totalCount'] as num? ?? 0).toInt(),
      openCount: (json['openCount'] as num? ?? 0).toInt(),
      completedCount: (json['completedCount'] as num? ?? 0).toInt(),
      recurringCount: (json['recurringCount'] as num? ?? 0).toInt(),
      topPriorityCount: (json['topPriorityCount'] as num? ?? 0).toInt(),
      withImagesCount: (json['withImagesCount'] as num? ?? 0).toInt(),
      completionPercentage: (json['completionPercentage'] as num? ?? 0).toInt(),
      imageCoveragePercentage: (json['imageCoveragePercentage'] as num? ?? 0)
          .toInt(),
      plannedTotal: (json['plannedTotal'] as num? ?? 0).toDouble(),
      openPlannedTotal: (json['openPlannedTotal'] as num? ?? 0).toDouble(),
      remainingRecurringBudgetTotal:
          (json['remainingRecurringBudgetTotal'] as num? ?? 0).toDouble(),
      recordedCount: (json['recordedCount'] as num? ?? 0).toInt(),
      recordedTotalAmount: (json['recordedTotalAmount'] as num? ?? 0)
          .toDouble(),
      overdueCount: (json['overdueCount'] as num? ?? 0).toInt(),
      next7DaysScheduledAmount: (json['next7DaysScheduledAmount'] as num? ?? 0)
          .toDouble(),
      next30DaysScheduledAmount:
          (json['next30DaysScheduledAmount'] as num? ?? 0).toDouble(),
      latestTodo: (json['latestTodo'] as Map<String, dynamic>?) != null
          ? TodoSummaryLatestItem.fromJson(
              json['latestTodo'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  final int totalCount;
  final int openCount;
  final int completedCount;
  final int recurringCount;
  final int topPriorityCount;
  final int withImagesCount;
  final int completionPercentage;
  final int imageCoveragePercentage;
  final double plannedTotal;
  final double openPlannedTotal;
  final double remainingRecurringBudgetTotal;
  final int recordedCount;
  final double recordedTotalAmount;
  final int overdueCount;
  final double next7DaysScheduledAmount;
  final double next30DaysScheduledAmount;
  final TodoSummaryLatestItem? latestTodo;
}

class TodoUpcomingItem {
  const TodoUpcomingItem({
    required this.id,
    required this.name,
    required this.frequency,
    required this.amount,
  });

  factory TodoUpcomingItem.fromJson(Map<String, dynamic> json) {
    return TodoUpcomingItem(
      id: json['id'] as String,
      name: json['name'] as String,
      frequency: TodoFrequency.fromApiValue(json['frequency'] as String?),
      amount: (json['amount'] as num? ?? 0).toDouble(),
    );
  }

  final String id;
  final String name;
  final TodoFrequency frequency;
  final double amount;
}

class TodoUpcomingDay {
  const TodoUpcomingDay({
    required this.date,
    required this.itemCount,
    required this.totalAmount,
    required this.items,
  });

  factory TodoUpcomingDay.fromJson(Map<String, dynamic> json) {
    return TodoUpcomingDay(
      date: json['date'] as String,
      itemCount: (json['itemCount'] as num? ?? 0).toInt(),
      totalAmount: (json['totalAmount'] as num? ?? 0).toDouble(),
      items: (json['items'] as List<dynamic>? ?? const <dynamic>[])
          .cast<Map<String, dynamic>>()
          .map(TodoUpcomingItem.fromJson)
          .toList(growable: false),
    );
  }

  final String date;
  final int itemCount;
  final double totalAmount;
  final List<TodoUpcomingItem> items;
}

class TodoReserveItem {
  const TodoReserveItem({
    required this.id,
    required this.name,
    required this.frequency,
    required this.targetAmount,
    required this.usedAmount,
    required this.remainingAmount,
    required this.remainingOccurrenceCount,
  });

  factory TodoReserveItem.fromJson(Map<String, dynamic> json) {
    return TodoReserveItem(
      id: json['id'] as String,
      name: json['name'] as String,
      frequency: TodoFrequency.fromApiValue(json['frequency'] as String?),
      targetAmount: (json['targetAmount'] as num? ?? 0).toDouble(),
      usedAmount: (json['usedAmount'] as num? ?? 0).toDouble(),
      remainingAmount: (json['remainingAmount'] as num? ?? 0).toDouble(),
      remainingOccurrenceCount: (json['remainingOccurrenceCount'] as num? ?? 0)
          .toInt(),
    );
  }

  final String id;
  final String name;
  final TodoFrequency frequency;
  final double targetAmount;
  final double usedAmount;
  final double remainingAmount;
  final int remainingOccurrenceCount;
}

class TodoReserveSummary {
  const TodoReserveSummary({
    required this.targetAmount,
    required this.usedAmount,
    required this.remainingAmount,
    required this.items,
  });

  factory TodoReserveSummary.fromJson(Map<String, dynamic> json) {
    return TodoReserveSummary(
      targetAmount: (json['targetAmount'] as num? ?? 0).toDouble(),
      usedAmount: (json['usedAmount'] as num? ?? 0).toDouble(),
      remainingAmount: (json['remainingAmount'] as num? ?? 0).toDouble(),
      items: (json['items'] as List<dynamic>? ?? const <dynamic>[])
          .cast<Map<String, dynamic>>()
          .map(TodoReserveItem.fromJson)
          .toList(growable: false),
    );
  }

  final double targetAmount;
  final double usedAmount;
  final double remainingAmount;
  final List<TodoReserveItem> items;
}

class TodoUpcomingSummary {
  const TodoUpcomingSummary({
    required this.windowDays,
    required this.daysWithPlans,
    required this.occurrenceCount,
    required this.totalScheduledAmount,
    required this.overdueCount,
    required this.reserveSummary,
    required this.days,
  });

  factory TodoUpcomingSummary.fromJson(Map<String, dynamic> json) {
    return TodoUpcomingSummary(
      windowDays: (json['windowDays'] as num? ?? 0).toInt(),
      daysWithPlans: (json['daysWithPlans'] as num? ?? 0).toInt(),
      occurrenceCount: (json['occurrenceCount'] as num? ?? 0).toInt(),
      totalScheduledAmount: (json['totalScheduledAmount'] as num? ?? 0)
          .toDouble(),
      overdueCount: (json['overdueCount'] as num? ?? 0).toInt(),
      reserveSummary: TodoReserveSummary.fromJson(
        (json['reserveSummary'] as Map<String, dynamic>?) ??
            const <String, dynamic>{},
      ),
      days: (json['days'] as List<dynamic>? ?? const <dynamic>[])
          .cast<Map<String, dynamic>>()
          .map(TodoUpcomingDay.fromJson)
          .toList(growable: false),
    );
  }

  final int windowDays;
  final int daysWithPlans;
  final int occurrenceCount;
  final double totalScheduledAmount;
  final int overdueCount;
  final TodoReserveSummary reserveSummary;
  final List<TodoUpcomingDay> days;
}
