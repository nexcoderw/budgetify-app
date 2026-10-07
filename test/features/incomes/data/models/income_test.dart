import 'package:budgetify/features/incomes/data/models/income.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats money without rounding away decimal values', () {
    expect(formatIncomeAmount('120000.50'), '120,000.50');
    expect(formatIncomeAmount('120000.00'), '120,000');
    expect(readIncomeAmount('999999999999'), '999999999999');
    expect(() => readIncomeAmount('-1'), throwsFormatException);
    expect(() => readIncomeAmount('NaN'), throwsFormatException);
  });

  test('keeps expected and received totals separate', () {
    final result = IncomePageResult.fromJson({
      'items': [],
      'pagination': {'hasNextPage': false},
      'summary': {'expectedAmount': '1000', 'receivedAmount': '500'},
    });
    expect(result.expectedAmount, '1000');
    expect(result.receivedAmount, '500');
    expect(result.hasNextPage, isFalse);
  });

  test('reads a linked income without creating another payment', () {
    final record = IncomeRecord.fromJson({
      'id': 'income',
      'label': 'Salary',
      'amount': '1000',
      'category': 'SALARY',
      'status': 'RECEIVED',
      'date': '2026-10-01T00:00:00Z',
      'expectedAt': '2026-09-30T00:00:00Z',
      'receivedTransactionId': 'payment',
      'paymentReference': 'REF-1',
    });
    expect(record.isExpected, isFalse);
    expect(record.receivedTransactionId, 'payment');
    expect(record.expectedAt, isNotNull);
  });
}
