enum TransactionTransferType {
  momoToMomo(apiValue: 'MOMO_TO_MOMO', label: 'MTN MoMo'),
  momoToEkash(apiValue: 'MOMO_TO_EKASH', label: 'eKash'),
  momoPay(apiValue: 'MOMO_PAY', label: 'MoMo Pay');

  const TransactionTransferType({required this.apiValue, required this.label});

  final String apiValue;
  final String label;

  static TransactionTransferType fromApiValue(String value) {
    return values.firstWhere(
      (item) => item.apiValue == value,
      orElse: () => throw FormatException(
        'Unsupported transaction transfer type: $value',
      ),
    );
  }
}

enum TransactionRecipientType {
  phone('PHONE'),
  bankAccount('BANK_ACCOUNT'),
  momoCode('MOMO_CODE');

  const TransactionRecipientType(this.apiValue);

  final String apiValue;

  static TransactionRecipientType fromApiValue(String value) {
    return values.firstWhere(
      (item) => item.apiValue == value,
      orElse: () => throw FormatException(
        'Unsupported transaction recipient type: $value',
      ),
    );
  }
}

enum TransactionCategory {
  transport('TRANSPORT', 'Transport'),
  groceries('GROCERIES', 'Groceries'),
  bills('BILLS', 'Bills'),
  rent('RENT', 'Rent'),
  healthcare('HEALTHCARE', 'Healthcare'),
  education('EDUCATION', 'Education'),
  foodDining('FOOD_DINING', 'Food & dining'),
  shopping('SHOPPING', 'Shopping'),
  family('FAMILY', 'Family'),
  entertainment('ENTERTAINMENT', 'Entertainment'),
  other('OTHER', 'Other');

  const TransactionCategory(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static TransactionCategory fromApiValue(String value) {
    return values.firstWhere(
      (item) => item.apiValue == value,
      orElse: () =>
          throw FormatException('Unsupported transaction category: $value'),
    );
  }

  static TransactionCategory fromLabel(String label) {
    return switch (label.trim().toLowerCase()) {
      'transport' => TransactionCategory.transport,
      'groceries' => TransactionCategory.groceries,
      'bills' => TransactionCategory.bills,
      'rent' => TransactionCategory.rent,
      'health' || 'healthcare' => TransactionCategory.healthcare,
      'education' => TransactionCategory.education,
      'dining' || 'food & dining' => TransactionCategory.foodDining,
      'shopping' => TransactionCategory.shopping,
      'family' => TransactionCategory.family,
      'entertainment' => TransactionCategory.entertainment,
      _ => TransactionCategory.other,
    };
  }
}

enum TransactionStatus {
  pending('PENDING', 'Pending'),
  processing('PROCESSING', 'Processing'),
  completed('COMPLETED', 'Completed'),
  failed('FAILED', 'Failed'),
  cancelled('CANCELLED', 'Cancelled'),
  reversed('REVERSED', 'Reversed');

  const TransactionStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static TransactionStatus fromApiValue(String value) {
    return values.firstWhere(
      (item) => item.apiValue == value,
      orElse: () =>
          throw FormatException('Unsupported transaction status: $value'),
    );
  }
}

enum TransactionEventType {
  created('CREATED', 'Transaction created'),
  ussdOpened('USSD_OPENED', 'MTN prompt opened'),
  providerResultReceived(
    'PROVIDER_RESULT_RECEIVED',
    'Provider result received',
  ),
  statusChanged('STATUS_CHANGED', 'Status changed');

  const TransactionEventType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static TransactionEventType fromApiValue(String value) {
    return values.firstWhere(
      (item) => item.apiValue == value,
      orElse: () =>
          throw FormatException('Unsupported transaction event type: $value'),
    );
  }
}

enum TransactionEventSource {
  system('SYSTEM', 'Budgetify'),
  mobileApp('MOBILE_APP', 'Mobile app'),
  providerSms('PROVIDER_SMS', 'Provider SMS'),
  providerApi('PROVIDER_API', 'Provider API');

