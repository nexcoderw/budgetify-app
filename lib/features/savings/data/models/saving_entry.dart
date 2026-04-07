import '../../../../core/models/created_by_summary.dart';

class SavingEntry {
  const SavingEntry({
    required this.id,
    required this.label,
    required this.amount,
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
  final DateTime date;
  final String? note;
  final bool stillHave;
  final CreatedBySummary? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
}
