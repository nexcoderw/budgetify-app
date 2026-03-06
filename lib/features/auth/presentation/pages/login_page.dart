import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../widgets/auth_layout.dart';
import '../widgets/auth_loading_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

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
    await Future<void>.delayed(const Duration(milliseconds: 900));

    if (!mounted) {
      return;
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

    await Future<void>.delayed(const Duration(milliseconds: 1800));

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    _showFeedback('Login action is ready for your authentication integration.');
  }

  void _showFeedback(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({required this.isSubmitting, required this.onSubmit});

  final bool isSubmitting;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      key: const ValueKey('login-form'),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Welcome to Budgetify',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: 14,
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
          SkeletonBox(height: 64, radius: 22),
        ],
      ),
    );
  }
}
