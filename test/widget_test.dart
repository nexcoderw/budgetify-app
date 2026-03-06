import 'package:flutter_test/flutter_test.dart';

import 'package:budgetify/app/app.dart';

void main() {
  testWidgets('renders the auth login experience', (WidgetTester tester) async {
    await tester.pumpWidget(const BudgetifyApp());
    await tester.pump(const Duration(milliseconds: 1000));

    expect(find.text('Budgetify'), findsOneWidget);
    expect(find.text('Continue with google'), findsOneWidget);
    expect(find.text('Terms & Conditions'), findsOneWidget);
  });
}
