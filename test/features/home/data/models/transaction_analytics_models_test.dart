import 'package:flutter_test/flutter_test.dart';

import 'package:budgetify/features/home/data/models/transaction_analytics_models.dart';
import 'package:budgetify/features/home/data/models/transaction_models.dart';

void main() {
  test('parses transaction analytics response', () {
    final analytics = TransactionAnalytics.fromJson(<String, dynamic>{
      'currency': 'RWF',
      'period': <String, dynamic>{
        'from': '2026-09-01T00:00:00.000Z',
        'to': '2026-09-30T20:00:00.000Z',
        'previousFrom': '2026-08-02T03:59:59.999Z',
        'previousTo': '2026-08-31T23:59:59.999Z',
      },
      'summary': <String, dynamic>{
        'sentAmount': 485000,
        'feesPaid': 6200,
        'totalDebited': 491200,
        'completedTransactions': 18,
        'pendingTransactions': 1,
        'processingTransactions': 2,
        'needsConfirmation': 3,
        'failedTransactions': 1,
        'cancelledTransactions': 1,
        'reversedTransactions': 0,
      },
      'comparison': <String, dynamic>{
        'previousSentAmount': 420000,
        'sentAmountChangePercentage': 15.48,
        'previousFeesPaid': 5300,
        'feesPaidChangePercentage': 16.98,
        'previousTotalDebited': 425300,
        'totalDebitedChangePercentage': 15.49,
        'previousCompletedTransactions': 15,
        'completedTransactionsChangePercentage': 20,
      },
      'confirmation': <String, dynamic>{
        'providerConfirmed': 14,
        'manuallyConfirmed': 4,
        'unclassified': 0,
      },
      'categories': [
        <String, dynamic>{
          'category': 'TRANSPORT',
          'sentAmount': 90000,
          'feesPaid': 700,
          'totalDebited': 90700,
          'transactions': 6,
          'percentage': 18.56,
        },
      ],
      'transferTypes': [
        <String, dynamic>{
          'transferType': 'MOMO_TO_MOMO',
          'sentAmount': 350000,
          'feesPaid': 4500,
          'totalDebited': 354500,
          'transactions': 12,
          'percentage': 72.16,
        },
      ],
    });

    expect(analytics.currency, 'RWF');

    expect(analytics.summary.sentAmount, 485000);

    expect(analytics.summary.needsConfirmation, 3);

    expect(analytics.confirmation.providerConfirmed, 14);

    expect(analytics.confirmation.manuallyConfirmed, 4);

    expect(analytics.confirmation.total, 18);

    expect(analytics.categories.single.category, TransactionCategory.transport);

    expect(analytics.categories.single.percentage, 18.56);

    expect(
      analytics.transferTypes.single.transferType,
      TransactionTransferType.momoToMomo,
    );

    expect(analytics.transferTypes.single.percentage, 72.16);

    expect(analytics.comparison.completedTransactionsChangePercentage, 20);
  });

  test('accepts null comparison percentage for new activity', () {
    final analytics = TransactionAnalytics.fromJson(<String, dynamic>{
      'currency': 'RWF',
      'period': <String, dynamic>{
        'from': '2026-09-01T00:00:00.000Z',
        'to': '2026-09-01T23:59:59.999Z',
        'previousFrom': '2026-08-31T00:00:00.000Z',
        'previousTo': '2026-08-31T23:59:59.999Z',
      },
      'summary': <String, dynamic>{
        'sentAmount': 25000,
        'feesPaid': 100,
        'totalDebited': 25100,
        'completedTransactions': 1,
        'pendingTransactions': 0,
        'processingTransactions': 0,
        'needsConfirmation': 0,
        'failedTransactions': 0,
        'cancelledTransactions': 0,
        'reversedTransactions': 0,
      },
      'comparison': <String, dynamic>{
        'previousSentAmount': 0,
        'sentAmountChangePercentage': null,
        'previousFeesPaid': 0,
        'feesPaidChangePercentage': null,
        'previousTotalDebited': 0,
        'totalDebitedChangePercentage': null,
        'previousCompletedTransactions': 0,
        'completedTransactionsChangePercentage': null,
      },
      'confirmation': <String, dynamic>{
        'providerConfirmed': 1,
        'manuallyConfirmed': 0,
        'unclassified': 0,
      },
      'categories': <dynamic>[],
      'transferTypes': <dynamic>[],
    });

    expect(analytics.comparison.sentAmountChangePercentage, isNull);

    expect(analytics.comparison.completedTransactionsChangePercentage, isNull);
  });

  test('rejects invalid analytics collections', () {
    expect(
      () => TransactionAnalytics.fromJson(<String, dynamic>{
        'currency': 'RWF',
        'period': <String, dynamic>{},
        'summary': <String, dynamic>{},
        'comparison': <String, dynamic>{},
        'confirmation': <String, dynamic>{},
        'categories': 'invalid',
        'transferTypes': <dynamic>[],
      }),
      throwsFormatException,
    );
  });
}
