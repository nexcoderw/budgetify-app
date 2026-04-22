import 'package:budgetify/features/todos/data/models/todo_item.dart';
import 'package:budgetify/features/expenses/data/models/expense_entry.dart';
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
    recordings: const <TodoRecordingItem>[],
    coverImageUrl: null,
    imageCount: 0,
    images: const <TodoImageItem>[],
    createdBy: null,
    createdAt: DateTime.utc(2026, 4, 1),
    updatedAt: DateTime.utc(2026, 4, 1),
  );
}

void main() {
  group('TodoItem recordings', () {
    test('parses recording audit totals from API responses', () {
      final item = TodoItem.fromJson(<String, dynamic>{
        'id': 'todo-1',
        'name': 'School fees',
        'price': 120000,
        'priority': 'PRIORITY',
        'status': 'RECORDED',
        'frequency': 'MONTHLY',
        'startDate': '2026-04-01',
        'endDate': '2026-05-01',
        'frequencyDays': <int>[],
        'occurrenceDates': <String>['2026-04-24'],
        'recordedOccurrenceDates': <String>['2026-04-24'],
        'remainingAmount': 0,
        'recordingCount': 1,
        'recordings': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'recording-1',
            'todoId': 'todo-1',
            'expenseId': 'expense-1',
            'occurrenceDate': '2026-04-24',
            'plannedAmount': 100000,
            'baseAmount': 99000,
            'feeAmount': 1000,
            'totalChargedAmount': 100000,
            'varianceAmount': 0,
            'paymentMethod': 'MOBILE_MONEY',
            'mobileMoneyChannel': 'P2P_TRANSFER',
            'mobileMoneyNetwork': 'ON_NET',
            'recordedAt': '2026-04-24T08:00:00.000Z',
            'recordedBy': <String, dynamic>{
              'id': 'user-1',
              'firstName': 'Alice',
              'lastName': 'Mutoni',
              'avatarUrl': null,
            },
            'expense': <String, dynamic>{
              'id': 'expense-1',
              'label': 'School fees',
              'category': 'SCHOOL_FEES',
              'date': '2026-04-24T00:00:00.000Z',
              'totalAmountRwf': 100000,
              'feeAmountRwf': 1000,
            },
          },
        ],
        'coverImageUrl': null,
        'imageCount': 0,
        'images': <Map<String, dynamic>>[],
        'createdBy': null,
        'createdAt': '2026-04-01T08:00:00.000Z',
        'updatedAt': '2026-04-24T08:00:00.000Z',
      });

      expect(item.recordings, hasLength(1));
      expect(item.recordings.first.plannedAmount, 100000);
      expect(item.recordings.first.feeAmount, 1000);
      expect(
        item.recordings.first.paymentMethod,
        ExpensePaymentMethod.mobileMoney,
      );
      expect(
        item.recordings.first.mobileMoneyChannel,
        ExpenseMobileMoneyChannel.p2pTransfer,
      );
      expect(
        item.recordings.first.expense?.category,
        ExpenseCategory.schoolFees,
      );
    });
  });

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
