import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_input.dart';

const int authOtpLength = 4;

class EmailOtpCountdown extends StatelessWidget {
  const EmailOtpCountdown({super.key, required this.seconds});

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

class EmailOtpForm extends StatelessWidget {
  const EmailOtpForm({
    super.key,
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

  String get _code => _controller.text;

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
    _controller
      ..removeListener(_handleCodeChanged)
      ..dispose();

    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();

    super.dispose();
  }

  void _handleCodeChanged() {
    var digits = _controller.text.replaceAll(RegExp(r'\D'), '');

    if (digits.length > authOtpLength) {
      digits = digits.substring(0, authOtpLength);
    }

    if (digits != _controller.text) {
      _controller.value = TextEditingValue(
        text: digits,
        selection: TextSelection.collapsed(offset: digits.length),
      );

      return;
    }

    widget.onChanged(digits);

    if (digits.length == authOtpLength && _focusNode.hasFocus) {
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

    final activeIndex = _code.length >= authOtpLength
        ? authOtpLength - 1
        : _code.length;

    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _focusInput,
          child: Row(
            children: List.generate(authOtpLength, (index) {
              final digit = index < _code.length ? _code[index] : '';

              final isActive = _isFocused && index == activeIndex;

              final isFilled = digit.isNotEmpty;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index == authOtpLength - 1 ? 0 : spacing,
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
                LengthLimitingTextInputFormatter(authOtpLength),
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
