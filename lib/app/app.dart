import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

import '../core/storage/secure_storage_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/application/auth_service.dart';
import '../features/auth/application/auth_service_contract.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/onboarding/application/onboarding_preferences.dart';
import '../features/onboarding/data/services/onboarding_storage.dart';
import '../features/onboarding/presentation/pages/onboarding_page.dart';

class BudgetifyApp extends StatelessWidget {
  const BudgetifyApp({super.key, this.authService, this.onboardingPreferences});

  static final AuthServiceContract _defaultAuthService =
      AuthService.createDefault();

  static final OnboardingPreferences _defaultOnboardingPreferences =
      OnboardingStorage(secureStorageService: SecureStorageService());

  final AuthServiceContract? authService;

  final OnboardingPreferences? onboardingPreferences;

  AuthServiceContract get _resolvedAuthService =>
      authService ?? BudgetifyApp._defaultAuthService;

  OnboardingPreferences get _resolvedOnboardingPreferences =>
      onboardingPreferences ?? BudgetifyApp._defaultOnboardingPreferences;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.dark();

    return ToastificationWrapper(
      child: MaterialApp(
        title: 'Budgetify',
        debugShowCheckedModeBanner: false,
        theme: theme,
        darkTheme: theme,
        themeMode: ThemeMode.dark,
        home: _AppEntry(
          authService: _resolvedAuthService,
          onboardingPreferences: _resolvedOnboardingPreferences,
        ),
      ),
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry({
    required this.authService,
    required this.onboardingPreferences,
  });

  final AuthServiceContract authService;

  final OnboardingPreferences onboardingPreferences;

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  bool? _hasCompletedOnboarding;

  @override
  void initState() {
    super.initState();

    _loadOnboardingState();
  }

  Future<void> _loadOnboardingState() async {
    var hasCompleted = false;

    try {
      hasCompleted = await widget.onboardingPreferences
          .hasCompletedOnboarding();
    } catch (_) {
      // A storage failure should never
      // prevent the app from opening.
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _hasCompletedOnboarding = hasCompleted;
    });
  }

  Future<void> _completeOnboarding() async {
    try {
      await widget.onboardingPreferences.markOnboardingCompleted();
    } finally {
      if (mounted) {
        setState(() {
          _hasCompletedOnboarding = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCompleted = _hasCompletedOnboarding;

    if (hasCompleted == null) {
      return const _AppStartupScreen();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: hasCompleted
          ? LoginPage(
              key: const ValueKey('login'),
              authService: widget.authService,
            )
          : OnboardingPage(
              key: const ValueKey('onboarding'),
              onFinished: _completeOnboarding,
            ),
    );
  }
}

class _AppStartupScreen extends StatelessWidget {
  const _AppStartupScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(
            strokeWidth: 1.6,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
