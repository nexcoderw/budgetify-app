import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/config/app_env.dart';
import 'features/auth/application/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppEnv.load();

  final authService = AuthService.createDefault();

  // On web the Google Identity Services plugin must be initialized before the
  // widget tree is built — otherwise renderButton() throws
  // "initWithParams() must be called before any other method".
  if (kIsWeb) {
    await authService.ensureInitialized();
  }

  runApp(BudgetifyApp(authService: authService));
}
