import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/data/models/auth_user.dart';
import 'app_bottom_nav_bar.dart';
import 'app_layout_section.dart';
import 'app_navbar.dart';

export 'app_layout_section.dart';

class AppLayout extends StatelessWidget {
  const AppLayout({
    super.key,
    required this.user,
    required this.currentSection,
    required this.child,
    required this.onSectionSelected,
    required this.onAvatarTap,
    this.scrollChild = true,
  });

  final AuthUser user;
  final AppLayoutSection currentSection;
  final Widget child;
  final ValueChanged<AppLayoutSection> onSectionSelected;
  final VoidCallback onAvatarTap;
  final bool scrollChild;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    final isCompact = size.width < 760;
    final isLarge = size.width >= 1200;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 1320,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isCompact
                    ? 16
                    : isLarge
                        ? 32
                        : 24,
                isCompact ? 14 : 20,
                isCompact
                    ? 16
                    : isLarge
                        ? 32
                        : 24,
                isCompact ? 8 : 12,
              ),
              child: Column(
                children: [
                  AppNavbar(
                    user: user,
                    onAvatarTap: onAvatarTap,
                  ),

                  SizedBox(
                    height: isCompact ? 20 : 28,
                  ),

                  Expanded(
                    child: _AppContent(
                      scrollChild: scrollChild,
                      child: child,
                    ),
                  ),

                  SizedBox(
                    height: isCompact ? 16 : 22,
                  ),

                  AppBottomNavBar(
                    currentSection: currentSection,
                    destinations: bottomAppNavDestinations,
                    onSectionSelected: onSectionSelected,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppContent extends StatelessWidget {
  const _AppContent({
    required this.scrollChild,
    required this.child,
  });

  final bool scrollChild;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const constraints = BoxConstraints(
      maxWidth: 1040,
    );

    if (!scrollChild) {
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: constraints,
          child: child,
        ),
      );
    }

    return SingleChildScrollView(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: constraints,
          child: child,
        ),
      ),
    );
  }
}
