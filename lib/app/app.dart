import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/application/auth_service.dart';
import '../features/auth/application/auth_service_contract.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/partnerships/application/partnership_invite_link_store.dart';
import '../features/partnerships/presentation/partnership_view_utils.dart';

class BudgetifyApp extends StatefulWidget {
  const BudgetifyApp({super.key, this.authService});

  static final AuthServiceContract _defaultAuthService =
      AuthService.createDefault();

  final AuthServiceContract? authService;

  @override
  State<BudgetifyApp> createState() => _BudgetifyAppState();
}

class _BudgetifyAppState extends State<BudgetifyApp> {
  StreamSubscription<Uri>? _appLinkSubscription;

  AuthServiceContract get _resolvedAuthService =>
      widget.authService ?? BudgetifyApp._defaultAuthService;

  @override
  void initState() {
    super.initState();
    _initInviteLinks();
  }

  @override
  void dispose() {
    _appLinkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initInviteLinks() async {
    if (kIsWeb) {
      return;
    }

    final appLinks = AppLinks();
    final initialUri = await appLinks.getInitialLink();
    _handleIncomingInviteUri(initialUri);

    _appLinkSubscription = appLinks.uriLinkStream.listen(
      _handleIncomingInviteUri,
      onError: (_) {},
    );
  }

  void _handleIncomingInviteUri(Uri? uri) {
    if (uri == null) {
      return;
    }

    final token = extractInviteTokenFromUri(uri);
    if (token == null) {
      return;
    }

    PartnershipInviteLinkStore.instance.stageInviteToken(token);
  }

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
        home: LoginPage(authService: _resolvedAuthService),
      ),
    );
  }
}
