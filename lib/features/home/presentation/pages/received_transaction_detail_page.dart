import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../application/received_transaction_service.dart';
import '../../data/models/received_transaction_models.dart';

class ReceivedTransactionDetailPage extends StatefulWidget {
  const ReceivedTransactionDetailPage({
    super.key,
    required this.receivedTransactionId,
    this.receivedTransactionService,
  });

  final String receivedTransactionId;

  final ReceivedTransactionService? receivedTransactionService;

  @override
  State<ReceivedTransactionDetailPage> createState() =>
      _ReceivedTransactionDetailPageState();
}

class _ReceivedTransactionDetailPageState
    extends State<ReceivedTransactionDetailPage> {
  late final ReceivedTransactionService _service;

  ReceivedTransaction? _transaction;

  bool _isLoading = true;

  bool _isUpdatingClassification = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _service =
        widget.receivedTransactionService ??
        ReceivedTransactionService.createDefault();

    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;

      _errorMessage = null;
    });

    try {
      final transaction = await _service.getDetail(
        receivedTransactionId: widget.receivedTransactionId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _transaction = transaction;
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
        _errorMessage = 'Could not load received transaction details.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _chooseClassification() async {
    if (_isUpdatingClassification) {
      return;
    }

    final transaction = _transaction;

    if (transaction == null) {
      return;
    }

    final selected =
        await showModalBottomSheet<ReceivedTransactionClassification>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (sheetContext) {
            return _ClassificationSheet(
              selected: transaction.classification,
              onSelected: (classification) {
                Navigator.of(sheetContext).pop(classification);
              },
            );
          },
        );

    if (!mounted ||
        selected == null ||
        selected == transaction.classification) {
      return;
    }

    await _updateClassification(selected);
  }

  Future<void> _updateClassification(
    ReceivedTransactionClassification classification,
  ) async {
    if (_isUpdatingClassification) {
      return;
    }

    setState(() {
      _isUpdatingClassification = true;
    });

    try {
      final updated = await _service.updateClassification(
        receivedTransactionId: widget.receivedTransactionId,
        classification: classification,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _transaction = updated;
      });

      AppToast.success(
        context,
        title: 'Classification updated',
        description:
            'This received payment is now classified as ${updated.classification.label.toLowerCase()}.',
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Could not update classification',
        description: error.message,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Could not update classification',
        description:
            'Budgetify could not save this classification. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingClassification = false;
        });
      }
    }
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
                  _BackButton(
                    onTap: () {
                      if (_isUpdatingClassification) {
                        return;
                      }

                      Navigator.of(context).pop();
                    },
                  ),
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () {
                unawaited(_load());
              },
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    final transaction = _transaction;

    if (transaction == null) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'RECEIVED PAYMENT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Payment details',
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
          _AmountCard(transaction: transaction),
          const SizedBox(height: 16),
          _ClassificationCard(
            classification: transaction.classification,
            isSaving: _isUpdatingClassification,
            onChange: () {
              unawaited(_chooseClassification());
            },
          ),
          const SizedBox(height: 16),
          _InfoCard(transaction: transaction),
          if (transaction.evidenceSource ==
              ReceivedTransactionEvidenceSource.providerSms) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'This payment was detected from structured transaction evidence parsed from an MTN SMS on the device. It is not independent MTN API verification.',
                style: TextStyle(
                  fontSize: 10,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

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
            onTap: onTap,
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

class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.transaction});

  final ReceivedTransaction transaction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const HugeIcon(
              icon: HugeIcons.strokeRoundedMoneyReceiveCircle,
              size: 25,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            '+${_formatAmount(transaction.amount)} RWF',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'From ${transaction.senderDisplayName}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassificationCard extends StatelessWidget {
  const _ClassificationCard({
    required this.classification,
    required this.isSaving,
    required this.onChange,
  });

  final ReceivedTransactionClassification classification;

  final bool isSaving;

  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Classification',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Describe what this received money represents. This changes analytics only and does not change the payment itself.',
            style: TextStyle(
              fontSize: 9.5,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedTransactionHistory,
                    size: 18,
                    strokeWidth: 1.8,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classification.label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _classificationDescription(classification),
                        style: const TextStyle(
                          fontSize: 9,
                          height: 1.35,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppButton(
            label: 'Change classification',
            icon: HugeIcons.strokeRoundedArrowRight01,
            variant: AppButtonVariant.secondary,
            isLoading: isSaving,
            onPressed: isSaving ? null : onChange,
          ),
        ],
      ),
    );
  }
}

