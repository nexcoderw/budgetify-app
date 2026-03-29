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
      final session = await widget.authService.verifyEmailOtp(
        widget.email,
        _currentOtp,
      );

      if (!mounted) return;

      AppToast.success(
        context,
        title: 'Signed in successfully',
        description: 'Welcome, ${session.user.fullName ?? session.user.email}.',
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
        description:
            'A new code was sent to ${widget.initiateResponse.maskedEmail}.',
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
        isCodeComplete: _currentOtp.length == 6,
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
    required this.isCodeComplete,
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
  final bool isCodeComplete;
  final bool isVerifying;
  final bool isResending;
  final int resendCountdown;
  final ValueChanged<String> onOtpChanged;
  final VoidCallback onVerify;
  final VoidCallback onResend;

  @override
  State<_OtpForm> createState() => _OtpFormState();
}

class _OtpFormState extends State<_OtpForm>
    with SingleTickerProviderStateMixin {
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
                  const SizedBox(height: 18),
                  _DeliverySummaryCard(
                    maskedEmail: widget.maskedEmail,
                    isRegister: widget.isRegister,
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
                isCodeComplete: widget.isCodeComplete,
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
                label: widget.isRegister
                    ? 'Verify & create account'
                    : 'Verify & sign in',
                loadingLabel: 'Verifying code…',
                isLoading: widget.isVerifying,
                fontSize: 14,
                leading: HugeIcon(
                  icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                  size: 18,
                  color: AppColors.background,
                  strokeWidth: 1.8,
                ),
                onPressed: widget.isCodeComplete ? widget.onVerify : null,
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

class _DeliverySummaryCard extends StatelessWidget {
  const _DeliverySummaryCard({
    required this.maskedEmail,
    required this.isRegister,
  });

  final String maskedEmail;
  final bool isRegister;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedSent,
                size: 18,
                color: AppColors.primary,
                strokeWidth: 1.8,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isRegister ? 'Registration email' : 'Sign-in email',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  maskedEmail,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'DMSans',
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Text(
              '6 digits',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontFamily: 'DMSans',
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
  const _OtpFieldsRow({required this.onChanged, required this.isCodeComplete});

  final ValueChanged<String> onChanged;
  final bool isCodeComplete;

  @override
  State<_OtpFieldsRow> createState() => _OtpFieldsRowState();
}

class _OtpFieldsRowState extends State<_OtpFieldsRow> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _controller.addListener(_handleCodeChanged);
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleCodeChanged);
    _focusNode.removeListener(_handleFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get _code => _controller.text;

  void _handleCodeChanged() {
    var digits = _controller.text.replaceAll(RegExp(r'\D'), '');

    if (digits.length > 6) {
      digits = digits.substring(0, 6);
    }

    if (digits != _controller.text) {
      _controller.value = TextEditingValue(
        text: digits,
        selection: TextSelection.collapsed(offset: digits.length),
      );
      return;
    }

    widget.onChanged(digits);

    if (digits.length == 6 && _focusNode.hasFocus) {
      _focusNode.unfocus();
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _handleFocusChanged() {
    if (_isFocused == _focusNode.hasFocus) {
      return;
    }

    setState(() => _isFocused = _focusNode.hasFocus);
  }

  void _focusInput() {
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }

    _controller.selection = TextSelection.collapsed(offset: _code.length);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.06),
                AppColors.surfaceElevated.withValues(alpha: 0.92),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Enter your code',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    widget.isCodeComplete ? 'Code ready' : 'Paste supported',
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.isCodeComplete
                          ? AppColors.success
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'DMSans',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _focusInput,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 360;
                    final spacing = isCompact ? 6.0 : 8.0;
                    final cellHeight = isCompact ? 58.0 : 64.0;
                    final activeIndex = _code.length >= 6 ? 5 : _code.length;

                    return Row(
                      children: List.generate(6, (index) {
                        final digit = index < _code.length ? _code[index] : '';
                        final isActive = _isFocused && index == activeIndex;
                        final isFilled = digit.isNotEmpty;

                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: index == 5 ? 0 : spacing,
                            ),
                            child: _OtpDigitCell(
                              digit: digit,
                              isActive: isActive,
                              isFilled: isFilled,
                              height: cellHeight,
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.isCodeComplete
                    ? 'Looks good. Continue when you are ready.'
                    : 'You can type or paste the full 6-digit code.',
                style: TextStyle(
                  fontSize: 11,
                  color: widget.isCodeComplete
                      ? AppColors.success.withValues(alpha: 0.94)
                      : AppColors.textSecondary,
                  fontFamily: 'DMSans',
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 1,
          height: 1,
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofillHints: const [AutofillHints.oneTimeCode],
              enableSuggestions: false,
              autocorrect: false,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                counterText: '',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OtpDigitCell extends StatelessWidget {
  const _OtpDigitCell({
    required this.digit,
    required this.isActive,
    required this.isFilled,
    required this.height,
  });

  final String digit;
  final bool isActive;
  final bool isFilled;
  final double height;

  @override
  Widget build(BuildContext context) {
    final borderColor = isActive
        ? AppColors.primary
        : isFilled
        ? AppColors.primary.withValues(alpha: 0.42)
        : AppColors.border;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isActive
                ? AppColors.primary.withValues(alpha: 0.16)
                : isFilled
                ? Colors.white.withValues(alpha: 0.07)
                : AppColors.surfaceElevated,
            isActive ? Colors.white.withValues(alpha: 0.08) : AppColors.surface,
          ],
        ),
        border: Border.all(color: borderColor, width: isActive ? 1.6 : 1.0),
        boxShadow: [
          if (isActive)
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.18),
              blurRadius: 18,
            )
          else if (isFilled)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 10,
            ),
        ],
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: digit.isNotEmpty
              ? Text(
                  digit,
                  key: ValueKey<String>('digit-$digit'),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFamily: 'DMSans',
                    letterSpacing: 0.8,
                  ),
                )
              : isActive
              ? Container(
                  key: const ValueKey('active-caret'),
                  width: 2,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                )
              : Container(
                  key: const ValueKey('empty-placeholder'),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
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
