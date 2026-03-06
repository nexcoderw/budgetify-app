import 'package:flutter_test/flutter_test.dart';

import 'package:budgetify/app/app.dart';
import 'package:budgetify/features/auth/application/auth_service_contract.dart';
import 'package:budgetify/features/auth/data/models/auth_session.dart';
import 'package:budgetify/features/auth/data/models/auth_user.dart';

class _FakeAuthService implements AuthServiceContract {
  @override
  Future<void> clearSession() async {}

  @override
  Future<void> logout() async {}

  @override
  Future<AuthSession> refreshSession() {
    throw UnimplementedError();
  }

  @override
  Future<AuthUser?> restoreAuthenticatedUser() async => null;

  @override
  Future<AuthSession> signInWithGoogle() {
    throw UnimplementedError();
  }
}

void main() {
  testWidgets('renders the auth login experience', (WidgetTester tester) async {
    await tester.pumpWidget(BudgetifyApp(authService: _FakeAuthService()));
    await tester.pump(const Duration(milliseconds: 1000));

    expect(find.text('Budgetify'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Terms & Conditions'), findsOneWidget);
  });
}
