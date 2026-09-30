import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budgetify/app/app.dart';
import 'package:budgetify/core/widgets/app_button.dart';
import 'package:budgetify/core/widgets/app_input.dart';
import 'package:budgetify/features/auth/application/auth_service_contract.dart';
import 'package:budgetify/features/auth/data/models/auth_session.dart';
import 'package:budgetify/features/auth/data/models/auth_user.dart';
import 'package:budgetify/features/auth/data/models/email_initiate_response.dart';
import 'package:budgetify/features/auth/data/models/password_auth_models.dart';
import 'package:budgetify/features/onboarding/application/onboarding_preferences.dart';

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
  Future<PasswordStatus> getPasswordStatus(String email) async {
    return const PasswordStatus(hasPassword: false);
  }

  @override
  Future<PasswordChallenge> requestPasswordChallenge(String email) {
    throw UnimplementedError();
  }

  @override
  Future<PasswordSetupGrant> verifyPasswordChallenge(String email, String otp) {
    throw UnimplementedError();
  }

  @override
  Future<void> setPassword({
    required String grantToken,
    required String password,
    required String confirmPassword,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession> signInWithPassword({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AuthUser> requestCurrentUserDeletion() async {
    final user = restoredUser;

    if (user == null) {
      throw StateError('No restored user is available for this test.');
    }

    return AuthUser(
      id: user.id,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      fullName: user.fullName,
      avatarUrl: user.avatarUrl,
      isEmailVerified: user.isEmailVerified,
      status: user.status,
      lastLoginAt: user.lastLoginAt,
      accountDeletionRequestedAt: DateTime.utc(2026, 4, 7),
      accountDeletionScheduledFor: DateTime.utc(2026, 5, 7),
      createdAt: user.createdAt,
      updatedAt: DateTime.utc(2026, 4, 7),
    );
  }

  @override
  Future<AuthSession> refreshSession() {
    throw UnimplementedError();
  }

  @override
  Future<AuthUser?> restoreAuthenticatedUser() async {
    return restoredUser;
  }

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
      accountDeletionRequestedAt: user.accountDeletionRequestedAt,
      accountDeletionScheduledFor: user.accountDeletionScheduledFor,
      createdAt: user.createdAt,
      updatedAt: DateTime.utc(2026, 3, 29),
    );
  }
}

class _FakeOnboardingPreferences implements OnboardingPreferences {
  _FakeOnboardingPreferences({required bool completed})
    : _completed = completed;

  bool _completed;

  int markCompletedCallCount = 0;

  @override
  Future<bool> hasCompletedOnboarding() async {
    return _completed;
  }

  @override
  Future<void> markOnboardingCompleted() async {
    _completed = true;
    markCompletedCallCount++;
  }
}

Future<void> _pumpAppPastOnboarding(
  WidgetTester tester, {
  required _FakeAuthService authService,
}) async {
  await tester.pumpWidget(
    BudgetifyApp(
      authService: authService,
      onboardingPreferences: _FakeOnboardingPreferences(completed: true),
    ),
  );

  // Resolve the onboarding preference lookup.
  await tester.pump();

  // Allow the LoginPage startup/session lookup to run.
  await tester.pump(const Duration(milliseconds: 1000));
}

Future<void> _tapOnboardingContinue(WidgetTester tester) async {
  final button = find.widgetWithText(AppButton, 'Continue');

  expect(button, findsOneWidget);

  await tester.ensureVisible(button);

  await tester.tap(button);

  // Start PageController.animateToPage().
  await tester.pump();

  // Complete the 440 ms page animation.
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _finishOnboardingTransition(WidgetTester tester) async {
  // Flush the Future returned by the fake preference storage
  // and allow AnimatedSwitcher to start.
  await tester.pump();

  // AnimatedSwitcher lasts 380 ms.
  await tester.pump(const Duration(milliseconds: 420));
}

void main() {
  group('onboarding', () {
    testWidgets('shows onboarding before authentication on first launch', (
      WidgetTester tester,
    ) async {
      final onboardingPreferences = _FakeOnboardingPreferences(
        completed: false,
      );

      await tester.pumpWidget(
        BudgetifyApp(
          authService: _FakeAuthService(),
          onboardingPreferences: onboardingPreferences,
        ),
      );

      await tester.pump();

      expect(
        find.text('Your money, finally in one clear place.'),
        findsOneWidget,
      );

      expect(find.text('WELCOME TO BUDGETIFY'), findsOneWidget);

      expect(find.text('Skip'), findsOneWidget);

      expect(find.text('Continue'), findsOneWidget);

      expect(find.text('Continue with Google'), findsNothing);
    });

    testWidgets('moves through all onboarding slides', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        BudgetifyApp(
          authService: _FakeAuthService(),
          onboardingPreferences: _FakeOnboardingPreferences(completed: false),
        ),
      );

      await tester.pump();

      expect(
        find.text('Your money, finally in one clear place.'),
        findsOneWidget,
      );

      await _tapOnboardingContinue(tester);

      expect(find.text('Send money with confidence.'), findsOneWidget);

      expect(find.text('SMARTER PAYMENTS'), findsOneWidget);

      await _tapOnboardingContinue(tester);

      expect(find.text('Make every franc more intentional.'), findsOneWidget);

      expect(find.text('MORE CONTROL'), findsOneWidget);

      expect(find.widgetWithText(AppButton, 'Get started'), findsOneWidget);
    });

    testWidgets('completes onboarding from Get started', (
      WidgetTester tester,
    ) async {
      final onboardingPreferences = _FakeOnboardingPreferences(
        completed: false,
      );

      await tester.pumpWidget(
        BudgetifyApp(
          authService: _FakeAuthService(),
          onboardingPreferences: onboardingPreferences,
        ),
      );

      await tester.pump();

      await _tapOnboardingContinue(tester);

      await _tapOnboardingContinue(tester);

      final getStartedButton = find.widgetWithText(AppButton, 'Get started');

      expect(getStartedButton, findsOneWidget);

      await tester.ensureVisible(getStartedButton);

      await tester.tap(getStartedButton);

      await _finishOnboardingTransition(tester);

      expect(onboardingPreferences.markCompletedCallCount, 1);

      expect(find.text('Skip'), findsNothing);

      expect(
        find.text('Your money, finally in one clear place.'),
        findsNothing,
      );
    });

    testWidgets('skips onboarding and remembers completion', (
      WidgetTester tester,
    ) async {
      final onboardingPreferences = _FakeOnboardingPreferences(
        completed: false,
      );

      await tester.pumpWidget(
        BudgetifyApp(
          authService: _FakeAuthService(),
          onboardingPreferences: onboardingPreferences,
        ),
      );

      await tester.pump();

      final skipButton = find.text('Skip');

      expect(skipButton, findsOneWidget);

      await tester.tap(skipButton);

      await _finishOnboardingTransition(tester);

      expect(onboardingPreferences.markCompletedCallCount, 1);

      expect(find.text('Skip'), findsNothing);

      expect(
        find.text('Your money, finally in one clear place.'),
        findsNothing,
      );
    });
  });

  group('authentication', () {
    testWidgets('renders the auth login experience after onboarding', (
      WidgetTester tester,
    ) async {
      await _pumpAppPastOnboarding(tester, authService: _FakeAuthService());

      expect(find.text('Budgetify'), findsOneWidget);

      expect(find.text('Continue with Google'), findsOneWidget);

      expect(find.text('T&T'), findsOneWidget);
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
        accountDeletionRequestedAt: null,
        accountDeletionScheduledFor: null,
        createdAt: DateTime.utc(2026, 3, 6),
        updatedAt: DateTime.utc(2026, 3, 6),
      );

      await _pumpAppPastOnboarding(
        tester,
        authService: _FakeAuthService(restoredUser: restoredUser),
      );

      await tester.pump(const Duration(milliseconds: 1200));

      expect(find.byTooltip('Menu'), findsOneWidget);

      expect(find.text('JD'), findsOneWidget);

      expect(find.text('AMOUNT'), findsOneWidget);

      expect(find.text('Send money'), findsOneWidget);

      await tester.tap(find.byTooltip('Profile'));

      await tester.pumpAndSettle();

      expect(find.text('Personal details'), findsOneWidget);

      expect(find.text('Save changes'), findsOneWidget);

      expect(find.byTooltip('Log out'), findsOneWidget);

      expect(find.text('Delete my account'), findsNothing);

      await tester.tap(find.text('Delete account'));

      await tester.pumpAndSettle();

      expect(find.text('Delete my account'), findsOneWidget);
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
          accountDeletionRequestedAt: null,
          accountDeletionScheduledFor: null,
          createdAt: DateTime.utc(2026, 3, 29),
          updatedAt: DateTime.utc(2026, 3, 29),
        );

        final authService = _FakeAuthService(restoredUser: restoredUser);

        await _pumpAppPastOnboarding(tester, authService: authService);

        await tester.pump(const Duration(milliseconds: 600));

        expect(find.text('Complete your profile'), findsOneWidget);

        final firstNameInput = find.descendant(
          of: find.byType(AppInput).at(0),
          matching: find.byType(EditableText),
        );

        final lastNameInput = find.descendant(
          of: find.byType(AppInput).at(1),
          matching: find.byType(EditableText),
        );

        await tester.enterText(firstNameInput, 'Alice');

        await tester.enterText(lastNameInput, 'Mutoni');

        await tester.tap(find.text('Save and continue'));

        await tester.pump(const Duration(milliseconds: 400));

        await tester.pump(const Duration(milliseconds: 1200));

        expect(authService.updateCurrentUserNamesCallCount, 1);

        expect(authService.lastUpdatedFirstName, 'Alice');

        expect(authService.lastUpdatedLastName, 'Mutoni');

        expect(find.text('AM'), findsOneWidget);

        expect(find.text('AMOUNT'), findsOneWidget);
      },
    );
  });
}
