import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budgetify/app/app.dart';
import 'package:budgetify/features/auth/application/auth_service_contract.dart';
import 'package:budgetify/features/auth/data/models/auth_session.dart';
import 'package:budgetify/features/auth/data/models/auth_user.dart';
import 'package:budgetify/features/auth/data/models/email_initiate_response.dart';

class _FakeAuthService implements AuthServiceContract {
  _FakeAuthService({this.restoredUser});

  final AuthUser? restoredUser;
  int updateCurrentUserNamesCallCount = 0;
  String? lastUpdatedFirstName;
  String? lastUpdatedLastName;

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

  @override
  Future<AuthUser> updateCurrentUserNames({
    required String firstName,
    required String lastName,
  }) async {
    updateCurrentUserNamesCallCount++;
    lastUpdatedFirstName = firstName;
    lastUpdatedLastName = lastName;

    final user = restoredUser;
    if (user == null) {
      throw StateError('No restored user is available for this test.');
    }

    return AuthUser(
      id: user.id,
      email: user.email,
      firstName: firstName,
      lastName: lastName,
      fullName: '$firstName $lastName',
      avatarUrl: user.avatarUrl,
      isEmailVerified: user.isEmailVerified,
      status: user.status,
      lastLoginAt: user.lastLoginAt,
      createdAt: user.createdAt,
      updatedAt: DateTime.utc(2026, 3, 29),
    );
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

  testWidgets(
    'completes missing profile names before opening the landing page',
    (WidgetTester tester) async {
      final restoredUser = AuthUser(
        id: 'user-2',
        email: 'alice@example.com',
        firstName: null,
        lastName: null,
        fullName: null,
        avatarUrl: null,
        isEmailVerified: true,
        status: 'ACTIVE',
        lastLoginAt: DateTime.utc(2026, 3, 29),
        createdAt: DateTime.utc(2026, 3, 29),
        updatedAt: DateTime.utc(2026, 3, 29),
      );
      final authService = _FakeAuthService(restoredUser: restoredUser);

      await tester.pumpWidget(BudgetifyApp(authService: authService));
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Complete your profile'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'Alice');
      await tester.enterText(find.byType(TextFormField).at(1), 'Mutoni');
      await tester.tap(find.text('Save and continue'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 1200));

      expect(authService.updateCurrentUserNamesCallCount, 1);
      expect(authService.lastUpdatedFirstName, 'Alice');
      expect(authService.lastUpdatedLastName, 'Mutoni');
      expect(find.text('Alice M.'), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
    },
  );
}
