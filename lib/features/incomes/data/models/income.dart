enum IncomeCategory {
  salary('SALARY', 'Salary'),
  freelance('FREELANCE', 'Freelance'),
  dividends('DIVIDENDS', 'Dividends'),
  rental('RENTAL', 'Rental'),
  sideHustle('SIDE_HUSTLE', 'Side hustle'),
  loanRecovery('LOAN_RECOVERY', 'Loan recovery'),
  other('OTHER', 'Other');

  const IncomeCategory(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

class IncomeRecord {
  IncomeRecord.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      label = json['label'] as String,
      amount = readIncomeAmount(json['amount']),
      category = IncomeCategory.values.firstWhere(
        (item) => item.apiValue == json['category'],
      ),
      status = json['status'] as String,
      date = DateTime.parse(json['date'] as String).toLocal(),
      expectedAt = json['expectedAt'] == null
          ? null
          : DateTime.parse(json['expectedAt'] as String).toLocal(),
      receivedTransactionId = json['receivedTransactionId'] as String?,
      paymentReference = json['paymentReference'] as String? {
    if (!const ['EXPECTED', 'RECEIVED', 'REVERSED'].contains(status)) {
      throw const FormatException('Invalid income status.');
    }
  }

  final String id;
  final String label;
  final String amount;
  final IncomeCategory category;
  final String status;
  final DateTime date;
  final DateTime? expectedAt;
  final String? receivedTransactionId;
  final String? paymentReference;
  bool get isExpected => status == 'EXPECTED';
}

class IncomePageResult {
  IncomePageResult.fromJson(Map<String, dynamic> json)
    : items = (json['items'] as List)
          .map(
            (item) =>
                IncomeRecord.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      hasNextPage = (json['pagination'] as Map)['hasNextPage'] as bool,
      expectedAmount = readIncomeAmount(
        (json['summary'] as Map)['expectedAmount'],
      ),
      receivedAmount = readIncomeAmount(
        (json['summary'] as Map)['receivedAmount'],
      );
  final List<IncomeRecord> items;
  final bool hasNextPage;
  final String expectedAmount;
  final String receivedAmount;
}

String readIncomeAmount(Object? value) {
  if (value is! String || !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value)) {
    throw const FormatException('Invalid income amount.');
  }
  return value;
}

String formatIncomeAmount(String amount) {
  final parts = amount.split('.');
  final whole = parts.first.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
  return parts.length == 1 || int.parse(parts[1]) == 0
      ? whole
      : '$whole.${parts[1]}';
}
