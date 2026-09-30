import 'package:budgetify/features/home/application/mtn_transaction_sms_parser.dart';
import 'package:budgetify/features/home/data/models/provider_sms_message.dart';
import 'package:budgetify/features/home/data/models/transaction_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser =
      MtnTransactionSmsParser();

  test(
    'parses a completed MoMo transfer',
    () {
      final message =
          ProviderSmsMessage(
        id: '101',
        address: 'MobileMoney',
        body:
            'You have transferred 25000 RWF to JEAN TEST '
            '(250788123456) from your mobile money account '
            'at 2026-09-30 18:30:00. '
            'Financial Transaction Id: 18473920531.',
        receivedAt:
            DateTime.utc(
          2026,
          9,
          30,
          16,
          30,
        ),
      );

      final result =
          parser.parse(message);

      expect(
        result,
        isNotNull,
      );

      expect(
        result!.status,
        TransactionStatus.completed,
      );

      expect(
        result.amount,
        25000,
      );

      expect(
        result.providerReference,
        '18473920531',
      );

      expect(
        result.receiverIdentifier,
        '250788123456',
      );

      expect(
        result.receiverName,
        'JEAN TEST',
      );
    },
  );

  test(
    'parses insufficient funds failure',
    () {
      final message =
          ProviderSmsMessage(
        id: '102',
        address: 'MoMo',
        body:
            'Your MoMo transaction of 25000 RWF failed due to insufficient balance.',
        receivedAt:
            DateTime.utc(
          2026,
          9,
          30,
          16,
          32,
        ),
      );

      final result =
          parser.parse(message);

      expect(
        result,
        isNotNull,
      );

      expect(
        result!.status,
        TransactionStatus.failed,
      );

      expect(
        result.amount,
        25000,
      );

      expect(
        result.failureCode,
        'INSUFFICIENT_FUNDS',
      );
    },
  );

  test(
    'ignores unrelated SMS',
    () {
      final message =
          ProviderSmsMessage(
        id: '103',
        address: 'Example',
        body:
            'Your account balance is 25000 RWF.',
        receivedAt:
            DateTime.utc(
          2026,
          9,
          30,
          16,
          35,
        ),
      );

      expect(
        parser.parse(message),
        isNull,
      );
    },
  );

  test(
    'does not complete without provider reference',
    () {
      final message =
          ProviderSmsMessage(
        id: '104',
        address: 'MobileMoney',
        body:
            'You have transferred 25000 RWF to 0788123456 from your mobile money account.',
        receivedAt:
            DateTime.utc(
          2026,
          9,
          30,
          16,
          40,
        ),
      );

      expect(
        parser.parse(message),
        isNull,
      );
    },
  );
}
