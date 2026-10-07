import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/data/models/auth_user.dart';
import 'app_bottom_nav_bar.dart';
import 'app_layout_section.dart';
import 'app_navbar.dart';
import 'app_sidebar.dart';

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
    this.navbarTrailing,
  });

  final AuthUser user;
  final AppLayoutSection currentSection;
  final Widget child;
  final ValueChanged<AppLayoutSection> onSectionSelected;
  final VoidCallback onAvatarTap;
  final bool scrollChild;
  final Widget? navbarTrailing;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    final isCompact = size.width < 760;
    final isLarge = size.width >= 1200;

    return Scaffold(
      backgroundColor: AppColors.background,
      drawerScrimColor: Colors.black.withValues(alpha: 0.6),
      drawer: Builder(
        builder: (drawerContext) => AppSidebar(
          user: user,
          currentSection: currentSection,
          onClose: () => Scaffold.of(drawerContext).closeDrawer(),
          onSectionSelected: (section) {
            Scaffold.of(drawerContext).closeDrawer();
            onSectionSelected(section);
          },
          onProfileTap: () {
            Scaffold.of(drawerContext).closeDrawer();
            onAvatarTap();
          },
        ),
      ),
      body: Builder(
        builder: (scaffoldContext) => SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isCompact ? 16 : isLarge ? 32 : 24,
                  isCompact ? 14 : 20,
                  isCompact ? 16 : isLarge ? 32 : 24,
                  isCompact ? 8 : 12,
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _AppContent(
                        scrollChild: scrollChild,
                        topPadding: isCompact ? 66 : 74,
                        bottomPadding: isCompact ? 84 : 96,
                        child: child,
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: AppNavbar(
                        user: user,
                        onMenuTap: () {
                          FocusScope.of(scaffoldContext).unfocus();
                          Scaffold.of(scaffoldContext).openDrawer();
                        },
                        onAvatarTap: onAvatarTap,
                        trailing: navbarTrailing,
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: AppBottomNavBar(
                        currentSection: currentSection,
                        destinations: bottomAppNavDestinations,
                        onSectionSelected: onSectionSelected,
                      ),
                    ),
                  ],
                ),
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
    required this.bottomPadding,
    required this.topPadding,
  });

  final bool scrollChild;
  final Widget child;
  final double bottomPadding;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    const constraints = BoxConstraints(
      maxWidth: 1040,
    );

    if (!scrollChild) {
      return Padding(
        padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: constraints,
            child: child,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
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
