import 'dart:async';

import 'package:flutter/material.dart';

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
        mainAxisSize: MainAxisSize.min,
        children: [
          AuthLoadingButton(
            label: 'Continue with google',
            loadingLabel: 'Connecting to google',
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
        children: const [SkeletonBox(height: 64, radius: 22)],
      ),
    );
  }
}
