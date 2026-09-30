enum TransactionAnalyticsPeriodPreset {
  sevenDays('7 days'),
  thirtyDays('30 days'),
  thisMonth('This month'),
  thisYear('This year');

  const TransactionAnalyticsPeriodPreset(this.label);

  final String label;

  TransactionAnalyticsRange rangeFor(DateTime now) {
    final localNow = now.toLocal();

    final start = switch (this) {
      TransactionAnalyticsPeriodPreset.sevenDays => DateTime(
        localNow.year,
        localNow.month,
        localNow.day - 6,
      ),
      TransactionAnalyticsPeriodPreset.thirtyDays => DateTime(
        localNow.year,
        localNow.month,
        localNow.day - 29,
      ),
      TransactionAnalyticsPeriodPreset.thisMonth => DateTime(
        localNow.year,
        localNow.month,
        1,
      ),
      TransactionAnalyticsPeriodPreset.thisYear => DateTime(
        localNow.year,
        1,
        1,
      ),
    };

    return TransactionAnalyticsRange(from: start, to: localNow);
  }
}

class TransactionAnalyticsRange {
  TransactionAnalyticsRange({required this.from, required this.to})
    : assert(
        !from.isAfter(to),
        'Analytics start date must not occur after its end date.',
      );

  final DateTime from;
  final DateTime to;
}
