import 'package:flutter_test/flutter_test.dart';

import 'package:budgetify/app/app.dart';
import 'package:budgetify/features/auth/application/auth_service_contract.dart';
import 'package:budgetify/features/auth/data/models/auth_session.dart';
import 'package:budgetify/features/auth/data/models/auth_user.dart';
import 'package:budgetify/features/auth/data/models/email_initiate_response.dart';

class _FakeAuthService implements AuthServiceContract {
  _FakeAuthService({this.restoredUser});

  final AuthUser? restoredUser;

  @override
  Future<void> clearSession() async {}

  @override
  Future<void> ensureInitialized() async {}

  @override
  Future<EmailInitiateResponse> initiateEmailAuth(String email) {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {}

  @override
  Future<AuthSession> refreshSession() {
    throw UnimplementedError();
  }

  @override
  Future<AuthUser?> restoreAuthenticatedUser() async => restoredUser;

  @override
  Future<AuthSession> signInWithGoogle() {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession> signInWithGoogleIdToken(String idToken) {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession> verifyEmailOtp(String email, String otp) {
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

  testWidgets('redirects authenticated users to the landing page', (
    WidgetTester tester,
  ) async {
    final restoredUser = AuthUser(
      id: 'user-1',
      email: 'jane@example.com',
      firstName: 'Jane',
      lastName: 'Doe',
      fullName: 'Jane Doe',
      avatarUrl: null,
      isEmailVerified: true,
      status: 'ACTIVE',
      lastLoginAt: DateTime.utc(2026, 3, 6),
      createdAt: DateTime.utc(2026, 3, 6),
      updatedAt: DateTime.utc(2026, 3, 6),
    );

    await tester.pumpWidget(
      BudgetifyApp(authService: _FakeAuthService(restoredUser: restoredUser)),
    );
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('Budgetify'), findsOneWidget);
    expect(find.text('Jane D.'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(
      find.text('Data is illustrative · Real sync coming soon'),
      findsOneWidget,
    );
  });
}