  const TransactionEventSource(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static TransactionEventSource fromApiValue(String value) {
    return values.firstWhere(
      (item) => item.apiValue == value,
      orElse: () =>
          throw FormatException('Unsupported transaction event source: $value'),
    );
  }
}

TransactionRecipientType inferTransactionRecipientType(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');

  final isPhone =
      RegExp(r'^07\d{8}$').hasMatch(digits) ||
      RegExp(r'^2507\d{8}$').hasMatch(digits) ||
      RegExp(r'^7\d{8}$').hasMatch(digits);

  if (isPhone) {
    return TransactionRecipientType.phone;
  }

  if (RegExp(r'^\d{3,9}$').hasMatch(digits)) {
    return TransactionRecipientType.momoCode;
  }

  return TransactionRecipientType.bankAccount;
}

bool isValidTransactionRecipient(String value, TransactionRecipientType type) {
  final digits = value.replaceAll(RegExp(r'\D'), '');

  if (type == TransactionRecipientType.phone) {
    return RegExp(r'^07\d{8}$').hasMatch(digits) ||
        RegExp(r'^2507\d{8}$').hasMatch(digits) ||
        RegExp(r'^7\d{8}$').hasMatch(digits);
  }

  if (type == TransactionRecipientType.momoCode) {
    return RegExp(r'^\d{3,12}$').hasMatch(digits);
  }

  return RegExp(r'^\d{6,34}$').hasMatch(digits);
}

TransactionTransferType inferTransactionTransferType({
  required String recipientIdentifier,
  required TransactionRecipientType recipientType,
}) {
  if (recipientType == TransactionRecipientType.momoCode) {
    return TransactionTransferType.momoPay;
  }

  if (recipientType == TransactionRecipientType.bankAccount) {
    return TransactionTransferType.momoToEkash;
  }

  final digits = recipientIdentifier.replaceAll(RegExp(r'\D'), '');

  final localNumber = digits.startsWith('250')
      ? '0${digits.substring(3)}'
      : digits.startsWith('7')
      ? '0$digits'
      : digits;

  final isMtnNumber =
      localNumber.startsWith('078') || localNumber.startsWith('079');

  return isMtnNumber
      ? TransactionTransferType.momoToMomo
      : TransactionTransferType.momoToEkash;
}

class TransactionQuote {
  const TransactionQuote({
    required this.transferType,
    required this.currency,
    required this.amount,
    required this.feeAmount,
    required this.totalAmount,
    required this.tariffVersion,
    required this.tariffSource,
  });

  factory TransactionQuote.fromJson(Map<String, dynamic> json) {
    return TransactionQuote(
      transferType: TransactionTransferType.fromApiValue(
        _requiredString(json, 'transferType'),
      ),
      currency: _requiredString(json, 'currency'),
      amount: _requiredInt(json, 'amount'),
      feeAmount: _requiredInt(json, 'feeAmount'),
      totalAmount: _requiredInt(json, 'totalAmount'),
      tariffVersion: _requiredString(json, 'tariffVersion'),
      tariffSource: _requiredString(json, 'tariffSource'),
    );
  }

  final TransactionTransferType transferType;
  final String currency;
  final int amount;
  final int feeAmount;
  final int totalAmount;
  final String tariffVersion;
  final String tariffSource;
}

class PaymentTransaction {
  const PaymentTransaction({
    required this.id,
    required this.reference,
    required this.transferType,
    required this.status,
    required this.category,
    required this.currency,
    required this.amount,
    required this.feeAmount,
    required this.totalAmount,
    required this.recipientType,
    required this.receiverIdentifier,
    required this.receiverName,
    required this.note,
    required this.tariffVersion,
    required this.tariffSource,
    required this.providerReference,
    required this.failureCode,
    required this.failureReason,
    required this.processedAt,
    required this.completedAt,
    required this.failedAt,
    required this.cancelledAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) {
    return PaymentTransaction(
      id: _requiredString(json, 'id'),
      reference: _requiredString(json, 'reference'),
      transferType: TransactionTransferType.fromApiValue(
        _requiredString(json, 'transferType'),
      ),
      status: TransactionStatus.fromApiValue(_requiredString(json, 'status')),
      category: TransactionCategory.fromApiValue(
        _requiredString(json, 'category'),
      ),
      currency: _requiredString(json, 'currency'),
      amount: _requiredInt(json, 'amount'),
      feeAmount: _requiredInt(json, 'feeAmount'),
      totalAmount: _requiredInt(json, 'totalAmount'),
      recipientType: TransactionRecipientType.fromApiValue(
        _requiredString(json, 'recipientType'),
      ),
      receiverIdentifier: _requiredString(json, 'receiverIdentifier'),
      receiverName: _optionalString(json, 'receiverName'),
      note: _optionalString(json, 'note'),
      tariffVersion: _requiredString(json, 'tariffVersion'),
      tariffSource: _requiredString(json, 'tariffSource'),
      providerReference: _optionalString(json, 'providerReference'),
      failureCode: _optionalString(json, 'failureCode'),
      failureReason: _optionalString(json, 'failureReason'),
      processedAt: _optionalDate(json, 'processedAt'),
      completedAt: _optionalDate(json, 'completedAt'),
      failedAt: _optionalDate(json, 'failedAt'),
      cancelledAt: _optionalDate(json, 'cancelledAt'),
      createdAt: _requiredDate(json, 'createdAt'),
      updatedAt: _requiredDate(json, 'updatedAt'),
    );
  }

  final String id;
  final String reference;
  final TransactionTransferType transferType;
  final TransactionStatus status;
  final TransactionCategory category;
  final String currency;

  final int amount;
  final int feeAmount;
  final int totalAmount;

  final TransactionRecipientType recipientType;
  final String receiverIdentifier;
  final String? receiverName;
  final String? note;

  final String tariffVersion;
  final String tariffSource;

  final String? providerReference;
  final String? failureCode;
  final String? failureReason;

  final DateTime? processedAt;
  final DateTime? completedAt;
  final DateTime? failedAt;
  final DateTime? cancelledAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get recipientDisplayName {
    final name = receiverName?.trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    return receiverIdentifier;
  }
}

class TransactionEventRecord {
  const TransactionEventRecord({
    required this.id,
    required this.type,
    required this.source,
    required this.fromStatus,
    required this.toStatus,
    required this.providerReference,
    required this.failureCode,
    required this.failureReason,
    required this.occurredAt,
    required this.createdAt,
  });

