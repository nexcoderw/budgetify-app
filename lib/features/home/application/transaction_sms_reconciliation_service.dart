import '../data/models/provider_sms_message.dart';
import '../data/models/transaction_models.dart';
import '../data/services/device_sms_service.dart';
import 'mtn_transaction_sms_parser.dart';
import 'transaction_service.dart';
import 'transaction_sms_matcher.dart';

class SmsReconciliationSummary {
  const SmsReconciliationSummary({
    required this.scannedMessages,
    required this.parsedMessages,
    required this.matchedTransactions,
    required this.failedUpdates,
    required this.ambiguousMessages,
    required this.duplicateMessages,
    required this.unmatchedMessages,
  });

  const SmsReconciliationSummary.empty()
    : scannedMessages = 0,
      parsedMessages = 0,
      matchedTransactions = 0,
      failedUpdates = 0,
      ambiguousMessages = 0,
      duplicateMessages = 0,
      unmatchedMessages = 0;

  final int scannedMessages;
  final int parsedMessages;
  final int matchedTransactions;
  final int failedUpdates;
  final int ambiguousMessages;
  final int duplicateMessages;
  final int unmatchedMessages;

  bool get hasChanges => matchedTransactions > 0;

  bool get hasAttentionNeeded => ambiguousMessages > 0 || failedUpdates > 0;
}

enum TransactionReconciliationOutcome {
  updated,
  alreadyResolved,
  noMatch,
  ambiguous,
  permissionDenied,
  unsupported,
}

class TransactionReconciliationResult {
  const TransactionReconciliationResult({
    required this.outcome,
    required this.transaction,
    required this.checkedAt,
    required this.scannedMessages,
    required this.parsedMessages,
    required this.duplicateMessages,
  });

  final TransactionReconciliationOutcome outcome;
  final PaymentTransaction transaction;
  final DateTime checkedAt;
  final int scannedMessages;
  final int parsedMessages;
  final int duplicateMessages;

  bool get statusChanged => outcome == TransactionReconciliationOutcome.updated;
}

class TransactionSmsReconciliationService {
  TransactionSmsReconciliationService({
    required DeviceSmsService deviceSmsService,
    required TransactionService transactionService,
    required MtnTransactionSmsParser parser,
    TransactionSmsMatcher matcher = const TransactionSmsMatcher(),
  }) : _deviceSmsService = deviceSmsService,
       _transactionService = transactionService,
       _parser = parser,
       _matcher = matcher;

  factory TransactionSmsReconciliationService.createDefault({
    TransactionService? transactionService,
  }) {
    return TransactionSmsReconciliationService(
      deviceSmsService: const DeviceSmsService(),
      transactionService:
          transactionService ?? TransactionService.createDefault(),
      parser: const MtnTransactionSmsParser(),
    );
  }

  static const _maximumOpenPages = 5;

  static const _scanLead = Duration(minutes: 2);

  static const _maximumSmsHistory = Duration(days: 7);

  final DeviceSmsService _deviceSmsService;

  final TransactionService _transactionService;

  final MtnTransactionSmsParser _parser;

  final TransactionSmsMatcher _matcher;

  bool get isSupported => _deviceSmsService.isSupported;

  Future<DeviceSmsPermission> checkPermission() {
    return _deviceSmsService.checkPermission();
  }

  Future<DeviceSmsPermission> requestPermission() {
    return _deviceSmsService.requestPermission();
  }

  Future<SmsReconciliationSummary> reconcileIfPermitted() async {
    final permission = await checkPermission();

    if (permission != DeviceSmsPermission.granted) {
      return const SmsReconciliationSummary.empty();
    }

    return reconcile();
  }

