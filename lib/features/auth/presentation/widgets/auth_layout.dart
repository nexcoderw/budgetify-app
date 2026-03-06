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
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
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
                    const SizedBox(height: 18),
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
    return Row(
      children: [
        const GlassBadge(
          padding: EdgeInsets.all(10),
          child: Icon(
            Icons.account_balance_wallet_rounded,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 14),
        Text(
          'Budgetify',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 28,
            color: AppColors.textPrimary,
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
