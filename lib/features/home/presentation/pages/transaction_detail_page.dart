import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../application/transaction_service.dart';
import '../../application/transaction_sms_matcher.dart';
import '../../application/transaction_sms_reconciliation_service.dart';
import '../../data/models/provider_sms_message.dart';
import '../../data/models/transaction_models.dart';
import '../widgets/transaction_manual_confirmation_sheet.dart';

class TransactionDetailPage extends StatefulWidget {
  const TransactionDetailPage({
    super.key,
    required this.transactionId,
    this.transactionService,
    this.smsReconciliationService,
  });

  final String transactionId;
  final TransactionService? transactionService;

  final TransactionSmsReconciliationService? smsReconciliationService;

  @override
  State<TransactionDetailPage> createState() => _TransactionDetailPageState();
}

class _TransactionDetailPageState extends State<TransactionDetailPage> {
  late final TransactionService _transactionService;

  late final TransactionSmsReconciliationService _smsReconciliationService;

  TransactionDetail? _detail;

  bool _isLoading = true;
  bool _isCheckingStatus = false;

  String? _errorMessage;
  String? _reconciliationMessage;

  DateTime? _lastCheckedAt;

  @override
  void initState() {
    super.initState();

    _transactionService =
        widget.transactionService ?? TransactionService.createDefault();

    _smsReconciliationService =
        widget.smsReconciliationService ??
        TransactionSmsReconciliationService.createDefault(
          transactionService: _transactionService,
        );

    unawaited(_load());
  }

