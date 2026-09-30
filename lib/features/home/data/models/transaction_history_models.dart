import 'received_transaction_models.dart';
import 'transaction_models.dart';

enum TransactionHistoryDirection {
  sent(apiValue: 'SENT', label: 'Sent'),
  received(apiValue: 'RECEIVED', label: 'Received');

  const TransactionHistoryDirection({
    required this.apiValue,
    required this.label,
  });

  final String apiValue;
  final String label;

  static TransactionHistoryDirection fromApiValue(String value) {
    return values.firstWhere(
      (item) => item.apiValue == value,
      orElse: () => throw FormatException(
        'Unsupported transaction history direction: $value',
      ),
    );
  }
}

class TransactionHistoryItem {
  const TransactionHistoryItem({
    required this.id,
    required this.direction,
    required this.reference,
    required this.status,
    required this.currency,
    required this.amount,
    required this.feeAmount,
    required this.totalAmount,
    required this.counterpartyIdentifier,
    required this.counterpartyName,
    required this.providerReference,
    required this.transferType,
    required this.category,
    required this.classification,
    required this.evidenceSource,
    required this.processedAt,
    required this.activityAt,
    required this.createdAt,
  });

  factory TransactionHistoryItem.fromJson(Map<String, dynamic> json) {
    final transferType = _optionalString(json, 'transferType');

    final category = _optionalString(json, 'category');

    final classification = _optionalString(json, 'classification');

    final evidenceSource = _optionalString(json, 'evidenceSource');

    return TransactionHistoryItem(
      id: _requiredString(json, 'id'),
      direction: TransactionHistoryDirection.fromApiValue(
        _requiredString(json, 'direction'),
      ),
      reference: _requiredString(json, 'reference'),
      status: TransactionStatus.fromApiValue(_requiredString(json, 'status')),
      currency: _requiredString(json, 'currency'),
      amount: _requiredInt(json, 'amount'),
      feeAmount: _optionalInt(json, 'feeAmount'),
      totalAmount: _optionalInt(json, 'totalAmount'),
      counterpartyIdentifier: _optionalString(json, 'counterpartyIdentifier'),
      counterpartyName: _optionalString(json, 'counterpartyName'),
      providerReference: _optionalString(json, 'providerReference'),
      transferType: transferType == null
          ? null
          : TransactionTransferType.fromApiValue(transferType),
      category: category == null
          ? null
          : TransactionCategory.fromApiValue(category),
      classification: classification == null
          ? null
          : ReceivedTransactionClassification.fromApiValue(classification),
      evidenceSource: evidenceSource == null
          ? null
          : ReceivedTransactionEvidenceSource.fromApiValue(evidenceSource),
      processedAt: _optionalDate(json, 'processedAt'),
      activityAt: _requiredDate(json, 'activityAt'),
      createdAt: _requiredDate(json, 'createdAt'),
    );
  }

  final String id;

  final TransactionHistoryDirection direction;

  final String reference;

  final TransactionStatus status;

  final String currency;

  final int amount;

  final int? feeAmount;
  final int? totalAmount;

  final String? counterpartyIdentifier;
  final String? counterpartyName;

  final String? providerReference;

  final TransactionTransferType? transferType;
  final TransactionCategory? category;

  final ReceivedTransactionClassification? classification;

  final ReceivedTransactionEvidenceSource? evidenceSource;

  final DateTime? processedAt;

  final DateTime activityAt;
  final DateTime createdAt;

  bool get isSent => direction == TransactionHistoryDirection.sent;

  bool get isReceived => direction == TransactionHistoryDirection.received;

  String get counterpartyDisplayName {
    final name = counterpartyName?.trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    final identifier = counterpartyIdentifier?.trim();

    if (identifier != null && identifier.isNotEmpty) {
      return identifier;
    }

    return isReceived ? 'Unknown sender' : 'Unknown recipient';
  }

  String get methodLabel {
    if (isReceived) {
      return 'MTN MoMo';
    }

    return transferType?.label ?? 'Transfer';
  }

  bool needsConfirmation({DateTime? now}) {
    if (!isSent) {
      return false;
    }

    if (status != TransactionStatus.pending &&
        status != TransactionStatus.processing) {
      return false;
    }

    final anchor = processedAt ?? createdAt;

    final current = now ?? DateTime.now();

    if (current.isBefore(anchor)) {
      return false;
    }

    return current.difference(anchor) >= const Duration(minutes: 10);
  }
}

class TransactionHistoryListResult {
  const TransactionHistoryListResult({
    required this.items,
    required this.pagination,
  });

  factory TransactionHistoryListResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];

    if (rawItems is! List) {
      throw const FormatException('Transaction history items are invalid.');
    }

    return TransactionHistoryListResult(
      items: rawItems
          .map(
            (item) => TransactionHistoryItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      pagination: TransactionPagination.fromJson(
        Map<String, dynamic>.from(json['pagination'] as Map),
      ),
    );
  }

  final List<TransactionHistoryItem> items;

  final TransactionPagination pagination;
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

  throw FormatException('Missing or invalid $key.');
}

int? _optionalInt(Map<String, dynamic> json, String key) {
  final value = json[key];

  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  throw FormatException('Invalid $key.');
}

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);

  final parsed = DateTime.tryParse(value);

  if (parsed == null) {
    throw FormatException('Invalid $key.');
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
    throw FormatException('Invalid $key.');
  }

  return parsed;
}
