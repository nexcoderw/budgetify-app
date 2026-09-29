import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_input.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../application/transaction_service.dart';
import '../../application/ussd_transfer_service.dart';
import '../../data/models/transaction_models.dart';
import '../widgets/send_money_category_sheet.dart';
import 'select_recipient_page.dart';

class SendMoneyPage extends StatefulWidget {
  const SendMoneyPage({
    super.key,
    this.transactionService,
    this.ussdTransferService,
  });

  final TransactionService? transactionService;
  final UssdTransferService? ussdTransferService;

  @override
  State<SendMoneyPage> createState() => _SendMoneyPageState();
}

enum _SendMoneyMode { recipient, momoCode }

class _SendMoneyPageState extends State<SendMoneyPage>
    with SingleTickerProviderStateMixin {
  static const int _maximumDigits = 12;

  final _momoCodeController = TextEditingController();

  late final AnimationController _entranceController;
  late final Animation<double> _entranceOpacity;
  late final Animation<Offset> _entranceOffset;
  late final TransactionService _transactionService;
  late final UssdTransferService _ussdTransferService;

  String _amountDigits = '';
  bool _lastChangeWasDelete = false;
  _SendMoneyMode _mode = _SendMoneyMode.recipient;
  PaymentTransaction? _pendingMomoPayTransaction;
  String? _activeMomoPaySignature;
  String? _momoPayIdempotencyKey;
  bool _isStartingMomoPay = false;

  bool get _hasAmount => _amountDigits.isNotEmpty && _amountDigits != '0';

  bool get _hasValidMomoCode => isValidTransactionRecipient(
    _momoCodeController.text,
    TransactionRecipientType.momoCode,
  );

  bool get _canContinue =>
      _hasAmount &&
      (_mode == _SendMoneyMode.recipient || _hasValidMomoCode) &&
      !_isStartingMomoPay;

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

    _transactionService =
        widget.transactionService ?? TransactionService.createDefault();
    _ussdTransferService =
        widget.ussdTransferService ?? const UssdTransferService();
    _momoCodeController.addListener(_handleMomoCodeChanged);

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
    _momoCodeController
      ..removeListener(_handleMomoCodeChanged)
      ..dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _handleMomoCodeChanged() {
    _activeMomoPaySignature = null;
    _pendingMomoPayTransaction = null;

    if (mounted) {
      setState(() {});
    }
  }

  void _selectMode(_SendMoneyMode mode) {
    if (_mode == mode || _isStartingMomoPay) {
      return;
    }

    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    setState(() => _mode = mode);
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

  Future<void> _sendMoney() async {
    if (!_canContinue) {
      return;
    }

    if (_mode == _SendMoneyMode.momoCode && !_hasValidMomoCode) {
      AppToast.error(
        context,
        title: 'Invalid MoMo code',
        description: 'Enter a MoMo merchant code containing 3 to 12 digits.',
      );
      return;
    }

    FocusScope.of(context).unfocus();

    final category = await showSendMoneyCategorySheet(
      context,
      amount: _formattedAmount,
    );

    if (!mounted || category == null) {
      return;
    }

    if (_mode == _SendMoneyMode.momoCode) {
      await _startMomoPay(category);
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SelectRecipientPage(
          amount: _formattedAmount,
          category: category,
        ),
      ),
    );
  }

  Future<void> _startMomoPay(String category) async {
    if (_isStartingMomoPay) {
      return;
    }

    final momoCode = _momoCodeController.text.replaceAll(RegExp(r'\D'), '');
    final amount = int.parse(_amountDigits);

    if (!_ussdTransferService.isSupported) {
      AppToast.error(
        context,
        title: 'USSD unavailable on this device',
        description:
            'Use Budgetify on an Android phone or iPhone to open the MTN MoMo Pay prompt.',
      );
      return;
    }

    final transferSignature = '$amount:$momoCode:$category';

    if (_activeMomoPaySignature != transferSignature) {
      _activeMomoPaySignature = transferSignature;
      _momoPayIdempotencyKey = _createIdempotencyKey();
      _pendingMomoPayTransaction = null;
    }

    setState(() => _isStartingMomoPay = true);

    try {
      final allowed = await _ussdTransferService.prepare();

      if (!allowed) {
        if (!mounted) {
          return;
        }

        AppToast.error(
          context,
          title: 'Phone access required',
          description:
              'Allow phone access so Budgetify can open the MTN MoMo Pay prompt.',
        );
        return;
      }

      final transaction =
          _pendingMomoPayTransaction ??
          await _transactionService.create(
            amount: amount,
            transferType: TransactionTransferType.momoPay,
            recipientType: TransactionRecipientType.momoCode,
            category: TransactionCategory.fromLabel(category),
            receiverIdentifier: momoCode,
            idempotencyKey: _momoPayIdempotencyKey!,
          );

      _pendingMomoPayTransaction = transaction;

      await _ussdTransferService.launch(
        transferType: TransactionTransferType.momoPay,
        recipientType: TransactionRecipientType.momoCode,
        receiverIdentifier: momoCode,
        amount: amount,
      );

      if (!mounted) {
        return;
      }

      AppToast.info(
        context,
        title: 'MoMo Pay opened',
        description:
            'Confirm the merchant payment in the MTN prompt. It remains pending until confirmed.',
      );
    } on ApiException catch (error) {
      if (mounted) {
        AppToast.error(
          context,
          title: 'Could not prepare payment',
          description: error.message,
        );
      }
    } on PlatformException catch (error) {
      if (mounted) {
        AppToast.error(
          context,
          title: 'Could not open MTN MoMo',
          description: error.message ?? 'Please try again.',
        );
      }
    } on ArgumentError catch (error) {
      if (mounted) {
        AppToast.error(
          context,
          title: 'Invalid payment details',
          description: error.message?.toString() ?? 'Check the MoMo code.',
        );
      }
    } catch (_) {
      if (mounted) {
        AppToast.error(
          context,
          title: 'Payment unavailable',
          description: 'The payment could not be started. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isStartingMomoPay = false);
      }
    }
  }

  String _createIdempotencyKey() {
    final random = Random.secure();
    final randomPart = List<int>.generate(
      16,
      (_) => random.nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();

    return 'momo-pay-${DateTime.now().microsecondsSinceEpoch}-$randomPart';
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
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.all(isCompact ? 16 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SendMoneyModeSelector(
                mode: _mode,
                onSelected: _selectMode,
              ),
              if (_mode == _SendMoneyMode.momoCode) ...[
                SizedBox(height: isCompact ? 14 : 16),
                AppInput(
                  controller: _momoCodeController,
                  label: 'MoMo merchant code',
                  hintText: 'Enter merchant code',
                  leadingIcon: HugeIcons.strokeRoundedMoneySendSquare,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(12),
                  ],
                  maxLength: 12,
                  borderRadius: 999,
                  onSubmitted: (_) {
                    if (_canContinue) {
                      _sendMoney();
                    }
                  },
                ),
              ],
              SizedBox(height: isCompact ? 16 : 20),
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
              Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: 240,
                  child: AppButton(
                    label: _mode == _SendMoneyMode.momoCode
                        ? 'Pay with MoMo'
                        : 'Send money',
                    icon: HugeIcons.strokeRoundedMoneySendCircle,
                    size: AppButtonSize.md,
                    isLoading: _isStartingMomoPay,
                    onPressed: _canContinue ? _sendMoney : null,
                  ),
                ),
              ),
              const SizedBox(
                height: 12,
              ),
              _NextStepHint(mode: _mode),
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

class _SendMoneyModeSelector extends StatelessWidget {
  const _SendMoneyModeSelector({
    required this.mode,
    required this.onSelected,
  });

  final _SendMoneyMode mode;
  final ValueChanged<_SendMoneyMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Payment destination',
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: _SendMoneyModeButton(
                label: 'Phone / account',
                icon: Icons.person_outline_rounded,
                isSelected: mode == _SendMoneyMode.recipient,
                onPressed: () => onSelected(_SendMoneyMode.recipient),
              ),
            ),
            Expanded(
              child: _SendMoneyModeButton(
                label: 'MoMo code',
                icon: Icons.storefront_outlined,
                isSelected: mode == _SendMoneyMode.momoCode,
                onPressed: () => onSelected(_SendMoneyMode.momoCode),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SendMoneyModeButton extends StatelessWidget {
  const _SendMoneyModeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final color = isSelected ? AppColors.primary : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 180),
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.11)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
    final keySize = widget.compact ? 55.0 : 61.0;

    return Semantics(
      button: true,
      label: widget.label,
      hint: widget.onLongPress == null
          ? null
          : 'Hold to clear the amount',
      child: Center(
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
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
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
              customBorder: const CircleBorder(),
              splashColor: AppColors.primary.withValues(
                alpha: 0.10,
              ),
              highlightColor: Colors.transparent,
              child: AnimatedContainer(
                duration: const Duration(
                  milliseconds: 100,
                ),
                width: keySize,
                height: keySize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isPressed
                      ? AppColors.primary.withValues(
                          alpha: 0.10,
                        )
                      : Colors.white.withValues(
                          alpha: 0.04,
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
      ),
    );
  }
}

class _NextStepHint extends StatelessWidget {
  const _NextStepHint({required this.mode});

  final _SendMoneyMode mode;

  @override
  Widget build(BuildContext context) {
    return Text(
      mode == _SendMoneyMode.momoCode
          ? 'MTN will ask you to confirm the merchant payment.'
          : 'You’ll choose the recipient in the next step.',
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
