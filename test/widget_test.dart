import 'package:flutter_test/flutter_test.dart';

import 'package:budgetify/app/app.dart';

void main() {
  testWidgets('renders the auth login experience', (WidgetTester tester) async {
    await tester.pumpWidget(const BudgetifyApp());

    expect(find.text('Budgetify'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Terms & Conditions'), findsOneWidget);
  });
}
