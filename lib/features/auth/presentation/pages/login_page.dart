import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../application/auth_service_contract.dart';
import '../../data/models/auth_user.dart';
import '../../data/services/google_identity_service.dart';
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
  AuthUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  Future<void> _loadPage() async {
    AuthUser? restoredUser;

    try {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      restoredUser = await widget.authService.restoreAuthenticatedUser();
    } catch (error) {
      if (mounted) {
        AppToast.info(
          context,
          title: 'Session unavailable',
          description: _readableError(error),
        );
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _currentUser = restoredUser;
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
            : _LoginForm(
                isSubmitting: _isSubmitting,
                currentUser: _currentUser,
                onSubmit: _submit,
              ),
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

      setState(() {
        _currentUser = session.user;
      });

      AppToast.success(
        context,
        title: 'Signed in successfully',
        description:
            'Connected as ${session.user.fullName ?? session.user.email}.',
      );
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
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.isSubmitting,
    required this.onSubmit,
    required this.currentUser,
  });

  final bool isSubmitting;
  final Future<void> Function() onSubmit;
  final AuthUser? currentUser;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 420;
        final panelPadding = isCompact ? 22.0 : 28.0;
        final titleSize = isCompact ? 22.0 : 24.0;
        final userLabel = currentUser?.fullName ?? currentUser?.email;
        final highlightColor = AppColors.primary.withValues(alpha: 0.14);

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
                currentUser == null
                    ? 'Budgetify helps you organize spending, monitor budgets, and keep your finances clear in one place.'
                    : 'Your Google account is connected to the Budgetify API and ready for authenticated requests.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: const [
                  _AuthSignal(
                    icon: HugeIcons.strokeRoundedShield01,
                    label: 'Verified Google identity',
                  ),
                  _AuthSignal(
                    icon: HugeIcons.strokeRoundedRefresh,
                    label: 'Rotating secure session',
                  ),
                  _AuthSignal(
                    icon: HugeIcons.strokeRoundedCheckmarkBadge02,
                    label: 'Connected to Budgetify API',
                  ),
                ],
              ),
              if (currentUser != null) ...[
                const SizedBox(height: 16),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        highlightColor,
                        Colors.white.withValues(alpha: 0.05),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          backgroundImage: currentUser!.avatarUrl == null
                              ? null
                              : NetworkImage(currentUser!.avatarUrl!),
                          child: currentUser!.avatarUrl == null
                              ? HugeIcon(
                                  icon: HugeIcons.strokeRoundedUserCircle,
                                  size: 18,
                                  color: AppColors.textPrimary,
                                  strokeWidth: 1.8,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userLabel ?? 'Connected account',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      fontSize: 12,
                                      color: AppColors.textPrimary,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                currentUser!.email,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.success.withValues(alpha: 0.24),
                            ),
                          ),
                          child: const Center(
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedCheckmarkBadge02,
                              size: 18,
                              color: AppColors.success,
                              strokeWidth: 1.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              AuthLoadingButton(
                label: currentUser == null
                    ? 'Continue with Google'
                    : 'Reconnect with Google',
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

class _AuthSignal extends StatelessWidget {
  const _AuthSignal({required this.icon, required this.label});

  final List<List<dynamic>> icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: icon,
              size: 16,
              color: AppColors.primary,
              strokeWidth: 1.8,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
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
