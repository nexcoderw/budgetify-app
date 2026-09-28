import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_toast.dart';

class SendMoneyPage extends StatefulWidget {
  const SendMoneyPage({super.key});

  @override
  State<SendMoneyPage> createState() => _SendMoneyPageState();
}

class _SendMoneyPageState extends State<SendMoneyPage>
    with SingleTickerProviderStateMixin {
  static const int _maximumDigits = 12;

  late final AnimationController _entranceController;
  late final Animation<double> _entranceOpacity;
  late final Animation<Offset> _entranceOffset;

  String _amountDigits = '';
  bool _lastChangeWasDelete = false;

  bool get _hasAmount => _amountDigits.isNotEmpty && _amountDigits != '0';

  String get _formattedAmount {
    final value = _amountDigits.isEmpty ? '0' : _amountDigits;
    final buffer = StringBuffer();

    for (var index = 0; index < value.length; index++) {
      final remaining = value.length - index;

      buffer.write(value[index]);

      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }

    return buffer.toString();
  }

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );

    final entranceCurve = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );

    _entranceOpacity = entranceCurve;

    _entranceOffset = Tween<Offset>(
      begin: const Offset(0, 0.018),
      end: Offset.zero,
    ).animate(entranceCurve);

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  void _appendDigits(String digits) {
    if (_amountDigits.length >= _maximumDigits) {
      HapticFeedback.heavyImpact();
      return;
    }

    final remaining = _maximumDigits - _amountDigits.length;

    final acceptedLength =
        digits.length < remaining ? digits.length : remaining;

    final acceptedDigits = digits.substring(0, acceptedLength);

    if (acceptedDigits.isEmpty) {
      return;
    }

    final nextValue = '$_amountDigits$acceptedDigits'.replaceFirst(
      RegExp(r'^0+(?=\d)'),
      '',
    );

    HapticFeedback.selectionClick();

    setState(() {
      _lastChangeWasDelete = false;
      _amountDigits = nextValue;
    });
  }

  void _deleteDigit() {
    if (_amountDigits.isEmpty) {
      HapticFeedback.selectionClick();
      return;
    }

    HapticFeedback.selectionClick();

    setState(() {
      _lastChangeWasDelete = true;

      _amountDigits = _amountDigits.substring(
        0,
        _amountDigits.length - 1,
      );
    });
  }

  void _clearAmount() {
    if (_amountDigits.isEmpty) {
      return;
    }

    HapticFeedback.mediumImpact();

    setState(() {
      _lastChangeWasDelete = true;
      _amountDigits = '';
    });
  }

  void _continue() {
    AppToast.info(
      context,
      title: 'Amount ready',
      description: 'Recipient selection will be connected in the next step.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final disableAnimations = mediaQuery.disableAnimations;
    final isCompact = mediaQuery.size.width < 420;

    final content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 520,
        ),
        child: _GlassSurface(
          radius: isCompact ? 30 : 36,
          blur: 28,
          color: Colors.white.withValues(
            alpha: 0.055,
          ),
          padding: EdgeInsets.all(
            isCompact ? 16 : 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SendMoneyHeader(
                compact: isCompact,
              ),
              SizedBox(
                height: isCompact ? 22 : 28,
              ),
              _AmountDisplay(
                amount: _formattedAmount,
                changeWasDelete: _lastChangeWasDelete,
                disableAnimations: disableAnimations,
                onClear: _hasAmount ? _clearAmount : null,
                compact: isCompact,
              ),
              SizedBox(
                height: isCompact ? 20 : 24,
              ),
              _AmountKeypad(
                compact: isCompact,
                onDigitPressed: _appendDigits,
                onDeletePressed: _deleteDigit,
                onDeleteLongPress: _clearAmount,
              ),
              SizedBox(
                height: isCompact ? 20 : 24,
              ),
              AppButton(
                label: 'Continue',
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: AppButtonSize.lg,
                onPressed: _hasAmount ? _continue : null,
              ),
              const SizedBox(
                height: 12,
              ),
              const _NextStepHint(),
            ],
          ),
        ),
      ),
    );

    if (disableAnimations) {
      return content;
    }

    return FadeTransition(
      opacity: _entranceOpacity,
      child: SlideTransition(
        position: _entranceOffset,
        child: content,
      ),
    );
  }
}

