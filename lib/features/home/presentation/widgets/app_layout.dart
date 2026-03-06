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
    required this.onLogout,
    this.isLoggingOut = false,
  });

  final AuthUser user;
  final AppLayoutSection currentSection;
  final Widget child;
  final ValueChanged<AppLayoutSection> onSectionSelected;
  final VoidCallback? onLogout;
  final bool isLoggingOut;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 760;

    return Scaffold(
      body: DecoratedBox(
        decoration: const _AppBackgroundDecoration(),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isCompact ? 16 : 24,
                  18,
                  isCompact ? 16 : 24,
                  isCompact ? 16 : 22,
                ),
                child: Column(
                  children: [
                    AppNavbar(
                      user: user,
                      isLoggingOut: isLoggingOut,
                      onLogout: onLogout,
                    ),
                    SizedBox(height: isCompact ? 18 : 24),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1040),
                            child: child,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: isCompact ? 14 : 18),
                    AppBottomNavBar(
                      currentSection: currentSection,
                      destinations: defaultAppNavDestinations,
                      onSectionSelected: onSectionSelected,
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

class _AppBackgroundDecoration extends Decoration {
  const _AppBackgroundDecoration();

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _AppBackgroundPainter();
  }
}

class _AppBackgroundPainter extends BoxPainter {
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) {
      return;
    }

    final rect = offset & size;
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.background, Color(0xFF0E131A), Color(0xFF161E28)],
      ).createShader(rect);
    canvas.drawRect(rect, paint);

    canvas.drawCircle(
      Offset(offset.dx + size.width * 0.16, offset.dy + size.height * 0.18),
      size.shortestSide * 0.18,
      Paint()..color = AppColors.primary.withValues(alpha: 0.08),
    );
    canvas.drawCircle(
      Offset(offset.dx + size.width * 0.86, offset.dy + size.height * 0.76),
      size.shortestSide * 0.24,
      Paint()..color = Colors.white.withValues(alpha: 0.04),
    );
  }
}
