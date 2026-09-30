import 'package:flutter_test/flutter_test.dart';

import 'package:budgetify/features/home/application/transaction_analytics_period.dart';

void main() {
  final now = DateTime(2026, 9, 30, 21, 24, 15);

  test('builds seven day analytics period', () {
    final range = TransactionAnalyticsPeriodPreset.sevenDays.rangeFor(now);

    expect(range.from, DateTime(2026, 9, 24));

    expect(range.to, now);
  });

  test('builds thirty day analytics period across month boundary', () {
    final range = TransactionAnalyticsPeriodPreset.thirtyDays.rangeFor(now);

    expect(range.from, DateTime(2026, 9, 1));

    expect(range.to, now);
  });

  test('builds this month analytics period', () {
    final range = TransactionAnalyticsPeriodPreset.thisMonth.rangeFor(now);

    expect(range.from, DateTime(2026, 9, 1));

    expect(range.to, now);
  });

  test('builds this year analytics period', () {
    final range = TransactionAnalyticsPeriodPreset.thisYear.rangeFor(now);

    expect(range.from, DateTime(2026, 1, 1));

    expect(range.to, now);
  });
}
