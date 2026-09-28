import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../application/transaction_service.dart';
import '../../application/ussd_transfer_service.dart';
import '../../data/models/transaction_models.dart';

class TransactionReviewPage extends StatefulWidget {
  const TransactionReviewPage({
    super.key,
    required this.amount,
    required this.category,
    required this.recipientIdentifier,
    required this.recipientType,
    this.recipientName,
    this.transactionService,
    this.ussdTransferService,
  });

  final int amount;
  final String category;
  final String recipientIdentifier;
  final TransactionRecipientType recipientType;
  final String? recipientName;

  final TransactionService? transactionService;
  final UssdTransferService? ussdTransferService;

  @override
  State<TransactionReviewPage> createState() =>
      _TransactionReviewPageState();
}

class _TransactionReviewPageState
    extends State<TransactionReviewPage> {
  late final TransactionService _transactionService;
  late final UssdTransferService _ussdTransferService;
  late final String _idempotencyKey;

  late TransactionTransferType _transferType;

  TransactionQuote? _quote;
  PaymentTransaction? _transaction;

  bool _isLoadingQuote = true;
  bool _isStartingTransfer = false;

  @override
  void initState() {
    super.initState();

    _transactionService =
        widget.transactionService ??
        TransactionService.createDefault();

    _ussdTransferService =
        widget.ussdTransferService ??
        const UssdTransferService();

    _idempotencyKey = _createIdempotencyKey();

    _transferType =
        widget.recipientType ==
                TransactionRecipientType.bankAccount
            ? TransactionTransferType.momoToEkash
            : TransactionTransferType.momoToMomo;

    _loadQuote();
  }

  Future<void> _loadQuote() async {
    setState(() {
      _isLoadingQuote = true;
      _quote = null;
    });

    try {
      final quote = await _transactionService.quote(
        amount: widget.amount,
        transferType: _transferType,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _quote = quote;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Could not calculate fee',
        description: error.message,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Could not calculate fee',
        description:
            'Please check your connection and try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingQuote = false;
        });
      }
    }
  }

  Future<void> _selectTransferType(
    TransactionTransferType type,
  ) async {
    if (
        type ==
            TransactionTransferType.momoToMomo &&
        widget.recipientType ==
            TransactionRecipientType.bankAccount) {
      return;
    }

    if (_transferType == type) {
      return;
    }

    setState(() {
      _transferType = type;
      _transaction = null;
    });

    await _loadQuote();
  }

  Future<void> _startTransfer() async {
    if (
        _quote == null ||
        _isLoadingQuote ||
        _isStartingTransfer) {
      return;
    }

    setState(() {
      _isStartingTransfer = true;
    });

    try {
      final allowed =
          await _ussdTransferService.prepare();

      if (!allowed) {
        if (!mounted) {
          return;
        }

        AppToast.error(
          context,
          title: 'Phone access required',
          description:
              'Allow phone access so Budgetify can open the MTN transfer prompt.',
        );

        return;
      }

      final transaction =
          _transaction ??
          await _transactionService.create(
            amount: widget.amount,
            transferType: _transferType,
            recipientType: widget.recipientType,
            category:
                TransactionCategory.fromLabel(
              widget.category,
            ),
            receiverIdentifier:
                widget.recipientIdentifier,
            idempotencyKey: _idempotencyKey,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _transaction = transaction;
      });

      await _ussdTransferService.launch(
        transferType: _transferType,
        recipientType: widget.recipientType,
        receiverIdentifier:
            widget.recipientIdentifier,
        amount: widget.amount,
      );

      if (!mounted) {
        return;
      }

      AppToast.info(
        context,
        title: 'MoMo opened',
        description:
            'Complete the transfer in the MTN prompt. The transaction remains pending until it is confirmed.',
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Could not prepare transfer',
        description: error.message,
      );
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Could not open MoMo',
        description:
            error.message ??
            'Please try again.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Transfer unavailable',
        description:
            'The transfer could not be started. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isStartingTransfer = false;
        });
      }
    }
  }

  String _createIdempotencyKey() {
    final random = Random.secure();

    final randomPart = List<int>.generate(
      16,
      (_) => random.nextInt(256),
    ).map(
      (value) => value
          .toRadixString(16)
          .padLeft(2, '0'),
    ).join();

    return 'ussd-${DateTime.now().microsecondsSinceEpoch}-$randomPart';
  }

  @override
  Widget build(BuildContext context) {
    final quote = _quote;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 560,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                14,
                16,
                20,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: () =>
                            Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'REVIEW',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'Ready to send?',
                    style: TextStyle(
                      fontSize: 27,
                      height: 1.05,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Review the recipient, transfer method and total before opening MoMo.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _RecipientCard(
                    name: widget.recipientName,
                    identifier:
                        widget.recipientIdentifier,
                    recipientType:
                        widget.recipientType,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'SEND USING',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.3,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _TransferMethodButton(
                          label: 'MTN MoMo',
                          subtitle: 'MoMo number',
                          selected:
                              _transferType ==
                              TransactionTransferType
                                  .momoToMomo,
                          enabled:
                              widget.recipientType ==
                              TransactionRecipientType
                                  .phone,
                          onTap: () =>
                              _selectTransferType(
                            TransactionTransferType
                                .momoToMomo,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TransferMethodButton(
                          label: 'eKash',
                          subtitle:
                              'Airtel or bank',
                          selected:
                              _transferType ==
                              TransactionTransferType
                                  .momoToEkash,
                          enabled: true,
                          onTap: () =>
                              _selectTransferType(
                            TransactionTransferType
                                .momoToEkash,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius:
                          BorderRadius.circular(24),
                    ),
                    child: _isLoadingQuote
                        ? const Center(
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color:
                                  AppColors.primary,
                            ),
                          )
                        : quote == null
                        ? const Text(
                            'Fee unavailable',
                            textAlign:
                                TextAlign.center,
                            style: TextStyle(
                              color: AppColors
                                  .textSecondary,
                            ),
                          )
                        : Column(
                            children: [
                              _AmountRow(
                                label:
                                    'Amount',
                                amount:
                                    quote.amount,
                              ),
                              const SizedBox(
                                height: 12,
                              ),
                              _AmountRow(
                                label:
                                    'Transaction fee',
                                amount:
                                    quote.feeAmount,
                              ),
                              const Padding(
                                padding:
                                    EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                child: Divider(
                                  height: 1,
                                  color:
                                      AppColors.border,
                                ),
                              ),
                              _AmountRow(
                                label:
                                    'Total',
                                amount:
                                    quote.totalAmount,
                                emphasized: true,
                              ),
                            ],
                          ),
                  ),
                  const Spacer(),
                  if (_transaction != null) ...[
                    Text(
                      'Pending: ${_transaction!.reference}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        color:
                            AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Center(
                    child: SizedBox(
                      width: 250,
                      child: AppButton(
                        label:
                            _transaction == null
                            ? 'Open MoMo'
                            : 'Open MoMo again',
                        iconWidget: const Icon(
                          Icons.phone_in_talk_rounded,
                          color:
                              AppColors.background,
                        ),
                        size: AppButtonSize.md,
                        isLoading:
                            _isStartingTransfer,
                        onPressed:
                            quote == null
                            ? null
                            : _startTransfer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecipientCard extends StatelessWidget {
  const _RecipientCard({
    required this.name,
    required this.identifier,
    required this.recipientType,
  });

  final String? name;
  final String identifier;
  final TransactionRecipientType recipientType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(
                alpha: 0.13,
              ),
            ),
            child: Icon(
              recipientType ==
                      TransactionRecipientType.phone
                  ? Icons.person_outline_rounded
                  : Icons.account_balance_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  name ??
                      (recipientType ==
                              TransactionRecipientType
                                  .phone
                          ? 'Phone recipient'
                          : 'Bank account'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color:
                        AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  identifier,
                  style: const TextStyle(
                    fontSize: 11,
                    color:
                        AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferMethodButton
    extends StatelessWidget {
  const _TransferMethodButton({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: selected
            ? AppColors.primary.withValues(
                alpha: 0.12,
              )
            : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color:
                        AppColors.textSecondary,
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

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.amount,
    this.emphasized = false,
  });

  final String label;
  final int amount;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: emphasized ? 13 : 11,
            fontWeight: emphasized
                ? FontWeight.w700
                : FontWeight.w500,
            color: emphasized
                ? AppColors.textPrimary
                : AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          '${_formatAmount(amount)} RWF',
          style: TextStyle(
            fontSize: emphasized ? 16 : 12,
            fontWeight: emphasized
                ? FontWeight.w800
                : FontWeight.w700,
            color: emphasized
                ? AppColors.primary
                : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

String _formatAmount(int amount) {
  final value = amount.toString();
  final buffer = StringBuffer();

  for (
    var index = 0;
    index < value.length;
    index++
  ) {
    final remaining =
        value.length - index;

    buffer.write(value[index]);

    if (
        remaining > 1 &&
        remaining % 3 == 1) {
      buffer.write(',');
    }
  }

  return buffer.toString();
}