class _SendMoneyHeader extends StatelessWidget {
  const _SendMoneyHeader({
    required this.compact,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SEND MONEY',
                style: TextStyle(
                  fontSize: 10,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: AppColors.primary.withValues(
                    alpha: 0.92,
                  ),
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              Text(
                'How much?',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(
                      fontSize: compact ? 25 : 28,
                      height: 1.05,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(
                height: 7,
              ),
              const Text(
                'Enter the amount you want to send.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(
          width: 18,
        ),
        const _CurrencyBadge(),
      ],
    );
  }
}

class _CurrencyBadge extends StatelessWidget {
  const _CurrencyBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        7,
        7,
        12,
        7,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: 0.055,
        ),
        borderRadius: BorderRadius.circular(
          999,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CurrencyMark(),
          SizedBox(
            width: 8,
          ),
          Text(
            'RWF',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrencyMark extends StatelessWidget {
  const _CurrencyMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(
          alpha: 0.95,
        ),
      ),
      alignment: Alignment.center,
      child: const Text(
        'R',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: AppColors.background,
        ),
      ),
    );
  }
}

class _AmountDisplay extends StatelessWidget {
  const _AmountDisplay({
    required this.amount,
    required this.changeWasDelete,
    required this.disableAnimations,
    required this.onClear,
    required this.compact,
  });

