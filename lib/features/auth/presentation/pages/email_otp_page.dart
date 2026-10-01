import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_input.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../application/auth_service_contract.dart';
import '../../data/models/password_auth_models.dart';
import '../widgets/auth_layout.dart';
import 'password_setup_page.dart';

const int _otpLength = 4;
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
    if (_currentOtp.length != _otpLength || _isVerifying || _isResending) {
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
          builder: (_) => PasswordSetupPage(
            authService: widget.authService,
            grantToken: grant.token,
            isRecovery: widget.isRecovery,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Invalid code',
        description: _readableError(error),
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
        description: 'A new 4-digit code was sent to ${challenge.maskedEmail}.',
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
        description: _readableError(error),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
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

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      headerTrailing: _resendCountdown > 0
          ? _OtpCountdown(seconds: _resendCountdown)
          : null,
      child: _OtpForm(
        email: widget.challenge.maskedEmail,
        otpGeneration: _otpGeneration,
        isCodeComplete: _currentOtp.length == _otpLength,
        isVerifying: _isVerifying,
        isResending: _isResending,
        resendCountdown: _resendCountdown,
        onOtpChanged: (otp) {
          setState(() {
            _currentOtp = otp;
          });
        },
        onVerify: _verify,
        onResend: _resend,
      ),
    );
  }
}

class _OtpCountdown extends StatelessWidget {
  const _OtpCountdown({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    final minutes = seconds ~/ 60;

    final remainingSeconds = seconds % 60;

    final value =
        '${minutes.toString().padLeft(2, '0')}:'
        '${remainingSeconds.toString().padLeft(2, '0')}';

    return Semantics(
      label: '$seconds seconds remaining',
      child: Text(
        value,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _OtpForm extends StatelessWidget {
  const _OtpForm({
    required this.email,
    required this.otpGeneration,
    required this.isCodeComplete,
    required this.isVerifying,
    required this.isResending,
    required this.resendCountdown,
    required this.onOtpChanged,
    required this.onVerify,
    required this.onResend,
  });

  final String email;

  final int otpGeneration;

  final bool isCodeComplete;

  final bool isVerifying;

  final bool isResending;

  final int resendCountdown;

  final ValueChanged<String> onOtpChanged;

  final VoidCallback onVerify;

  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 420;

    final titleSize = isCompact ? 22.0 : 25.0;

    final canRequestAnother = resendCountdown == 0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 0 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'OTP verification',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: titleSize,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Enter the 4-digit code sent to $email.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 12,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),

          SizedBox(height: isCompact ? 24 : 30),

          _OtpFieldsRow(
            key: ValueKey<int>(otpGeneration),
            onChanged: onOtpChanged,
          ),

          const SizedBox(height: 22),

          AppButton(
            label: 'Verify email',
            isLoading: isVerifying,
            size: AppButtonSize.md,
            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
            onPressed: isCodeComplete && !isResending ? onVerify : null,
          ),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: canRequestAnother
                ? Padding(
                    key: const ValueKey('request-another-code'),
                    padding: const EdgeInsets.only(top: 12),
                    child: AppButton(
                      label: 'Request another code',
                      isLoading: isResending,
                      size: AppButtonSize.md,
                      variant: AppButtonVariant.secondary,
                      icon: HugeIcons.strokeRoundedReload,
                      onPressed: isResending || isVerifying ? null : onResend,
                    ),
                  )
                : const SizedBox.shrink(
                    key: ValueKey('request-another-code-hidden'),
                  ),
          ),

          const SizedBox(height: 14),

          Align(
            alignment: Alignment.center,
            child: Semantics(
              button: true,
              label: 'Go back to login',
              child: TextButton(
                onPressed: isVerifying || isResending
                    ? null
                    : () {
                        Navigator.of(context).pop();
                      },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                child: const Text(
                  'Go back to login',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpFieldsRow extends StatefulWidget {
  const _OtpFieldsRow({super.key, required this.onChanged});

  final ValueChanged<String> onChanged;

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

    if (digits.length > _otpLength) {
      digits = digits.substring(0, _otpLength);
    }

    if (digits != _controller.text) {
      _controller.value = TextEditingValue(
        text: digits,
        selection: TextSelection.collapsed(offset: digits.length),
      );

      return;
    }

    widget.onChanged(digits);

    if (digits.length == _otpLength && _focusNode.hasFocus) {
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

    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
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

    final spacing = isCompact ? 8.0 : 12.0;

    final cellHeight = isCompact ? 58.0 : 66.0;

    final activeIndex = _code.length >= _otpLength
        ? _otpLength - 1
        : _code.length;

    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _focusInput,
          child: Row(
            children: List.generate(_otpLength, (index) {
              final digit = index < _code.length ? _code[index] : '';

              final isActive = _isFocused && index == activeIndex;

              final isFilled = digit.isNotEmpty;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index == _otpLength - 1 ? 0 : spacing,
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
                LengthLimitingTextInputFormatter(_otpLength),
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isActive
            ? AppColors.primary.withValues(alpha: 0.16)
            : isFilled
            ? AppColors.surface
            : AppColors.surfaceElevated,
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
                    fontSize: 26,
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
