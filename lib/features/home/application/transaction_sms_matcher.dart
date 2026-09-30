import '../data/models/transaction_models.dart';
import 'mtn_transaction_sms_parser.dart';

const transactionConfirmationGracePeriod = Duration(minutes: 10);

enum TransactionSmsMatchKind { matched, ambiguous, none }

class TransactionSmsMatchResult {
  const TransactionSmsMatchResult._({
    required this.kind,
    required this.transaction,
    required this.candidateCount,
  });

  const TransactionSmsMatchResult.matched(PaymentTransaction transaction)
    : this._(
        kind: TransactionSmsMatchKind.matched,
        transaction: transaction,
        candidateCount: 1,
      );

  const TransactionSmsMatchResult.ambiguous(int candidateCount)
    : this._(
        kind: TransactionSmsMatchKind.ambiguous,
        transaction: null,
        candidateCount: candidateCount,
      );

  const TransactionSmsMatchResult.none()
    : this._(
        kind: TransactionSmsMatchKind.none,
        transaction: null,
        candidateCount: 0,
      );

  final TransactionSmsMatchKind kind;
  final PaymentTransaction? transaction;
  final int candidateCount;
}

class ProviderSmsDeduplicationResult {
  const ProviderSmsDeduplicationResult({
    required this.results,
    required this.duplicateMessages,
    required this.conflictingResults,
  });

  final List<ParsedProviderSmsResult> results;
  final int duplicateMessages;
  final List<ParsedProviderSmsResult> conflictingResults;

  int get conflictingMessages => conflictingResults.length;
}

class TransactionSmsMatcher {
  const TransactionSmsMatcher({
    this.earlyTolerance = const Duration(minutes: 2),
    this.candidateWindow = const Duration(hours: 2),
  });

  final Duration earlyTolerance;
  final Duration candidateWindow;

  TransactionSmsMatchResult match(
    ParsedProviderSmsResult result,
    List<PaymentTransaction> transactions,
  ) {
    final openTransactions = transactions
        .where(isTransactionOpen)
        .toList(growable: false);

    if (openTransactions.isEmpty) {
      return const TransactionSmsMatchResult.none();
    }

    final providerReference = result.providerReference?.trim();

    if (providerReference != null && providerReference.isNotEmpty) {
      final referenceMatches = openTransactions
          .where((transaction) {
            final existing = transaction.providerReference;

            return existing != null &&
                existing.toLowerCase() == providerReference.toLowerCase();
          })
          .toList(growable: false);

      if (referenceMatches.length > 1) {
        return TransactionSmsMatchResult.ambiguous(referenceMatches.length);
      }

      if (referenceMatches.length == 1) {
        final transaction = referenceMatches.single;

        if (!_evidenceMatchesTransaction(result, transaction)) {
          return const TransactionSmsMatchResult.ambiguous(1);
        }

        return TransactionSmsMatchResult.matched(transaction);
      }
    }

    final amountAndTimeMatches = openTransactions
        .where((transaction) {
          if (transaction.amount != result.amount) {
            return false;
          }

          return _isInsideCandidateWindow(result, transaction);
        })
        .toList(growable: false);

    if (amountAndTimeMatches.isEmpty) {
      return const TransactionSmsMatchResult.none();
    }

    final smsRecipient = result.receiverIdentifier;

    if (smsRecipient != null) {
      final matchingRecipients = amountAndTimeMatches
          .where((transaction) => recipientMatches(transaction, smsRecipient))
          .toList(growable: false);

      if (matchingRecipients.isEmpty) {
        return const TransactionSmsMatchResult.none();
      }

      if (matchingRecipients.length > 1) {
        return TransactionSmsMatchResult.ambiguous(matchingRecipients.length);
      }

      return TransactionSmsMatchResult.matched(matchingRecipients.single);
    }

    if (amountAndTimeMatches.length > 1) {
      return TransactionSmsMatchResult.ambiguous(amountAndTimeMatches.length);
    }

    return TransactionSmsMatchResult.matched(amountAndTimeMatches.single);
  }

  bool recipientMatches(PaymentTransaction transaction, String smsRecipient) {
    final stored = transaction.receiverIdentifier.replaceAll(RegExp(r'\D'), '');

    final received = smsRecipient.replaceAll(RegExp(r'\D'), '');

    if (stored.isEmpty || received.isEmpty) {
      return false;
    }

    if (transaction.recipientType != TransactionRecipientType.phone) {
      // Bank accounts and merchant codes
      // must match exactly.
      return stored == received;
    }

    final normalizedStored = _normalizeRwandaPhone(stored);

    final normalizedReceived = _normalizeRwandaPhone(received);

    return normalizedStored != null && normalizedStored == normalizedReceived;
  }