  Future<void> _load({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final detail = await _transactionService.getDetail(
        transactionId: widget.transactionId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _detail = detail;
        _errorMessage = null;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Could not load transaction details.';
      });
    } finally {
      if (mounted && showLoader) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkTransactionStatus() async {
    if (_isCheckingStatus) {
      return;
    }

    final detail = _detail;

    if (detail == null) {
      return;
    }

    setState(() {
      _isCheckingStatus = true;
      _reconciliationMessage = null;
    });

    try {
      var result = await _smsReconciliationService.reconcileTransaction(
        detail.transaction,
      );

      if (result.outcome == TransactionReconciliationOutcome.permissionDenied) {
        final permission = await _smsReconciliationService.requestPermission();

        if (!mounted) {
          return;
        }

        if (permission != DeviceSmsPermission.granted) {
          setState(() {
            _lastCheckedAt = result.checkedAt;

            _reconciliationMessage =
                'SMS access is disabled. The transaction remains unchanged.';
          });

          AppToast.error(
            context,
            title: 'SMS access required',
            description:
                'Enable SMS access to let Budgetify check MTN transaction confirmations.',
          );

          return;
        }

        result = await _smsReconciliationService.reconcileTransaction(
          detail.transaction,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _lastCheckedAt = result.checkedAt;

        _reconciliationMessage = _messageForResult(result);
      });

      switch (result.outcome) {
        case TransactionReconciliationOutcome.updated:
          await _load(showLoader: false);

          if (!mounted) {
            return;
          }

          final updated = result.transaction;

          if (updated.status == TransactionStatus.completed) {
            AppToast.success(
              context,
              title: 'Transaction confirmed',
              description:
                  'MTN confirmation was matched safely to this transaction.',
            );
          } else {
            AppToast.info(
              context,
              title: 'Transaction status updated',
              description:
                  'MTN reported ${updated.status.label.toLowerCase()}.',
            );
          }

        case TransactionReconciliationOutcome.alreadyResolved:
          await _load(showLoader: false);

        case TransactionReconciliationOutcome.noMatch:
          AppToast.info(
            context,
            title: 'No confirmation found',
            description:
                'Budgetify found no reliable MTN message for this transaction. Its current status was not changed.',
          );

        case TransactionReconciliationOutcome.ambiguous:
          AppToast.info(
            context,
            title: 'Confirmation needs review',
            description:
                'More than one MTN message could match this transaction. Budgetify did not guess or change its status.',
          );

        case TransactionReconciliationOutcome.unsupported:
          AppToast.info(
            context,
            title: 'Automatic check unavailable',
            description:
                'SMS transaction confirmation is currently available on Android only.',
          );

        case TransactionReconciliationOutcome.permissionDenied:
          // Handled above.
          break;
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Could not check transaction',
        description: error.message,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Could not check transaction',
        description:
            'Budgetify could not safely reconcile this transaction. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingStatus = false;
        });
      }
    }
  }

  Future<void> _confirmTransactionManually() async {
    if (_isCheckingStatus) {
      return;
    }

    final detail = _detail;

    if (detail == null) {
      return;
    }

    final transaction = detail.transaction;

    if (transaction.status != TransactionStatus.pending &&
        transaction.status != TransactionStatus.processing) {
      return;
    }

    final choice = await showManualTransactionConfirmationSheet(
      context,
      transaction: transaction,
    );

    if (!mounted || choice == null) {
      return;
    }

    if (choice == ManualTransactionConfirmationChoice.notSure) {
      AppToast.info(
        context,
        title: 'Transaction unchanged',
        description: 'The payment remains open until you confirm its result.',
      );

      return;
    }

    final status = choice.status;

    if (status == null) {
      return;
    }

    setState(() {
      _isCheckingStatus = true;
    });

    try {
      final updated = await _transactionService.recordManualResult(
        transactionId: transaction.id,
        status: status,
      );

      await _load(showLoader: false);

      if (!mounted) {
        return;
      }

      if (updated.status == TransactionStatus.completed) {
        AppToast.success(
          context,
          title: 'Payment confirmed',
          description: 'The transaction was manually confirmed as successful.',
        );
      } else {
        AppToast.info(
          context,
          title: 'Payment result recorded',
          description: 'The transaction was manually confirmed as failed.',
        );
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      // Reload in case the server accepted the
      // result but the client lost the response.
      await _load(showLoader: false);

      if (!mounted) {
        return;
      }

      final latest = _detail?.transaction;

      if (latest != null &&
          latest.status != TransactionStatus.pending &&
          latest.status != TransactionStatus.processing) {
        AppToast.info(
          context,
          title: 'Transaction refreshed',
          description: 'The transaction already has a final status.',
        );

        return;
      }

      AppToast.error(
        context,
        title: 'Could not record result',
        description: error.message,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Could not record result',
        description:
            'Budgetify could not save your manual confirmation. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingStatus = false;
        });
      }
    }
  }

  String _messageForResult(TransactionReconciliationResult result) {
    return switch (result.outcome) {
      TransactionReconciliationOutcome.updated =>
        'A reliable MTN confirmation was found and the transaction was updated.',
      TransactionReconciliationOutcome.alreadyResolved =>
        'This transaction already has a final status.',
      TransactionReconciliationOutcome.noMatch =>
        'No reliable MTN confirmation was found. This does not mean the transfer failed.',
      TransactionReconciliationOutcome.ambiguous =>
        'Multiple MTN messages could match. Budgetify left the transaction unchanged rather than guessing.',
      TransactionReconciliationOutcome.permissionDenied =>
        'SMS access is required to check transaction confirmations.',
      TransactionReconciliationOutcome.unsupported =>
        'Automatic SMS confirmation is unavailable on this device.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopBar(onBack: () => Navigator.of(context).pop()),
                  const SizedBox(height: 20),
                  Expanded(child: _buildContent()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          color: AppColors.primary,
        ),
      );
    }

    final error = _errorMessage;

    if (error != null) {
      return _DetailError(
        message: error,
        onRetry: () {
          unawaited(_load());
        },
      );
    }

    final detail = _detail;

    if (detail == null) {
      return const SizedBox.shrink();
    }

    final transaction = detail.transaction;

    final needsConfirmation = transactionNeedsConfirmation(transaction);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'TRANSACTION',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Transaction details',
                  style: TextStyle(
                    fontSize: 26,
                    height: 1.05,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _StatusBadge(transaction: transaction),
            ],
          ),
          const SizedBox(height: 24),
          _AmountSummary(transaction: transaction),
          if (isTransactionOpen(transaction)) ...[
            const SizedBox(height: 16),
            if (supportsIosManualTransactionConfirmation)
              _IosManualRecoveryCard(
                needsConfirmation: needsConfirmation,
                isSaving: _isCheckingStatus,
                onConfirm: () {
                  unawaited(_confirmTransactionManually());
                },
              )
            else
              _TransactionRecoveryCard(
                needsConfirmation: needsConfirmation,
                isChecking: _isCheckingStatus,
                lastCheckedAt: _lastCheckedAt,
                message: _reconciliationMessage,
                onCheck: () {
                  unawaited(_checkTransactionStatus());
                },
              ),
          ],
          const SizedBox(height: 16),
          _InformationCard(
            transaction: transaction,
            confirmationSource: confirmationSource,
          ),
          if (transaction.failureCode != null ||
              transaction.failureReason != null) ...[
            const SizedBox(height: 16),
            _FailureCard(transaction: transaction),
          ],
          const SizedBox(height: 28),
          Row(
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedTransactionHistory,
                size: 19,
                color: AppColors.primary,
              ),
              const SizedBox(width: 9),
              const Text(
                'Timeline',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${detail.events.length} events',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _TransactionTimeline(events: detail.events),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Tooltip(
        message: 'Back',
        child: Material(
          color: AppColors.surfaceElevated,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onBack,
            customBorder: const CircleBorder(),
            child: const SizedBox.square(
              dimension: 44,
              child: Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowLeft01,
                  size: 19,
                  strokeWidth: 1.9,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountSummary extends StatelessWidget {
  const _AmountSummary({required this.transaction});

  final PaymentTransaction transaction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedMoneySendSquare,
            size: 26,
            color: AppColors.primary,
          ),
          const SizedBox(height: 14),
          Text(
            '${_formatAmount(transaction.amount)} RWF',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            transaction.recipientDisplayName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _AmountMetric(
                  label: 'Fee',
                  value: '${_formatAmount(transaction.feeAmount)} RWF',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AmountMetric(
                  label: 'Total',
                  value: '${_formatAmount(transaction.totalAmount)} RWF',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IosManualRecoveryCard extends StatelessWidget {
  const _IosManualRecoveryCard({
    required this.needsConfirmation,
    required this.isSaving,
    required this.onConfirm,
  });

  final bool needsConfirmation;
  final bool isSaving;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final accent = needsConfirmation
        ? AppColors.primaryMuted
        : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedTransactionHistory,
                  size: 19,
                  strokeWidth: 1.8,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      needsConfirmation
                          ? 'Needs confirmation'
                          : 'Waiting for confirmation',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      needsConfirmation
                          ? 'Budgetify cannot automatically read MTN confirmation SMS on iPhone. Confirm the result when you know whether the payment succeeded or failed.'
                          : 'After completing the MTN payment, you can record the result here.',
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Confirm payment result',
            icon: HugeIcons.strokeRoundedTransactionHistory,
            size: AppButtonSize.sm,
            variant: AppButtonVariant.secondary,
            isLoading: isSaving,
            onPressed: isSaving ? null : onConfirm,
          ),
        ],
      ),
    );
  }
}

class _TransactionRecoveryCard extends StatelessWidget {
  const _TransactionRecoveryCard({
    required this.needsConfirmation,
    required this.isChecking,
    required this.lastCheckedAt,
    required this.message,
    required this.onCheck,
  });

  final bool needsConfirmation;
  final bool isChecking;
  final DateTime? lastCheckedAt;
  final String? message;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    final accent = needsConfirmation
        ? AppColors.primaryMuted
        : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedTransactionHistory,
                  size: 19,
                  strokeWidth: 1.8,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      needsConfirmation
                          ? 'Needs confirmation'
                          : 'Waiting for confirmation',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      needsConfirmation
                          ? 'Budgetify has not found reliable MTN confirmation yet. This does not mean the payment failed.'
                          : 'Budgetify will keep this transaction open until reliable MTN confirmation is found.',
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (message != null) ...[
            const SizedBox(height: 14),
            Text(
              message!,
              style: const TextStyle(
                fontSize: 10,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (lastCheckedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Last checked ${_formatDateTime(lastCheckedAt!.toLocal())}',
              style: TextStyle(
                fontSize: 9,
                color: AppColors.textSecondary.withValues(alpha: 0.72),
              ),
            ),
          ],
          const SizedBox(height: 16),
          AppButton(
            label: 'Check transaction status',
            icon: HugeIcons.strokeRoundedTransactionHistory,
            size: AppButtonSize.sm,
            variant: AppButtonVariant.secondary,
            isLoading: isChecking,
            onPressed: isChecking ? null : onCheck,
          ),
        ],
      ),
    );
  }
}

