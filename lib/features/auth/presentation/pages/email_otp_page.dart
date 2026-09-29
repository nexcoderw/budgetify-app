import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_input.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../application/auth_service_contract.dart';
import '../../data/models/email_initiate_response.dart';
import '../auth_post_auth_navigation.dart';
import '../widgets/auth_layout.dart';
import '../widgets/profile_completion_dialog.dart';

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

      final resolvedUser = await ProfileCompletionDialog.showIfRequired(
        context,
        authService: widget.authService,
        user: session.user,
      );

      if (!mounted) return;

      AppToast.success(
        context,
        title: 'Signed in successfully',
        description: 'Welcome, ${resolvedUser.fullName ?? resolvedUser.email}.',
      );

      await openPostAuthDestination(
        context: context,
        authService: widget.authService,
        user: resolvedUser,
        clearStack: true,
      );
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
    final panelPadding = isCompact ? 18.0 : 26.0;
    final titleSize = isCompact ? 22.0 : 25.0;

    return GlassPanel(
      padding: EdgeInsets.all(panelPadding),
      borderRadius: BorderRadius.circular(30),
      blur: 24,
      opacity: 0.14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _fadeAt(0.0, 0.5),
            child: SlideTransition(
              position: _slideAt(0.0, 0.5),
              child: const _BackButton(),
            ),
          ),
          SizedBox(height: isCompact ? 18 : 24),
          FadeTransition(
            opacity: _fadeAt(0.08, 0.58),
            child: SlideTransition(
              position: _slideAt(0.08, 0.58),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isRegister
                              ? 'Verify your email'
                              : 'Welcome back',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontSize: titleSize,
                                color: AppColors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Enter the six-digit code we sent you.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FadeTransition(
            opacity: _fadeAt(0.14, 0.64),
            child: SlideTransition(
              position: _slideAt(0.14, 0.64),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.045),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedMail01,
                      size: 18,
                      color: AppColors.primary,
                      strokeWidth: 1.8,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.maskedEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'DMSans',
                        ),
                      ),
                    ),
                    const Text(
                      '6 digits',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'DMSans',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: isCompact ? 22 : 28),
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
          FadeTransition(
            opacity: _fadeAt(0.28, 0.78),
            child: SlideTransition(
              position: _slideAt(0.28, 0.78),
              child: AppButton(
                label: widget.isRegister
                    ? 'Verify & create account'
                    : 'Verify & sign in',
                isLoading: widget.isVerifying,
                size: AppButtonSize.md,
                icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                onPressed: widget.isCodeComplete ? widget.onVerify : null,
              ),
            ),
          ),
          const SizedBox(height: 18),
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

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: 'Back',
      icon: HugeIcons.strokeRoundedArrowLeft01,
      size: AppButtonSize.sm,
      variant: AppButtonVariant.ghost,
      fullWidth: false,
      onPressed: () => Navigator.of(context).pop(),
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
    final isCompact = MediaQuery.sizeOf(context).width < 390;
    final spacing = isCompact ? 5.0 : 8.0;
    final cellHeight = isCompact ? 54.0 : 62.0;
    final activeIndex = _code.length >= 6 ? 5 : _code.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Verification code',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: Text(
                widget.isCodeComplete ? 'Ready' : 'Paste supported',
                key: ValueKey<bool>(widget.isCodeComplete),
                style: TextStyle(
                  fontSize: 11,
                  color: widget.isCodeComplete
                      ? AppColors.success
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'DMSans',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _focusInput,
          child: Row(
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
          ),
        ),
        const SizedBox(height: 10),
        Text(
          widget.isCodeComplete
              ? 'Code complete. You can continue.'
              : 'Type or paste the code from your email.',
          style: TextStyle(
            fontSize: 11,
            color: widget.isCodeComplete
                ? AppColors.success.withValues(alpha: 0.94)
                : AppColors.textSecondary,
            fontFamily: 'DMSans',
            height: 1.45,
          ),
        ),
        SizedBox(
          width: 1,
          height: 1,
          child: Opacity(
            opacity: 0,
            child: AppInput(
              controller: _controller,
              focusNode: _focusNode,
              variant: AppInputVariant.bare,
              autofillHints: const [AutofillHints.oneTimeCode],
              enableSuggestions: false,
              autocorrect: false,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
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
    final canResend = countdown == 0;

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
              'Resend in ${countdown}s',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontFamily: 'DMSans',
              ),
            )
          else
            AppButton(
              label: 'Resend code',
              icon: HugeIcons.strokeRoundedReload,
              size: AppButtonSize.sm,
              variant: AppButtonVariant.ghost,
              isLoading: isResending,
              fullWidth: false,
              onPressed: onResend,
            ),
        ],
      ),
    );
  }
}
