import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_input.dart';
import '../auth_password_visibility_button.dart';

class PasswordSetupForm extends StatefulWidget {
  const PasswordSetupForm({
    super.key,
    required this.isRecovery,
    required this.isSaving,
    required this.onSubmit,
  });

  final bool isRecovery;
  final bool isSaving;

  final Future<void> Function(String password, String confirmPassword) onSubmit;

  @override
  State<PasswordSetupForm> createState() => _PasswordSetupFormState();
}

class _PasswordSetupFormState extends State<PasswordSetupForm> {
  final _formKey = GlobalKey<FormState>();

  final _passwordController = TextEditingController();

  final _confirmPasswordController = TextEditingController();

  final _passwordFocusNode = FocusNode();

  final _confirmPasswordFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  String get _password => _passwordController.text;

  bool get _hasMinimumLength => _password.length >= 8;

  bool get _hasUppercase => RegExp('[A-Z]').hasMatch(_password);

  bool get _hasNumber => RegExp(r'\d').hasMatch(_password);

  bool get _hasSymbol => RegExp(r'[^A-Za-z0-9\s]').hasMatch(_password);

  bool get _isPasswordValid =>
      _hasMinimumLength && _hasUppercase && _hasNumber && _hasSymbol;

  @override
  void initState() {
    super.initState();

    _passwordController.addListener(_refreshPasswordState);
  }

  @override
  void dispose() {
    _passwordController
      ..removeListener(_refreshPasswordState)
      ..dispose();

    _confirmPasswordController.dispose();

    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();

    super.dispose();
  }

  void _refreshPasswordState() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (widget.isSaving || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    await widget.onSubmit(
      _passwordController.text,
      _confirmPasswordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 420;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 0 : 12),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.isRecovery
                  ? 'Create a new password'
                  : 'Secure your account',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: isCompact ? 22 : 25,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isRecovery
                  ? 'Choose a password you have not used before.'
                  : 'You verified your email. Create a password for faster sign-in next time.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                height: 1.55,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            AppInput(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              hintText: 'Password',
              leadingIcon: HugeIcons.strokeRoundedCirclePassword,
              obscureText: _obscurePassword,
              enableSuggestions: false,
              autocorrect: false,
              autofillHints: const [AutofillHints.newPassword],
              maxLength: 128,
              textInputAction: TextInputAction.next,
              borderRadius: 28,
              suffixIcon: AuthPasswordVisibilityButton(
                isObscured: _obscurePassword,
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              validator: (_) {
                return _isPasswordValid
                    ? null
                    : 'Use all four password requirements below';
              },
              onSubmitted: (_) {
                _confirmPasswordFocusNode.requestFocus();
              },
            ),
            const SizedBox(height: 12),
            AppInput(
              controller: _confirmPasswordController,
              focusNode: _confirmPasswordFocusNode,
              hintText: 'Confirm password',
              leadingIcon: HugeIcons.strokeRoundedCircleLockCheck02,
              obscureText: _obscureConfirmation,
              enableSuggestions: false,
              autocorrect: false,
              autofillHints: const [AutofillHints.newPassword],
              maxLength: 128,
              textInputAction: TextInputAction.done,
              borderRadius: 28,
              suffixIcon: AuthPasswordVisibilityButton(
                isObscured: _obscureConfirmation,
                onPressed: () {
                  setState(() {
                    _obscureConfirmation = !_obscureConfirmation;
                  });
                },
              ),
              validator: (value) {
                return value == _passwordController.text
                    ? null
                    : 'Passwords do not match';
              },
              onSubmitted: (_) {
                unawaited(_submit());
              },
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PasswordRule(label: '8+ characters', met: _hasMinimumLength),
                _PasswordRule(label: 'Uppercase', met: _hasUppercase),
                _PasswordRule(label: 'Number', met: _hasNumber),
                _PasswordRule(label: 'Symbol', met: _hasSymbol),
              ],
            ),
            const SizedBox(height: 24),
            AppButton(
              label: widget.isRecovery ? 'Update password' : 'Create password',
              isLoading: widget.isSaving,
              size: AppButtonSize.md,
              icon: HugeIcons.strokeRoundedPasswordValidation,
              onPressed: _isPasswordValid && !widget.isSaving
                  ? () {
                      unawaited(_submit());
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordRule extends StatelessWidget {
  const _PasswordRule({required this.label, required this.met});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: met
            ? AppColors.primary.withValues(alpha: 0.15)
            : AppColors.surfaceElevated,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: met
                ? HugeIcons.strokeRoundedCheckmarkCircle02
                : HugeIcons.strokeRoundedCircle,
            size: 14,
            color: met ? AppColors.primary : AppColors.textSecondary,
            strokeWidth: 1.8,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: met ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