class _AmountMetric extends StatelessWidget {
  const _AmountMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({
    required this.transaction,
    required this.confirmationSource,
  });

  final PaymentTransaction transaction;
  final String? confirmationSource;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          _DetailRow(label: 'Recipient', value: transaction.receiverIdentifier),
          const _DetailDivider(),
          _DetailRow(label: 'Method', value: transaction.transferType.label),
          const _DetailDivider(),
          _DetailRow(label: 'Category', value: transaction.category.label),
          const _DetailDivider(),
          _DetailRow(label: 'Reference', value: transaction.reference),
          if (confirmationSource != null) ...[
            const _DetailDivider(),
            _DetailRow(label: 'Confirmation', value: confirmationSource!),
          ],
          if (transaction.providerReference != null) ...[
            const _DetailDivider(),
            _DetailRow(
              label: 'Provider reference',
              value: transaction.providerReference!,
            ),
          ],
          const _DetailDivider(),
          _DetailRow(
            label: 'Created',
            value: _formatDateTime(transaction.createdAt.toLocal()),
          ),
          if (transaction.processedAt != null) ...[
            const _DetailDivider(),
            _DetailRow(
              label: 'Processing',
              value: _formatDateTime(transaction.processedAt!.toLocal()),
            ),
          ],
          if (transaction.completedAt != null) ...[
            const _DetailDivider(),
            _DetailRow(
              label: 'Completed',
              value: _formatDateTime(transaction.completedAt!.toLocal()),
            ),
          ],
          if (transaction.failedAt != null) ...[
            const _DetailDivider(),
            _DetailRow(
              label: 'Failed',
              value: _formatDateTime(transaction.failedAt!.toLocal()),
            ),
          ],
          if (transaction.cancelledAt != null) ...[
            const _DetailDivider(),
            _DetailRow(
              label: 'Cancelled',
              value: _formatDateTime(transaction.cancelledAt!.toLocal()),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailDivider extends StatelessWidget {
  const _DetailDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Container(height: 1, color: Colors.white.withValues(alpha: 0.045)),
    );
  }
}

class _FailureCard extends StatelessWidget {
  const _FailureCard({required this.transaction});