  final String amount;
  final bool changeWasDelete;
  final bool disableAnimations;
  final VoidCallback? onClear;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final amountWidget = FittedBox(
      key: ValueKey(
        amount,
      ),
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        amount,
        maxLines: 1,
        style: TextStyle(
          fontSize: compact ? 56 : 68,
          height: 1,
          fontWeight: FontWeight.w700,
          letterSpacing: compact ? -2.4 : -3.2,
          color: AppColors.textPrimary,
        ),
      ),
    );

    return _GlassSurface(
      radius: 28,
      blur: 20,
      color: Colors.white.withValues(
        alpha: 0.04,
      ),
      padding: EdgeInsets.fromLTRB(
        compact ? 20 : 24,
        compact ? 20 : 24,
        compact ? 20 : 24,
        18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'AMOUNT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              if (onClear != null)
                _ClearButton(
                  onPressed: onClear!,
                ),
            ],
          ),
          SizedBox(
            height: compact ? 20 : 24,
          ),
          SizedBox(
            height: compact ? 60 : 72,
            width: double.infinity,
            child: disableAnimations
                ? amountWidget
                : AnimatedSwitcher(
                    duration: const Duration(
                      milliseconds: 140,
                    ),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (
                      child,
                      animation,
                    ) {
                      final verticalOffset =
                          changeWasDelete ? -0.08 : 0.08;

                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: Offset(
                              0,
                              verticalOffset,
                            ),
                            end: Offset.zero,
                          ).animate(
                            animation,
                          ),
                          child: child,
                        ),
                      );
                    },
                    child: amountWidget,
                  ),
          ),
          const SizedBox(
            height: 10,
          ),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(
                width: 8,
              ),
              const Text(
                'Rwandan francs',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClearButton extends StatelessWidget {
  const _ClearButton({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Clear amount',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(
            999,
          ),
          splashColor: AppColors.primary.withValues(
            alpha: 0.10,
          ),
          highlightColor: AppColors.primary.withValues(
            alpha: 0.05,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: 0.055,
              ),
              borderRadius: BorderRadius.circular(
                999,
              ),
            ),
            child: const Text(
              'Clear',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountKeypad extends StatelessWidget {
  const _AmountKeypad({
    required this.compact,
    required this.onDigitPressed,
    required this.onDeletePressed,
    required this.onDeleteLongPress,
  });

  final bool compact;
  final ValueChanged<String> onDigitPressed;
  final VoidCallback onDeletePressed;
  final VoidCallback onDeleteLongPress;

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];

    return Container(
      padding: EdgeInsets.all(
        compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(
          alpha: 0.10,
        ),
        borderRadius: BorderRadius.circular(
          28,
        ),
      ),
      child: Column(
        children: [
          for (final row in rows) ...[
            _KeypadRow(
              values: row,
              compact: compact,
              onPressed: onDigitPressed,
            ),
            SizedBox(
              height: compact ? 7 : 8,
            ),
          ],
          Row(
            children: [
              Expanded(
                child: _AmountKey(
                  label: '00',
                  compact: compact,
                  onPressed: () {
                    onDigitPressed(
                      '00',
                    );
                  },
                ),
              ),
              SizedBox(
                width: compact ? 7 : 8,
              ),
              Expanded(
                child: _AmountKey(
                  label: '0',
                  compact: compact,
                  onPressed: () {
                    onDigitPressed(
                      '0',
                    );
                  },
                ),
              ),
              SizedBox(
                width: compact ? 7 : 8,
              ),
              Expanded(
                child: _AmountKey(
                  label: 'Delete',
                  compact: compact,
                  icon: HugeIcons.strokeRoundedDelete02,
                  onPressed: onDeletePressed,
                  onLongPress: onDeleteLongPress,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeypadRow extends StatelessWidget {
  const _KeypadRow({
    required this.values,
    required this.compact,
    required this.onPressed,
  });

  final List<String> values;
  final bool compact;
  final ValueChanged<String> onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (
          var index = 0;
          index < values.length;
          index++
        ) ...[
          if (index > 0)
            SizedBox(
              width: compact ? 7 : 8,
            ),
          Expanded(
            child: _AmountKey(
              label: values[index],
              compact: compact,
              onPressed: () {
                onPressed(
                  values[index],
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _AmountKey extends StatefulWidget {
  const _AmountKey({
    required this.label,
    required this.compact,
    required this.onPressed,
    this.icon,
    this.onLongPress,
  });

  final String label;
  final bool compact;
  final VoidCallback onPressed;
  final dynamic icon;
  final VoidCallback? onLongPress;

  @override
  State<_AmountKey> createState() => _AmountKeyState();
}

class _AmountKeyState extends State<_AmountKey> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.disableAnimationsOf(context);

    return Semantics(
      button: true,
      label: widget.label,
      hint: widget.onLongPress == null
          ? null
          : 'Hold to clear the amount',
      child: AnimatedScale(
        scale: disableAnimations || !_isPressed
            ? 1
            : 0.96,
        duration: disableAnimations
            ? Duration.zero
            : const Duration(
                milliseconds: 85,
              ),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(
            20,
          ),
          child: InkWell(
            onTap: widget.onPressed,
            onLongPress: widget.onLongPress,
            onHighlightChanged: (value) {
              if (_isPressed != value) {
                setState(() {
                  _isPressed = value;
                });
              }
            },
            borderRadius: BorderRadius.circular(
              20,
            ),
            splashColor: AppColors.primary.withValues(
              alpha: 0.10,
            ),
            highlightColor: Colors.transparent,
            child: AnimatedContainer(
              duration: const Duration(
                milliseconds: 100,
              ),
              height: widget.compact ? 55 : 61,
              decoration: BoxDecoration(
                color: _isPressed
                    ? AppColors.primary.withValues(
                        alpha: 0.10,
                      )
                    : Colors.white.withValues(
                        alpha: 0.04,
                      ),
                borderRadius: BorderRadius.circular(
                  20,
                ),
              ),
              alignment: Alignment.center,
              child: widget.icon == null
                  ? Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: widget.compact ? 19 : 20,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    )
                  : HugeIcon(
                      icon: widget.icon,
                      size: 20,
                      strokeWidth: 1.8,
                      color: AppColors.textSecondary,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NextStepHint extends StatelessWidget {
  const _NextStepHint();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'You’ll choose the recipient in the next step.',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 10,
        height: 1.5,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _GlassSurface extends StatelessWidget {
  const _GlassSurface({
    required this.child,
    required this.radius,
    required this.blur,
    required this.color,
    this.padding,
  });

  final Widget child;
  final double radius;
  final double blur;
  final Color color;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(
      radius,
    );

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blur,
          sigmaY: blur,
        ),
        child: Container(
          padding: padding,
          color: color,
          child: child,
        ),
      ),
    );
  }
}