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
    final body = _normalizeBody(message.body);

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

    // Completion requires a provider-issued
    // transaction reference. We never infer success
    // from wording alone.
    if (status == TransactionStatus.completed && providerReference == null) {
      return null;
    }

    final recipient = _extractRecipient(body);

    final failure = _failureInformation(body, status);

    final occurredAt = _extractProviderOccurredAt(body) ?? message.receivedAt;

    return ParsedProviderSmsResult(
      messageId: message.id,
      status: status,
      amount: amount,
      occurredAt: occurredAt,
      providerReference: providerReference,
      receiverName: recipient?.name,
      receiverIdentifier: recipient?.identifier,
      failureCode: failure.$1,
      failureReason: failure.$2,
    );
  }

  String _normalizeBody(String body) {
    return body.replaceAll(RegExp(r'\s+'), ' ').trim();
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
        text.contains('was not completed') ||
        text.contains('insufficient balance') ||
        text.contains('insufficient funds') ||
        text.contains('declined') ||
        text.contains('rejected')) {
      return TransactionStatus.failed;
    }

    final successfulOutgoing = RegExp(
      r'\byou\s+have\s+'
      r'(?:successfully\s+)?'
      r'(?:transferred|sent|paid)\b',
      caseSensitive: false,
    ).hasMatch(body);

    if (successfulOutgoing) {
      return TransactionStatus.completed;
    }

    final explicitSuccess = RegExp(
      r'\b(?:transaction|transfer|payment)\b'
      r'.{0,100}'
      r'\b(?:successful|successfully completed)\b',
      caseSensitive: false,
    ).hasMatch(body);

    if (explicitSuccess) {
      return TransactionStatus.completed;
    }

    return null;
  }

  int? _extractAmount(String body) {
    final patterns = <RegExp>[
      RegExp(
        r'(?:transferred|sent|paid)\s+'
        r'([0-9][0-9,\s]*?)\s*RWF\b',
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
        r'([0-9][0-9,\s]*?)\s*RWF\b',
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

      final normalized = captured.replaceAll(RegExp(r'[,\s]'), '');

      final amount = int.tryParse(normalized);

      if (amount != null) {
        return amount;
      }
    }

    return null;
  }

  String? _extractProviderReference(String body) {
    final patterns = <RegExp>[
      RegExp(
        r'(?:financial\s+transaction\s+'
        r'(?:id|reference)'
        r'|transaction\s+'
        r'(?:id|reference)'
        r'|txn\s*(?:id|reference)?)'
        r'\s*(?::|#|-)?\s*'
        r'(?:is\s+)?'
        r'([A-Za-z0-9]'
        r'[A-Za-z0-9._/-]{2,127})',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(body);

      final raw = match?.group(1);

      if (raw == null) {
        continue;
      }

      final value = raw.replaceFirst(RegExp(r'[.,;:]+$'), '').trim();

      if (value.length >= 3) {
        return value;
      }
    }

    return null;
  }

  _SmsRecipient? _extractRecipient(String body) {
    final namedMatch = RegExp(
      r'\bto\s+'
      r'(.{1,120}?)'
      r'\s*\('
      r'([^)]{3,50})'
      r'\)',
      caseSensitive: false,
    ).firstMatch(body);

    if (namedMatch != null) {
      final rawIdentifier = namedMatch.group(2);

      if (rawIdentifier != null) {
        final identifier = _normalizeRecipientIdentifier(rawIdentifier);

        if (identifier != null) {
          return _SmsRecipient(
            identifier: identifier,
            name: _normalizeName(namedMatch.group(1)),
          );
        }
      }
    }

    final phoneMatch = RegExp(
      r'\bto\s+'
      r'(\+?2507\d{8}'
      r'|07\d{8}'
      r'|7\d{8})\b',
      caseSensitive: false,
    ).firstMatch(body);

    final phone = phoneMatch?.group(1);

    if (phone == null) {
      return null;
    }

    return _SmsRecipient(
      identifier: phone.replaceAll(RegExp(r'\D'), ''),
      name: null,
    );
  }

  String? _normalizeRecipientIdentifier(String value) {
    // Masked recipient values must never be
    // used for automatic reconciliation.
    if (value.contains('*')) {
      return null;
    }

    final compact = value.replaceAll(RegExp(r'[\s()+-]'), '');

    if (!RegExp(r'^\d{3,34}$').hasMatch(compact)) {
      return null;
    }

    return compact;
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

  DateTime? _extractProviderOccurredAt(String body) {
    final match = RegExp(
      r'\bat\s+'
      r'(20\d{2})-(\d{2})-(\d{2})'
      r'\s+'
      r'(\d{2}):(\d{2}):(\d{2})\b',
      caseSensitive: false,
    ).firstMatch(body);

    if (match == null) {
      return null;
    }

    final year = int.tryParse(match.group(1) ?? '');

    final month = int.tryParse(match.group(2) ?? '');

    final day = int.tryParse(match.group(3) ?? '');

    final hour = int.tryParse(match.group(4) ?? '');

    final minute = int.tryParse(match.group(5) ?? '');

    final second = int.tryParse(match.group(6) ?? '');

    if (year == null ||
        month == null ||
        day == null ||
        hour == null ||
        minute == null ||
        second == null) {
      return null;
    }

    final parsed = DateTime(year, month, day, hour, minute, second);

    // DateTime normalizes invalid values, so
    // explicitly ensure the SMS contained a
    // valid timestamp.
    if (parsed.year != year ||
        parsed.month != month ||
        parsed.day != day ||
        parsed.hour != hour ||
        parsed.minute != minute ||
        parsed.second != second) {
      return null;
    }

    return parsed;
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

    if (text.contains('declined')) {
      return ('PROVIDER_DECLINED', 'The provider declined the transaction.');
    }

    if (text.contains('rejected')) {
      return ('PROVIDER_REJECTED', 'The provider rejected the transaction.');
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
