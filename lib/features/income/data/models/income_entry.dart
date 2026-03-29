class IncomeEntry {
  const IncomeEntry({
    required this.id,
    required this.label,
    required this.amount,
    required this.category,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
  });

  factory IncomeEntry.fromJson(Map<String, dynamic> json) {
    return IncomeEntry(
      id: json['id'] as String,
      label: json['label'] as String,
      amount: (json['amount'] as num).toDouble(),
      category: IncomeCategory.fromApi(json['category'] as String),
      date: DateTime.parse(json['date'] as String).toLocal(),
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
    );
  }

  final String id;
  final String label;
  final double amount;
  final IncomeCategory category;
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;
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
