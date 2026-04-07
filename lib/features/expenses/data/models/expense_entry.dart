import '../../../../core/models/created_by_summary.dart';

class ExpenseEntry {
  const ExpenseEntry({
    required this.id,
    required this.label,
    required this.amount,
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
  final ExpenseCategory category;
  final DateTime date;
  final String? note;
  final CreatedBySummary? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
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
