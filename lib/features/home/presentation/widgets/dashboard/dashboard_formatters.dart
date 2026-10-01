import '../../../data/models/transaction_analytics_models.dart';

String formatDashboardComparison(double? percentage) {
  if (percentage == null) {
    return 'New vs previous period';
  }

  if (percentage == 0) {
    return 'No change vs previous period';
  }

  final prefix = percentage > 0 ? '+' : '';

  return '$prefix${formatDashboardPercentage(percentage)} vs previous period';
}

String formatDashboardNetComparison(int change, String currency) {
  if (change == 0) {
    return 'No change vs previous period';
  }

  return '${formatDashboardSignedAmount(change)} '
      '$currency vs previous period';
}

String formatDashboardPercentage(double value) {
  final isWhole = value == value.roundToDouble();

  return '${value.toStringAsFixed(isWhole ? 0 : 1)}%';
}

String formatDashboardAmount(int amount) {
  final isNegative = amount < 0;
  final value = amount.abs().toString();
  final buffer = StringBuffer();

  for (var index = 0; index < value.length; index++) {
    final remaining = value.length - index;

    buffer.write(value[index]);

    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }

  final formatted = buffer.toString();

  return isNegative ? '-$formatted' : formatted;
}

String formatDashboardSignedAmount(int amount) {
  if (amount > 0) {
    return '+${formatDashboardAmount(amount)}';
  }

  return formatDashboardAmount(amount);
}

String formatDashboardPeriodRange(TransactionAnalyticsPeriod period) {
  final from = period.from.toLocal();
  final to = period.to.toLocal();

  if (from.year == to.year && from.month == to.month && from.day == to.day) {
    return '${_shortDate(from)} • ${_shortTime(to)}';
  }

  if (from.year == to.year) {
    return '${from.day} ${_month(from.month)} – '
        '${to.day} ${_month(to.month)} ${to.year}';
  }

  return '${from.day} ${_month(from.month)} ${from.year} – '
      '${to.day} ${_month(to.month)} ${to.year}';
}

String _shortDate(DateTime date) {
  return '${date.day} ${_month(date.month)} ${date.year}';
}

String _shortTime(DateTime date) {
  final hour = date.hour == 0
      ? 12
      : date.hour > 12
      ? date.hour - 12
      : date.hour;

  final minute = date.minute.toString().padLeft(2, '0');

  final period = date.hour >= 12 ? 'PM' : 'AM';

  return '$hour:$minute $period';
}

String _month(int month) {
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

  return months[month - 1];
}
