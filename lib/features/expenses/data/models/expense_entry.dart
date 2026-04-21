import '../../../../core/models/created_by_summary.dart';

class ExpenseEntry {
  const ExpenseEntry({
    required this.id,
    required this.label,
    required this.amount,
    required this.currency,
    required this.amountRwf,
    required this.feeAmount,
    required this.feeAmountRwf,
    required this.totalAmountRwf,
    required this.paymentMethod,
    required this.mobileMoneyChannel,
    required this.mobileMoneyProvider,
    required this.mobileMoneyNetwork,
    required this.category,
    required this.date,
    required this.note,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ExpenseEntry.fromJson(Map<String, dynamic> json) {
    return ExpenseEntry(
      id: json['id'] as String,
      label: json['label'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: ExpenseCurrency.fromApi(json['currency'] as String? ?? 'RWF'),
      amountRwf: ((json['amountRwf'] as num?) ?? (json['amount'] as num))
          .toDouble(),
      feeAmount: (json['feeAmount'] as num? ?? 0).toDouble(),
      feeAmountRwf: (json['feeAmountRwf'] as num? ?? 0).toDouble(),
      totalAmountRwf:
          ((json['totalAmountRwf'] as num?) ??
                  (json['amountRwf'] as num?) ??
                  (json['amount'] as num))
              .toDouble(),
      paymentMethod: ExpensePaymentMethod.fromApi(
        json['paymentMethod'] as String? ?? 'CASH',
      ),
      mobileMoneyChannel: (json['mobileMoneyChannel'] as String?) == null
          ? null
          : ExpenseMobileMoneyChannel.fromApi(
              json['mobileMoneyChannel'] as String,
            ),
      mobileMoneyProvider: (json['mobileMoneyProvider'] as String?) == null
          ? null
          : ExpenseMobileMoneyProvider.fromApi(
              json['mobileMoneyProvider'] as String,
            ),
      mobileMoneyNetwork: (json['mobileMoneyNetwork'] as String?) == null
          ? null
          : ExpenseMobileMoneyNetwork.fromApi(
              json['mobileMoneyNetwork'] as String,
            ),
      category: ExpenseCategory.fromApi(json['category'] as String),
      date: DateTime.parse(json['date'] as String).toLocal(),
      note: json['note'] as String?,
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
  final ExpenseCurrency currency;
  final double amountRwf;
  final double feeAmount;
  final double feeAmountRwf;
  final double totalAmountRwf;
  final ExpensePaymentMethod paymentMethod;
  final ExpenseMobileMoneyChannel? mobileMoneyChannel;
  final ExpenseMobileMoneyProvider? mobileMoneyProvider;
  final ExpenseMobileMoneyNetwork? mobileMoneyNetwork;
  final ExpenseCategory category;
  final DateTime date;
  final String? note;
  final CreatedBySummary? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class ExpenseSummary {
  const ExpenseSummary({
    required this.totalExpensesRwf,
    required this.totalFeesRwf,
    required this.totalChargedExpensesRwf,
    required this.averageExpenseRwf,
    required this.largestExpenseRwf,
    required this.availableMoneyNowRwf,
    required this.expenseCount,
  });

  factory ExpenseSummary.fromJson(Map<String, dynamic> json) {
    return ExpenseSummary(
      totalExpensesRwf: (json['totalExpensesRwf'] as num? ?? 0).toDouble(),
      totalFeesRwf: (json['totalFeesRwf'] as num? ?? 0).toDouble(),
      totalChargedExpensesRwf: (json['totalChargedExpensesRwf'] as num? ?? 0)
          .toDouble(),
      averageExpenseRwf: (json['averageExpenseRwf'] as num? ?? 0).toDouble(),
      largestExpenseRwf: (json['largestExpenseRwf'] as num? ?? 0).toDouble(),
      availableMoneyNowRwf: (json['availableMoneyNowRwf'] as num? ?? 0)
          .toDouble(),
      expenseCount: json['expenseCount'] as int? ?? 0,
    );
  }

  final double totalExpensesRwf;
  final double totalFeesRwf;
  final double totalChargedExpensesRwf;
  final double averageExpenseRwf;
  final double largestExpenseRwf;
  final double availableMoneyNowRwf;
  final int expenseCount;
}

class ExpenseAudit {
  const ExpenseAudit({
    required this.periodStartDate,
    required this.periodEndDate,
    required this.totalBaseExpensesRwf,
    required this.totalPaymentFeesRwf,
    required this.totalChargedExpensesRwf,
    required this.expenseCount,
    required this.feeBearingExpenseCount,
    required this.availableMoneyBeforeExpensesRwf,
    required this.availableMoneyAfterExpensesRwf,
    required this.recomputedAvailableMoneyAfterExpensesRwf,
    required this.reconciliationDifferenceRwf,
    required this.isBalanced,
  });

  factory ExpenseAudit.fromJson(Map<String, dynamic> json) {
    return ExpenseAudit(
      periodStartDate: json['periodStartDate'] as String?,
      periodEndDate: json['periodEndDate'] as String?,
      totalBaseExpensesRwf: (json['totalBaseExpensesRwf'] as num? ?? 0)
          .toDouble(),
      totalPaymentFeesRwf: (json['totalPaymentFeesRwf'] as num? ?? 0)
          .toDouble(),
      totalChargedExpensesRwf: (json['totalChargedExpensesRwf'] as num? ?? 0)
          .toDouble(),
      expenseCount: json['expenseCount'] as int? ?? 0,
      feeBearingExpenseCount: json['feeBearingExpenseCount'] as int? ?? 0,
      availableMoneyBeforeExpensesRwf:
          (json['availableMoneyBeforeExpensesRwf'] as num? ?? 0).toDouble(),
      availableMoneyAfterExpensesRwf:
          (json['availableMoneyAfterExpensesRwf'] as num? ?? 0).toDouble(),
      recomputedAvailableMoneyAfterExpensesRwf:
          (json['recomputedAvailableMoneyAfterExpensesRwf'] as num? ?? 0)
              .toDouble(),
      reconciliationDifferenceRwf:
          (json['reconciliationDifferenceRwf'] as num? ?? 0).toDouble(),
      isBalanced: json['isBalanced'] as bool? ?? false,
    );
  }

  final String? periodStartDate;
  final String? periodEndDate;
  final double totalBaseExpensesRwf;
  final double totalPaymentFeesRwf;
  final double totalChargedExpensesRwf;
  final int expenseCount;
  final int feeBearingExpenseCount;
  final double availableMoneyBeforeExpensesRwf;
  final double availableMoneyAfterExpensesRwf;
  final double recomputedAvailableMoneyAfterExpensesRwf;
  final double reconciliationDifferenceRwf;
  final bool isBalanced;
}

class MobileMoneyQuote {
  const MobileMoneyQuote({
    required this.amount,
    required this.currency,
    required this.amountRwf,
    required this.feeAmount,
    required this.feeAmountRwf,
    required this.totalAmountRwf,
    required this.mobileMoneyProvider,
    required this.mobileMoneyChannel,
    required this.mobileMoneyNetwork,
  });

  factory MobileMoneyQuote.fromJson(Map<String, dynamic> json) {
    return MobileMoneyQuote(
      amount: (json['amount'] as num? ?? 0).toDouble(),
      currency: ExpenseCurrency.fromApi(json['currency'] as String? ?? 'RWF'),
      amountRwf: (json['amountRwf'] as num? ?? 0).toDouble(),
      feeAmount: (json['feeAmount'] as num? ?? 0).toDouble(),
      feeAmountRwf: (json['feeAmountRwf'] as num? ?? 0).toDouble(),
      totalAmountRwf: (json['totalAmountRwf'] as num? ?? 0).toDouble(),
      mobileMoneyProvider: ExpenseMobileMoneyProvider.fromApi(
        json['mobileMoneyProvider'] as String,
      ),
      mobileMoneyChannel: ExpenseMobileMoneyChannel.fromApi(
        json['mobileMoneyChannel'] as String,
      ),
      mobileMoneyNetwork: (json['mobileMoneyNetwork'] as String?) == null
          ? null
          : ExpenseMobileMoneyNetwork.fromApi(
              json['mobileMoneyNetwork'] as String,
            ),
    );
  }

  final double amount;
  final ExpenseCurrency currency;
  final double amountRwf;
  final double feeAmount;
  final double feeAmountRwf;
  final double totalAmountRwf;
  final ExpenseMobileMoneyProvider mobileMoneyProvider;
  final ExpenseMobileMoneyChannel mobileMoneyChannel;
  final ExpenseMobileMoneyNetwork? mobileMoneyNetwork;
}

class ExpenseCategoryOption {
  const ExpenseCategoryOption({required this.value, required this.label});

  factory ExpenseCategoryOption.fromJson(Map<String, dynamic> json) {
    return ExpenseCategoryOption(
      value: ExpenseCategory.fromApi(json['value'] as String),
      label: json['label'] as String,
    );
  }

  final ExpenseCategory value;
  final String label;
}

enum ExpenseCurrency {
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

  static ExpenseCurrency fromApi(String value) {
    return switch (value) {
      'RWF' => ExpenseCurrency.rwf,
      'USD' => ExpenseCurrency.usd,
      _ => throw StateError('Unsupported expense currency: $value'),
    };
  }
}

enum ExpensePaymentMethod {
  cash,
  bank,
  mobileMoney,
  card,
  other;

  String get apiValue => switch (this) {
    cash => 'CASH',
    bank => 'BANK',
    mobileMoney => 'MOBILE_MONEY',
    card => 'CARD',
    other => 'OTHER',
  };

  String get displayName => switch (this) {
    cash => 'Cash',
    bank => 'Bank',
    mobileMoney => 'Mobile money',
    card => 'Card',
    other => 'Other',
  };

  static ExpensePaymentMethod fromApi(String value) {
    return switch (value) {
      'CASH' => ExpensePaymentMethod.cash,
      'BANK' => ExpensePaymentMethod.bank,
      'MOBILE_MONEY' => ExpensePaymentMethod.mobileMoney,
      'CARD' => ExpensePaymentMethod.card,
      'OTHER' => ExpensePaymentMethod.other,
      _ => throw StateError('Unsupported expense payment method: $value'),
    };
  }
}

enum ExpenseMobileMoneyChannel {
  merchantCode,
  p2pTransfer;

  String get apiValue => switch (this) {
    merchantCode => 'MERCHANT_CODE',
    p2pTransfer => 'P2P_TRANSFER',
  };

  String get displayName => switch (this) {
    merchantCode => 'Merchant code',
    p2pTransfer => 'Normal transfer',
  };

  static ExpenseMobileMoneyChannel fromApi(String value) {
    return switch (value) {
      'MERCHANT_CODE' => ExpenseMobileMoneyChannel.merchantCode,
      'P2P_TRANSFER' => ExpenseMobileMoneyChannel.p2pTransfer,
      _ => throw StateError('Unsupported mobile money channel: $value'),
    };
  }
}

enum ExpenseMobileMoneyProvider {
  mtnRwanda,
  other;

  String get apiValue => switch (this) {
    mtnRwanda => 'MTN_RWANDA',
    other => 'OTHER',
  };

  String get displayName => switch (this) {
    mtnRwanda => 'MTN Rwanda',
    other => 'Other',
  };

  static ExpenseMobileMoneyProvider fromApi(String value) {
    return switch (value) {
      'MTN_RWANDA' => ExpenseMobileMoneyProvider.mtnRwanda,
      'OTHER' => ExpenseMobileMoneyProvider.other,
      _ => throw StateError('Unsupported mobile money provider: $value'),
    };
  }
}

enum ExpenseMobileMoneyNetwork {
  onNet,
  offNet;

  String get apiValue => switch (this) {
    onNet => 'ON_NET',
    offNet => 'OFF_NET',
  };

  String get displayName => switch (this) {
    onNet => 'MTN to MTN',
    offNet => 'Other network',
  };

  static ExpenseMobileMoneyNetwork fromApi(String value) {
    return switch (value) {
      'ON_NET' => ExpenseMobileMoneyNetwork.onNet,
      'OFF_NET' => ExpenseMobileMoneyNetwork.offNet,
      _ => throw StateError('Unsupported mobile money network: $value'),
    };
  }
}

enum ExpenseCategory {
  foodDining,
  transport,
  housing,
  loan,
  utilities,
  healthcare,
  education,
  entertainment,
  shopping,
  personalCare,
  travel,
  savings,
  other;

  String get apiValue => switch (this) {
    ExpenseCategory.foodDining => 'FOOD_DINING',
    ExpenseCategory.transport => 'TRANSPORT',
    ExpenseCategory.housing => 'HOUSING',
    ExpenseCategory.loan => 'LOAN',
    ExpenseCategory.utilities => 'UTILITIES',
    ExpenseCategory.healthcare => 'HEALTHCARE',
    ExpenseCategory.education => 'EDUCATION',
    ExpenseCategory.entertainment => 'ENTERTAINMENT',
    ExpenseCategory.shopping => 'SHOPPING',
    ExpenseCategory.personalCare => 'PERSONAL_CARE',
    ExpenseCategory.travel => 'TRAVEL',
    ExpenseCategory.savings => 'SAVINGS',
    ExpenseCategory.other => 'OTHER',
  };

  String get displayName => switch (this) {
    ExpenseCategory.foodDining => 'Food and dining',
    ExpenseCategory.transport => 'Transport',
    ExpenseCategory.housing => 'Housing',
    ExpenseCategory.loan => 'Loan',
    ExpenseCategory.utilities => 'Utilities',
    ExpenseCategory.healthcare => 'Healthcare',
    ExpenseCategory.education => 'Education',
    ExpenseCategory.entertainment => 'Entertainment',
    ExpenseCategory.shopping => 'Shopping',
    ExpenseCategory.personalCare => 'Personal care',
    ExpenseCategory.travel => 'Travel',
    ExpenseCategory.savings => 'Savings',
    ExpenseCategory.other => 'Other',
  };

  static ExpenseCategory fromApi(String value) {
    return switch (value) {
      'FOOD_DINING' => ExpenseCategory.foodDining,
      'TRANSPORT' => ExpenseCategory.transport,
      'HOUSING' => ExpenseCategory.housing,
      'LOAN' => ExpenseCategory.loan,
      'UTILITIES' => ExpenseCategory.utilities,
      'HEALTHCARE' => ExpenseCategory.healthcare,
      'EDUCATION' => ExpenseCategory.education,
      'ENTERTAINMENT' => ExpenseCategory.entertainment,
      'SHOPPING' => ExpenseCategory.shopping,
      'PERSONAL_CARE' => ExpenseCategory.personalCare,
      'TRAVEL' => ExpenseCategory.travel,
      'SAVINGS' => ExpenseCategory.savings,
      'OTHER' => ExpenseCategory.other,
      _ => throw StateError('Unsupported expense category: $value'),
    };
  }
}
