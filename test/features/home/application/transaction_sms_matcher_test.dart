import 'package:budgetify/features/home/application/mtn_transaction_sms_parser.dart';
import 'package:budgetify/features/home/application/transaction_sms_matcher.dart';
import 'package:budgetify/features/home/data/models/transaction_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const matcher = TransactionSmsMatcher();

  group('transaction matching', () {
    test('matches explicit recipient when amounts are duplicated', () {
      final first = _transaction(
        id: 'first',
        amount: 25000,
        recipient: '0788123456',
      );

      final second = _transaction(
        id: 'second',
        amount: 25000,
        recipient: '0791123456',
      );

      final result = _providerResult(amount: 25000, recipient: '250791123456');

      final match = matcher.match(result, <PaymentTransaction>[first, second]);

      expect(match.kind, TransactionSmsMatchKind.matched);

      expect(match.transaction?.id, 'second');
    });

    test('treats same amount and recipient twice as ambiguous', () {
      final first = _transaction(
        id: 'first',
        amount: 25000,
        recipient: '0788123456',
        processedAt: DateTime(2026, 9, 30, 18),
      );

      final second = _transaction(
        id: 'second',
        amount: 25000,
        recipient: '250788123456',
        processedAt: DateTime(2026, 9, 30, 18, 10),
      );

      final result = _providerResult(
        amount: 25000,
        recipient: '0788123456',
        occurredAt: DateTime(2026, 9, 30, 18, 12),
      );

      final match = matcher.match(result, <PaymentTransaction>[first, second]);

      expect(match.kind, TransactionSmsMatchKind.ambiguous);

      expect(match.candidateCount, 2);
    });

    test('does not fall back to amount when recipient conflicts', () {
      final transaction = _transaction(amount: 25000, recipient: '0788123456');

      final result = _providerResult(amount: 25000, recipient: '0791123456');

      final match = matcher.match(result, <PaymentTransaction>[transaction]);

      expect(match.kind, TransactionSmsMatchKind.none);
    });

    test('does not match SMS that predates processing window', () {
      final transaction = _transaction(
        processedAt: DateTime(2026, 9, 30, 18, 30),
      );

      final result = _providerResult(occurredAt: DateTime(2026, 9, 30, 18, 20));

      expect(
        matcher.match(result, <PaymentTransaction>[transaction]).kind,
        TransactionSmsMatchKind.none,
      );
    });

    test('allows delayed confirmation inside candidate window', () {
      final transaction = _transaction(processedAt: DateTime(2026, 9, 30, 18));

      final result = _providerResult(occurredAt: DateTime(2026, 9, 30, 19, 30));

      expect(
        matcher.match(result, <PaymentTransaction>[transaction]).kind,
        TransactionSmsMatchKind.matched,
      );
    });

    test('does not match confirmation outside candidate window', () {
      final transaction = _transaction(processedAt: DateTime(2026, 9, 30, 18));

      final result = _providerResult(occurredAt: DateTime(2026, 9, 30, 20, 1));

      expect(
        matcher.match(result, <PaymentTransaction>[transaction]).kind,
        TransactionSmsMatchKind.none,
      );
    });

    test('requires exact bank account matching', () {
      final transaction = _transaction(
        recipientType: TransactionRecipientType.bankAccount,
        recipient: '123456789012',
        transferType: TransactionTransferType.momoToEkash,
      );

      final result = _providerResult(recipient: '999456789012');

      expect(
        matcher.match(result, <PaymentTransaction>[transaction]).kind,
        TransactionSmsMatchKind.none,
      );
    });

    test('prefers provider reference before time window', () {
      final transaction = _transaction(
        providerReference: 'PROVIDER-123',
        processedAt: DateTime(2026, 9, 30, 10),
      );

      final result = _providerResult(
        providerReference: 'PROVIDER-123',
        occurredAt: DateTime(2026, 9, 30, 18),
      );

      expect(
        matcher.match(result, <PaymentTransaction>[transaction]).kind,
        TransactionSmsMatchKind.matched,
      );
    });

    test('rejects conflicting evidence even with provider reference', () {
      final transaction = _transaction(
        amount: 25000,
        providerReference: 'PROVIDER-123',
      );

      final result = _providerResult(
        amount: 50000,
        providerReference: 'PROVIDER-123',
      );

      expect(
        matcher.match(result, <PaymentTransaction>[transaction]).kind,
        TransactionSmsMatchKind.ambiguous,
      );
    });
  });

  group('SMS deduplication', () {
    test('deduplicates repeated provider reference', () {
      final first = _providerResult(
        messageId: 'sms-1',
        providerReference: 'REF-001',
      );

      final duplicate = _providerResult(
        messageId: 'sms-2',
        providerReference: 'REF-001',
        occurredAt: DateTime(2026, 9, 30, 18, 1),
      );

      final deduplicated = deduplicateParsedProviderSmsResults(
        <ParsedProviderSmsResult>[first, duplicate],
      );

      expect(deduplicated.results.length, 1);

      expect(deduplicated.duplicateMessages, 1);

      expect(deduplicated.conflictingResults, isEmpty);
    });

    test('rejects conflicting SMS with same provider reference', () {
      final success = _providerResult(
        messageId: 'sms-1',
        providerReference: 'REF-001',
        status: TransactionStatus.completed,
      );

      final failure = _providerResult(
        messageId: 'sms-2',
        providerReference: 'REF-001',
        status: TransactionStatus.failed,
        failureCode: 'PROVIDER_FAILED',
      );

      final deduplicated = deduplicateParsedProviderSmsResults(
        <ParsedProviderSmsResult>[success, failure],
      );

      expect(deduplicated.results, isEmpty);

      expect(deduplicated.conflictingResults.length, 2);
    });
  });

  group('confirmation age', () {
    test('marks old processing transaction as needing confirmation', () {
      final transaction = _transaction(processedAt: DateTime(2026, 9, 30, 18));

      expect(
        transactionNeedsConfirmation(
          transaction,
          now: DateTime(2026, 9, 30, 18, 15),
        ),
        isTrue,
      );
    });

    test(
      'does not mark recent processing transaction as needing confirmation',
      () {
        final transaction = _transaction(
          processedAt: DateTime(2026, 9, 30, 18),
        );

        expect(
          transactionNeedsConfirmation(
            transaction,
            now: DateTime(2026, 9, 30, 18, 5),
          ),
          isFalse,
        );
      },
    );

    test('never marks final transaction as needing confirmation', () {
      final transaction = _transaction(
        status: TransactionStatus.completed,
        processedAt: DateTime(2026, 9, 30, 18),
      );

      expect(
        transactionNeedsConfirmation(
          transaction,
          now: DateTime(2026, 9, 30, 20),
        ),
        isFalse,
      );
    });
  });
}

