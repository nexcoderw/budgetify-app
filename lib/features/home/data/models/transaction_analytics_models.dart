import 'transaction_models.dart';

class TransactionAnalytics {
  const TransactionAnalytics({
    required this.currency,
    required this.period,
    required this.summary,
    required this.comparison,
    required this.confirmation,
    required this.categories,
    required this.transferTypes,
  });

  factory TransactionAnalytics.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['categories'];

    final rawTransferTypes = json['transferTypes'];

    if (rawCategories is! List) {
      throw const FormatException(
        'Transaction analytics categories are invalid.',
      );
    }

    if (rawTransferTypes is! List) {
      throw const FormatException(
        'Transaction analytics transfer types are invalid.',
      );
    }

    return TransactionAnalytics(
      currency: _requiredString(json, 'currency'),
      period: TransactionAnalyticsPeriod.fromJson(
        _requiredMap(json['period'], 'period'),
      ),
      summary: TransactionAnalyticsSummary.fromJson(
        _requiredMap(json['summary'], 'summary'),
      ),
      comparison: TransactionAnalyticsComparison.fromJson(
        _requiredMap(json['comparison'], 'comparison'),
      ),
      confirmation: TransactionAnalyticsConfirmation.fromJson(
        _requiredMap(json['confirmation'], 'confirmation'),
      ),
      categories: rawCategories
          .map(
            (item) => TransactionCategoryAnalytics.fromJson(
              _requiredMap(item, 'category analytics'),
            ),
          )
          .toList(growable: false),
      transferTypes: rawTransferTypes
          .map(
            (item) => TransactionTransferTypeAnalytics.fromJson(
              _requiredMap(item, 'transfer type analytics'),
            ),
          )
          .toList(growable: false),
    );
  }

  final String currency;

  final TransactionAnalyticsPeriod period;

  final TransactionAnalyticsSummary summary;

  final TransactionAnalyticsComparison comparison;

  final TransactionAnalyticsConfirmation confirmation;

  final List<TransactionCategoryAnalytics> categories;

  final List<TransactionTransferTypeAnalytics> transferTypes;

  bool get hasCompletedActivity {
    return summary.completedTransactions > 0;
  }
}

class TransactionAnalyticsPeriod {
  const TransactionAnalyticsPeriod({
    required this.from,
    required this.to,
    required this.previousFrom,
    required this.previousTo,
  });

  factory TransactionAnalyticsPeriod.fromJson(Map<String, dynamic> json) {
    return TransactionAnalyticsPeriod(
      from: _requiredDate(json, 'from'),
      to: _requiredDate(json, 'to'),
      previousFrom: _requiredDate(json, 'previousFrom'),
      previousTo: _requiredDate(json, 'previousTo'),
    );
  }

  final DateTime from;
  final DateTime to;
  final DateTime previousFrom;
  final DateTime previousTo;
}

class TransactionAnalyticsSummary {
  const TransactionAnalyticsSummary({
    required this.sentAmount,
    required this.feesPaid,
    required this.totalDebited,
    required this.completedTransactions,
    required this.pendingTransactions,
    required this.processingTransactions,
    required this.needsConfirmation,
    required this.failedTransactions,
    required this.cancelledTransactions,
    required this.reversedTransactions,
  });

  factory TransactionAnalyticsSummary.fromJson(Map<String, dynamic> json) {
    return TransactionAnalyticsSummary(
      sentAmount: _requiredInt(json, 'sentAmount'),
      feesPaid: _requiredInt(json, 'feesPaid'),
      totalDebited: _requiredInt(json, 'totalDebited'),
      completedTransactions: _requiredInt(json, 'completedTransactions'),
      pendingTransactions: _requiredInt(json, 'pendingTransactions'),
      processingTransactions: _requiredInt(json, 'processingTransactions'),
      needsConfirmation: _requiredInt(json, 'needsConfirmation'),
      failedTransactions: _requiredInt(json, 'failedTransactions'),
      cancelledTransactions: _requiredInt(json, 'cancelledTransactions'),
      reversedTransactions: _requiredInt(json, 'reversedTransactions'),
    );
  }

  final int sentAmount;
  final int feesPaid;
  final int totalDebited;

  final int completedTransactions;
  final int pendingTransactions;
  final int processingTransactions;
  final int needsConfirmation;
  final int failedTransactions;
  final int cancelledTransactions;
  final int reversedTransactions;
}

class TransactionAnalyticsComparison {
  const TransactionAnalyticsComparison({
    required this.previousSentAmount,
    required this.sentAmountChangePercentage,
    required this.previousFeesPaid,
    required this.feesPaidChangePercentage,
    required this.previousTotalDebited,
    required this.totalDebitedChangePercentage,
    required this.previousCompletedTransactions,
    required this.completedTransactionsChangePercentage,
  });

