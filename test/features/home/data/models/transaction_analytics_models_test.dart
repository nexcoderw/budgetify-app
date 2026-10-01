import 'package:flutter_test/flutter_test.dart';

import 'package:budgetify/features/home/data/models/received_transaction_models.dart';
import 'package:budgetify/features/home/data/models/transaction_analytics_models.dart';
import 'package:budgetify/features/home/data/models/transaction_models.dart';

void main() {
  test('parses combined sent and received transaction analytics response', () {
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
        'receivedAmount': 235000,
        'feesPaid': 6200,
        'totalDebited': 491200,
        'netCashMovement': -256200,
        'completedTransactions': 18,
        'receivedTransactions': 7,
        'pendingTransactions': 1,
        'processingTransactions': 2,
        'needsConfirmation': 3,
        'failedTransactions': 1,
        'cancelledTransactions': 1,
        'reversedTransactions': 0,
        'receivedReversedTransactions': 1,
      },
      'comparison': <String, dynamic>{
        'previousSentAmount': 420000,
        'sentAmountChangePercentage': 15.48,
        'previousReceivedAmount': 180000,
        'receivedAmountChangePercentage': 30.56,
        'previousFeesPaid': 5300,
        'feesPaidChangePercentage': 16.98,
        'previousTotalDebited': 425300,
        'totalDebitedChangePercentage': 15.49,
        'previousNetCashMovement': -245300,
        'netCashMovementChange': -10900,
        'previousCompletedTransactions': 15,
        'completedTransactionsChangePercentage': 20,
        'previousReceivedTransactions': 5,
        'receivedTransactionsChangePercentage': 40,
      },
      'confirmation': <String, dynamic>{
        'smsEvidence': 10,
        'providerApiConfirmed': 4,
        'manuallyConfirmed': 4,
        'unclassified': 0,
      },
      'receivedEvidence': <String, dynamic>{
        'smsEvidence': 5,
        'providerApiEvidence': 1,
        'manualEntries': 1,
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
      'receivedClassifications': [
        <String, dynamic>{
          'classification': 'REIMBURSEMENT',
          'receivedAmount': 85000,
          'transactions': 3,
          'percentage': 36.17,
        },
        <String, dynamic>{
          'classification': 'UNCLASSIFIED',
          'receivedAmount': 150000,
          'transactions': 4,
          'percentage': 63.83,
        },
      ],
    });

    expect(analytics.currency, 'RWF');

    expect(analytics.summary.sentAmount, 485000);

    expect(analytics.summary.receivedAmount, 235000);

    expect(analytics.summary.totalDebited, 491200);

    expect(analytics.summary.netCashMovement, -256200);

    expect(analytics.summary.receivedTransactions, 7);

    expect(analytics.summary.receivedReversedTransactions, 1);

    expect(analytics.summary.needsConfirmation, 3);

    expect(analytics.comparison.receivedAmountChangePercentage, 30.56);

    expect(analytics.comparison.previousNetCashMovement, -245300);

    expect(analytics.comparison.netCashMovementChange, -10900);

    expect(analytics.confirmation.smsEvidence, 10);

    expect(analytics.confirmation.providerApiConfirmed, 4);

    expect(analytics.confirmation.manuallyConfirmed, 4);

    expect(analytics.confirmation.total, 18);

    expect(analytics.receivedEvidence.smsEvidence, 5);

    expect(analytics.receivedEvidence.providerApiEvidence, 1);

    expect(analytics.receivedEvidence.manualEntries, 1);

    expect(analytics.receivedEvidence.total, 7);

    expect(analytics.categories.single.category, TransactionCategory.transport);

    expect(analytics.categories.single.percentage, 18.56);

    expect(
      analytics.transferTypes.single.transferType,
      TransactionTransferType.momoToMomo,
    );

    expect(analytics.transferTypes.single.percentage, 72.16);

    expect(
      analytics.receivedClassifications.first.classification,
      ReceivedTransactionClassification.reimbursement,
    );

    expect(analytics.receivedClassifications.first.receivedAmount, 85000);

    expect(analytics.receivedClassifications.first.percentage, 36.17);

    expect(analytics.hasCompletedActivity, isTrue);
  });

  test(
    'accepts null comparison percentages for new sent and received activity',
    () {
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
          'receivedAmount': 15000,
          'feesPaid': 100,
          'totalDebited': 25100,
          'netCashMovement': -10100,
          'completedTransactions': 1,
          'receivedTransactions': 1,
          'pendingTransactions': 0,
          'processingTransactions': 0,
          'needsConfirmation': 0,
          'failedTransactions': 0,
          'cancelledTransactions': 0,
          'reversedTransactions': 0,
          'receivedReversedTransactions': 0,
        },
        'comparison': <String, dynamic>{
          'previousSentAmount': 0,
          'sentAmountChangePercentage': null,
          'previousReceivedAmount': 0,
          'receivedAmountChangePercentage': null,
          'previousFeesPaid': 0,
          'feesPaidChangePercentage': null,
          'previousTotalDebited': 0,
          'totalDebitedChangePercentage': null,
          'previousNetCashMovement': 0,
          'netCashMovementChange': -10100,
          'previousCompletedTransactions': 0,
          'completedTransactionsChangePercentage': null,
          'previousReceivedTransactions': 0,
          'receivedTransactionsChangePercentage': null,
        },
        'confirmation': <String, dynamic>{
          'smsEvidence': 1,
          'providerApiConfirmed': 0,
          'manuallyConfirmed': 0,
          'unclassified': 0,
        },
        'receivedEvidence': <String, dynamic>{
          'smsEvidence': 1,
          'providerApiEvidence': 0,
          'manualEntries': 0,
        },
        'categories': <dynamic>[],
        'transferTypes': <dynamic>[],
        'receivedClassifications': <dynamic>[],
      });

      expect(analytics.comparison.sentAmountChangePercentage, isNull);

      expect(analytics.comparison.receivedAmountChangePercentage, isNull);

      expect(
        analytics.comparison.completedTransactionsChangePercentage,
        isNull,
      );

      expect(analytics.comparison.receivedTransactionsChangePercentage, isNull);

      expect(analytics.comparison.netCashMovementChange, -10100);
    },
  );

  test('reports completed activity when only received money exists', () {
    final analytics = TransactionAnalytics.fromJson(<String, dynamic>{
      'currency': 'RWF',
      'period': <String, dynamic>{
        'from': '2026-09-01T00:00:00.000Z',
        'to': '2026-09-01T23:59:59.999Z',
        'previousFrom': '2026-08-31T00:00:00.000Z',
        'previousTo': '2026-08-31T23:59:59.999Z',
      },
      'summary': <String, dynamic>{
        'sentAmount': 0,
        'receivedAmount': 5000,
        'feesPaid': 0,
        'totalDebited': 0,
        'netCashMovement': 5000,
        'completedTransactions': 0,
        'receivedTransactions': 1,
        'pendingTransactions': 0,
        'processingTransactions': 0,
        'needsConfirmation': 0,
        'failedTransactions': 0,
        'cancelledTransactions': 0,
        'reversedTransactions': 0,
        'receivedReversedTransactions': 0,
      },
      'comparison': <String, dynamic>{
        'previousSentAmount': 0,
        'sentAmountChangePercentage': 0,
        'previousReceivedAmount': 0,
        'receivedAmountChangePercentage': null,
        'previousFeesPaid': 0,
        'feesPaidChangePercentage': 0,
        'previousTotalDebited': 0,
        'totalDebitedChangePercentage': 0,
        'previousNetCashMovement': 0,
        'netCashMovementChange': 5000,
        'previousCompletedTransactions': 0,
        'completedTransactionsChangePercentage': 0,
        'previousReceivedTransactions': 0,
        'receivedTransactionsChangePercentage': null,
      },
      'confirmation': <String, dynamic>{
        'smsEvidence': 0,
        'providerApiConfirmed': 0,
        'manuallyConfirmed': 0,
        'unclassified': 0,
      },
      'receivedEvidence': <String, dynamic>{
        'smsEvidence': 0,
        'providerApiEvidence': 0,
        'manualEntries': 1,
      },
      'categories': <dynamic>[],
      'transferTypes': <dynamic>[],
      'receivedClassifications': [
        <String, dynamic>{
          'classification': 'UNCLASSIFIED',
          'receivedAmount': 5000,
          'transactions': 1,
          'percentage': 100,
        },
      ],
    });

    expect(analytics.hasCompletedActivity, isTrue);

    expect(analytics.summary.netCashMovement, 5000);
  });

  test('rejects invalid analytics collections', () {
    expect(
      () => TransactionAnalytics.fromJson(<String, dynamic>{
        'currency': 'RWF',
        'period': <String, dynamic>{},
        'summary': <String, dynamic>{},
        'comparison': <String, dynamic>{},
        'confirmation': <String, dynamic>{},
        'receivedEvidence': <String, dynamic>{},
        'categories': 'invalid',
        'transferTypes': <dynamic>[],
        'receivedClassifications': <dynamic>[],
      }),
      throwsFormatException,
    );
  });
}
