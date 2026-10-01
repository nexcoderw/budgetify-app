import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../application/auth_service_contract.dart';
import '../../data/services/google_identity_service.dart';
import '../auth_post_auth_navigation.dart';
import '../auth_readable_error.dart';
import '../widgets/auth_layout.dart';
import '../widgets/login/login_form.dart';
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

        await openPostAuthDestination(
          context: context,
          authService: widget.authService,
          user: resolvedUser,
        );

        return;
      }
    } catch (error) {
      if (mounted) {
        AppToast.info(
          context,
          title: 'Session unavailable',
          description: readableAuthError(error),
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
    if (!mounted) {
      return;
    }

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
    if (!mounted) {
      return;
    }

    AppToast.error(
      context,
      title: 'Google sign-in failed',
      description: readableAuthError(error),
    );
  }

  Future<void> _submitWebToken(String idToken) async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final session = await widget.authService.signInWithGoogleIdToken(idToken);

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
            'Connected as '
            '${resolvedUser.fullName ?? resolvedUser.email}.',
      );

      await openPostAuthDestination(
        context: context,
        authService: widget.authService,
        user: resolvedUser,
      );
    } catch (error) {
      if (mounted) {
        AppToast.error(
          context,
          title: 'Sign-in failed',
          description: readableAuthError(error),
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

  Future<bool> _checkPasswordStatus(String email) async {
    final status = await widget.authService.getPasswordStatus(email);

    return status.hasPassword;
  }

  Future<void> _startPasswordSetup(
    String email, {
    required bool isRecovery,
  }) async {
    setState(() {
      _isEmailSubmitting = true;
    });

    try {
      final challenge = await widget.authService.requestPasswordChallenge(
        email,
      );

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        PageRouteBuilder<void>(
          pageBuilder: (context, animation, secondaryAnimation) {
            return EmailOtpPage(
              authService: widget.authService,
              email: email,
              challenge: challenge,
              isRecovery: isRecovery,
            );
          },
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
          title: 'Could not verify email',
          description: readableAuthError(error),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isEmailSubmitting = false;
        });
      }
    }
  }

  Future<void> _submitPassword(String email, String password) async {
    setState(() {
      _isEmailSubmitting = true;
    });

    try {
      final session = await widget.authService.signInWithPassword(
        email: email,
        password: password,
      );

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
            'Welcome, '
            '${resolvedUser.fullName ?? resolvedUser.email}.',
      );

      await openPostAuthDestination(
        context: context,
        authService: widget.authService,
        user: resolvedUser,
      );
    } catch (error) {
      if (mounted) {
        AppToast.error(
          context,
          title: 'Sign-in failed',
          description: readableAuthError(error),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isEmailSubmitting = false;
        });
      }
    }
  }

  Future<void> _submitGoogle() async {
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
            'Connected as '
            '${resolvedUser.fullName ?? resolvedUser.email}.',
      );

      await openPostAuthDestination(
        context: context,
        authService: widget.authService,
        user: resolvedUser,
      );
    } on GoogleIdentityException catch (error) {
      if (!mounted) {
        return;
      }

      final message = readableAuthError(error);

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
          description: readableAuthError(error),
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

  @override
  Widget build(BuildContext context) {
    if (_isPageLoading) {
      return const _InitializingScreen();
    }

    return AuthLayout(
      child: LoginForm(
        isEmailSubmitting: _isEmailSubmitting,
        isGoogleSubmitting: _isSubmitting,
        onCheckPasswordStatus: _checkPasswordStatus,
        onPasswordSubmit: _submitPassword,
        onStartPasswordSetup: _startPasswordSetup,
        onGoogleSubmit: kIsWeb ? null : _submitGoogle,
        webGoogleButtonBuilder: kIsWeb ? renderGoogleSignInButton : null,
      ),
    );
  }
}

class _InitializingScreen extends StatelessWidget {
  const _InitializingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: const Center(
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
}
