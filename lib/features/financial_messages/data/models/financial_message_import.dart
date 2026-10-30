enum FinancialMessageImportStatus {
  pending('PENDING', 'Pending'),
  confirmed('CONFIRMED', 'Recorded'),
  dismissed('DISMISSED', 'Dismissed'),
  expired('EXPIRED', 'Expired');

  const FinancialMessageImportStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static FinancialMessageImportStatus fromApiValue(String value) {
    return values.firstWhere(
      (item) => item.apiValue == value,
      orElse: () => throw FormatException(
        'Unsupported financial message import status: $value',
      ),
    );
  }
}

enum FinancialMessageParseStatus {
  unparsed('UNPARSED'),
  parsed('PARSED'),
  needsDetails('NEEDS_DETAILS'),
  rejected('REJECTED');

  const FinancialMessageParseStatus(this.apiValue);

  final String apiValue;

  static FinancialMessageParseStatus fromApiValue(String value) {
    return values.firstWhere(
      (item) => item.apiValue == value,
      orElse: () => throw FormatException(
        'Unsupported financial message parse status: $value',
      ),
    );
  }
}

enum FinancialMessageDuplicateStatus {
  notChecked('NOT_CHECKED'),
  clear('CLEAR'),
  possibleDuplicate('POSSIBLE_DUPLICATE'),
  confirmedDuplicate('CONFIRMED_DUPLICATE');

  const FinancialMessageDuplicateStatus(this.apiValue);

  final String apiValue;

  static FinancialMessageDuplicateStatus fromApiValue(String value) {
    return values.firstWhere(
      (item) => item.apiValue == value,
      orElse: () => throw FormatException(
        'Unsupported financial message duplicate status: $value',
      ),
    );
  }
}

class FinancialMessageImport {
  const FinancialMessageImport({
    required this.id,
    required this.sourceHint,
    required this.providerCode,
    required this.status,
    required this.parseStatus,
    required this.duplicateStatus,
    required this.amount,
    required this.fee,
    required this.messageReceivedAt,
    required this.occurredAt,
    required this.senderName,
    required this.senderIdentifier,
    required this.accountLastFour,
    required this.providerReference,
    required this.rawMessage,
    required this.receivedTransactionId,
    required this.incomeId,
    required this.createdAt,
  });

  factory FinancialMessageImport.fromJson(Map<String, dynamic> json) {
    return FinancialMessageImport(
      id: _requiredString(json, 'id'),
      sourceHint: _requiredString(json, 'sourceHint'),
      providerCode: _optionalString(json, 'providerCode'),
      status: FinancialMessageImportStatus.fromApiValue(
        _requiredString(json, 'status'),
      ),
      parseStatus: FinancialMessageParseStatus.fromApiValue(
        _requiredString(json, 'parseStatus'),
      ),
      duplicateStatus: FinancialMessageDuplicateStatus.fromApiValue(
        _requiredString(json, 'duplicateStatus'),
      ),
      amount: _optionalMoney(json, 'amount'),
      fee: _optionalMoney(json, 'fee'),
      messageReceivedAt: _requiredDate(json, 'messageReceivedAt'),
      occurredAt: _optionalDate(json, 'occurredAt'),
      senderName: _optionalString(json, 'senderName'),
      senderIdentifier: _optionalString(json, 'senderIdentifier'),
      accountLastFour: _optionalString(json, 'accountLastFour'),
      providerReference: _optionalString(json, 'providerReference'),
      rawMessage: _optionalString(json, 'rawMessage'),
      receivedTransactionId: _optionalString(
        json,
        'confirmedReceivedTransactionId',
      ),
      incomeId: _optionalString(json, 'confirmedIncomeId'),
      createdAt: _requiredDate(json, 'createdAt'),
    );
  }

  final String id;
  final String sourceHint;
  final String? providerCode;
  final FinancialMessageImportStatus status;
  final FinancialMessageParseStatus parseStatus;
  final FinancialMessageDuplicateStatus duplicateStatus;
  final String? amount;
  final String? fee;
  final DateTime messageReceivedAt;
  final DateTime? occurredAt;
  final String? senderName;
  final String? senderIdentifier;
  final String? accountLastFour;
  final String? providerReference;
  final String? rawMessage;
  final String? receivedTransactionId;
  final String? incomeId;
  final DateTime createdAt;

  String get senderLabel {
    final name = senderName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    final identifier = senderIdentifier?.trim();
    if (identifier != null && identifier.isNotEmpty) {
      return identifier;
    }
    return 'Sender needs review';
  }

  String get sourceLabel {
    return switch (providerCode ?? sourceHint) {
      'MTN_MOMO_RW' || 'MTN_MOMO' => 'MTN MoMo',
      'AIRTEL_MONEY_RW' || 'AIRTEL_MONEY' => 'Airtel Money',
      'BANK_OF_KIGALI_RW' || 'BANK_OF_KIGALI' => 'Bank of Kigali',
      'ACCESS_BANK_RW' || 'ACCESS_BANK_RWANDA' => 'Access Bank',
      'EQUITY_BANK_RW' || 'EQUITY_BANK_RWANDA' => 'Equity Bank',
      'I_AND_M_BANK_RW' => 'I&M Bank',
      'BPR_BANK_RW' => 'BPR Bank',
      'COGEBANQUE_RW' => 'Cogebanque',
      'ECOBANK_RW' => 'Ecobank',
      'GTBANK_RW' => 'GTBank',
      'NCBA_RW' => 'NCBA',
      'BANK_OF_AFRICA_RW' => 'Bank of Africa',
      _ => 'Payment message',
    };
  }

  bool get needsAttention {
    return parseStatus != FinancialMessageParseStatus.parsed ||
        duplicateStatus == FinancialMessageDuplicateStatus.possibleDuplicate ||
        duplicateStatus ==
            FinancialMessageDuplicateStatus.confirmedDuplicate;
  }
}

class FinancialMessageImportPage {
  const FinancialMessageImportPage({
    required this.items,
    required this.page,
    required this.total,
    required this.hasNextPage,
    required this.pendingCount,
  });

  factory FinancialMessageImportPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final pagination = _requiredMap(json['pagination'], 'pagination');
    if (rawItems is! List) {
      throw const FormatException('Imported message list is invalid.');
    }

    return FinancialMessageImportPage(
      items: rawItems
          .map(
            (item) => FinancialMessageImport.fromJson(
              _requiredMap(item, 'imported message'),
            ),
          )
          .toList(growable: false),
      page: _requiredInt(pagination, 'page'),
      total: _requiredInt(pagination, 'total'),
      hasNextPage: _requiredBool(pagination, 'hasNextPage'),
      pendingCount: _requiredInt(json, 'pendingCount'),
    );
  }

  final List<FinancialMessageImport> items;
  final int page;
  final int total;
  final bool hasNextPage;
  final int pendingCount;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing or invalid $key.');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('Invalid $key.');
  }
  return value;
}

String? _optionalMoney(Map<String, dynamic> json, String key) {
  final value = _optionalString(json, key);
  if (value == null) {
    return null;
  }
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value)) {
    throw FormatException('Invalid $key.');
  }
  return value;
}

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Invalid $key.');
  }
  return parsed.toLocal();
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
  return parsed.toLocal();
}

Map<String, dynamic> _requiredMap(Object? value, String label) {
  if (value is! Map) {
    throw FormatException('Invalid $label.');
  }
  return Map<String, dynamic>.from(value);
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('Invalid $key.');
  }
  return value;
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw FormatException('Invalid $key.');
  }
  return value;
}
