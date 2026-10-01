import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../application/auth_service_contract.dart';
import '../../data/models/password_auth_models.dart';
import '../auth_readable_error.dart';
import '../widgets/auth_layout.dart';
import '../widgets/email_otp/email_otp_form.dart';
import 'password_setup_page.dart';

const int _resendDelaySeconds = 60;

class EmailOtpPage extends StatefulWidget {
  const EmailOtpPage({
    super.key,
    required this.authService,
    required this.email,
    required this.challenge,
    required this.isRecovery,
  });

  final AuthServiceContract authService;
  final String email;
  final PasswordChallenge challenge;
  final bool isRecovery;

  @override
  State<EmailOtpPage> createState() => _EmailOtpPageState();
}

class _EmailOtpPageState extends State<EmailOtpPage> {
  bool _isVerifying = false;
  bool _isResending = false;

  String _currentOtp = '';

  int _resendCountdown = _resendDelaySeconds;

  int _otpGeneration = 0;

  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();

    _startResendTimer();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();

    super.dispose();
  }

  void _startResendTimer() {
    _resendCountdown = _resendDelaySeconds;

    _resendTimer?.cancel();

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();

        return;
      }

      if (_resendCountdown <= 1) {
        timer.cancel();

        setState(() {
          _resendCountdown = 0;
        });

        return;
      }

      setState(() {
        _resendCountdown--;
      });
    });
  }

  Future<void> _verify() async {
    if (_currentOtp.length != authOtpLength || _isVerifying || _isResending) {
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      final grant = await widget.authService.verifyPasswordChallenge(
        widget.email,
        _currentOtp,
      );

      if (!mounted) {
        return;
      }

      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (_) {
            return PasswordSetupPage(
              authService: widget.authService,
              grantToken: grant.token,
              isRecovery: widget.isRecovery,
            );
          },
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Invalid code',
        description: readableAuthError(error),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _resend() async {
    if (_resendCountdown > 0 || _isResending || _isVerifying) {
      return;
    }

    setState(() {
      _isResending = true;
    });

    try {
      final challenge = await widget.authService.requestPasswordChallenge(
        widget.email,
      );

      if (!mounted) {
        return;
      }

      AppToast.success(
        context,
        title: 'Code sent',
        description:
            'A new 4-digit code was sent to '
            '${challenge.maskedEmail}.',
      );

      setState(() {
        _currentOtp = '';
        _otpGeneration++;
      });

      _startResendTimer();
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Could not send another code',
        description: readableAuthError(error),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      headerTrailing: _resendCountdown > 0
          ? EmailOtpCountdown(seconds: _resendCountdown)
          : null,
      child: EmailOtpForm(
        email: widget.challenge.maskedEmail,
        otpGeneration: _otpGeneration,
        isCodeComplete: _currentOtp.length == authOtpLength,
        isVerifying: _isVerifying,
        isResending: _isResending,
        resendCountdown: _resendCountdown,
        onOtpChanged: (otp) {
          setState(() {
            _currentOtp = otp;
          });
        },
        onVerify: () {
          unawaited(_verify());
        },
        onResend: () {
          unawaited(_resend());
        },
      ),
    );
  }
}
