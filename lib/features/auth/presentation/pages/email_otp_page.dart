import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../application/auth_service_contract.dart';
import '../../data/models/auth_user.dart';
import '../../data/models/email_initiate_response.dart';
import '../../../home/presentation/pages/landing_page.dart';
import '../widgets/auth_layout.dart';
import '../widgets/auth_loading_button.dart';

class EmailOtpPage extends StatefulWidget {
  const EmailOtpPage({
    super.key,
    required this.authService,
    required this.email,
    required this.initiateResponse,
  });

  final AuthServiceContract authService;
  final String email;
  final EmailInitiateResponse initiateResponse;

  @override
  State<EmailOtpPage> createState() => _EmailOtpPageState();
}

class _EmailOtpPageState extends State<EmailOtpPage> {
  bool _isVerifying = false;
  bool _isResending = false;
  String _currentOtp = '';
  int _resendCountdown = 60;
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
    _resendCountdown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _verify() async {
    if (_currentOtp.length != 6) return;

    setState(() => _isVerifying = true);

    try {
      final session =
          await widget.authService.verifyEmailOtp(widget.email, _currentOtp);

      if (!mounted) return;

      AppToast.success(
        context,
        title: 'Signed in successfully',
        description:
            'Welcome, ${session.user.fullName ?? session.user.email}.',
      );

      _openLanding(session.user);
    } catch (error) {
      if (mounted) {
        AppToast.error(
          context,
          title: 'Invalid code',
          description: _readableError(error),
        );
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _isResending = true);

    try {
      await widget.authService.initiateEmailAuth(widget.email);

      if (!mounted) return;

      AppToast.success(
        context,
        title: 'Code resent',
        description: 'A new code was sent to ${widget.initiateResponse.maskedEmail}.',
      );

      _startResendTimer();
    } catch (error) {
      if (mounted) {
        AppToast.error(
          context,
          title: 'Could not resend code',
          description: _readableError(error),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
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
    Navigator.of(context).pushAndRemoveUntil(
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
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      child: _OtpForm(
        email: widget.email,
        maskedEmail: widget.initiateResponse.maskedEmail,
        isRegister: widget.initiateResponse.isRegister,
        isVerifying: _isVerifying,
        isResending: _isResending,
        resendCountdown: _resendCountdown,
        onOtpChanged: (otp) => setState(() => _currentOtp = otp),
        onVerify: _verify,
        onResend: _resend,
      ),
    );
  }
}

// ── OTP form panel ───────────────────────────────────────────────────────────

class _OtpForm extends StatefulWidget {
  const _OtpForm({
    required this.email,
    required this.maskedEmail,
    required this.isRegister,
    required this.isVerifying,
    required this.isResending,
    required this.resendCountdown,
    required this.onOtpChanged,
    required this.onVerify,
    required this.onResend,
  });

  final String email;
  final String maskedEmail;
  final bool isRegister;
  final bool isVerifying;
  final bool isResending;
  final int resendCountdown;
  final ValueChanged<String> onOtpChanged;
  final VoidCallback onVerify;
  final VoidCallback onResend;

  @override
  State<_OtpForm> createState() => _OtpFormState();
}

class _OtpFormState extends State<_OtpForm> with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 860),
    )..forward();
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 420;
    final panelPadding = isCompact ? 22.0 : 28.0;
    final titleSize = isCompact ? 20.0 : 22.0;

    return GlassPanel(
      padding: EdgeInsets.all(panelPadding),
      borderRadius: BorderRadius.circular(34),
      blur: 26,
      opacity: 0.16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Back button ─────────────────────────────────────────────────
          FadeTransition(
            opacity: _fadeAt(0.0, 0.5),
            child: SlideTransition(
              position: _slideAt(0.0, 0.5),
              child: _BackButton(),
            ),
          ),

          const SizedBox(height: 20),

          // ── Icon + title + subtitle ─────────────────────────────────────
          FadeTransition(
            opacity: _fadeAt(0.08, 0.58),
            child: SlideTransition(
              position: _slideAt(0.08, 0.58),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedMail01,
                        size: 24,
                        color: AppColors.primary,
                        strokeWidth: 1.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Check your inbox',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontSize: titleSize,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.55,
                        fontFamily: 'DMSans',
                      ),
                      children: [
                        TextSpan(
                          text: widget.isRegister
                              ? 'Creating your account — a '
                              : 'Welcome back — a ',
                        ),
                        const TextSpan(
                          text: '6-digit code',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const TextSpan(text: ' was sent to '),
                        TextSpan(
                          text: widget.maskedEmail,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── OTP boxes ───────────────────────────────────────────────────
          FadeTransition(
            opacity: _fadeAt(0.18, 0.68),
            child: SlideTransition(
              position: _slideAt(0.18, 0.68),
              child: _OtpFieldsRow(
                onChanged: widget.onOtpChanged,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Verify button ───────────────────────────────────────────────
          FadeTransition(
            opacity: _fadeAt(0.28, 0.78),
            child: SlideTransition(
              position: _slideAt(0.28, 0.78),
              child: AuthLoadingButton(
                label: widget.isRegister ? 'Create account' : 'Sign in',
                loadingLabel: 'Verifying…',
                isLoading: widget.isVerifying,
                fontSize: 14,
                leading: HugeIcon(
                  icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                  size: 18,
                  color: AppColors.background,
                  strokeWidth: 1.8,
                ),
                onPressed: widget.onVerify,
              ),
            ),
          ),

          const SizedBox(height: 22),

          // ── Resend + change email ───────────────────────────────────────
          FadeTransition(
            opacity: _fadeAt(0.38, 0.9),
            child: SlideTransition(
              position: _slideAt(0.38, 0.9),
              child: _ResendRow(
                countdown: widget.resendCountdown,
                isResending: widget.isResending,
                onResend: widget.onResend,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Back button ──────────────────────────────────────────────────────────────

class _BackButton extends StatefulWidget {
  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowLeft01,
                  size: 16,
                  color: AppColors.textSecondary,
                  strokeWidth: 1.8,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Back',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontFamily: 'DMSans',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── OTP input row ────────────────────────────────────────────────────────────

class _OtpFieldsRow extends StatefulWidget {
  const _OtpFieldsRow({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  State<_OtpFieldsRow> createState() => _OtpFieldsRowState();
}

class _OtpFieldsRowState extends State<_OtpFieldsRow> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();

  void _onFieldChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    widget.onChanged(_otp);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, _buildBox),
    );
  }

  Widget _buildBox(int index) {
    return SizedBox(
      width: 46,
      height: 58,
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              _controllers[index].text.isEmpty &&
              index > 0) {
            _controllers[index - 1].clear();
            _focusNodes[index - 1].requestFocus();
            widget.onChanged(_otp);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextFormField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          textInputAction:
              index < 5 ? TextInputAction.next : TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(1),
          ],
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontFamily: 'DMSans',
          ),
          decoration: InputDecoration(
            contentPadding: EdgeInsets.zero,
            isCollapsed: true,
            filled: true,
            fillColor: AppColors.surfaceElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.8),
            ),
          ),
          onChanged: (value) => _onFieldChanged(index, value),
        ),
      ),
    );
  }
}

// ── Resend row ───────────────────────────────────────────────────────────────

class _ResendRow extends StatelessWidget {
  const _ResendRow({
    required this.countdown,
    required this.isResending,
    required this.onResend,
  });

  final int countdown;
  final bool isResending;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final canResend = countdown == 0 && !isResending;

    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          Text(
            "Didn't receive the code?",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
          ),
          if (!canResend)
            Text(
              countdown > 0 ? 'Resend in ${countdown}s' : 'Resending…',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontFamily: 'DMSans',
              ),
            )
          else
            _ResendButton(onTap: onResend),
        ],
      ),
    );
  }
}

class _ResendButton extends StatefulWidget {
  const _ResendButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_ResendButton> createState() => _ResendButtonState();
}

class _ResendButtonState extends State<_ResendButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedOpacity(
        opacity: _pressed ? 0.6 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedReload,
              size: 13,
              color: AppColors.primary,
              strokeWidth: 1.8,
            ),
            const SizedBox(width: 5),
            Text(
              'Resend code',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
