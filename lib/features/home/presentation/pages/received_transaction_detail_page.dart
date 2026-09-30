import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
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
                  _BackButton(onTap: () => Navigator.of(context).pop()),
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

  String two(int number) => number.toString().padLeft(2, '0');

  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