PaymentTransaction _transaction({
  String id = 'transaction-1',
  int amount = 25000,
  String recipient = '0788123456',
  TransactionRecipientType recipientType = TransactionRecipientType.phone,
  TransactionTransferType transferType = TransactionTransferType.momoToMomo,
  TransactionStatus status = TransactionStatus.processing,
  String? providerReference,
  DateTime? createdAt,
  DateTime? processedAt,
}) {
  final created = createdAt ?? DateTime(2026, 9, 30, 17, 59);

  return PaymentTransaction(
    id: id,
    reference: 'BGT-$id',
    transferType: transferType,
    status: status,
    category: TransactionCategory.other,
    currency: 'RWF',
    amount: amount,
    feeAmount: 100,
    totalAmount: amount + 100,
    recipientType: recipientType,
    receiverIdentifier: recipient,
    receiverName: null,
    note: null,
    tariffVersion: 'test',
    tariffSource: 'test',
    providerReference: providerReference,
    failureCode: null,
    failureReason: null,
    processedAt: processedAt ?? DateTime(2026, 9, 30, 18),
    completedAt: null,
    failedAt: null,
    cancelledAt: null,
    createdAt: created,
    updatedAt: created,
  );
}

ParsedProviderSmsResult _providerResult({
  String messageId = 'sms-1',
  int amount = 25000,
  String? recipient = '0788123456',
  String? providerReference = 'REFERENCE-001',
  TransactionStatus status = TransactionStatus.completed,
  DateTime? occurredAt,
  String? failureCode,
}) {
  return ParsedProviderSmsResult(
    messageId: messageId,
    status: status,
    amount: amount,
    occurredAt: occurredAt ?? DateTime(2026, 9, 30, 18, 5),
    providerReference: providerReference,
    receiverName: null,
    receiverIdentifier: recipient,
    failureCode: failureCode,
    failureReason: null,
  );
}
