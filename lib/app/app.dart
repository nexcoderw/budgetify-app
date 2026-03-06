import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/application/auth_service.dart';
import '../features/auth/application/auth_service_contract.dart';
import '../features/auth/presentation/pages/login_page.dart';

class BudgetifyApp extends StatelessWidget {
  const BudgetifyApp({super.key, this.authService});

  static final AuthServiceContract _defaultAuthService =
      AuthService.createDefault();

  final AuthServiceContract? authService;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.dark();
    final resolvedAuthService = authService ?? _defaultAuthService;

    return ToastificationWrapper(
      child: MaterialApp(
        title: 'Budgetify',
        debugShowCheckedModeBanner: false,
        theme: theme,
        darkTheme: theme,
        themeMode: ThemeMode.dark,
        home: LoginPage(authService: resolvedAuthService),
      ),
    );
  }
}
