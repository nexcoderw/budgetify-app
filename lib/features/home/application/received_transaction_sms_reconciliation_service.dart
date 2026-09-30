import '../data/models/provider_sms_message.dart';
import '../data/services/device_sms_service.dart';
import 'mtn_received_transaction_sms_parser.dart';
import 'received_transaction_service.dart';

class ReceivedSmsReconciliationSummary {
  const ReceivedSmsReconciliationSummary({
    required this.scannedMessages,
    required this.parsedMessages,
    required this.acceptedPayments,
    required this.failedUpdates,
    required this.duplicateMessages,
    required this.conflictingMessages,
  });

  const ReceivedSmsReconciliationSummary.empty()
    : scannedMessages = 0,
      parsedMessages = 0,
      acceptedPayments = 0,
      failedUpdates = 0,
      duplicateMessages = 0,
      conflictingMessages = 0;

  final int scannedMessages;

  final int parsedMessages;

  /// Number of incoming evidence records accepted
  /// by the backend. The backend may return an
  /// existing record when the evidence is retried.
  final int acceptedPayments;

  final int failedUpdates;

  final int duplicateMessages;

  final int conflictingMessages;

  bool get hasAcceptedPayments => acceptedPayments > 0;

  bool get hasAttentionNeeded => failedUpdates > 0 || conflictingMessages > 0;
}

class ReceivedTransactionSmsReconciliationService {
  ReceivedTransactionSmsReconciliationService({
    required DeviceSmsService deviceSmsService,
    required ReceivedTransactionService receivedTransactionService,
    required MtnReceivedTransactionSmsParser parser,
  }) : _deviceSmsService = deviceSmsService,
       _receivedTransactionService = receivedTransactionService,
       _parser = parser;

  factory ReceivedTransactionSmsReconciliationService.createDefault({
    ReceivedTransactionService? receivedTransactionService,
  }) {
    return ReceivedTransactionSmsReconciliationService(
      deviceSmsService: const DeviceSmsService(),
      receivedTransactionService:
          receivedTransactionService ??
          ReceivedTransactionService.createDefault(),
      parser: const MtnReceivedTransactionSmsParser(),
    );
  }

  static const Duration _maximumSmsHistory = Duration(days: 7);

  static const Duration _scanOverlap = Duration(minutes: 2);

  static const int _maximumMessages = 200;

  final DeviceSmsService _deviceSmsService;

  final ReceivedTransactionService _receivedTransactionService;

  final MtnReceivedTransactionSmsParser _parser;

  DateTime? _lastSuccessfulScanAt;

  bool get isSupported => _deviceSmsService.isSupported;

  Future<ReceivedSmsReconciliationSummary> reconcileIfPermitted() async {
    if (!isSupported) {
      return const ReceivedSmsReconciliationSummary.empty();
    }

    final permission = await _deviceSmsService.checkPermission();

    if (permission != DeviceSmsPermission.granted) {
      return const ReceivedSmsReconciliationSummary.empty();
    }

    return reconcile();
  }

  Future<ReceivedSmsReconciliationSummary> reconcile() async {
    if (!isSupported) {
      return const ReceivedSmsReconciliationSummary.empty();
    }

    final permission = await _deviceSmsService.checkPermission();

    if (permission != DeviceSmsPermission.granted) {
      return const ReceivedSmsReconciliationSummary.empty();
    }

    final scanStartedAt = DateTime.now();

    final messages = await _deviceSmsService.readRecentMomoMessages(
      since: _scanStart(scanStartedAt),
      limit: _maximumMessages,
    );

    final parsed = _parseMessages(messages);

    final deduplicated = deduplicateParsedReceivedProviderSmsResults(parsed);

    var acceptedPayments = 0;

    var failedUpdates = 0;

    for (final result in deduplicated.results) {
      try {
        await _receivedTransactionService.recordProviderSms(
          clientEventId: _clientEventId(result),
          amount: result.amount,
          providerReference: result.providerReference,
          occurredAt: result.occurredAt,
          senderIdentifier: result.senderIdentifier,
          senderName: result.senderName,
        );

        acceptedPayments++;
      } catch (_) {
        // Incoming reconciliation is opportunistic.
        // One failed item must not stop the remaining
        // valid SMS evidence from syncing.
        failedUpdates++;
      }
    }

    // Commit the scan watermark only after every backend
    // write attempted during this scan succeeded.
    //
    // If one write fails, preserve the previous watermark so
    // the failed SMS evidence remains eligible for the next scan.
    // Successful records are safe to see again because the
    // backend received-payment endpoint is idempotent.
    if (failedUpdates == 0) {
      _lastSuccessfulScanAt = scanStartedAt;
    }

    return ReceivedSmsReconciliationSummary(
      scannedMessages: messages.length,
      parsedMessages: parsed.length,
      acceptedPayments: acceptedPayments,
      failedUpdates: failedUpdates,
      duplicateMessages: deduplicated.duplicateMessages,
      conflictingMessages: deduplicated.conflictingMessages,
    );
  }

  List<ParsedReceivedProviderSmsResult> _parseMessages(
    List<ProviderSmsMessage> messages,
  ) {
    final parsed =
        messages
            .map(_parser.parse)
            .whereType<ParsedReceivedProviderSmsResult>()
            .toList(growable: false)
          ..sort((left, right) => left.occurredAt.compareTo(right.occurredAt));

    return parsed;
  }

  DateTime _scanStart(DateTime now) {
    final oldestAllowed = now.subtract(_maximumSmsHistory);

    final previousScan = _lastSuccessfulScanAt;

    if (previousScan == null) {
      return oldestAllowed;
    }

    final overlapping = previousScan.subtract(_scanOverlap);

    if (overlapping.isBefore(oldestAllowed)) {
      return oldestAllowed;
    }

    return overlapping;
  }

  String _clientEventId(ParsedReceivedProviderSmsResult result) {
    final normalizedMessageId = result.messageId.replaceAll(
      RegExp(r'[^A-Za-z0-9._:-]'),
      '_',
    );

    final safeMessageId = normalizedMessageId.isEmpty
        ? 'unknown'
        : normalizedMessageId.length > 36
        ? normalizedMessageId.substring(0, 36)
        : normalizedMessageId;

    final occurredAtMillis = result.occurredAt.toUtc().millisecondsSinceEpoch;

    return 'received-sms-$safeMessageId-$occurredAtMillis';
  }
}
