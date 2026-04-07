import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../../auth/application/auth_service_contract.dart';
import '../../../auth/data/models/auth_user.dart';
import '../../../expenses/application/expense_service.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../income/application/income_service.dart';
import '../../../loans/application/loan_service.dart';
import '../../../partnerships/application/partnership_service.dart';
import '../../../partnerships/application/partnership_invite_link_store.dart';
import '../../../partnerships/presentation/pages/accept_partnership_invite_page.dart';
import '../../../savings/application/saving_service.dart';
import '../../../todos/application/todo_service.dart';
import '../../../todos/presentation/pages/todo_page.dart';
import '../widgets/app_layout.dart';
import 'dashboard/dashboard_page.dart';
import 'expense_page.dart';
import 'income_page.dart';
import 'loan_page.dart';
import 'profile_page.dart';
import 'saving_page.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key, required this.authService, required this.user});

  final AuthServiceContract authService;
  final AuthUser user;

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final PartnershipInviteLinkStore _inviteLinkStore =
      PartnershipInviteLinkStore.instance;
  final IncomeService _incomeService = IncomeService.createDefault();
  final ExpenseService _expenseService = ExpenseService.createDefault();
  final LoanService _loanService = LoanService.createDefault();
  final SavingService _savingService = SavingService.createDefault();
  final TodoService _todoService = TodoService.createDefault();
  final PartnershipService _partnershipService =
      PartnershipService.createDefault();
  late AuthUser _currentUser;
  bool _isLoggingOut = false;
  bool _isInviteAcceptanceOpen = false;
  AppLayoutSection _currentSection = AppLayoutSection.dashboard;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _inviteLinkStore.pendingInviteToken.addListener(_onPendingInviteChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onPendingInviteChanged();
    });
  }

  @override
  void dispose() {
    _inviteLinkStore.pendingInviteToken.removeListener(_onPendingInviteChanged);
    super.dispose();
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
  Widget build(BuildContext context) {
    return AppLayout(
      user: _currentUser,
      currentSection: _currentSection,
      scrollChild: _currentSection != AppLayoutSection.todos,
      isLoggingOut: _isLoggingOut,
      onLogout: _isLoggingOut ? null : _logout,
      onSectionSelected: _selectSection,
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
    switch (_currentSection) {
      case AppLayoutSection.dashboard:
        return DashboardPage(
          user: _currentUser,
          incomeService: _incomeService,
          expenseService: _expenseService,
          savingService: _savingService,
          loanService: _loanService,
          todoService: _todoService,
          partnershipService: _partnershipService,
        );
      case AppLayoutSection.income:
        return IncomePage(incomeService: _incomeService);
      case AppLayoutSection.expense:
        return ExpensePage(expenseService: _expenseService);
      case AppLayoutSection.todos:
        return TodoPage(
          todoService: _todoService,
          expenseService: _expenseService,
          embedded: true,
        );
      case AppLayoutSection.saving:
        return SavingPage(
          savingService: _savingService,
          expenseService: _expenseService,
        );
      case AppLayoutSection.loans:
        return LoanPage(loanService: _loanService);
      case AppLayoutSection.profile:
        return ProfilePage(
          user: _currentUser,
          authService: widget.authService,
          partnershipService: _partnershipService,
          isLoggingOut: _isLoggingOut,
          onLogout: _isLoggingOut ? null : _logout,
          onUserChanged: _handleUserChanged,
        );
    }
  }

  void _selectSection(AppLayoutSection section) {
    if (_currentSection == section) {
      return;
    }

    setState(() {
      _currentSection = section;
    });
  }

  void _onPendingInviteChanged() {
    unawaited(_openPendingInviteIfNeeded());
  }

  Future<void> _openPendingInviteIfNeeded() async {
    if (!mounted || _isInviteAcceptanceOpen) {
      return;
    }

    final token = await _inviteLinkStore.takePendingInviteToken();
    if (!mounted || token == null) {
      return;
    }

    _isInviteAcceptanceOpen = true;

    try {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => AcceptPartnershipInvitePage(
            currentUser: _currentUser,
            partnershipService: _partnershipService,
            initialInviteValue: token,
          ),
        ),
      );
    } finally {
      _isInviteAcceptanceOpen = false;
      if (mounted && _inviteLinkStore.pendingInviteToken.value != null) {
        unawaited(_openPendingInviteIfNeeded());
      }
    }
  }

  void _handleUserChanged(AuthUser nextUser) {
    if (!mounted) {
      return;
    }

    setState(() {
      _currentUser = nextUser;
    });
  }

  Future<void> _logout() async {
    setState(() {
      _isLoggingOut = true;
    });

    try {
      await widget.authService.logout();

      if (!mounted) {
        return;
      }

      AppToast.success(
        context,
        title: 'Signed out',
        description: 'Your Budgetify session has been closed safely.',
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => LoginPage(authService: widget.authService),
        ),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Unable to sign out',
        description: _readableError(error),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  String _readableError(Object error) {
    final message = error.toString().trim();
    if (message.startsWith('Exception: ')) {
      return message.replaceFirst('Exception: ', '');
    }

    if (message.startsWith('StateError: ')) {
      return message.replaceFirst('StateError: ', '');
    }

    return message;
  }
}
