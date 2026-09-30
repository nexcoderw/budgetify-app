import '../data/models/provider_sms_message.dart';
import '../data/models/transaction_models.dart';

class ParsedProviderSmsResult {
  const ParsedProviderSmsResult({
    required this.messageId,
    required this.status,
    required this.amount,
    required this.occurredAt,
    this.providerReference,
    this.receiverName,
    this.receiverIdentifier,
    this.failureCode,
    this.failureReason,
  });

  final String messageId;
  final TransactionStatus status;
  final int amount;
  final DateTime occurredAt;

  final String? providerReference;
  final String? receiverName;
  final String? receiverIdentifier;

  final String? failureCode;
  final String? failureReason;
}

class MtnTransactionSmsParser {
  const MtnTransactionSmsParser();

  ParsedProviderSmsResult? parse(ProviderSmsMessage message) {
    final body = message.body.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (!_looksLikeMomoMessage(address: message.address, body: body)) {
      return null;
    }

    final status = _extractStatus(body);

    if (status == null) {
      return null;
    }

    final amount = _extractAmount(body);

    if (amount == null || amount <= 0) {
      return null;
    }

    final providerReference = _extractProviderReference(body);

    // Never mark a payment completed unless the
    // provider supplied a transaction reference.
    if (status == TransactionStatus.completed && providerReference == null) {
      return null;
    }

    final recipient = _extractRecipient(body);

    final failure = _failureInformation(body, status);

    return ParsedProviderSmsResult(
      messageId: message.id,
      status: status,
      amount: amount,
      occurredAt: message.receivedAt,
      providerReference: providerReference,
      receiverName: recipient?.name,
      receiverIdentifier: recipient?.identifier,
      failureCode: failure.$1,
      failureReason: failure.$2,
    );
  }

  bool _looksLikeMomoMessage({required String address, required String body}) {
    final sender = address.toLowerCase();

    final text = body.toLowerCase();

    if (!text.contains('rwf')) {
      return false;
    }

    final senderLooksRelevant =
        sender.contains('mtn') ||
        sender.contains('momo') ||
        sender.contains('m-money') ||
        sender.contains('mobilemoney');

    final bodyLooksRelevant =
        text.contains('mobile money') ||
        text.contains('momo') ||
        text.contains('financial transaction id');

    return senderLooksRelevant || bodyLooksRelevant;
  }

  TransactionStatus? _extractStatus(String body) {
    final text = body.toLowerCase();

    if (text.contains('cancelled') || text.contains('canceled')) {
      return TransactionStatus.cancelled;
    }

    if (text.contains('failed') ||
        text.contains('unsuccessful') ||
        text.contains('not successful') ||
        text.contains('could not be completed') ||
        text.contains('insufficient balance') ||
        text.contains('insufficient funds')) {
      return TransactionStatus.failed;
    }

    final successfulTransfer = RegExp(
      r'\b(?:you\s+have\s+)?'
      r'(?:transferred|sent|paid)\b',
      caseSensitive: false,
    ).hasMatch(body);

    if (successfulTransfer) {
      return TransactionStatus.completed;
    }

    return null;
  }

  int? _extractAmount(String body) {
    final patterns = <RegExp>[
      RegExp(
        r'(?:transferred|sent|paid)\s+'
        r'([0-9][0-9,]*)\s*RWF\b',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:transferred|sent|paid)\s+'
        r'RWF\s*([0-9][0-9,]*)\b',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:transaction|payment|transfer)\s+'
        r'(?:of\s+)?'
        r'([0-9][0-9,]*)\s*RWF\b',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:transaction|payment|transfer)\s+'
        r'(?:of\s+)?'
        r'RWF\s*([0-9][0-9,]*)\b',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(body);

      final captured = match?.group(1);

      if (captured == null) {
        continue;
      }

      final normalized = captured.replaceAll(',', '');

      final amount = int.tryParse(normalized);

      if (amount != null) {
        return amount;
      }
    }

    return null;
  }

  String? _extractProviderReference(String body) {
    final match = RegExp(
      r'(?:financial\s+transaction\s+id'
      r'|transaction\s+(?:id|reference)'
      r'|txn\s*(?:id|reference)?)'
      r'\s*(?::|#|-)?\s*'
      r'(?:is\s+)?'
      r'([A-Za-z0-9]'
      r'[A-Za-z0-9._/-]{2,127})',
      caseSensitive: false,
    ).firstMatch(body);

    final value = match?.group(1);

    if (value == null) {
      return null;
    }

    return value.replaceFirst(RegExp(r'[.,;:]+$'), '').trim();
  }

  _SmsRecipient? _extractRecipient(String body) {
    final namedMatch = RegExp(
      r'\bto\s+'
      r'(.{1,120}?)'
      r'\s*\('
      r'(\+?2507\d{8}'
      r'|07\d{8}'
      r'|7\d{8})'
      r'\)',
      caseSensitive: false,
    ).firstMatch(body);

    if (namedMatch != null) {
      final name = namedMatch.group(1)?.trim();

      final identifier = namedMatch.group(2);

      if (identifier != null) {
        return _SmsRecipient(
          identifier: identifier,
          name: _normalizeName(name),
        );
      }
    }

    final numberMatch = RegExp(
      r'\bto\s+'
      r'(\+?2507\d{8}'
      r'|07\d{8}'
      r'|7\d{8})\b',
      caseSensitive: false,
    ).firstMatch(body);

    final identifier = numberMatch?.group(1);

    if (identifier == null) {
      return null;
    }

    return _SmsRecipient(identifier: identifier, name: null);
  }

  String? _normalizeName(String? name) {
    if (name == null) {
      return null;
    }

    final normalized = name.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (normalized.isEmpty) {
      return null;
    }

    if (normalized.length > 120) {
      return normalized.substring(0, 120);
    }

    return normalized;
  }

  (String?, String?) _failureInformation(
    String body,
    TransactionStatus status,
  ) {
    if (status == TransactionStatus.completed) {
      return (null, null);
    }

    final text = body.toLowerCase();

    if (text.contains('insufficient balance') ||
        text.contains('insufficient funds')) {
      return (
        'INSUFFICIENT_FUNDS',
        'The provider reported insufficient funds.',
      );
    }

    if (status == TransactionStatus.cancelled) {
      return (
        'PROVIDER_CANCELLED',
        'The provider reported that the transaction was cancelled.',
      );
    }

    return (
      'PROVIDER_FAILED',
      'The provider reported that the transaction failed.',
    );
  }
}

class _SmsRecipient {
  const _SmsRecipient({required this.identifier, required this.name});

  final String identifier;
  final String? name;
}
