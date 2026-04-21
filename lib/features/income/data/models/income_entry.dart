import '../../../../core/models/created_by_summary.dart';

class IncomeEntry {
  const IncomeEntry({
    required this.id,
    required this.label,
    required this.amount,
    required this.currency,
    required this.amountRwf,
    required this.category,
    required this.date,
    required this.received,
    required this.allocatedToSavingsRwf,
    required this.remainingAvailableRwf,
    required this.allocationStatus,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory IncomeEntry.fromJson(Map<String, dynamic> json) {
    return IncomeEntry(
      id: json['id'] as String,
      label: json['label'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: CurrencyCode.fromApi(json['currency'] as String? ?? 'RWF'),
      amountRwf: ((json['amountRwf'] as num?) ?? (json['amount'] as num))
          .toDouble(),
      category: IncomeCategory.fromApi(json['category'] as String),
      date: DateTime.parse(json['date'] as String).toLocal(),
      received: json['received'] as bool? ?? false,
      allocatedToSavingsRwf:
          (json['allocatedToSavingsRwf'] as num? ?? 0).toDouble(),
      remainingAvailableRwf:
          ((json['remainingAvailableRwf'] as num?) ??
                  (json['amountRwf'] as num?) ??
                  (json['amount'] as num))
              .toDouble(),
      allocationStatus: IncomeAllocationStatus.fromApi(
        json['allocationStatus'] as String? ?? 'UNALLOCATED',
      ),
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
  final CurrencyCode currency;
  final double amountRwf;
  final IncomeCategory category;
  final DateTime date;
  final bool received;
  final double allocatedToSavingsRwf;
  final double remainingAvailableRwf;
  final IncomeAllocationStatus allocationStatus;
  final CreatedBySummary? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class IncomeSummary {
  const IncomeSummary({
    required this.totalIncomeRwf,
    required this.receivedIncomeRwf,
    required this.pendingIncomeRwf,
    required this.totalExpensesRwf,
    required this.totalSavingsBalanceRwf,
    required this.availableMoneyNowRwf,
    required this.totalIncomeCount,
    required this.receivedIncomeCount,
    required this.pendingIncomeCount,
  });

  factory IncomeSummary.fromJson(Map<String, dynamic> json) {
    return IncomeSummary(
      totalIncomeRwf: (json['totalIncomeRwf'] as num? ?? 0).toDouble(),
      receivedIncomeRwf: (json['receivedIncomeRwf'] as num? ?? 0).toDouble(),
      pendingIncomeRwf: (json['pendingIncomeRwf'] as num? ?? 0).toDouble(),
      totalExpensesRwf: (json['totalExpensesRwf'] as num? ?? 0).toDouble(),
      totalSavingsBalanceRwf:
          (json['totalSavingsBalanceRwf'] as num? ?? 0).toDouble(),
      availableMoneyNowRwf:
          (json['availableMoneyNowRwf'] as num? ?? 0).toDouble(),
      totalIncomeCount: json['totalIncomeCount'] as int? ?? 0,
      receivedIncomeCount: json['receivedIncomeCount'] as int? ?? 0,
      pendingIncomeCount: json['pendingIncomeCount'] as int? ?? 0,
    );
  }

  final double totalIncomeRwf;
  final double receivedIncomeRwf;
  final double pendingIncomeRwf;
  final double totalExpensesRwf;
  final double totalSavingsBalanceRwf;
  final double availableMoneyNowRwf;
  final int totalIncomeCount;
  final int receivedIncomeCount;
  final int pendingIncomeCount;
}

class IncomeSavingAllocation {
  const IncomeSavingAllocation({
    required this.id,
    required this.savingId,
    required this.savingLabel,
    required this.transactionId,
    required this.transactionDate,
    required this.amount,
    required this.currency,
    required this.amountRwf,
    required this.note,
    required this.isReversed,
    required this.isReversal,
    required this.reversedByTransactionId,
  });

  factory IncomeSavingAllocation.fromJson(Map<String, dynamic> json) {
    return IncomeSavingAllocation(
      id: json['id'] as String,
      savingId: json['savingId'] as String,
      savingLabel: json['savingLabel'] as String,
      transactionId: json['transactionId'] as String,
      transactionDate: DateTime.parse(
        json['transactionDate'] as String,
      ).toLocal(),
      amount: (json['amount'] as num).toDouble(),
      currency: CurrencyCode.fromApi(json['currency'] as String? ?? 'RWF'),
      amountRwf: (json['amountRwf'] as num? ?? 0).toDouble(),
      note: json['note'] as String?,
      isReversed: json['isReversed'] as bool? ?? false,
      isReversal: json['isReversal'] as bool? ?? false,
      reversedByTransactionId: json['reversedByTransactionId'] as String?,
    );
  }

  final String id;
  final String savingId;
  final String savingLabel;
  final String transactionId;
  final DateTime transactionDate;
  final double amount;
  final CurrencyCode currency;
  final double amountRwf;
  final String? note;
  final bool isReversed;
  final bool isReversal;
  final String? reversedByTransactionId;
}

class IncomeDetail extends IncomeEntry {
  const IncomeDetail({
    required super.id,
    required super.label,
    required super.amount,
    required super.currency,
    required super.amountRwf,
    required super.category,
    required super.date,
    required super.received,
    required super.allocatedToSavingsRwf,
    required super.remainingAvailableRwf,
    required super.allocationStatus,
    required super.createdBy,
    required super.createdAt,
    required super.updatedAt,
    required this.allocationCount,
    required this.savingAllocations,
  });

  factory IncomeDetail.fromJson(Map<String, dynamic> json) {
    final base = IncomeEntry.fromJson(json);

    return IncomeDetail(
      id: base.id,
      label: base.label,
      amount: base.amount,
      currency: base.currency,
      amountRwf: base.amountRwf,
      category: base.category,
      date: base.date,
      received: base.received,
      allocatedToSavingsRwf: base.allocatedToSavingsRwf,
      remainingAvailableRwf: base.remainingAvailableRwf,
      allocationStatus: base.allocationStatus,
      createdBy: base.createdBy,
      createdAt: base.createdAt,
      updatedAt: base.updatedAt,
      allocationCount: json['allocationCount'] as int? ?? 0,
      savingAllocations:
          ((json['savingAllocations'] as List<dynamic>?) ?? const [])
              .map(
                (item) => IncomeSavingAllocation.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(growable: false),
    );
  }

  final int allocationCount;
  final List<IncomeSavingAllocation> savingAllocations;
}

enum CurrencyCode {
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

  static CurrencyCode fromApi(String value) {
    return switch (value) {
      'RWF' => CurrencyCode.rwf,
      'USD' => CurrencyCode.usd,
      _ => throw StateError('Unsupported currency: $value'),
    };
  }
}

enum IncomeCategory {
  salary,
  freelance,
  dividends,
  rental,
  sideHustle,
  other;

  String get apiValue => switch (this) {
    salary => 'SALARY',
    freelance => 'FREELANCE',
    dividends => 'DIVIDENDS',
    rental => 'RENTAL',
    sideHustle => 'SIDE_HUSTLE',
    other => 'OTHER',
  };

  String get displayName => switch (this) {
    salary => 'Salary',
    freelance => 'Freelance',
    dividends => 'Dividends',
    rental => 'Rental',
    sideHustle => 'Side hustle',
    other => 'Other',
  };

  static IncomeCategory fromApi(String value) {
    return switch (value) {
      'SALARY' => IncomeCategory.salary,
      'FREELANCE' => IncomeCategory.freelance,
      'DIVIDENDS' => IncomeCategory.dividends,
      'RENTAL' => IncomeCategory.rental,
      'SIDE_HUSTLE' => IncomeCategory.sideHustle,
      'OTHER' => IncomeCategory.other,
      _ => throw StateError('Unsupported income category: $value'),
    };
  }
}

enum IncomeAllocationStatus {
  unallocated,
  partiallyAllocated,
  fullyAllocated;

  String get apiValue => switch (this) {
    unallocated => 'UNALLOCATED',
    partiallyAllocated => 'PARTIALLY_ALLOCATED',
    fullyAllocated => 'FULLY_ALLOCATED',
  };

  String get displayName => switch (this) {
    unallocated => 'Unallocated',
    partiallyAllocated => 'Partially allocated',
    fullyAllocated => 'Fully allocated',
  };

  static IncomeAllocationStatus fromApi(String value) {
    return switch (value) {
      'UNALLOCATED' => IncomeAllocationStatus.unallocated,
      'PARTIALLY_ALLOCATED' => IncomeAllocationStatus.partiallyAllocated,
      'FULLY_ALLOCATED' => IncomeAllocationStatus.fullyAllocated,
      _ => throw StateError('Unsupported allocation status: $value'),
    };
  }
}
