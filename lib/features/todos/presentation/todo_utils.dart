import '../../expenses/data/models/expense_entry.dart';
import '../data/models/todo_item.dart';

const List<int> todoWeekdayValues = <int>[0, 1, 2, 3, 4, 5, 6];
const List<String> todoWeekdayLabels = <String>[
  'Sun',
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
];

String getTodayDateValue() {
  final now = DateTime.now();
  final offset = now.timeZoneOffset.inMilliseconds;

  return formatDateOnly(now.subtract(Duration(milliseconds: offset)));
}

String formatDateOnly(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');

  return '$year-$month-$day';
}

DateTime parseDateOnly(String value) {
  final parts = value.split('-').map(int.parse).toList(growable: false);
  return DateTime(parts[0], parts[1], parts[2]);
}

DateTime addDays(DateTime date, int days) {
  return date.add(Duration(days: days));
}

String formatTodoDate(DateTime value) {
  const months = <String>[
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

  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}

String formatTodoFrequencyLabel(TodoFrequency frequency) {
  switch (frequency) {
    case TodoFrequency.weekly:
      return 'Weekly';
    case TodoFrequency.monthly:
      return 'Monthly';
    case TodoFrequency.yearly:
      return 'Yearly';
    case TodoFrequency.once:
      return 'Once';
  }
}

String computeTodoEndDate(String startDate, TodoFrequency frequency) {
  final parsedStart = parseDateOnly(startDate);

  switch (frequency) {
    case TodoFrequency.weekly:
      return formatDateOnly(addDays(parsedStart, 7));
    case TodoFrequency.monthly:
      return formatDateOnly(
        DateTime(parsedStart.year, parsedStart.month + 1, parsedStart.day),
      );
    case TodoFrequency.yearly:
      return formatDateOnly(
        DateTime(parsedStart.year + 1, parsedStart.month, parsedStart.day),
      );
    case TodoFrequency.once:
      return formatDateOnly(parsedStart);
  }
}

List<int> sortNumberValues(Iterable<int> values) {
  final normalized = values.toSet().toList(growable: false)..sort();
  return List<int>.unmodifiable(normalized);
}

List<String> sortDateValues(Iterable<String> values) {
  final normalized = values.toSet().toList(
    growable: false,
  )..sort((left, right) => parseDateOnly(left).compareTo(parseDateOnly(right)));
  return List<String>.unmodifiable(normalized);
}

List<String> buildTodoOccurrenceDates({
  required TodoFrequency frequency,
  required String startDate,
  required String endDate,
  List<int> frequencyDays = const <int>[],
  List<String> occurrenceDates = const <String>[],
}) {
  final start = parseDateOnly(startDate);
  final end = parseDateOnly(endDate);

  if (frequency == TodoFrequency.once) {
    return <String>[formatDateOnly(start)];
  }

  if (frequency == TodoFrequency.weekly) {
    final weekdays = sortNumberValues(
      frequencyDays.where((value) => value >= 0 && value <= 6),
    );
    final dates = <String>[];

    for (
      var cursor = DateTime(start.year, start.month, start.day);
      cursor.isBefore(end);
      cursor = addDays(cursor, 1)
    ) {
      if (weekdays.contains(cursor.weekday % 7)) {
        dates.add(formatDateOnly(cursor));
      }
    }

    return List<String>.unmodifiable(dates);
  }

  final filtered = occurrenceDates.where((value) {
    final current = parseDateOnly(value);
    return !current.isBefore(start) && current.isBefore(end);
  });

  return sortDateValues(filtered);
}

bool isRecurringTodo(TodoItem entry) {
  return entry.frequency != TodoFrequency.once;
}

List<String> getRemainingOccurrenceDates(TodoItem entry) {
  return entry.occurrenceDates
      .where((date) => !entry.recordedOccurrenceDates.contains(date))
      .toList(growable: false);
}

double getSuggestedTodoExpenseAmount(TodoItem entry) {
  if (!isRecurringTodo(entry)) {
    return entry.price;
  }

  final remainingAmount = entry.remainingAmount ?? entry.price;
  final remainingOccurrences = getRemainingOccurrenceDates(entry).length;

  if (remainingAmount <= 0 || remainingOccurrences <= 0) {
    return 0;
  }

  return double.parse(
    (remainingAmount / remainingOccurrences).toStringAsFixed(2),
  );
}

bool canRecordTodoExpense(TodoItem entry) {
  if (entry.done) {
    return false;
  }

  if (!isRecurringTodo(entry)) {
    return true;
  }

  return (entry.remainingAmount ?? 0) > 0 &&
      getRemainingOccurrenceDates(entry).isNotEmpty;
}

String formatTodoScheduleSummary(TodoItem entry) {
  if (!isRecurringTodo(entry)) {
    final start = entry.startDate;
    return start == null ? 'One-time' : 'One-time on ${formatTodoDate(start)}';
  }

  final remainingCount = getRemainingOccurrenceDates(entry).length;
  return '${entry.occurrenceDates.length} planned · $remainingCount left';
}

ExpenseCategory? resolveDefaultTodoExpenseCategory(
  List<ExpenseCategoryOption> categories,
) {
  if (categories.isEmpty) {
    return null;
  }

  for (final option in categories) {
    if (option.value == ExpenseCategory.shopping) {
      return option.value;
    }
  }

  for (final option in categories) {
    if (option.value == ExpenseCategory.other) {
      return option.value;
    }
  }

  return categories.first.value;
}
