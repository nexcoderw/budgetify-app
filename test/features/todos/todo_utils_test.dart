import 'package:budgetify/features/todos/data/models/todo_item.dart';
import 'package:budgetify/features/todos/presentation/todo_utils.dart';
import 'package:flutter_test/flutter_test.dart';

TodoItem _buildTodo({
  required TodoFrequency frequency,
  required TodoStatus status,
  double? remainingAmount,
  List<String> occurrenceDates = const <String>[],
  List<String> recordedOccurrenceDates = const <String>[],
}) {
  return TodoItem(
    id: 'todo-1',
    name: 'School fees',
    price: 120000,
    priority: TodoPriority.priority,
    status: status,
    frequency: frequency,
    startDate: DateTime.utc(2026, 4, 1),
    endDate: DateTime.utc(2026, 5, 1),
    frequencyDays: const <int>[1],
    occurrenceDates: occurrenceDates,
    recordedOccurrenceDates: recordedOccurrenceDates,
    remainingAmount: remainingAmount,
    recordingCount: recordedOccurrenceDates.length,
    coverImageUrl: null,
    imageCount: 0,
    images: const <TodoImageItem>[],
    createdBy: null,
    createdAt: DateTime.utc(2026, 4, 1),
    updatedAt: DateTime.utc(2026, 4, 1),
  );
}

void main() {
  group('TodoStatus', () {
    test('maps API values and closed-state semantics correctly', () {
      expect(TodoStatus.fromApiValue('ACTIVE'), TodoStatus.active);
      expect(TodoStatus.fromApiValue('RECORDED'), TodoStatus.recorded);
      expect(TodoStatus.fromApiValue('COMPLETED'), TodoStatus.completed);
      expect(TodoStatus.fromApiValue('SKIPPED'), TodoStatus.skipped);
      expect(TodoStatus.fromApiValue('ARCHIVED'), TodoStatus.archived);

      expect(isClosedTodoStatus(TodoStatus.active), isFalse);
      expect(isClosedTodoStatus(TodoStatus.recorded), isFalse);
      expect(isClosedTodoStatus(TodoStatus.completed), isTrue);
      expect(isClosedTodoStatus(TodoStatus.skipped), isTrue);
      expect(isClosedTodoStatus(TodoStatus.archived), isTrue);
    });
  });

  group('canRecordTodoExpense', () {
    test(
      'allows a one-time active todo and blocks recorded or closed states',
      () {
        final activeTodo = _buildTodo(
          frequency: TodoFrequency.once,
          status: TodoStatus.active,
        );
        final recordedTodo = _buildTodo(
          frequency: TodoFrequency.once,
          status: TodoStatus.recorded,
        );
        final completedTodo = _buildTodo(
          frequency: TodoFrequency.once,
          status: TodoStatus.completed,
        );

        expect(canRecordTodoExpense(activeTodo), isTrue);
        expect(canRecordTodoExpense(recordedTodo), isFalse);
        expect(canRecordTodoExpense(completedTodo), isFalse);
      },
    );

    test(
      'only allows recurring todos with budget and unrecorded occurrences left',
      () {
        final recurringTodo = _buildTodo(
          frequency: TodoFrequency.monthly,
          status: TodoStatus.active,
          remainingAmount: 40000,
          occurrenceDates: const <String>['2026-04-01', '2026-04-15'],
          recordedOccurrenceDates: const <String>['2026-04-01'],
        );
        final exhaustedBudgetTodo = _buildTodo(
          frequency: TodoFrequency.monthly,
          status: TodoStatus.active,
          remainingAmount: 0,
          occurrenceDates: const <String>['2026-04-01', '2026-04-15'],
          recordedOccurrenceDates: const <String>['2026-04-01'],
        );
        final fullyRecordedTodo = _buildTodo(
          frequency: TodoFrequency.monthly,
          status: TodoStatus.active,
          remainingAmount: 40000,
          occurrenceDates: const <String>['2026-04-01', '2026-04-15'],
          recordedOccurrenceDates: const <String>['2026-04-01', '2026-04-15'],
        );

        expect(canRecordTodoExpense(recurringTodo), isTrue);
        expect(canRecordTodoExpense(exhaustedBudgetTodo), isFalse);
        expect(canRecordTodoExpense(fullyRecordedTodo), isFalse);
      },
    );
  });
}
