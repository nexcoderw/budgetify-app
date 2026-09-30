import 'package:budgetify/features/home/data/models/received_transaction_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses received transaction response', () {
    final transaction = ReceivedTransaction.fromJson(<String, dynamic>{
      'id': '26fb4ee5-c445-41e0-a023-7024479bbabc',
      'reference': 'BGR-MJYD6U04-4BC719DA461E',
      'status': 'COMPLETED',
      'classification': 'UNCLASSIFIED',
      'evidenceSource': 'PROVIDER_SMS',
      'currency': 'RWF',
      'amount': 25000,
      'senderIdentifier': '+250788123456',
      'senderName': 'TEST SENDER',
      'providerReference': '18473920531',
      'occurredAt': '2026-09-30T19:35:20.000Z',
      'reversedAt': null,
      'note': null,
      'createdAt': '2026-09-30T19:35:30.000Z',
      'updatedAt': '2026-09-30T19:35:30.000Z',
    });

    expect(transaction.amount, 25000);

    expect(transaction.status, ReceivedTransactionStatus.completed);

    expect(
      transaction.classification,
      ReceivedTransactionClassification.unclassified,
    );

    expect(
      transaction.evidenceSource,
      ReceivedTransactionEvidenceSource.providerSms,
    );

    expect(transaction.senderDisplayName, 'TEST SENDER');

    expect(transaction.providerReference, '18473920531');
  });

  test('falls back to sender identifier for display', () {
    final transaction = ReceivedTransaction.fromJson(<String, dynamic>{
      'id': '26fb4ee5-c445-41e0-a023-7024479bbabc',
      'reference': 'BGR-MJYD6U04-4BC719DA461E',
      'status': 'COMPLETED',
      'classification': 'UNCLASSIFIED',
      'evidenceSource': 'PROVIDER_SMS',
      'currency': 'RWF',
      'amount': 25000,
      'senderIdentifier': '+250788123456',
      'senderName': null,
      'providerReference': '18473920531',
      'occurredAt': '2026-09-30T19:35:20.000Z',
      'reversedAt': null,
      'note': null,
      'createdAt': '2026-09-30T19:35:30.000Z',
      'updatedAt': '2026-09-30T19:35:30.000Z',
    });

    expect(transaction.senderDisplayName, '+250788123456');
  });

  test('parses received transaction list pagination', () {
    final result = ReceivedTransactionListResult.fromJson(<String, dynamic>{
      'items': <dynamic>[],
      'pagination': <String, dynamic>{
        'page': 1,
        'limit': 20,
        'total': 0,
        'totalPages': 0,
        'hasNextPage': false,
        'hasPreviousPage': false,
      },
    });

    expect(result.items, isEmpty);

    expect(result.pagination.page, 1);

    expect(result.pagination.hasNextPage, isFalse);
  });
}
