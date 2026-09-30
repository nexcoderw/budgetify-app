import 'package:budgetify/features/home/application/mtn_received_transaction_sms_parser.dart';
import 'package:budgetify/features/home/data/models/provider_sms_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = MtnReceivedTransactionSmsParser();

  group('received transaction parsing', () {
    test('parses standard received M-Money transaction', () {
      final message = ProviderSmsMessage(
        id: '401',
        address: 'M-Money',
        body:
            'You have received 25,000 RWF from '
            'TEST SENDER (250788123456) '
            'on your mobile money account '
            'at 2026-09-30 19:20:00. '
            'Your new balance: 100000 RWF. '
            'Financial Transaction Id: 18473920534.',
        receivedAt: DateTime(2026, 9, 30, 19, 21),
      );

      final result = parser.parse(message);

      expect(result, isNotNull);

      expect(result!.amount, 25000);

      expect(result.providerReference, '18473920534');

      expect(result.senderName, 'TEST SENDER');

      expect(result.senderIdentifier, '250788123456');

      expect(result.occurredAt, DateTime(2026, 9, 30, 19, 20));
    });

    test('supports RWF before the amount', () {
      final message = ProviderSmsMessage(
        id: '402',
        address: 'MTN MoMo',
        body:
            'You have received RWF 12000 from '
            '0788123456 on your MoMo account '
            'at 2026-09-30 19:25:00. '
            'Transaction ID: RX-12000.',
        receivedAt: DateTime(2026, 9, 30, 19, 25),
      );

      final result = parser.parse(message);

      expect(result, isNotNull);

      expect(result!.amount, 12000);

      expect(result.senderIdentifier, '0788123456');

      expect(result.providerReference, 'RX-12000');
    });

    test('keeps sender name when identifier is masked', () {
      final message = ProviderSmsMessage(
        id: '403',
        address: 'MobileMoney',
        body:
            'You have received 5000 RWF from '
            'TEST SENDER (*********456) '
            'on your mobile money account '
            'at 2026-09-30 19:30:00. '
            'Financial Transaction Id: RX5000.',
        receivedAt: DateTime(2026, 9, 30, 19, 30),
      );

      final result = parser.parse(message);

      expect(result, isNotNull);

      expect(result!.senderName, 'TEST SENDER');

      expect(result.senderIdentifier, isNull);
    });

    test('rejects received payment without provider reference', () {
      final message = ProviderSmsMessage(
        id: '404',
        address: 'M-Money',
        body:
            'You have received 25000 RWF from '
            'TEST SENDER (250788123456) '
            'on your mobile money account '
            'at 2026-09-30 19:35:00.',
        receivedAt: DateTime(2026, 9, 30, 19, 35),
      );

      expect(parser.parse(message), isNull);
    });

    test('rejects received payment without provider occurrence time', () {
      final message = ProviderSmsMessage(
        id: '405',
        address: 'M-Money',
        body:
            'You have received 25000 RWF from '
            'TEST SENDER (250788123456). '
            'Financial Transaction Id: RX25000.',
        receivedAt: DateTime(2026, 9, 30, 19, 40),
      );

      expect(parser.parse(message), isNull);
    });

    test('does not treat outgoing transfer as received money', () {
      final message = ProviderSmsMessage(
        id: '406',
        address: 'M-Money',
        body:
            'You have transferred 25000 RWF to '
            'RECIPIENT (250788123456) '
            'from your mobile money account '
            'at 2026-09-30 19:45:00. '
            'Financial Transaction Id: TX25000.',
        receivedAt: DateTime(2026, 9, 30, 19, 45),
      );

      expect(parser.parse(message), isNull);
    });

    test('ignores unrelated balance message', () {
      final message = ProviderSmsMessage(
        id: '407',
        address: 'M-Money',
        body: 'Your mobile money balance is 25000 RWF.',
        receivedAt: DateTime(2026, 9, 30, 19, 50),
      );

      expect(parser.parse(message), isNull);
    });
  });

  group('received SMS deduplication', () {
    ParsedReceivedProviderSmsResult result({
      required String messageId,
      int amount = 25000,
      String providerReference = 'RECEIVED-001',
      String? senderIdentifier = '250788123456',
      String? senderName = 'TEST SENDER',
    }) {
      return ParsedReceivedProviderSmsResult(
        messageId: messageId,
        amount: amount,
        providerReference: providerReference,
        occurredAt: DateTime(2026, 9, 30, 20),
        senderName: senderName,
        senderIdentifier: senderIdentifier,
      );
    }

    test('deduplicates equivalent provider references', () {
      final deduplicated = deduplicateParsedReceivedProviderSmsResults(
        <ParsedReceivedProviderSmsResult>[
          result(messageId: 'sms-1'),
          result(messageId: 'sms-2'),
        ],
      );

      expect(deduplicated.results.length, 1);

      expect(deduplicated.duplicateMessages, 1);

      expect(deduplicated.conflictingResults, isEmpty);
    });

    test('rejects conflicting amount with the same provider reference', () {
      final deduplicated = deduplicateParsedReceivedProviderSmsResults(
        <ParsedReceivedProviderSmsResult>[
          result(messageId: 'sms-1', amount: 25000),
          result(messageId: 'sms-2', amount: 50000),
        ],
      );

      expect(deduplicated.results, isEmpty);

      expect(deduplicated.conflictingMessages, 2);
    });

    test('rejects conflicting sender with the same provider reference', () {
      final deduplicated = deduplicateParsedReceivedProviderSmsResults(
        <ParsedReceivedProviderSmsResult>[
          result(messageId: 'sms-1', senderIdentifier: '250788123456'),
          result(messageId: 'sms-2', senderIdentifier: '250791123456'),
        ],
      );

      expect(deduplicated.results, isEmpty);

      expect(deduplicated.conflictingMessages, 2);
    });
  });
}
