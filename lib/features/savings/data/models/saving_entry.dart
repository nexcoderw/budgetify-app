import '../../../../core/models/created_by_summary.dart';

class SavingEntry {
  const SavingEntry({
    required this.id,
    required this.label,
    required this.amount,
    required this.currency,
    required this.amountRwf,
    required this.targetAmount,
    required this.targetCurrency,
    required this.targetAmountRwf,
    required this.startDate,
    required this.endDate,
    required this.timeframeDays,
    required this.targetProgressPercentage,
    required this.timeframeProgressPercentage,
    required this.totalDepositedRwf,
    required this.totalWithdrawnRwf,
    required this.currentBalanceRwf,
    required this.date,
    required this.note,
    required this.stillHave,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SavingEntry.fromJson(Map<String, dynamic> json) {
    return SavingEntry(
      id: json['id'] as String,
      label: json['label'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: SavingCurrencyCode.fromApi(
        json['currency'] as String? ?? 'RWF',
      ),
      amountRwf: ((json['amountRwf'] as num?) ?? (json['amount'] as num))
          .toDouble(),
      targetAmount: (json['targetAmount'] as num?)?.toDouble(),
      targetCurrency: (json['targetCurrency'] as String?) == null
          ? null
          : SavingCurrencyCode.fromApi(json['targetCurrency'] as String),
      targetAmountRwf: (json['targetAmountRwf'] as num?)?.toDouble(),
      startDate: (json['startDate'] as String?) == null
          ? null
          : DateTime.parse(json['startDate'] as String).toLocal(),
      endDate: (json['endDate'] as String?) == null
          ? null
          : DateTime.parse(json['endDate'] as String).toLocal(),
      timeframeDays: json['timeframeDays'] as int?,
      targetProgressPercentage:
          (json['targetProgressPercentage'] as num?)?.toDouble(),
      timeframeProgressPercentage:
          (json['timeframeProgressPercentage'] as num?)?.toDouble(),
      totalDepositedRwf:
          ((json['totalDepositedRwf'] as num?) ??
                  (json['amountRwf'] as num?) ??
                  (json['amount'] as num))
              .toDouble(),
      totalWithdrawnRwf: (json['totalWithdrawnRwf'] as num? ?? 0).toDouble(),
      currentBalanceRwf:
          ((json['currentBalanceRwf'] as num?) ??
                  (json['amountRwf'] as num?) ??
                  (json['amount'] as num))
              .toDouble(),
      date: DateTime.parse(json['date'] as String).toLocal(),
      note: json['note'] as String?,
      stillHave: json['stillHave'] as bool? ?? true,
      createdBy: (json['createdBy'] as Map<String, dynamic>?) != null
          ? CreatedBySummary.fromJson(json['createdBy'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
    );
  }

  final String id;
  final String label;
  final double amount;
  final SavingCurrencyCode currency;
  final double amountRwf;
  final double? targetAmount;
  final SavingCurrencyCode? targetCurrency;
  final double? targetAmountRwf;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? timeframeDays;
  final double? targetProgressPercentage;
  final double? timeframeProgressPercentage;
  final double totalDepositedRwf;
  final double totalWithdrawnRwf;
  final double currentBalanceRwf;
  final DateTime date;
  final String? note;
  final bool stillHave;
  final CreatedBySummary? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class SavingTransactionEntry {
  const SavingTransactionEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.currency,
    required this.amountRwf,
    required this.date,
    required this.note,
    required this.incomeSources,
    required this.createdAt,
  });

  factory SavingTransactionEntry.fromJson(Map<String, dynamic> json) {
    return SavingTransactionEntry(
      id: json['id'] as String,
      type: SavingTransactionTypeCode.fromApi(json['type'] as String),
      amount: (json['amount'] as num).toDouble(),
      currency: SavingCurrencyCode.fromApi(
        json['currency'] as String? ?? 'RWF',
      ),
      amountRwf: (json['amountRwf'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String).toLocal(),
      note: json['note'] as String?,
      incomeSources: ((json['incomeSources'] as List<dynamic>?) ?? const [])
          .map(
            (item) => SavingTransactionIncomeSourceEntry.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    );
  }

  final String id;
  final SavingTransactionTypeCode type;
  final double amount;
  final SavingCurrencyCode currency;
  final double amountRwf;
  final DateTime date;
  final String? note;
  final List<SavingTransactionIncomeSourceEntry> incomeSources;
  final DateTime createdAt;
}

class SavingTransactionIncomeSourceEntry {
  const SavingTransactionIncomeSourceEntry({
    required this.id,
    required this.incomeId,
    required this.incomeLabel,
    required this.incomeCategory,
    required this.amount,
    required this.currency,
    required this.amountRwf,
  });

  factory SavingTransactionIncomeSourceEntry.fromJson(
    Map<String, dynamic> json,
  ) {
    return SavingTransactionIncomeSourceEntry(
      id: json['id'] as String,
      incomeId: json['incomeId'] as String,
      incomeLabel: json['incomeLabel'] as String,
      incomeCategory: json['incomeCategory'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: SavingCurrencyCode.fromApi(
        json['currency'] as String? ?? 'RWF',
      ),
      amountRwf: (json['amountRwf'] as num).toDouble(),
    );
  }

  final String id;
  final String incomeId;
  final String incomeLabel;
  final String incomeCategory;
  final double amount;
  final SavingCurrencyCode currency;
  final double amountRwf;
}

enum SavingCurrencyCode {
  rwf,
  usd;

  String get apiValue => switch (this) {
    rwf => 'RWF',
    usd => 'USD',
  };

  String get displayName => switch (this) {
    rwf => 'RWF',
    usd => 'USD',
  };

  static SavingCurrencyCode fromApi(String value) {
    return switch (value) {
      'RWF' => SavingCurrencyCode.rwf,
      'USD' => SavingCurrencyCode.usd,
      _ => throw StateError('Unsupported saving currency: $value'),
    };
  }
}

enum SavingTransactionTypeCode {
  deposit,
  withdrawal,
  adjustment;

  String get apiValue => switch (this) {
    deposit => 'DEPOSIT',
    withdrawal => 'WITHDRAWAL',
    adjustment => 'ADJUSTMENT',
  };

  static SavingTransactionTypeCode fromApi(String value) {
    return switch (value) {
      'DEPOSIT' => SavingTransactionTypeCode.deposit,
      'WITHDRAWAL' => SavingTransactionTypeCode.withdrawal,
      'ADJUSTMENT' => SavingTransactionTypeCode.adjustment,
      _ => throw StateError('Unsupported saving transaction type: $value'),
    };
  }
}
