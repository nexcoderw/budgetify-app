import 'package:budgetify/features/home/data/models/transaction_history_models.dart';
import 'package:budgetify/features/home/data/models/transaction_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses mixed money history', () {
    final result = TransactionHistoryListResult.fromJson(<String, dynamic>{
      'items': [
        {
          'id': 'received-1',
          'direction': 'RECEIVED',
          'reference': 'BGR-1',
          'status': 'COMPLETED',
          'currency': 'RWF',
          'amount': 25000,
          'feeAmount': null,
          'totalAmount': null,
          'counterpartyIdentifier': '+250791123456',
          'counterpartyName': 'Jean Claude',
          'providerReference': 'RX-1',
          'transferType': null,
          'category': null,
          'classification': 'UNCLASSIFIED',
          'evidenceSource': 'PROVIDER_SMS',
          'processedAt': null,
          'activityAt': '2026-09-30T20:05:00.000Z',
          'createdAt': '2026-09-30T20:06:00.000Z',
        },
        {
          'id': 'sent-1',
          'direction': 'SENT',
          'reference': 'BGT-1',
          'status': 'PROCESSING',
          'currency': 'RWF',
          'amount': 10000,
          'feeAmount': 20,
          'totalAmount': 10020,
          'counterpartyIdentifier': '+250788123456',
          'counterpartyName': 'Alice',
          'providerReference': null,
          'transferType': 'MOMO_TO_MOMO',
          'category': 'FAMILY',
          'classification': null,
          'evidenceSource': null,
          'processedAt': '2026-09-30T20:00:00.000Z',
          'activityAt': '2026-09-30T19:59:00.000Z',
          'createdAt': '2026-09-30T19:59:00.000Z',
        },
      ],
      'pagination': {
        'page': 1,
        'limit': 20,
        'total': 2,
        'totalPages': 1,
        'hasNextPage': false,
        'hasPreviousPage': false,
      },
    });

    expect(result.items.length, 2);

    expect(result.items.first.isReceived, isTrue);

    expect(result.items.first.counterpartyDisplayName, 'Jean Claude');

    expect(result.items.last.isSent, isTrue);

    expect(result.items.last.transferType, TransactionTransferType.momoToMomo);
  });

  test('marks old open sent transaction as needing confirmation', () {
    final item = TransactionHistoryItem.fromJson({
      'id': 'sent-1',
      'direction': 'SENT',
      'reference': 'BGT-1',
      'status': 'PROCESSING',
      'currency': 'RWF',
      'amount': 10000,
      'feeAmount': 20,
      'totalAmount': 10020,
      'counterpartyIdentifier': '+250788123456',
      'counterpartyName': null,
      'providerReference': null,
      'transferType': 'MOMO_TO_MOMO',
      'category': 'OTHER',
      'classification': null,
      'evidenceSource': null,
      'processedAt': '2026-09-30T18:00:00.000Z',
      'activityAt': '2026-09-30T18:00:00.000Z',
      'createdAt': '2026-09-30T17:59:00.000Z',
    });

    expect(
      item.needsConfirmation(now: DateTime.parse('2026-09-30T18:15:00.000Z')),
      isTrue,
    );
  });
}
