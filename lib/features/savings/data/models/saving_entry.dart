import '../../../../core/models/created_by_summary.dart';

class SavingEntry {
  const SavingEntry({
    required this.id,
    required this.label,
    required this.amount,
    required this.currency,
    required this.amountRwf,
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
