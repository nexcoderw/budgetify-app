import 'package:budgetify/features/home/data/models/transaction_history_models.dart';
import 'package:budgetify/features/home/presentation/widgets/history/history_insights.dart';
import 'package:budgetify/features/home/presentation/widgets/history/history_transaction_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionHistoryItem _transaction({
  required String id,
  required DateTime date,
  int amount = 1000,
  int? fee = 20,
  String direction = 'SENT',
  String status = 'COMPLETED',
  String currency = 'RWF',
}) => TransactionHistoryItem.fromJson({
  'id': id,
  'reference': id,
  'direction': direction,
  'status': status,
  'currency': currency,
  'amount': amount,
  'feeAmount': fee,
  'activityAt': date.toIso8601String(),
  'createdAt': date.toIso8601String(),
});

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('includes recorded fees and immediately filters with badges', (
    tester,
  ) async {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 10);
    await tester.pumpWidget(
      _host(
        HistoryInsights(
          transactions: [
            _transaction(id: 'current', date: now),
            _transaction(id: 'previous', date: lastMonth, amount: 2000, fee: 40),
            _transaction(id: 'pending', date: now, status: 'PENDING'),
            _transaction(id: 'received', date: now, direction: 'RECEIVED'),
            _transaction(id: 'other-currency', date: now, currency: 'USD'),
          ],
          errorMessage: null,
          onRetry: () {},
        ),
      ),
    );

    expect(find.byType(ChoiceChip), findsNWidgets(5));
    expect(find.text('1,020 RWF'), findsOneWidget);
    expect(find.text('Transaction fees'), findsOneWidget);
    expect(find.text('20 RWF'), findsOneWidget);

    await tester.tap(find.text('Last month'));
    await tester.pumpAndSettle();
    expect(find.text('2,040 RWF'), findsOneWidget);
    expect(find.text('40 RWF'), findsOneWidget);
    expect(find.text('1,020 RWF'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not treat unavailable fees as confirmed zero', (tester) async {
    await tester.pumpWidget(
      _host(
        HistoryInsights(
          transactions: [
            _transaction(id: 'unknown-fee', date: DateTime.now(), fee: null),
          ],
          errorMessage: null,
          onRetry: () {},
        ),
      ),
    );
    expect(
      find.text('Fees unavailable for 1 payment(s); not included in total.'),
      findsOneWidget,
    );
    expect(find.text('1,000 RWF'), findsNWidgets(2));
  });

  testWidgets('shows outgoing fees in the transaction list', (tester) async {
    await tester.pumpWidget(
      _host(
        HistoryTransactionList(
          transactions: [
            _transaction(id: 'known', date: DateTime.now()),
            _transaction(id: 'unknown', date: DateTime.now(), fee: null),
          ],
          compact: true,
          onTap: (_) {},
        ),
      ),
    );
    expect(find.text('Fee 20 RWF'), findsOneWidget);
    expect(find.text('Fee unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
