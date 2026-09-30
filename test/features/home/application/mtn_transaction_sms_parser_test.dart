import 'package:budgetify/features/home/application/mtn_transaction_sms_parser.dart';
import 'package:budgetify/features/home/data/models/provider_sms_message.dart';
import 'package:budgetify/features/home/data/models/transaction_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = MtnTransactionSmsParser();

  group('completed transactions', () {
    test('parses standard outgoing M-Money transfer', () {
      final message = ProviderSmsMessage(
        id: '101',
        address: 'M-Money',
        body:
            'You have transferred 31,000 RWF to '
            'RECIPIENT NAME (250788123456) '
            'from your mobile money account '
            'at 2026-09-30 18:30:00. '
            'Your new balance: 100000 RWF. '
            'Financial Transaction Id: 18473920531.',
        receivedAt: DateTime(2026, 9, 30, 18, 31),
      );

      final result = parser.parse(message);

      expect(result, isNotNull);

      expect(result!.status, TransactionStatus.completed);

      expect(result.amount, 31000);

      expect(result.providerReference, '18473920531');

      expect(result.receiverIdentifier, '250788123456');

      expect(result.receiverName, 'RECIPIENT NAME');

      expect(result.occurredAt, DateTime(2026, 9, 30, 18, 30));
    });

    test('uses provider timestamp instead of SMS receipt time', () {
      final message = ProviderSmsMessage(
        id: '102',
        address: 'MobileMoney',
        body:
            'You have transferred 25000 RWF to '
            '0788123456 from your mobile money account '
            'at 2026-09-30 18:30:00. '
            'Financial Transaction Id: 18473920532.',
        receivedAt: DateTime(2026, 9, 30, 18, 35),
      );

      final result = parser.parse(message);

      expect(result, isNotNull);

      expect(result!.occurredAt, DateTime(2026, 9, 30, 18, 30));
    });

    test('parses parenthesized merchant identifier', () {
      final message = ProviderSmsMessage(
        id: '103',
        address: 'MoMo',
        body:
            'You have paid 5000 RWF to '
            'TEST MERCHANT (123456) '
            'from your mobile money account '
            'at 2026-09-30 18:40:00. '
            'Financial Transaction Id: PAY123456789.',
        receivedAt: DateTime(2026, 9, 30, 18, 40),
      );

      final result = parser.parse(message);

      expect(result, isNotNull);

      expect(result!.amount, 5000);

      expect(result.receiverIdentifier, '123456');

      expect(result.receiverName, 'TEST MERCHANT');
    });

    test('does not complete without provider reference', () {
      final message = ProviderSmsMessage(
        id: '104',
        address: 'MobileMoney',
        body:
            'You have transferred 25000 RWF to '
            '0788123456 from your mobile money account.',
        receivedAt: DateTime(2026, 9, 30, 18, 40),
      );

      expect(parser.parse(message), isNull);
    });

    test('does not use masked recipient for matching', () {
      final message = ProviderSmsMessage(
        id: '105',
        address: 'MobileMoney',
        body:
            'You have transferred 25000 RWF to '
            'RECIPIENT (*********456) '
            'from your mobile money account '
            'at 2026-09-30 18:50:00. '
            'Financial Transaction Id: 18473920533.',
        receivedAt: DateTime(2026, 9, 30, 18, 50),
      );

      final result = parser.parse(message);

      expect(result, isNotNull);

      expect(result!.receiverIdentifier, isNull);
    });
  });

  group('failed transactions', () {
    test('parses insufficient funds', () {
      final message = ProviderSmsMessage(
        id: '201',
        address: 'MoMo',
        body:
            'Your MoMo transaction of 25000 RWF '
            'failed due to insufficient balance.',
        receivedAt: DateTime(2026, 9, 30, 19),
      );

      final result = parser.parse(message);

      expect(result, isNotNull);

      expect(result!.status, TransactionStatus.failed);

      expect(result.amount, 25000);

      expect(result.failureCode, 'INSUFFICIENT_FUNDS');
    });

    test('parses declined transaction', () {
      final message = ProviderSmsMessage(
        id: '202',
        address: 'MTN MoMo',
        body:
            'Your MoMo transaction of 10000 RWF '
            'was declined.',
        receivedAt: DateTime(2026, 9, 30, 19, 5),
      );

      final result = parser.parse(message);

      expect(result, isNotNull);

      expect(result!.status, TransactionStatus.failed);

      expect(result.failureCode, 'PROVIDER_DECLINED');
    });

    test('parses cancelled transaction', () {
      final message = ProviderSmsMessage(
        id: '203',
        address: 'MoMo',
        body:
            'Your MoMo transaction of 5000 RWF '
            'was cancelled.',
        receivedAt: DateTime(2026, 9, 30, 19, 10),
      );

      final result = parser.parse(message);

      expect(result, isNotNull);

      expect(result!.status, TransactionStatus.cancelled);

      expect(result.failureCode, 'PROVIDER_CANCELLED');
    });
  });

  group('message rejection', () {
    test('ignores unrelated balance SMS', () {
      final message = ProviderSmsMessage(
        id: '301',
        address: 'Example',
        body: 'Your account balance is 25000 RWF.',
        receivedAt: DateTime(2026, 9, 30, 19, 15),
      );

      expect(parser.parse(message), isNull);
    });

    test('does not treat received money as outgoing payment', () {
      final message = ProviderSmsMessage(
        id: '302',
        address: 'M-Money',
        body:
            'You have received 25000 RWF from '
            'SENDER NAME (250788123456) '
            'on your mobile money account '
            'at 2026-09-30 19:20:00. '
            'Financial Transaction Id: 18473920534.',
        receivedAt: DateTime(2026, 9, 30, 19, 20),
      );

      expect(parser.parse(message), isNull);
    });

    test('ignores message without RWF', () {
      final message = ProviderSmsMessage(
        id: '303',
        address: 'MoMo',
        body: 'Your transaction was completed successfully.',
        receivedAt: DateTime(2026, 9, 30, 19, 25),
      );

      expect(parser.parse(message), isNull);
    });
  });
}
