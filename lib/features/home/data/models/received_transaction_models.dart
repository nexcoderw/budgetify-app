enum ReceivedTransactionStatus {
  completed(apiValue: 'COMPLETED', label: 'Completed'),
  reversed(apiValue: 'REVERSED', label: 'Reversed');

  const ReceivedTransactionStatus({
    required this.apiValue,
    required this.label,
  });

  final String apiValue;
  final String label;

  static ReceivedTransactionStatus fromApiValue(String value) {
    return values.firstWhere(
      (item) => item.apiValue == value,
      orElse: () => throw FormatException(
        'Unsupported received transaction status: $value',
      ),
    );
  }
}

enum ReceivedTransactionClassification {
  unclassified(apiValue: 'UNCLASSIFIED', label: 'Unclassified'),
  income(apiValue: 'INCOME', label: 'Income'),
  reimbursement(apiValue: 'REIMBURSEMENT', label: 'Reimbursement'),
  loanRepayment(apiValue: 'LOAN_REPAYMENT', label: 'Loan repayment'),
  ownTransfer(apiValue: 'OWN_TRANSFER', label: 'Own transfer'),
  other(apiValue: 'OTHER', label: 'Other');

  const ReceivedTransactionClassification({
    required this.apiValue,
    required this.label,
  });

  final String apiValue;
  final String label;

  static ReceivedTransactionClassification fromApiValue(String value) {
    return values.firstWhere(
      (item) => item.apiValue == value,
      orElse: () => throw FormatException(
        'Unsupported received transaction classification: $value',
      ),
    );
  }
}

enum ReceivedTransactionEvidenceSource {
  providerSms(apiValue: 'PROVIDER_SMS', label: 'Provider SMS'),
  providerApi(apiValue: 'PROVIDER_API', label: 'Provider API'),
  manual(apiValue: 'MANUAL', label: 'Manual');

  const ReceivedTransactionEvidenceSource({
    required this.apiValue,
    required this.label,
  });

  final String apiValue;
  final String label;

  static ReceivedTransactionEvidenceSource fromApiValue(String value) {
    return values.firstWhere(
      (item) => item.apiValue == value,
      orElse: () => throw FormatException(
        'Unsupported received transaction evidence source: $value',
      ),
    );
  }
}

class ReceivedTransaction {
  const ReceivedTransaction({
    required this.id,
    required this.reference,
    required this.status,
    required this.classification,
    required this.evidenceSource,
    required this.currency,
    required this.amount,
    required this.senderIdentifier,
    required this.senderName,
    required this.providerReference,
    required this.occurredAt,
    required this.reversedAt,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReceivedTransaction.fromJson(Map<String, dynamic> json) {
    return ReceivedTransaction(
      id: _requiredString(json, 'id'),
      reference: _requiredString(json, 'reference'),
      status: ReceivedTransactionStatus.fromApiValue(
        _requiredString(json, 'status'),
      ),
      classification: ReceivedTransactionClassification.fromApiValue(
        _requiredString(json, 'classification'),
      ),
      evidenceSource: ReceivedTransactionEvidenceSource.fromApiValue(
        _requiredString(json, 'evidenceSource'),
      ),
      currency: _requiredString(json, 'currency'),
      amount: _requiredInt(json, 'amount'),
      senderIdentifier: _optionalString(json, 'senderIdentifier'),
      senderName: _optionalString(json, 'senderName'),
      providerReference: _optionalString(json, 'providerReference'),
      occurredAt: _requiredDate(json, 'occurredAt'),
      reversedAt: _optionalDate(json, 'reversedAt'),
      note: _optionalString(json, 'note'),
      createdAt: _requiredDate(json, 'createdAt'),
      updatedAt: _requiredDate(json, 'updatedAt'),
    );
  }

  final String id;
  final String reference;

  final ReceivedTransactionStatus status;

  final ReceivedTransactionClassification classification;

  final ReceivedTransactionEvidenceSource evidenceSource;

  final String currency;

  final int amount;

  final String? senderIdentifier;
  final String? senderName;

  final String? providerReference;

  final DateTime occurredAt;
  final DateTime? reversedAt;

  final String? note;

  final DateTime createdAt;
  final DateTime updatedAt;

  String get senderDisplayName {
    final name = senderName?.trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    final identifier = senderIdentifier?.trim();

    if (identifier != null && identifier.isNotEmpty) {
      return identifier;
    }

    return 'Unknown sender';
  }
}

class ReceivedTransactionPagination {
  const ReceivedTransactionPagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPreviousPage,
  });

  factory ReceivedTransactionPagination.fromJson(Map<String, dynamic> json) {
    return ReceivedTransactionPagination(
      page: _requiredInt(json, 'page'),
      limit: _requiredInt(json, 'limit'),
      total: _requiredInt(json, 'total'),
      totalPages: _requiredInt(json, 'totalPages'),
      hasNextPage: _requiredBool(json, 'hasNextPage'),
      hasPreviousPage: _requiredBool(json, 'hasPreviousPage'),
    );
  }

  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPreviousPage;
}

class ReceivedTransactionListResult {
  const ReceivedTransactionListResult({
    required this.items,
    required this.pagination,
  });

  factory ReceivedTransactionListResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];

    if (rawItems is! List) {
      throw const FormatException(
        'Received transaction list items are invalid.',
      );
    }

    return ReceivedTransactionListResult(
      items: rawItems
          .map(
            (item) => ReceivedTransaction.fromJson(
              _requiredMap(item, 'received transaction'),
            ),
          )
          .toList(growable: false),
      pagination: ReceivedTransactionPagination.fromJson(
        _requiredMap(json['pagination'], 'pagination'),
      ),
    );
  }

  final List<ReceivedTransaction> items;

  final ReceivedTransactionPagination pagination;
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

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];

  if (value == null) {
    return null;
  }

  if (value is String) {
    return value;
  }

  throw FormatException('Invalid $key.');
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

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];

  if (value is bool) {
    return value;
  }

  throw FormatException('Missing or invalid $key.');
}

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);

  final parsed = DateTime.tryParse(value);

  if (parsed == null) {
    throw FormatException('Invalid $key date.');
  }

  return parsed;
}

DateTime? _optionalDate(Map<String, dynamic> json, String key) {
  final value = _optionalString(json, key);

  if (value == null) {
    return null;
  }

  final parsed = DateTime.tryParse(value);

  if (parsed == null) {
    throw FormatException('Invalid $key date.');
  }

  return parsed;
}
