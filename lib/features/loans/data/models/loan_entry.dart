import '../../../../core/models/created_by_summary.dart';
import '../../../expenses/data/models/expense_entry.dart';

class LoanEntry {
  const LoanEntry({
    required this.id,
    required this.label,
    required this.amount,
    required this.date,
    required this.paid,
    required this.note,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LoanEntry.fromJson(Map<String, dynamic> json) {
    return LoanEntry(
      id: json['id'] as String,
      label: json['label'] as String,
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String).toLocal(),
      paid: json['paid'] as bool? ?? false,
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
  final DateTime date;
  final bool paid;
  final String? note;
  final CreatedBySummary? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class LoanSettlementResponse {
  const LoanSettlementResponse({required this.loan, required this.expense});

  factory LoanSettlementResponse.fromJson(Map<String, dynamic> json) {
    return LoanSettlementResponse(
      loan: LoanEntry.fromJson(json['loan'] as Map<String, dynamic>),
      expense: ExpenseEntry.fromJson(json['expense'] as Map<String, dynamic>),
    );
  }

  final LoanEntry loan;
  final ExpenseEntry expense;
}
