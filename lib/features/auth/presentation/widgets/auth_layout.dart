import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_panel.dart';
import 'auth_footer_links.dart';

class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const _AuthBackgroundDecoration(),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 34),
                child: Column(
                  children: [
                    const _AuthHeader(),
                    const SizedBox(height: 24),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: child,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const AuthFooterLinks(),
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

class _AuthHeader extends StatelessWidget {
  const _AuthHeader();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 600;
    final logoSize = isCompact ? 30.0 : 30.0;
    final logoPadding = isCompact ? 6.0 : 7.0;
    final titleSize = isCompact ? 24.0 : 26.0;

    return Row(
      children: [
        GlassPanel(
          padding: EdgeInsets.all(logoPadding),
          blur: 20,
          opacity: 0.12,
          borderRadius: BorderRadius.circular(18),
          child: Image.asset(
            'assets/branding/appstore.png',
            width: logoSize,
            height: logoSize,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            'Budgetify',
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: titleSize,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthBackgroundDecoration extends Decoration {
  const _AuthBackgroundDecoration();

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _AuthBackgroundPainter();
  }
}

class _AuthBackgroundPainter extends BoxPainter {
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
        colors: [AppColors.background, Color(0xFF0D1116), Color(0xFF131922)],
      ).createShader(rect);
    canvas.drawRect(rect, paint);

    final accentPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.08);
    canvas.drawCircle(
      Offset(offset.dx + size.width * 0.2, offset.dy + size.height * 0.18),
      size.shortestSide * 0.2,
      accentPaint,
    );
    canvas.drawCircle(
      Offset(offset.dx + size.width * 0.82, offset.dy + size.height * 0.78),
      size.shortestSide * 0.28,
      Paint()..color = Colors.white.withValues(alpha: 0.04),
    );
  }
}