  bool _evidenceMatchesTransaction(
    ParsedProviderSmsResult result,
    PaymentTransaction transaction,
  ) {
    if (transaction.amount != result.amount) {
      return false;
    }

    final smsRecipient = result.receiverIdentifier;

    if (smsRecipient != null && !recipientMatches(transaction, smsRecipient)) {
      return false;
    }

    return true;
  }

  bool _isInsideCandidateWindow(
    ParsedProviderSmsResult result,
    PaymentTransaction transaction,
  ) {
    final anchor = transaction.processedAt ?? transaction.createdAt;

    final earliest = anchor.subtract(earlyTolerance);

    final latest = anchor.add(candidateWindow);

    return !result.occurredAt.isBefore(earliest) &&
        !result.occurredAt.isAfter(latest);
  }

  String? _normalizeRwandaPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');

    if (RegExp(r'^2507\d{8}$').hasMatch(digits)) {
      return digits.substring(3);
    }

    if (RegExp(r'^07\d{8}$').hasMatch(digits)) {
      return digits.substring(1);
    }

    if (RegExp(r'^7\d{8}$').hasMatch(digits)) {
      return digits;
    }

    return null;
  }
}

bool isTransactionOpen(PaymentTransaction transaction) {
  return transaction.status == TransactionStatus.pending ||
      transaction.status == TransactionStatus.processing;
}

bool transactionNeedsConfirmation(
  PaymentTransaction transaction, {
  DateTime? now,
  Duration gracePeriod = transactionConfirmationGracePeriod,
}) {
  if (!isTransactionOpen(transaction)) {
    return false;
  }

  final current = now ?? DateTime.now();

  final anchor = transaction.processedAt ?? transaction.createdAt;

  if (current.isBefore(anchor)) {
    return false;
  }

  return current.difference(anchor) >= gracePeriod;
}

ProviderSmsDeduplicationResult deduplicateParsedProviderSmsResults(
  List<ParsedProviderSmsResult> results,
) {
  if (results.isEmpty) {
    return const ProviderSmsDeduplicationResult(
      results: [],
      duplicateMessages: 0,
      conflictingResults: [],
    );
  }

  final groups = <String, List<ParsedProviderSmsResult>>{};

  for (final result in results) {
    final providerReference = result.providerReference?.trim();

    final key = providerReference != null && providerReference.isNotEmpty
        ? 'provider:${providerReference.toLowerCase()}'
        : 'message:${result.messageId}';

    groups.putIfAbsent(key, () => []);

    groups[key]!.add(result);
  }

  final unique = <ParsedProviderSmsResult>[];

  final conflicting = <ParsedProviderSmsResult>[];

  var duplicateMessages = 0;

  for (final group in groups.values) {
    if (group.length == 1) {
      unique.add(group.single);

      continue;
    }

    final first = group.first;

    final equivalent = group
        .skip(1)
        .every((result) => _sameProviderEvidence(first, result));

    if (equivalent) {
      final ordered = <ParsedProviderSmsResult>[...group]
        ..sort((left, right) => left.occurredAt.compareTo(right.occurredAt));

      unique.add(ordered.first);

      duplicateMessages += group.length - 1;

      continue;
    }

    // A provider reference or message identifier
    // carrying contradictory transaction evidence
    // must never be reconciled automatically.
    conflicting.addAll(group);
  }

  unique.sort((left, right) => left.occurredAt.compareTo(right.occurredAt));

  conflicting.sort(
    (left, right) => left.occurredAt.compareTo(right.occurredAt),
  );

  return ProviderSmsDeduplicationResult(
    results: unique,
    duplicateMessages: duplicateMessages,
    conflictingResults: conflicting,
  );
}

bool _sameProviderEvidence(
  ParsedProviderSmsResult left,
  ParsedProviderSmsResult right,
) {
  return left.status == right.status &&
      left.amount == right.amount &&
      _comparableIdentifier(left.receiverIdentifier) ==
          _comparableIdentifier(right.receiverIdentifier) &&
      left.failureCode == right.failureCode;
}

String? _comparableIdentifier(String? value) {
  if (value == null) {
    return null;
  }

  final digits = value.replaceAll(RegExp(r'\D'), '');

  if (digits.isNotEmpty) {
    return digits;
  }

  final normalized = value.trim().toLowerCase();

  return normalized.isEmpty ? null : normalized;
}