class _ClassificationSheet extends StatelessWidget {
  const _ClassificationSheet({
    required this.selected,
    required this.onSelected,
  });

  final ReceivedTransactionClassification selected;

  final ValueChanged<ReceivedTransactionClassification> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.32),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Classify received money',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose the description that best matches this payment. You can change it again later.',
              style: TextStyle(
                fontSize: 10,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            for (
              var index = 0;
              index < ReceivedTransactionClassification.values.length;
              index++
            ) ...[
              if (index > 0) const SizedBox(height: 8),
              _ClassificationOption(
                classification: ReceivedTransactionClassification.values[index],
                selected:
                    ReceivedTransactionClassification.values[index] == selected,
                onTap: onSelected,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ClassificationOption extends StatelessWidget {
  const _ClassificationOption({
    required this.classification,
    required this.selected,
    required this.onTap,
  });

  final ReceivedTransactionClassification classification;

  final bool selected;

  final ValueChanged<ReceivedTransactionClassification> onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.10)
          : AppColors.surfaceElevated.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () {
          onTap(classification);
        },
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.border,
                    width: 1.5,
                  ),
                  color: selected ? AppColors.primary : Colors.transparent,
                ),
                child: selected
                    ? const Icon(
                        Icons.check,
                        size: 14,
                        color: AppColors.background,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      classification.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppColors.textPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _classificationDescription(classification),
                      style: const TextStyle(
                        fontSize: 8.5,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.transaction});

  final ReceivedTransaction transaction;

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
          _InfoRow(label: 'Sender', value: transaction.senderDisplayName),
          _InfoRow(
            label: 'Sender identifier',
            value: transaction.senderIdentifier ?? 'Not available',
          ),
          _InfoRow(
            label: 'Classification',
            value: transaction.classification.label,
          ),
          _InfoRow(label: 'Evidence', value: transaction.evidenceSource.label),
          _InfoRow(
            label: 'Provider reference',
            value: transaction.providerReference ?? 'Not available',
          ),
          _InfoRow(label: 'Budgetify reference', value: transaction.reference),
          _InfoRow(
            label: 'Received',
            value: _formatDateTime(transaction.occurredAt),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;

  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 124,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.transaction});

  final ReceivedTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final reversed = transaction.status == ReceivedTransactionStatus.reversed;

    final color = reversed ? AppColors.danger : AppColors.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        transaction.status.label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

String _classificationDescription(
  ReceivedTransactionClassification classification,
) {
  return switch (classification) {
    ReceivedTransactionClassification.unclassified => 'Not categorized yet.',

    ReceivedTransactionClassification.income =>
      'Money treated as earned income.',

    ReceivedTransactionClassification.reimbursement =>
      'Money returned for something you previously paid for.',

    ReceivedTransactionClassification.loanRepayment =>
      'Money received as repayment of a loan.',

    ReceivedTransactionClassification.ownTransfer =>
      'Money moved between accounts that belong to you.',

    ReceivedTransactionClassification.other =>
      'Received money that does not fit another category.',
  };
}

String _formatAmount(int amount) {
  final digits = amount.toString();

  final buffer = StringBuffer();

  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write(',');
    }

    buffer.write(digits[index]);
  }

  return buffer.toString();
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();

  String two(int number) {
    return number.toString().padLeft(2, '0');
  }

  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