  factory TransactionEventRecord.fromJson(Map<String, dynamic> json) {
    final fromStatusValue = _optionalString(json, 'fromStatus');

    final toStatusValue = _optionalString(json, 'toStatus');

    return TransactionEventRecord(
      id: _requiredString(json, 'id'),
      type: TransactionEventType.fromApiValue(_requiredString(json, 'type')),
      source: TransactionEventSource.fromApiValue(
        _requiredString(json, 'source'),
      ),
      fromStatus: fromStatusValue == null
          ? null
          : TransactionStatus.fromApiValue(fromStatusValue),
      toStatus: toStatusValue == null
          ? null
          : TransactionStatus.fromApiValue(toStatusValue),
      providerReference: _optionalString(json, 'providerReference'),
      failureCode: _optionalString(json, 'failureCode'),
      failureReason: _optionalString(json, 'failureReason'),
      occurredAt: _requiredDate(json, 'occurredAt'),
      createdAt: _requiredDate(json, 'createdAt'),
    );
  }

  final String id;
  final TransactionEventType type;
  final TransactionEventSource source;
  final TransactionStatus? fromStatus;
  final TransactionStatus? toStatus;
  final String? providerReference;
  final String? failureCode;
  final String? failureReason;
  final DateTime occurredAt;
  final DateTime createdAt;
}

class TransactionPagination {
  const TransactionPagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPreviousPage,
  });

  factory TransactionPagination.fromJson(Map<String, dynamic> json) {
    return TransactionPagination(
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

class TransactionListResult {
  const TransactionListResult({required this.items, required this.pagination});

  factory TransactionListResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];

    if (rawItems is! List) {
      throw const FormatException('Transaction history items are invalid.');
    }

    return TransactionListResult(
      items: rawItems
          .map(
            (item) =>
                PaymentTransaction.fromJson(_jsonMap(item, 'transaction')),
          )
          .toList(growable: false),
      pagination: TransactionPagination.fromJson(
        _jsonMap(json['pagination'], 'pagination'),
      ),
    );
  }

  final List<PaymentTransaction> items;
  final TransactionPagination pagination;
}

class TransactionDetail {
  const TransactionDetail({required this.transaction, required this.events});

  factory TransactionDetail.fromJson(Map<String, dynamic> json) {
    final rawEvents = json['events'];

    if (rawEvents is! List) {
      throw const FormatException('Transaction event timeline is invalid.');
    }

    return TransactionDetail(
      transaction: PaymentTransaction.fromJson(json),
      events: rawEvents
          .map(
            (item) => TransactionEventRecord.fromJson(
              _jsonMap(item, 'transaction event'),
            ),
          )
          .toList(growable: false),
    );
  }

  final PaymentTransaction transaction;
  final List<TransactionEventRecord> events;
}

Map<String, dynamic> _jsonMap(Object? value, String field) {
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

  if (value is String && value.isNotEmpty) {
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
