import 'package:flutter/material.dart';

import '../../../auth/application/auth_service_contract.dart';
import '../../../auth/data/models/auth_user.dart';
import '../../../users/presentation/pages/profile_page.dart';
import '../widgets/app_layout.dart';
import 'history_page.dart';
import 'send_money_page.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key, required this.authService, required this.user});

  final AuthServiceContract authService;
  final AuthUser user;

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  late AuthUser _currentUser;
  AppLayoutSection _currentSection = AppLayoutSection.sendMoney;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
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
    if (_currentSection == AppLayoutSection.history) {
      return const HistoryPage();
    }

    return const SendMoneyPage();
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
