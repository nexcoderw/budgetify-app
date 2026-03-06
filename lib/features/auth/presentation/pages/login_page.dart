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
  bool _rememberMe = true;
  bool _obscurePassword = true;
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
            : _LoginForm(
                rememberMe: _rememberMe,
                obscurePassword: _obscurePassword,
                isSubmitting: _isSubmitting,
                onRememberMeChanged: (value) {
                  setState(() {
                    _rememberMe = value;
                  });
                },
                onTogglePasswordVisibility: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                onForgotPassword: () => _showFeedback(
                  'Password reset can be connected once the recovery flow is ready.',
                ),
                onSubmit: _submit,
              ),
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
  const _LoginForm({
    required this.rememberMe,
    required this.obscurePassword,
    required this.isSubmitting,
    required this.onRememberMeChanged,
    required this.onTogglePasswordVisibility,
    required this.onForgotPassword,
    required this.onSubmit,
  });

  final bool rememberMe;
  final bool obscurePassword;
  final bool isSubmitting;
  final ValueChanged<bool> onRememberMeChanged;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onForgotPassword;
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
          const GlassBadge(
            child: Text('Member access', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(height: 20),
          Text(
            'Welcome back',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Sign in to continue into your budgeting workspace.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 28),
          const _SectionLabel('Work email'),
          const SizedBox(height: 10),
          const _GlassTextField(
            keyboardType: TextInputType.emailAddress,
            hintText: 'name@company.com',
            prefixIcon: Icon(Icons.mail_outline_rounded),
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Password'),
          const SizedBox(height: 10),
          _GlassTextField(
            obscureText: obscurePassword,
            hintText: 'Enter your password',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              onPressed: onTogglePasswordVisibility,
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  value: rememberMe,
                  onChanged: (value) => onRememberMeChanged(value ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  checkboxShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  title: const Text(
                    'Keep me signed in',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: onForgotPassword,
                style: TextButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text('Forgot password?'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AuthLoadingButton(
            label: 'Sign in',
            loadingLabel: 'Signing in',
            isLoading: isSubmitting,
            fontSize: 12,
            onPressed: () {
              unawaited(onSubmit());
            },
          ),
          const SizedBox(height: 18),
          const _TrustPanel(),
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
          SkeletonBox(width: 118, height: 38, radius: 999),
          SizedBox(height: 22),
          SkeletonBox(width: 180, height: 34, radius: 18),
          SizedBox(height: 12),
          SkeletonBox(height: 15),
          SizedBox(height: 8),
          SkeletonBox(width: 230, height: 15),
          SizedBox(height: 28),
          SkeletonBox(width: 90, height: 16),
          SizedBox(height: 10),
          SkeletonBox(height: 58, radius: 18),
          SizedBox(height: 20),
          SkeletonBox(width: 90, height: 16),
          SizedBox(height: 10),
          SkeletonBox(height: 58, radius: 18),
          SizedBox(height: 18),
          SkeletonBox(height: 20, width: 200),
          SizedBox(height: 18),
          SkeletonBox(height: 64, radius: 22),
          SizedBox(height: 18),
          SkeletonBox(height: 92, radius: 22),
        ],
      ),
    );
  }
}

class _GlassTextField extends StatelessWidget {
  const _GlassTextField({
    this.keyboardType,
    this.obscureText = false,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
  });

  final TextInputType? keyboardType;
  final bool obscureText;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      blur: 18,
      opacity: 0.08,
      borderRadius: BorderRadius.circular(22),
      padding: EdgeInsets.zero,
      child: TextField(
        keyboardType: keyboardType,
        obscureText: obscureText,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}

class _TrustPanel extends StatelessWidget {
  const _TrustPanel();

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      blur: 18,
      opacity: 0.08,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const GlassBadge(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.verified_user_outlined, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Protected workspace. The authentication surface is ready for backend wiring and polished loading states.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: AppColors.textPrimary,
        fontSize: 12,
      ),
    );
  }
}