  final PaymentTransaction transaction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Transaction issue',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.danger,
            ),
          ),
          if (transaction.failureCode != null) ...[
            const SizedBox(height: 7),
            Text(
              transaction.failureCode!,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          if (transaction.failureReason != null) ...[
            const SizedBox(height: 5),
            Text(
              transaction.failureReason!,
              style: const TextStyle(
                fontSize: 11,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TransactionTimeline extends StatelessWidget {
  const _TransactionTimeline({required this.events});

  final List<TransactionEventRecord> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'No lifecycle events recorded.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          for (var index = 0; index < events.length; index++)
            _TimelineItem(
              event: events[index],
              isLast: index == events.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.event, required this.isLast});

  final TransactionEventRecord event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = event.toStatus == null
        ? AppColors.primary
        : _statusColor(event.toStatus!);

    final transition = event.fromStatus == null
        ? event.toStatus?.label
        : '${event.fromStatus!.label} → ${event.toStatus?.label ?? 'Unknown'}';

    final isManualConfirmation =
        event.type == TransactionEventType.statusChanged &&
        event.source == TransactionEventSource.mobileApp;

    final eventTitle = isManualConfirmation
        ? 'Manual confirmation'
        : event.type.label;

    final sourceLabel = isManualConfirmation
        ? 'Reported in Budgetify'
        : event.source.label;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          child: Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              if (!isLast)
                Container(width: 1, height: 62, color: AppColors.border),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eventTitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [sourceLabel, ?transition].join(' • '),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _formatDateTime(event.occurredAt.toLocal()),
                  style: TextStyle(
                    fontSize: 9,
                    color: AppColors.textSecondary.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.transaction});

  final PaymentTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final needsConfirmation = transactionNeedsConfirmation(transaction);

    final color = needsConfirmation
        ? AppColors.primaryMuted
        : _statusColor(transaction.status);

    final label = needsConfirmation
        ? 'Needs confirmation'
        : transaction.status.label;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedTransactionHistory,
              size: 28,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: const Text(
                'Try again',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _statusColor(TransactionStatus status) {
  return switch (status) {
    TransactionStatus.completed => AppColors.success,
    TransactionStatus.failed || TransactionStatus.cancelled => AppColors.danger,
    TransactionStatus.processing => AppColors.primary,
    TransactionStatus.pending => AppColors.textSecondary,
    TransactionStatus.reversed => AppColors.primaryMuted,
  };
}

String _formatAmount(int amount) {
  final value = amount.toString();

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

String _formatDateTime(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final hour = date.hour == 0
      ? 12
      : date.hour > 12
      ? date.hour - 12
      : date.hour;

  final minute = date.minute.toString().padLeft(2, '0');

  final period = date.hour >= 12 ? 'PM' : 'AM';

  return '${date.day} ${months[date.month - 1]} ${date.year} • $hour:$minute $period';
}

String? _confirmationSource(TransactionDetail detail) {
  final status = detail.transaction.status;

  if (status != TransactionStatus.completed &&
      status != TransactionStatus.failed &&
      status != TransactionStatus.cancelled) {
    return null;
  }

  for (final event in detail.events.reversed) {
    if (event.toStatus != status) {
      continue;
    }

    if (event.type == TransactionEventType.providerResultReceived &&
        event.source == TransactionEventSource.providerSms) {
      return 'Confirmed from MTN';
    }

    if (event.type == TransactionEventType.providerResultReceived &&
        event.source == TransactionEventSource.providerApi) {
      return 'Confirmed by provider';
    }

    if (event.type == TransactionEventType.statusChanged &&
        event.source == TransactionEventSource.mobileApp) {
      return 'Manually confirmed';
    }
  }

  return null;
}
