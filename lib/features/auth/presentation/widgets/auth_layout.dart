import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'auth_footer_links.dart';

class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.child,
    this.headerTrailing,
  });

  final Widget child;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final safePadding = MediaQuery.paddingOf(context);
    final availableFormHeight =
        screenHeight - safePadding.vertical - 163;
    final minimumFormHeight = availableFormHeight > 0
        ? availableFormHeight
        : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: SizedBox.expand(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  children: [
                    _AuthHeader(
                      trailing: headerTrailing,
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.only(
                          bottom: keyboardInset,
                        ),
                        child: Column(
                          children: [
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: minimumFormHeight,
                              ),
                              child: AnimatedPadding(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOutCubic,
                                padding: EdgeInsets.only(
                                  bottom: keyboardInset,
                                ),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 520,
                                    ),
                                    child: child,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const AuthFooterLinks(),
                          ],
                        ),
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

class _AuthHeader extends StatelessWidget {
  const _AuthHeader({
    this.trailing,
  });

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 600;
    final logoWidth = isCompact ? 38.0 : 42.0;
    final logoHeight = isCompact ? 30.0 : 33.0;
    final logoPadding = isCompact ? 6.0 : 7.0;
    final titleSize = isCompact ? 24.0 : 26.0;

    return Row(
      children: [
        Padding(
          padding: EdgeInsets.all(logoPadding),
          child: Image.asset(
            'assets/branding/png/tight/logo-color-beige-512.png',
            width: logoWidth,
            height: logoHeight,
            fit: BoxFit.contain,
            semanticLabel: 'Budgetify logo',
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
        if (trailing != null) ...[
          const SizedBox(width: 16),
          trailing!,
        ],
      ],
    );
  }
}
