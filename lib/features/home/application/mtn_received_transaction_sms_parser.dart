import '../data/models/provider_sms_message.dart';

class ParsedReceivedProviderSmsResult {
  const ParsedReceivedProviderSmsResult({
    required this.messageId,
    required this.amount,
    required this.providerReference,
    required this.occurredAt,
    required this.senderName,
    required this.senderIdentifier,
  });

  final String messageId;

  final int amount;

  final String providerReference;

  final DateTime occurredAt;

  final String? senderName;

  final String? senderIdentifier;
}

class ReceivedProviderSmsDeduplicationResult {
  const ReceivedProviderSmsDeduplicationResult({
    required this.results,
    required this.duplicateMessages,
    required this.conflictingResults,
  });

  final List<ParsedReceivedProviderSmsResult> results;

  final int duplicateMessages;

  final List<ParsedReceivedProviderSmsResult> conflictingResults;

  int get conflictingMessages => conflictingResults.length;
}

class MtnReceivedTransactionSmsParser {
  const MtnReceivedTransactionSmsParser();

  ParsedReceivedProviderSmsResult? parse(ProviderSmsMessage message) {
    final body = _normalizeBody(message.body);

    if (!_looksLikeMomoMessage(address: message.address, body: body)) {
      return null;
    }

    if (!_looksLikeIncomingPayment(body)) {
      return null;
    }

    final amount = _extractReceivedAmount(body);

    if (amount == null || amount <= 0) {
      return null;
    }

    final providerReference = _extractProviderReference(body);

    // Incoming payments are only recorded
    // automatically when we have a provider
    // reference suitable for deduplication.
    if (providerReference == null) {
      return null;
    }

    // Do not use SMS receipt time as the financial
    // occurrence time. Auto-import only when the
    // provider message contains its own timestamp.
    final occurredAt = _extractProviderOccurredAt(body);

    if (occurredAt == null) {
      return null;
    }

    final sender = _extractSender(body);

    if (sender == null || (sender.name == null && sender.identifier == null)) {
      return null;
    }

    return ParsedReceivedProviderSmsResult(
      messageId: message.id,
      amount: amount,
      providerReference: providerReference,
      occurredAt: occurredAt,
      senderName: sender.name,
      senderIdentifier: sender.identifier,
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

  bool _looksLikeIncomingPayment(String body) {
    return RegExp(
      r'\byou\s+(?:have\s+)?received\b',
      caseSensitive: false,
    ).hasMatch(body);
  }

  int? _extractReceivedAmount(String body) {
    final patterns = <RegExp>[
      RegExp(
        r'\breceived\s+'
        r'([0-9][0-9,\s]*?)'
        r'\s*RWF\b',
        caseSensitive: false,
      ),
      RegExp(
        r'\breceived\s+'
        r'RWF\s*'
        r'([0-9][0-9,]*)\b',
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
    final pattern = RegExp(
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
    );

    final match = pattern.firstMatch(body);

    final raw = match?.group(1);

    if (raw == null) {
      return null;
    }

    final value = raw.replaceFirst(RegExp(r'[.,;:]+$'), '').trim();

    return value.length >= 3 ? value : null;
  }

  _SmsSender? _extractSender(String body) {
    final namedMatch = RegExp(
      r'\bfrom\s+'
      r'(.{1,120}?)'
      r'\s*\('
      r'([^)]{3,50})'
      r'\)',
      caseSensitive: false,
    ).firstMatch(body);

    if (namedMatch != null) {
      final name = _normalizeName(namedMatch.group(1));

      final identifier = _normalizeSenderIdentifier(namedMatch.group(2));

      if (name != null || identifier != null) {
        return _SmsSender(name: name, identifier: identifier);
      }
    }

    final phoneMatch = RegExp(
      r'\bfrom\s+'
      r'(\+?2507\d{8}'
      r'|07\d{8}'
      r'|7\d{8})\b',
      caseSensitive: false,
    ).firstMatch(body);

    final phone = phoneMatch?.group(1);

    if (phone != null) {
      return _SmsSender(
        name: null,
        identifier: _normalizeSenderIdentifier(phone),
      );
    }

    final nameOnlyMatch = RegExp(
      r'\bfrom\s+'
      r'(.{2,120}?)'
      r'\s+(?:on|into)\s+your\s+'
      r'(?:mobile\s+money|momo)\s+account\b',
      caseSensitive: false,
    ).firstMatch(body);

    final name = _normalizeName(nameOnlyMatch?.group(1));

    if (name != null) {
      return _SmsSender(name: name, identifier: null);
    }

    return null;
  }

  String? _normalizeSenderIdentifier(String? value) {
    if (value == null || value.contains('*')) {
      return null;
    }

    final compact = value.replaceAll(RegExp(r'[\s()+-]'), '');

    if (!RegExp(r'^\d{3,34}$').hasMatch(compact)) {
      return null;
    }

    return compact;
  }

  String? _normalizeName(String? value) {
    if (value == null) {
      return null;
    }

    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();

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
}

class _SmsSender {
  const _SmsSender({required this.name, required this.identifier});

  final String? name;

  final String? identifier;
}

ReceivedProviderSmsDeduplicationResult
deduplicateParsedReceivedProviderSmsResults(
  List<ParsedReceivedProviderSmsResult> results,
) {
  if (results.isEmpty) {
    return const ReceivedProviderSmsDeduplicationResult(
      results: [],
      duplicateMessages: 0,
      conflictingResults: [],
    );
  }

  final groups = <String, List<ParsedReceivedProviderSmsResult>>{};

  for (final result in results) {
    final key = result.providerReference.trim().toLowerCase();

    groups.putIfAbsent(key, () => []);

    groups[key]!.add(result);
  }

  final unique = <ParsedReceivedProviderSmsResult>[];

  final conflicting = <ParsedReceivedProviderSmsResult>[];

  var duplicateMessages = 0;

  for (final group in groups.values) {
    if (group.length == 1) {
      unique.add(group.single);

      continue;
    }

    final first = group.first;

    final equivalent = group
        .skip(1)
        .every((result) => _sameReceivedEvidence(first, result));

    if (!equivalent) {
      conflicting.addAll(group);

      continue;
    }

    final ordered = <ParsedReceivedProviderSmsResult>[...group]
      ..sort((left, right) => left.occurredAt.compareTo(right.occurredAt));

    unique.add(ordered.first);

    duplicateMessages += group.length - 1;
  }

  unique.sort((left, right) => left.occurredAt.compareTo(right.occurredAt));

  conflicting.sort(
    (left, right) => left.occurredAt.compareTo(right.occurredAt),
  );

  return ReceivedProviderSmsDeduplicationResult(
    results: unique,
    duplicateMessages: duplicateMessages,
    conflictingResults: conflicting,
  );
}

bool _sameReceivedEvidence(
  ParsedReceivedProviderSmsResult left,
  ParsedReceivedProviderSmsResult right,
) {
  if (left.amount != right.amount || left.occurredAt != right.occurredAt) {
    return false;
  }

  final leftIdentifier = _comparableIdentifier(left.senderIdentifier);

  final rightIdentifier = _comparableIdentifier(right.senderIdentifier);

  if (leftIdentifier != null || rightIdentifier != null) {
    return leftIdentifier == rightIdentifier;
  }

  return _comparableName(left.senderName) == _comparableName(right.senderName);
}

String? _comparableIdentifier(String? value) {
  if (value == null) {
    return null;
  }

  final digits = value.replaceAll(RegExp(r'\D'), '');

  return digits.isEmpty ? null : digits;
}

String? _comparableName(String? value) {
  if (value == null) {
    return null;
  }

  final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();

  return normalized.isEmpty ? null : normalized;
}
