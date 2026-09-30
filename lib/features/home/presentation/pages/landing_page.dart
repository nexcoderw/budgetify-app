import 'dart:async';

import 'package:flutter/material.dart';

import '../../../auth/application/auth_service_contract.dart';
import '../../../auth/data/models/auth_user.dart';
import '../../../users/presentation/pages/profile_page.dart';
import '../../application/received_transaction_sms_reconciliation_service.dart';
import '../../application/transaction_sms_reconciliation_service.dart';
import '../widgets/app_layout.dart';
import 'dashboard_page.dart';
import 'history_page.dart';
import 'send_money_page.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key, required this.authService, required this.user});

  final AuthServiceContract authService;

  final AuthUser user;

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> with WidgetsBindingObserver {
  late AuthUser _currentUser;

  late final TransactionSmsReconciliationService _smsReconciliationService;

  late final ReceivedTransactionSmsReconciliationService
  _receivedSmsReconciliationService;

  AppLayoutSection _currentSection = AppLayoutSection.sendMoney;

  bool _isReconcilingSms = false;

  int _historyRefreshToken = 0;

  int _analyticsRefreshToken = 0;

  @override
  void initState() {
    super.initState();

    _currentUser = widget.user;

    _smsReconciliationService =
        TransactionSmsReconciliationService.createDefault();

    _receivedSmsReconciliationService =
        ReceivedTransactionSmsReconciliationService.createDefault();

    WidgetsBinding.instance.addObserver(this);

    unawaited(_reconcileSmsIfAllowed());
  }

  @override
  void didUpdateWidget(covariant LandingPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.user.updatedAt != widget.user.updatedAt ||
        oldWidget.user.id != widget.user.id) {
      _currentUser = widget.user;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_reconcileSmsIfAllowed());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  Future<void> _reconcileSmsIfAllowed() async {
    if (_isReconcilingSms) {
      return;
    }

    _isReconcilingSms = true;

    var outgoingChanged = false;

    try {
      try {
        final outgoingSummary = await _smsReconciliationService
            .reconcileIfPermitted();

        outgoingChanged = outgoingSummary.hasChanges;
      } catch (_) {
        // Outgoing reconciliation is opportunistic.
        // Failure must not interrupt app usage or
        // prevent incoming evidence from being checked.
      }

      try {
        await _receivedSmsReconciliationService.reconcileIfPermitted();
      } catch (_) {
        // Incoming SMS evidence is also opportunistic.
        // It must never interrupt normal app usage.
      }

      if (!mounted || !outgoingChanged) {
        return;
      }

      setState(() {
        _historyRefreshToken++;

        _analyticsRefreshToken++;
      });
    } finally {
      _isReconcilingSms = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      user: _currentUser,
      currentSection: _currentSection,
      onSectionSelected: _selectSection,
      onAvatarTap: _openProfile,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: KeyedSubtree(
          key: ValueKey<AppLayoutSection>(_currentSection),
          child: _sectionContent(),
        ),
      ),
    );
  }

  Widget _sectionContent() {
    return switch (_currentSection) {
      AppLayoutSection.dashboard => DashboardPage(
        refreshToken: _analyticsRefreshToken,
      ),

      AppLayoutSection.history => HistoryPage(
        smsReconciliationService: _smsReconciliationService,
        refreshToken: _historyRefreshToken,
      ),

      _ => const SendMoneyPage(),
    };
  }

  void _selectSection(AppLayoutSection section) {
    if (_currentSection == section) {
      return;
    }

    setState(() {
      _currentSection = section;
    });
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => ProfilePage(
          authService: widget.authService,
          user: _currentUser,
          onUserChanged: _updateCurrentUser,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.025, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _updateCurrentUser(AuthUser user) {
    if (!mounted) {
      return;
    }

    setState(() {
      _currentUser = user;
    });
  }
}
