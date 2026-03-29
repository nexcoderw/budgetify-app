import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../application/auth_service_contract.dart';
import '../../data/models/auth_user.dart';
import '../../data/services/google_identity_service.dart';
import '../../../home/presentation/pages/landing_page.dart';
import '../widgets/auth_layout.dart';
import '../widgets/auth_loading_button.dart';
import '../widgets/profile_completion_dialog.dart';
import 'email_otp_page.dart';
import 'web_render_button_stub.dart'
    if (dart.library.js_util) 'web_render_button_web.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.authService});

  final AuthServiceContract authService;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isPageLoading = true;
  bool _isSubmitting = false;
  bool _isEmailSubmitting = false;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _webGoogleSub;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  @override
  void dispose() {
    _webGoogleSub?.cancel();
    super.dispose();
  }

  Future<void> _loadPage() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 900));

      if (kIsWeb) {
        await _initWebGoogleSignIn();
      }

      final restoredUser = await widget.authService.restoreAuthenticatedUser();

      if (!mounted) {
        return;
      }

      if (restoredUser != null) {
        final resolvedUser = await ProfileCompletionDialog.showIfRequired(
          context,
          authService: widget.authService,
          user: restoredUser,
        );

        if (!mounted) {
          return;
        }

        _openLanding(resolvedUser);
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

    if (mounted) {
      setState(() {
        _isPageLoading = false;
      });
    }
  }

  Future<void> _initWebGoogleSignIn() async {
    await widget.authService.ensureInitialized();

    _webGoogleSub = GoogleSignIn.instance.authenticationEvents.listen(
      _onWebAuthEvent,
      onError: _onWebAuthError,
    );
  }

  void _onWebAuthEvent(GoogleSignInAuthenticationEvent event) {
    if (!mounted) return;

    if (event is GoogleSignInAuthenticationEventSignIn) {
      final idToken = event.user.authentication.idToken;

      if (idToken == null || idToken.isEmpty) {
        AppToast.error(
          context,
          title: 'Sign-in failed',
          description:
              'Google did not return an ID token. Check your OAuth configuration.',
        );
        return;
      }

      unawaited(_submitWebToken(idToken));
    }
  }

  void _onWebAuthError(Object error) {
    if (!mounted) return;

    AppToast.error(
      context,
      title: 'Google sign-in failed',
      description: _readableError(error),
    );
  }

  Future<void> _submitWebToken(String idToken) async {
    setState(() => _isSubmitting = true);

    try {
      final session = await widget.authService.signInWithGoogleIdToken(idToken);

      if (!mounted) return;

      final resolvedUser = await ProfileCompletionDialog.showIfRequired(
        context,
        authService: widget.authService,
        user: session.user,
      );

      if (!mounted) return;

      AppToast.success(
        context,
        title: 'Signed in successfully',
        description:
            'Connected as ${resolvedUser.fullName ?? resolvedUser.email}.',
      );

      _openLanding(resolvedUser);
    } catch (error) {
      if (mounted) {
        AppToast.error(
          context,
          title: 'Sign-in failed',
          description: _readableError(error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitEmail(String email) async {
    setState(() => _isEmailSubmitting = true);

    try {
      final response = await widget.authService.initiateEmailAuth(email);

      if (!mounted) return;

      Navigator.of(context).push(
        PageRouteBuilder<void>(
          pageBuilder: (context, animation, secondaryAnimation) => EmailOtpPage(
            authService: widget.authService,
            email: email,
            initiateResponse: response,
          ),
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
    } catch (error) {
      if (mounted) {
        AppToast.error(
          context,
          title: 'Could not send code',
          description: _readableError(error),
        );
      }
    } finally {
      if (mounted) setState(() => _isEmailSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isPageLoading) {
      return const _InitializingScreen();
    }

    return AuthLayout(
      child: _LoginForm(
        isEmailSubmitting: _isEmailSubmitting,
        isGoogleSubmitting: _isSubmitting,
        onEmailSubmit: _submitEmail,
        onGoogleSubmit: kIsWeb ? null : _submit,
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

      final resolvedUser = await ProfileCompletionDialog.showIfRequired(
        context,
        authService: widget.authService,
        user: session.user,
      );

      if (!mounted) {
        return;
      }

      AppToast.success(
        context,
        title: 'Signed in successfully',
        description:
            'Connected as ${resolvedUser.fullName ?? resolvedUser.email}.',
      );

      _openLanding(resolvedUser);
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

// ── Initializing splash ──────────────────────────────────────────────────────

class _InitializingScreen extends StatelessWidget {
  const _InitializingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.background,
              Color(0xFF0D1116),
              Color(0xFF131922),
            ],
          ),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                strokeWidth: 1.6,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Login form ───────────────────────────────────────────────────────────────

class _LoginForm extends StatefulWidget {
  const _LoginForm({
    required this.isEmailSubmitting,
    required this.isGoogleSubmitting,
    required this.onEmailSubmit,
    required this.onGoogleSubmit,
  });

  final bool isEmailSubmitting;
  final bool isGoogleSubmitting;
  final Future<void> Function(String email) onEmailSubmit;

  /// Null on web — Google sign-in is triggered by the rendered button widget.
  final Future<void> Function()? onGoogleSubmit;

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _emailFocusNode = FocusNode();
  late final AnimationController _entranceController;
  bool _hasEmail = false;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _emailController.addListener(() {
      final hasText = _emailController.text.isNotEmpty;
      if (hasText != _hasEmail) {
        setState(() => _hasEmail = hasText);
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  Animation<double> _fadeAt(double start, double end) => CurvedAnimation(
    parent: _entranceController,
    curve: Interval(start, end, curve: Curves.easeOutCubic),
  );

  Animation<Offset> _slideAt(double start, double end) =>
      Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _entranceController,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    unawaited(widget.onEmailSubmit(_emailController.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 420;
    final panelPadding = isCompact ? 22.0 : 28.0;
    final titleSize = isCompact ? 22.0 : 24.0;

    return GlassPanel(
      key: const ValueKey('login-form'),
      padding: EdgeInsets.all(panelPadding),
      borderRadius: BorderRadius.circular(34),
      blur: 26,
      opacity: 0.16,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Title & subtitle ────────────────────────────────────────────
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
                      'Enter your email to receive a one-time code, or continue with Google.',
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

            // ── Email field ─────────────────────────────────────────────────
            FadeTransition(
              opacity: _fadeAt(0.1, 0.65),
              child: SlideTransition(
                position: _slideAt(0.1, 0.65),
                child: _EmailField(
                  controller: _emailController,
                  focusNode: _emailFocusNode,
                  hasText: _hasEmail,
                  onClear: () {
                    _emailController.clear();
                    _emailFocusNode.requestFocus();
                  },
                  onSubmitted: (_) => _submit(),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Continue button ─────────────────────────────────────────────
            FadeTransition(
              opacity: _fadeAt(0.2, 0.75),
              child: SlideTransition(
                position: _slideAt(0.2, 0.75),
                child: AuthLoadingButton(
                  label: 'Continue with email',
                  loadingLabel: 'Sending code…',
                  isLoading: widget.isEmailSubmitting,
                  fontSize: 14,
                  leading: HugeIcon(
                    icon: HugeIcons.strokeRoundedSent,
                    size: 18,
                    color: AppColors.background,
                    strokeWidth: 1.8,
                  ),
                  onPressed: _submit,
                ),
              ),
            ),

            const SizedBox(height: 22),

            // ── OR divider ──────────────────────────────────────────────────
            FadeTransition(
              opacity: _fadeAt(0.3, 0.85),
              child: SlideTransition(
                position: _slideAt(0.3, 0.85),
                child: const _OrDivider(),
              ),
            ),

            const SizedBox(height: 22),

            // ── Google button ───────────────────────────────────────────────
            FadeTransition(
              opacity: _fadeAt(0.4, 1.0),
              child: SlideTransition(
                position: _slideAt(0.4, 1.0),
                child: kIsWeb
                    ? _WebSignInButton(isSubmitting: widget.isGoogleSubmitting)
                    : AuthLoadingButton(
                        label: 'Continue with Google',
                        loadingLabel: 'Connecting to Google…',
                        isLoading: widget.isGoogleSubmitting,
                        fontSize: 14,
                        leading: Image.asset(
                          'assets/images/google.png',
                          width: 18,
                          height: 18,
                        ),
                        onPressed: () {
                          unawaited(widget.onGoogleSubmit!());
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Email input field ────────────────────────────────────────────────────────

class _EmailField extends StatefulWidget {
  const _EmailField({
    required this.controller,
    required this.focusNode,
    required this.hasText,
    required this.onClear,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasText;
  final VoidCallback onClear;
  final ValueChanged<String> onSubmitted;

  @override
  State<_EmailField> createState() => _EmailFieldState();
}

class _EmailFieldState extends State<_EmailField> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _isFocused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  blurRadius: 16,
                  spreadRadius: 0,
                ),
              ]
            : [],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        autocorrect: false,
        onFieldSubmitted: widget.onSubmitted,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w400,
        ),
        validator: (value) {
          final v = value?.trim() ?? '';
          if (v.isEmpty) return 'Please enter your email address';
          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
            return 'Please enter a valid email address';
          }
          return null;
        },
        decoration: InputDecoration(
          hintText: 'Your email address',
          hintStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 18, right: 12),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedMail01,
              size: 18,
              color: _isFocused ? AppColors.primary : AppColors.textSecondary,
              strokeWidth: 1.8,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          suffixIcon: widget.hasText
              ? _ClearButton(onTap: widget.onClear)
              : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 17,
          ),
          filled: true,
          fillColor: AppColors.surfaceElevated,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
          ),
          errorStyle: const TextStyle(fontSize: 11, color: AppColors.danger),
        ),
      ),
    );
  }
}

// ── Clear field button ───────────────────────────────────────────────────────

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
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.86 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Padding(
          padding: const EdgeInsets.only(right: 14),
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

// ── OR divider ───────────────────────────────────────────────────────────────

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

// ── Web Google sign-in button ────────────────────────────────────────────────

class _WebSignInButton extends StatelessWidget {
  const _WebSignInButton({required this.isSubmitting});

  final bool isSubmitting;

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

    return Center(child: renderGoogleSignInButton());
  }
}