  Future<SmsReconciliationSummary> reconcile() async {
    if (!_deviceSmsService.isSupported) {
      return const SmsReconciliationSummary.empty();
    }

    final permission = await checkPermission();

    if (permission != DeviceSmsPermission.granted) {
      return const SmsReconciliationSummary.empty();
    }

    final openTransactions = await _loadOpenTransactions();

    if (openTransactions.isEmpty) {
      return const SmsReconciliationSummary.empty();
    }

    final messages = await _deviceSmsService.readRecentMomoMessages(
      since: _scanStart(openTransactions),
      limit: 100,
    );

    final parsedResults = _parseMessages(messages);

    final deduplicated = deduplicateParsedProviderSmsResults(parsedResults);

    final evidenceByTransaction = <String, List<ParsedProviderSmsResult>>{};

    var ambiguousMessages = 0;
    var unmatchedMessages = 0;
    var failedUpdates = 0;
    var matchedTransactions = 0;

    for (final conflicting in deduplicated.conflictingResults) {
      final match = _matcher.match(conflicting, openTransactions);

      if (match.kind == TransactionSmsMatchKind.none) {
        unmatchedMessages++;
      } else {
        ambiguousMessages++;
      }
    }

    for (final result in deduplicated.results) {
      final match = _matcher.match(result, openTransactions);

      switch (match.kind) {
        case TransactionSmsMatchKind.none:
          unmatchedMessages++;

        case TransactionSmsMatchKind.ambiguous:
          ambiguousMessages++;

        case TransactionSmsMatchKind.matched:
          final transaction = match.transaction!;

          evidenceByTransaction.putIfAbsent(transaction.id, () => []);

          evidenceByTransaction[transaction.id]!.add(result);
      }
    }

    for (final entry in evidenceByTransaction.entries) {
      final evidence = entry.value;

      // Multiple different messages matching
      // the same transaction are not safe to
      // auto-reconcile.
      if (evidence.length != 1) {
        ambiguousMessages += evidence.length;

        continue;
      }

      final transaction = openTransactions.firstWhere(
        (item) => item.id == entry.key,
      );

      try {
        await _submitProviderResult(transaction, evidence.single);

        matchedTransactions++;
      } catch (_) {
        failedUpdates++;
      }
    }

    return SmsReconciliationSummary(
      scannedMessages: messages.length,
      parsedMessages: parsedResults.length,
      matchedTransactions: matchedTransactions,
      failedUpdates: failedUpdates,
      ambiguousMessages: ambiguousMessages,
      duplicateMessages: deduplicated.duplicateMessages,
      unmatchedMessages: unmatchedMessages,
    );
  }

  Future<TransactionReconciliationResult> reconcileTransaction(
    PaymentTransaction transaction,
  ) async {
    final checkedAt = DateTime.now();

    if (!isTransactionOpen(transaction)) {
      return TransactionReconciliationResult(
        outcome: TransactionReconciliationOutcome.alreadyResolved,
        transaction: transaction,
        checkedAt: checkedAt,
        scannedMessages: 0,
        parsedMessages: 0,
        duplicateMessages: 0,
      );
    }

    if (!_deviceSmsService.isSupported) {
      return TransactionReconciliationResult(
        outcome: TransactionReconciliationOutcome.unsupported,
        transaction: transaction,
        checkedAt: checkedAt,
        scannedMessages: 0,
        parsedMessages: 0,
        duplicateMessages: 0,
      );
    }

    final permission = await checkPermission();

    if (permission != DeviceSmsPermission.granted) {
      return TransactionReconciliationResult(
        outcome: TransactionReconciliationOutcome.permissionDenied,
        transaction: transaction,
        checkedAt: checkedAt,
        scannedMessages: 0,
        parsedMessages: 0,
        duplicateMessages: 0,
      );
    }

    final messages = await _deviceSmsService.readRecentMomoMessages(
      since: _scanStart(<PaymentTransaction>[transaction]),
      limit: 100,
    );

    final parsed = _parseMessages(messages);

    final deduplicated = deduplicateParsedProviderSmsResults(parsed);

    var hasConflictingMatch = false;

    for (final conflicting in deduplicated.conflictingResults) {
      final match = _matcher.match(conflicting, <PaymentTransaction>[
        transaction,
      ]);

      if (match.kind != TransactionSmsMatchKind.none) {
        hasConflictingMatch = true;
        break;
      }
    }

    if (hasConflictingMatch) {
      return TransactionReconciliationResult(
        outcome: TransactionReconciliationOutcome.ambiguous,
        transaction: transaction,
        checkedAt: checkedAt,
        scannedMessages: messages.length,
        parsedMessages: parsed.length,
        duplicateMessages: deduplicated.duplicateMessages,
      );
    }

    final candidates = <ParsedProviderSmsResult>[];

    var ambiguous = false;

    for (final result in deduplicated.results) {
      final match = _matcher.match(result, <PaymentTransaction>[transaction]);

      if (match.kind == TransactionSmsMatchKind.ambiguous) {
        ambiguous = true;
        continue;
      }

      if (match.kind == TransactionSmsMatchKind.matched) {
        candidates.add(result);
      }
    }

    if (ambiguous || candidates.length > 1) {
      return TransactionReconciliationResult(
        outcome: TransactionReconciliationOutcome.ambiguous,
        transaction: transaction,
        checkedAt: checkedAt,
        scannedMessages: messages.length,
        parsedMessages: parsed.length,
        duplicateMessages: deduplicated.duplicateMessages,
      );
    }

    if (candidates.isEmpty) {
      return TransactionReconciliationResult(
        outcome: TransactionReconciliationOutcome.noMatch,
        transaction: transaction,
        checkedAt: checkedAt,
        scannedMessages: messages.length,
        parsedMessages: parsed.length,
        duplicateMessages: deduplicated.duplicateMessages,
      );
    }

    final updated = await _submitProviderResult(transaction, candidates.single);

    return TransactionReconciliationResult(
      outcome: TransactionReconciliationOutcome.updated,
      transaction: updated,
      checkedAt: checkedAt,
      scannedMessages: messages.length,
      parsedMessages: parsed.length,
      duplicateMessages: deduplicated.duplicateMessages,
    );
  }

