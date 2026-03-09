import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../application/auth_service_contract.dart';
import '../../data/models/auth_user.dart';
import '../../data/services/google_identity_service.dart';
import '../../../home/presentation/pages/landing_page.dart';
import '../widgets/auth_layout.dart';
import '../widgets/auth_loading_button.dart';
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

    if (mounted) {
      setState(() {
        _isPageLoading = false;
      });
    }
  }

  Future<void> _initWebGoogleSignIn() async {
    // Use the service's ensureInitialized so the _isInitialized flag is
    // tracked correctly — prevents double-initialization on signOut().
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

      AppToast.success(
        context,
        title: 'Signed in successfully',
        description:
            'Connected as ${session.user.fullName ?? session.user.email}.',
      );

      _openLanding(session.user);
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

  @override
  Widget build(BuildContext context) {
    if (_isPageLoading) {
      return const _InitializingScreen();
    }

    return AuthLayout(
      child: _LoginForm(
        isSubmitting: _isSubmitting,
        onSubmit: kIsWeb ? null : _submit,
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
            colors: [AppColors.background, Color(0xFF0D1116), Color(0xFF131922)],
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

class _LoginForm extends StatelessWidget {
  const _LoginForm({required this.isSubmitting, required this.onSubmit});

  final bool isSubmitting;

  /// Null on web — sign-in is triggered by the Google button widget.
  final Future<void> Function()? onSubmit;

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
              if (kIsWeb)
                _WebSignInButton(isSubmitting: isSubmitting)
              else
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
                    unawaited(onSubmit!());
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

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