  factory TransactionAnalyticsComparison.fromJson(Map<String, dynamic> json) {
    return TransactionAnalyticsComparison(
      previousSentAmount: _requiredInt(json, 'previousSentAmount'),
      sentAmountChangePercentage: _optionalDouble(
        json,
        'sentAmountChangePercentage',
      ),
      previousFeesPaid: _requiredInt(json, 'previousFeesPaid'),
      feesPaidChangePercentage: _optionalDouble(
        json,
        'feesPaidChangePercentage',
      ),
      previousTotalDebited: _requiredInt(json, 'previousTotalDebited'),
      totalDebitedChangePercentage: _optionalDouble(
        json,
        'totalDebitedChangePercentage',
      ),
      previousCompletedTransactions: _requiredInt(
        json,
        'previousCompletedTransactions',
      ),
      completedTransactionsChangePercentage: _optionalDouble(
        json,
        'completedTransactionsChangePercentage',
      ),
    );
  }

  final int previousSentAmount;

  final double? sentAmountChangePercentage;

  final int previousFeesPaid;

  final double? feesPaidChangePercentage;

  final int previousTotalDebited;

  final double? totalDebitedChangePercentage;

  final int previousCompletedTransactions;

  final double? completedTransactionsChangePercentage;
}

class TransactionAnalyticsConfirmation {
  const TransactionAnalyticsConfirmation({
    required this.smsEvidence,
    required this.providerApiConfirmed,
    required this.manuallyConfirmed,
    required this.unclassified,
  });

  factory TransactionAnalyticsConfirmation.fromJson(Map<String, dynamic> json) {
    return TransactionAnalyticsConfirmation(
      smsEvidence: _requiredInt(json, 'smsEvidence'),
      providerApiConfirmed: _requiredInt(json, 'providerApiConfirmed'),
      manuallyConfirmed: _requiredInt(json, 'manuallyConfirmed'),
      unclassified: _requiredInt(json, 'unclassified'),
    );
  }

  final int smsEvidence;

  final int providerApiConfirmed;

  final int manuallyConfirmed;

  final int unclassified;

  int get total {
    return smsEvidence +
        providerApiConfirmed +
        manuallyConfirmed +
        unclassified;
  }
}

class TransactionCategoryAnalytics {
  const TransactionCategoryAnalytics({
    required this.category,
    required this.sentAmount,
    required this.feesPaid,
    required this.totalDebited,
    required this.transactions,
    required this.percentage,
  });

  factory TransactionCategoryAnalytics.fromJson(Map<String, dynamic> json) {
    return TransactionCategoryAnalytics(
      category: TransactionCategory.fromApiValue(
        _requiredString(json, 'category'),
      ),
      sentAmount: _requiredInt(json, 'sentAmount'),
      feesPaid: _requiredInt(json, 'feesPaid'),
      totalDebited: _requiredInt(json, 'totalDebited'),
      transactions: _requiredInt(json, 'transactions'),
      percentage: _requiredDouble(json, 'percentage'),
    );
  }

  final TransactionCategory category;

  final int sentAmount;
  final int feesPaid;
  final int totalDebited;
  final int transactions;
  final double percentage;
}

class TransactionTransferTypeAnalytics {
  const TransactionTransferTypeAnalytics({
    required this.transferType,
    required this.sentAmount,
    required this.feesPaid,
    required this.totalDebited,
    required this.transactions,
    required this.percentage,
  });

  factory TransactionTransferTypeAnalytics.fromJson(Map<String, dynamic> json) {
    return TransactionTransferTypeAnalytics(
      transferType: TransactionTransferType.fromApiValue(
        _requiredString(json, 'transferType'),
      ),
      sentAmount: _requiredInt(json, 'sentAmount'),
      feesPaid: _requiredInt(json, 'feesPaid'),
      totalDebited: _requiredInt(json, 'totalDebited'),
      transactions: _requiredInt(json, 'transactions'),
      percentage: _requiredDouble(json, 'percentage'),
    );
  }

  final TransactionTransferType transferType;

  final int sentAmount;
  final int feesPaid;
  final int totalDebited;
  final int transactions;
  final double percentage;
}

Map<String, dynamic> _requiredMap(Object? value, String field) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }

  throw FormatException('Invalid $field payload.');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];

  if (value is String && value.trim().isNotEmpty) {
    return value;
  }

  throw FormatException('Missing or invalid $key.');
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];

  if (value is int) {
    return value;
  }

  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }

  throw FormatException('Missing or invalid $key.');
}

double _requiredDouble(Map<String, dynamic> json, String key) {
  final value = json[key];

  if (value is num && value.isFinite) {
    return value.toDouble();
  }

  throw FormatException('Missing or invalid $key.');
}

double? _optionalDouble(Map<String, dynamic> json, String key) {
  final value = json[key];

  if (value == null) {
    return null;
  }

  if (value is num && value.isFinite) {
    return value.toDouble();
  }

  throw FormatException('Invalid $key.');
}

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);

  final date = DateTime.tryParse(value);

  if (date == null) {
    throw FormatException('Invalid $key date.');
  }

  return date;
}
