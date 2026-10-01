import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_input.dart';
import '../../../../../core/widgets/app_toast.dart';
import '../auth_password_visibility_button.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({
    super.key,
    required this.isEmailSubmitting,
    required this.isGoogleSubmitting,
    required this.onCheckPasswordStatus,
    required this.onPasswordSubmit,
    required this.onStartPasswordSetup,
    required this.onGoogleSubmit,
    required this.webGoogleButtonBuilder,
  });

  final bool isEmailSubmitting;
  final bool isGoogleSubmitting;

  final Future<bool> Function(String email) onCheckPasswordStatus;

  final Future<void> Function(String email, String password) onPasswordSubmit;

  final Future<void> Function(String email, {required bool isRecovery})
  onStartPasswordSetup;

  /// Null on web. Web Google authentication is started
  /// by the Google-rendered button.
  final Future<void> Function()? onGoogleSubmit;

  /// Supplied by LoginPage so the conditional web import
  /// remains at the page boundary.
  final Widget Function()? webGoogleButtonBuilder;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  late final AnimationController _entranceController;

  Timer? _emailCheckTimer;

  bool _hasEmail = false;
  bool? _hasPassword;
  bool _isCheckingEmail = false;
  bool _obscurePassword = true;

  bool get _showsGoogleSignIn {
    return kIsWeb || defaultTargetPlatform != TargetPlatform.iOS;
  }

  bool get _hasValidEmail {
    return RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(_emailController.text.trim());
  }

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _emailController.addListener(_handleEmailChanged);
  }

  @override
  void dispose() {
    _emailCheckTimer?.cancel();

    _emailController
      ..removeListener(_handleEmailChanged)
      ..dispose();

    _passwordController.dispose();

    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();

    _entranceController.dispose();

    super.dispose();
  }

  Animation<double> _fadeAt(double start, double end) {
    return CurvedAnimation(
      parent: _entranceController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  Animation<Offset> _slideAt(double start, double end) {
    return Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      ),
    );
  }

  void _handleEmailChanged() {
    final hasText = _emailController.text.isNotEmpty;

    _emailCheckTimer?.cancel();

    setState(() {
      _hasEmail = hasText;
      _hasPassword = null;

      _passwordController.clear();
    });

    if (!_hasValidEmail) {
      return;
    }

    final checkedEmail = _emailController.text.trim();

    _emailCheckTimer = Timer(const Duration(milliseconds: 500), () {
      unawaited(_checkEmailInBackground(checkedEmail));
    });
  }

  Future<void> _checkEmailInBackground(String email) async {
    if (mounted) {
      setState(() {
        _isCheckingEmail = true;
      });
    }

    try {
      final hasPassword = await widget.onCheckPasswordStatus(email);

      if (!mounted || email != _emailController.text.trim()) {
        return;
      }

      setState(() {
        _hasPassword = hasPassword;
      });
    } catch (_) {
      // Background account discovery stays silent.
      // A foreground submit surfaces the failure.
    } finally {
      if (mounted && email == _emailController.text.trim()) {
        setState(() {
          _isCheckingEmail = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final email = _emailController.text.trim();

    var hasPassword = _hasPassword;

    if (hasPassword == null) {
      setState(() {
        _isCheckingEmail = true;
      });

      try {
        hasPassword = await widget.onCheckPasswordStatus(email);

        if (!mounted) {
          return;
        }

        setState(() {
          _hasPassword = hasPassword;
        });
      } catch (error) {
        if (mounted) {
          AppToast.error(
            context,
            title: 'Could not check account',
            description: error.toString(),
          );
        }

        return;
      } finally {
        if (mounted) {
          setState(() {
            _isCheckingEmail = false;
          });
        }
      }
    }

    if (hasPassword == true) {
      if (_passwordController.text.isEmpty) {
        _passwordFocusNode.requestFocus();

        return;
      }

      await widget.onPasswordSubmit(email, _passwordController.text);

      return;
    }

    await widget.onStartPasswordSetup(email, isRecovery: false);
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 420;

    final horizontalPadding = isCompact ? 0.0 : 12.0;

    final titleSize = isCompact ? 22.0 : 24.0;

    final showsPassword = _hasPassword == true;

    final subtitle = _showsGoogleSignIn
        ? 'Use your email and password, or continue with Google.'
        : 'Use your email and password to continue securely.';

    final buttonLabel = _hasPassword == false
        ? 'Set up password'
        : showsPassword
        ? 'Sign in'
        : 'Continue';

    return Padding(
      key: const ValueKey('login-form'),
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _fadeAt(0.0, 0.55),
              child: SlideTransition(
                position: _slideAt(0.0, 0.55),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sign in to Budgetify',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontSize: titleSize,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FadeTransition(
              opacity: _fadeAt(0.1, 0.65),
              child: SlideTransition(
                position: _slideAt(0.1, 0.65),
                child: AppInput(
                  controller: _emailController,
                  focusNode: _emailFocusNode,
                  hintText: 'Your email address',
                  leadingIcon: HugeIcons.strokeRoundedMail01,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: showsPassword
                      ? TextInputAction.next
                      : TextInputAction.done,
                  autocorrect: false,
                  borderRadius: 28,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w400,
                  ),
                  suffixIcon: _hasEmail
                      ? _ClearButton(
                          onTap: () {
                            _emailController.clear();

                            _emailFocusNode.requestFocus();
                          },
                        )
                      : null,
                  validator: (value) {
                    final email = value?.trim() ?? '';

                    if (email.isEmpty) {
                      return 'Please enter your email address';
                    }

                    if (!RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    ).hasMatch(email)) {
                      return 'Please enter a valid email address';
                    }

                    return null;
                  },
                  onSubmitted: (_) {
                    if (showsPassword) {
                      _passwordFocusNode.requestFocus();
                    } else {
                      unawaited(_submit());
                    }
                  },
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: showsPassword
                  ? Padding(
                      key: const ValueKey('password-field'),
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppInput(
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            hintText: 'Your password',
                            leadingIcon: HugeIcons.strokeRoundedCirclePassword,
                            obscureText: _obscurePassword,
                            enableSuggestions: false,
                            autocorrect: false,
                            autofillHints: const [AutofillHints.password],
                            maxLength: 128,
                            textInputAction: TextInputAction.done,
                            borderRadius: 28,
                            suffixIcon: AuthPasswordVisibilityButton(
                              isObscured: _obscurePassword,
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            validator: (value) {
                              if (_hasPassword == true &&
                                  (value?.isEmpty ?? true)) {
                                return 'Please enter your password';
                              }

                              return null;
                            },
                            onSubmitted: (_) {
                              unawaited(_submit());
                            },
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: widget.isEmailSubmitting
                                  ? null
                                  : () {
                                      unawaited(
                                        widget.onStartPasswordSetup(
                                          _emailController.text.trim(),
                                          isRecovery: true,
                                        ),
                                      );
                                    },
                              child: const Text('Forgot password?'),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('no-password-field')),
            ),
            const SizedBox(height: 12),
            FadeTransition(
              opacity: _fadeAt(0.2, 0.75),
              child: SlideTransition(
                position: _slideAt(0.2, 0.75),
                child: AppButton(
                  label: buttonLabel,
                  isLoading: widget.isEmailSubmitting || _isCheckingEmail,
                  size: AppButtonSize.md,
                  icon: HugeIcons.strokeRoundedSent,
                  onPressed: () {
                    unawaited(_submit());
                  },
                ),
              ),
            ),
            if (_showsGoogleSignIn) ...[
              const SizedBox(height: 22),
              FadeTransition(
                opacity: _fadeAt(0.3, 0.85),
                child: SlideTransition(
                  position: _slideAt(0.3, 0.85),
                  child: const _OrDivider(),
                ),
              ),
              const SizedBox(height: 22),
              FadeTransition(
                opacity: _fadeAt(0.4, 1.0),
                child: SlideTransition(
                  position: _slideAt(0.4, 1.0),
                  child: kIsWeb
                      ? _WebGoogleButton(
                          isSubmitting: widget.isGoogleSubmitting,
                          builder: widget.webGoogleButtonBuilder,
                        )
                      : AppButton(
                          label: 'Continue with Google',
                          isLoading: widget.isGoogleSubmitting,
                          size: AppButtonSize.md,
                          variant: AppButtonVariant.secondary,
                          iconWidget: Image.asset(
                            'assets/images/google.png',
                            fit: BoxFit.contain,
                          ),
                          onPressed: widget.onGoogleSubmit == null
                              ? null
                              : () {
                                  unawaited(widget.onGoogleSubmit!());
                                },
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ClearButton extends StatefulWidget {
  const _ClearButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_ClearButton> createState() => _ClearButtonState();
}

class _ClearButtonState extends State<_ClearButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) {
        setState(() {
          _pressed = true;
        });
      },
      onTapUp: (_) {
        setState(() {
          _pressed = false;
        });
      },
      onTapCancel: () {
        setState(() {
          _pressed = false;
        });
      },
      child: AnimatedScale(
        scale: _pressed ? 0.86 : 1,
        duration: const Duration(milliseconds: 120),
        child: const Padding(
          padding: EdgeInsets.only(right: 14),
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedCancel01,
            size: 16,
            color: AppColors.textSecondary,
            strokeWidth: 1.8,
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'or',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: AppColors.textSecondary,
              letterSpacing: 0.4,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
      ],
    );
  }
}

class _WebGoogleButton extends StatelessWidget {
  const _WebGoogleButton({required this.isSubmitting, required this.builder});

  final bool isSubmitting;

  final Widget Function()? builder;

  @override
  Widget build(BuildContext context) {
    if (isSubmitting) {
      return const SizedBox(
        height: 56,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              strokeWidth: 1.6,
            ),
          ),
        ),
      );
    }

    final googleButtonBuilder = builder;

    if (googleButtonBuilder == null) {
      return const SizedBox.shrink();
    }

    return Center(child: googleButtonBuilder());
  }
}
