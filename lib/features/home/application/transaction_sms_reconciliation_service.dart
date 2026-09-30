import '../data/models/provider_sms_message.dart';
import '../data/models/transaction_models.dart';
import '../data/services/device_sms_service.dart';
import 'mtn_transaction_sms_parser.dart';
import 'transaction_service.dart';

class SmsReconciliationSummary {
  const SmsReconciliationSummary({
    required this.scannedMessages,
    required this.parsedMessages,
    required this.matchedTransactions,
    required this.failedUpdates,
  });

  const SmsReconciliationSummary.empty()
    : scannedMessages = 0,
      parsedMessages = 0,
      matchedTransactions = 0,
      failedUpdates = 0;

  final int scannedMessages;
  final int parsedMessages;
  final int matchedTransactions;
  final int failedUpdates;

  bool get hasChanges => matchedTransactions > 0;
}

class TransactionSmsReconciliationService {
  TransactionSmsReconciliationService({
    required DeviceSmsService deviceSmsService,
    required TransactionService transactionService,
    required MtnTransactionSmsParser parser,
  }) : _deviceSmsService = deviceSmsService,
       _transactionService = transactionService,
       _parser = parser;

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

  static const _candidateWindow = Duration(hours: 2);

  static const _earlyTolerance = Duration(minutes: 5);

  static const _maximumSmsHistory = Duration(days: 7);

  final DeviceSmsService _deviceSmsService;

  final TransactionService _transactionService;

  final MtnTransactionSmsParser _parser;

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

    final now = DateTime.now();

    final oldestAllowed = now.subtract(_maximumSmsHistory);

    var earliest = openTransactions.first.createdAt;

    for (final transaction in openTransactions.skip(1)) {
      if (transaction.createdAt.isBefore(earliest)) {
        earliest = transaction.createdAt;
      }
    }

    var since = earliest.subtract(_earlyTolerance);

    if (since.isBefore(oldestAllowed)) {
      since = oldestAllowed;
    }

    final messages = await _deviceSmsService.readRecentMomoMessages(
      since: since,
      limit: 100,
    );

    final parsedResults =
        messages
            .map(_parser.parse)
            .whereType<ParsedProviderSmsResult>()
            .toList(growable: false)
          ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

    final remainingTransactions = <PaymentTransaction>[...openTransactions];

    var matched = 0;
    var failed = 0;

    for (final result in parsedResults) {
      final transaction = _findMatchingTransaction(
        result,
        remainingTransactions,
      );

      if (transaction == null) {
        continue;
      }

      try {
        await _transactionService.recordProviderSmsResult(
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

        remainingTransactions.removeWhere((item) => item.id == transaction.id);

        matched++;
      } catch (_) {
        failed++;
      }
    }

    return SmsReconciliationSummary(
      scannedMessages: messages.length,
      parsedMessages: parsedResults.length,
      matchedTransactions: matched,
      failedUpdates: failed,
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

  PaymentTransaction? _findMatchingTransaction(
    ParsedProviderSmsResult result,
    List<PaymentTransaction> transactions,
  ) {
    var candidates = transactions
        .where((transaction) {
          if (transaction.amount != result.amount) {
            return false;
          }

          final earliest = transaction.createdAt.subtract(_earlyTolerance);

          final latest = transaction.createdAt.add(_candidateWindow);

          return !result.occurredAt.isBefore(earliest) &&
              !result.occurredAt.isAfter(latest);
        })
        .toList(growable: false);

    final resultRecipient = result.receiverIdentifier;

    if (resultRecipient != null) {
      final recipientMatches = candidates
          .where(
            (transaction) => _recipientMatches(
              transaction.receiverIdentifier,
              resultRecipient,
            ),
          )
          .toList(growable: false);

      if (recipientMatches.length == 1) {
        return recipientMatches.single;
      }

      if (recipientMatches.isNotEmpty) {
        candidates = recipientMatches;
      }
    }

    // Never guess when multiple transactions
    // could correspond to one SMS.
    if (candidates.length != 1) {
      return null;
    }

    return candidates.single;
  }

  bool _recipientMatches(String transactionRecipient, String smsRecipient) {
    final left = transactionRecipient.replaceAll(RegExp(r'\D'), '');

    final right = smsRecipient.replaceAll(RegExp(r'\D'), '');

    if (left == right) {
      return true;
    }

    if (left.length >= 9 && right.length >= 9) {
      return left.substring(left.length - 9) ==
          right.substring(right.length - 9);
    }

    return false;
  }

  String _clientEventId(
    ParsedProviderSmsResult result,
    PaymentTransaction transaction,
  ) {
    return 'sms-result-${result.messageId}-${transaction.id}';
  }
}