  Future<List<PaymentTransaction>> _loadOpenTransactions() async {
    final pending = await _loadStatus(TransactionStatus.pending);

    final processing = await _loadStatus(TransactionStatus.processing);

    return <PaymentTransaction>[...pending, ...processing];
  }

  Future<List<PaymentTransaction>> _loadStatus(TransactionStatus status) async {
    final transactions = <PaymentTransaction>[];

    var page = 1;

    while (page <= _maximumOpenPages) {
      final result = await _transactionService.list(
        page: page,
        limit: 100,
        status: status,
      );

      transactions.addAll(result.items);

      if (!result.pagination.hasNextPage) {
        break;
      }

      page++;
    }

    return transactions;
  }

  List<ParsedProviderSmsResult> _parseMessages(
    List<ProviderSmsMessage> messages,
  ) {
    final parsed =
        messages
            .map(_parser.parse)
            .whereType<ParsedProviderSmsResult>()
            .toList(growable: false)
          ..sort((left, right) => left.occurredAt.compareTo(right.occurredAt));

    return parsed;
  }

  DateTime _scanStart(List<PaymentTransaction> transactions) {
    final now = DateTime.now();

    final oldestAllowed = now.subtract(_maximumSmsHistory);

    var earliest = _reconciliationAnchor(transactions.first);

    for (final transaction in transactions.skip(1)) {
      final anchor = _reconciliationAnchor(transaction);

      if (anchor.isBefore(earliest)) {
        earliest = anchor;
      }
    }

    var since = earliest.subtract(_scanLead);

    if (since.isBefore(oldestAllowed)) {
      since = oldestAllowed;
    }

    return since;
  }

  DateTime _reconciliationAnchor(PaymentTransaction transaction) {
    return transaction.processedAt ?? transaction.createdAt;
  }

  Future<PaymentTransaction> _submitProviderResult(
    PaymentTransaction transaction,
    ParsedProviderSmsResult result,
  ) {
    return _transactionService.recordProviderSmsResult(
      transactionId: transaction.id,
      clientEventId: _clientEventId(result, transaction),
      amount: result.amount,
      status: result.status,
      occurredAt: result.occurredAt,
      providerReference: result.providerReference,
      receiverName: result.receiverName,
      failureCode: result.failureCode,
      failureReason: result.failureReason,
    );
  }

  String _clientEventId(
    ParsedProviderSmsResult result,
    PaymentTransaction transaction,
  ) {
    final normalizedMessageId = result.messageId.replaceAll(
      RegExp(r'[^A-Za-z0-9._:-]'),
      '_',
    );

    final safeMessageId = normalizedMessageId.length > 36
        ? normalizedMessageId.substring(0, 36)
        : normalizedMessageId;

    return 'sms-result-$safeMessageId-${transaction.id}';
  }
}
