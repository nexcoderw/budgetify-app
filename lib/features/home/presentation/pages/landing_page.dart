import 'package:flutter/material.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../../auth/application/auth_service_contract.dart';
import '../../../auth/data/models/auth_user.dart';
import '../../../expenses/application/expense_service.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../income/application/income_service.dart';
import '../../../loans/application/loan_service.dart';
import '../../../partnerships/application/partnership_service.dart';
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
  final IncomeService _incomeService = IncomeService.createDefault();
  final ExpenseService _expenseService = ExpenseService.createDefault();
  final LoanService _loanService = LoanService.createDefault();
  final SavingService _savingService = SavingService.createDefault();
  final TodoService _todoService = TodoService.createDefault();
  final PartnershipService _partnershipService =
      PartnershipService.createDefault();
  bool _isLoggingOut = false;
  AppLayoutSection _currentSection = AppLayoutSection.dashboard;

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      user: widget.user,
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
        return DashboardPage(user: widget.user);
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
          user: widget.user,
          todoService: _todoService,
          expenseService: _expenseService,
          partnershipService: _partnershipService,
          isLoggingOut: _isLoggingOut,
          onLogout: _isLoggingOut ? null : _logout,
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
