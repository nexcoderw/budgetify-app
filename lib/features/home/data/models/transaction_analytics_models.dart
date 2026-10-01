import 'received_transaction_models.dart';
import 'transaction_models.dart';

class TransactionAnalytics {
  const TransactionAnalytics({
    required this.currency,
    required this.period,
    required this.summary,
    required this.comparison,
    required this.confirmation,
    required this.receivedEvidence,
    required this.categories,
    required this.transferTypes,
    required this.receivedClassifications,
  });

  factory TransactionAnalytics.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['categories'];

    final rawTransferTypes = json['transferTypes'];

    final rawReceivedClassifications = json['receivedClassifications'];

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

    if (rawReceivedClassifications is! List) {
      throw const FormatException(
        'Received transaction classifications are invalid.',
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
      receivedEvidence: ReceivedTransactionAnalyticsEvidence.fromJson(
        _requiredMap(json['receivedEvidence'], 'received evidence'),
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
      receivedClassifications: rawReceivedClassifications
          .map(
            (item) => ReceivedTransactionClassificationAnalytics.fromJson(
              _requiredMap(item, 'received classification analytics'),
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

  final ReceivedTransactionAnalyticsEvidence receivedEvidence;

  final List<TransactionCategoryAnalytics> categories;

  final List<TransactionTransferTypeAnalytics> transferTypes;

  final List<ReceivedTransactionClassificationAnalytics>
  receivedClassifications;

  bool get hasCompletedActivity {
    return summary.completedTransactions > 0 ||
        summary.receivedTransactions > 0;
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
    required this.receivedAmount,
    required this.feesPaid,
    required this.totalDebited,
    required this.netCashMovement,
    required this.completedTransactions,
    required this.receivedTransactions,
    required this.pendingTransactions,
    required this.processingTransactions,
    required this.needsConfirmation,
    required this.failedTransactions,
    required this.cancelledTransactions,
    required this.reversedTransactions,
    required this.receivedReversedTransactions,
  });

  factory TransactionAnalyticsSummary.fromJson(Map<String, dynamic> json) {
    return TransactionAnalyticsSummary(
      sentAmount: _requiredInt(json, 'sentAmount'),
      receivedAmount: _requiredInt(json, 'receivedAmount'),
      feesPaid: _requiredInt(json, 'feesPaid'),
      totalDebited: _requiredInt(json, 'totalDebited'),
      netCashMovement: _requiredInt(json, 'netCashMovement'),
      completedTransactions: _requiredInt(json, 'completedTransactions'),
      receivedTransactions: _requiredInt(json, 'receivedTransactions'),
      pendingTransactions: _requiredInt(json, 'pendingTransactions'),
      processingTransactions: _requiredInt(json, 'processingTransactions'),
      needsConfirmation: _requiredInt(json, 'needsConfirmation'),
      failedTransactions: _requiredInt(json, 'failedTransactions'),
      cancelledTransactions: _requiredInt(json, 'cancelledTransactions'),
      reversedTransactions: _requiredInt(json, 'reversedTransactions'),
      receivedReversedTransactions: _requiredInt(
        json,
        'receivedReversedTransactions',
      ),
    );
  }

  final int sentAmount;

  final int receivedAmount;

  final int feesPaid;

  final int totalDebited;

  final int netCashMovement;

  final int completedTransactions;

  final int receivedTransactions;

  final int pendingTransactions;

  final int processingTransactions;

  final int needsConfirmation;

  final int failedTransactions;

  final int cancelledTransactions;

  final int reversedTransactions;

  final int receivedReversedTransactions;
}

class TransactionAnalyticsComparison {
  const TransactionAnalyticsComparison({
    required this.previousSentAmount,
    required this.sentAmountChangePercentage,
    required this.previousReceivedAmount,
    required this.receivedAmountChangePercentage,
    required this.previousFeesPaid,
    required this.feesPaidChangePercentage,
    required this.previousTotalDebited,
    required this.totalDebitedChangePercentage,
    required this.previousNetCashMovement,
    required this.netCashMovementChange,
    required this.previousCompletedTransactions,
    required this.completedTransactionsChangePercentage,
    required this.previousReceivedTransactions,
    required this.receivedTransactionsChangePercentage,
  });

  factory TransactionAnalyticsComparison.fromJson(Map<String, dynamic> json) {
    return TransactionAnalyticsComparison(
      previousSentAmount: _requiredInt(json, 'previousSentAmount'),
      sentAmountChangePercentage: _optionalDouble(
        json,
        'sentAmountChangePercentage',
      ),
      previousReceivedAmount: _requiredInt(json, 'previousReceivedAmount'),
      receivedAmountChangePercentage: _optionalDouble(
        json,
        'receivedAmountChangePercentage',
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
      previousNetCashMovement: _requiredInt(json, 'previousNetCashMovement'),
      netCashMovementChange: _requiredInt(json, 'netCashMovementChange'),
      previousCompletedTransactions: _requiredInt(
        json,
        'previousCompletedTransactions',
      ),
      completedTransactionsChangePercentage: _optionalDouble(
        json,
        'completedTransactionsChangePercentage',
      ),
      previousReceivedTransactions: _requiredInt(
        json,
        'previousReceivedTransactions',
      ),
      receivedTransactionsChangePercentage: _optionalDouble(
        json,
        'receivedTransactionsChangePercentage',
      ),
    );
  }

  final int previousSentAmount;

  final double? sentAmountChangePercentage;

  final int previousReceivedAmount;

  final double? receivedAmountChangePercentage;

  final int previousFeesPaid;

  final double? feesPaidChangePercentage;

  final int previousTotalDebited;

  final double? totalDebitedChangePercentage;

  final int previousNetCashMovement;

  final int netCashMovementChange;

  final int previousCompletedTransactions;

  final double? completedTransactionsChangePercentage;

  final int previousReceivedTransactions;

  final double? receivedTransactionsChangePercentage;
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

class ReceivedTransactionAnalyticsEvidence {
  const ReceivedTransactionAnalyticsEvidence({
    required this.smsEvidence,
    required this.providerApiEvidence,
    required this.manualEntries,
  });

  factory ReceivedTransactionAnalyticsEvidence.fromJson(
    Map<String, dynamic> json,
  ) {
    return ReceivedTransactionAnalyticsEvidence(
      smsEvidence: _requiredInt(json, 'smsEvidence'),
      providerApiEvidence: _requiredInt(json, 'providerApiEvidence'),
      manualEntries: _requiredInt(json, 'manualEntries'),
    );
  }

  final int smsEvidence;

  final int providerApiEvidence;

  final int manualEntries;

  int get total {
    return smsEvidence + providerApiEvidence + manualEntries;
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

class ReceivedTransactionClassificationAnalytics {
  const ReceivedTransactionClassificationAnalytics({
    required this.classification,
    required this.receivedAmount,
    required this.transactions,
    required this.percentage,
  });

  factory ReceivedTransactionClassificationAnalytics.fromJson(
    Map<String, dynamic> json,
  ) {
    return ReceivedTransactionClassificationAnalytics(
      classification: ReceivedTransactionClassification.fromApiValue(
        _requiredString(json, 'classification'),
      ),
      receivedAmount: _requiredInt(json, 'receivedAmount'),
      transactions: _requiredInt(json, 'transactions'),
      percentage: _requiredDouble(json, 'percentage'),
    );
  }

  final ReceivedTransactionClassification classification;

  final int receivedAmount;

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
