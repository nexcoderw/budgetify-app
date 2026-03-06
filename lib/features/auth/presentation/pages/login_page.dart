import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../application/auth_service_contract.dart';
import '../../data/models/auth_user.dart';
import '../../data/services/google_identity_service.dart';
import '../../../home/presentation/pages/landing_page.dart';
import '../widgets/auth_layout.dart';
import '../widgets/auth_loading_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.authService});

  final AuthServiceContract authService;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isPageLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  Future<void> _loadPage() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      final restoredUser = await widget.authService.restoreAuthenticatedUser();

      if (!mounted) {
        return;
      }

      if (restoredUser != null) {
        _openLanding(restoredUser);
        return;
      }
    } catch (error) {
      if (mounted) {
        AppToast.info(
          context,
          title: 'Session unavailable',
          description: _readableError(error),
        );
      }
    }

    setState(() {
      _isPageLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _isPageLoading
            ? const _LoginPageSkeleton()
            : _LoginForm(isSubmitting: _isSubmitting, onSubmit: _submit),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final session = await widget.authService.signInWithGoogle();

      if (!mounted) {
        return;
      }

      AppToast.success(
        context,
        title: 'Signed in successfully',
        description:
            'Connected as ${session.user.fullName ?? session.user.email}.',
      );

      _openLanding(session.user);
    } on GoogleIdentityException catch (error) {
      if (!mounted) {
        return;
      }

      final message = _readableError(error);
      if (error.isCanceled) {
        AppToast.info(context, title: 'Sign-in canceled', description: message);
      } else {
        AppToast.error(
          context,
          title: 'Google sign-in unavailable',
          description: message,
        );
      }
    } catch (error) {
      if (mounted) {
        AppToast.error(
          context,
          title: 'Sign-in failed',
          description: _readableError(error),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
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

  void _openLanding(AuthUser user) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            LandingPage(authService: widget.authService, user: user),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.03),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({required this.isSubmitting, required this.onSubmit});

  final bool isSubmitting;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 420;
        final panelPadding = isCompact ? 22.0 : 28.0;
        final titleSize = isCompact ? 22.0 : 24.0;

        return GlassPanel(
          key: const ValueKey('login-form'),
          padding: EdgeInsets.all(panelPadding),
          borderRadius: BorderRadius.circular(34),
          blur: 26,
          opacity: 0.16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Welcome to Budgetify',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: titleSize,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Budgetify helps you organize spending, monitor budgets, and keep your finances clear in one place.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              const SizedBox(height: 20),
              AuthLoadingButton(
                label: 'Continue with Google',
                loadingLabel: 'Connecting to Google',
                isLoading: isSubmitting,
                fontSize: 12,
                leading: Image.asset(
                  'assets/images/google.png',
                  width: 18,
                  height: 18,
                ),
                onPressed: () {
                  unawaited(onSubmit());
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LoginPageSkeleton extends StatelessWidget {
  const _LoginPageSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: Column(
        key: const ValueKey('login-skeleton'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SkeletonBox(width: 160, height: 18, radius: 12),
          SizedBox(height: 8),
          SkeletonBox(height: 14, radius: 10),
          SizedBox(height: 8),
          SkeletonBox(width: 220, height: 14, radius: 10),
          SizedBox(height: 20),
          SkeletonBox(height: 56, radius: 28),
        ],
      ),
    );
  }
}
