import 'package:flutter_test/flutter_test.dart';

import 'package:budgetify/features/home/presentation/widgets/record_received_money/record_received_money_validation.dart';

void main() {
  group('validateReceivedAmount', () {
    test('requires a positive integer', () {
      expect(validateReceivedAmount(''), 'Enter a valid amount.');

      expect(validateReceivedAmount('0'), 'Enter a valid amount.');

      expect(validateReceivedAmount('-10'), 'Enter a valid amount.');
    });

    test('accepts valid amounts', () {
      expect(validateReceivedAmount('1'), isNull);

      expect(validateReceivedAmount('100000'), isNull);

      expect(validateReceivedAmount('10000000'), isNull);
    });

    test('rejects amounts above the limit', () {
      expect(
        validateReceivedAmount('10000001'),
        'Amount cannot exceed 10,000,000 RWF.',
      );
    });
  });

  group('validateReceivedSenderIdentifier', () {
    test('allows an empty sender number', () {
      expect(validateReceivedSenderIdentifier(''), isNull);
    });

    test('accepts supported phone formatting', () {
      expect(validateReceivedSenderIdentifier('+250 791 032 369'), isNull);

      expect(validateReceivedSenderIdentifier('0791-032-369'), isNull);
    });

    test('rejects unsupported characters', () {
      expect(
        validateReceivedSenderIdentifier('0791ABC369'),
        'Enter a valid sender number.',
      );
    });
  });

  group('validateReceivedProviderReference', () {
    test('allows an empty reference', () {
      expect(validateReceivedProviderReference(''), isNull);
    });

    test('accepts supported references', () {
      expect(validateReceivedProviderReference('TXN-123/ABC_45'), isNull);
    });

    test('rejects a reference shorter than three characters', () {
      expect(
        validateReceivedProviderReference('AB'),
        'Reference is too short.',
      );
    });

    test('rejects unsupported characters', () {
      expect(
        validateReceivedProviderReference('TXN 123'),
        'Reference contains unsupported characters.',
      );
    });
  });
}
