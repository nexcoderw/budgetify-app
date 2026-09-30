import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/transaction_service.dart';
import '../../data/models/transaction_models.dart';

class TransactionDetailPage extends StatefulWidget {
  const TransactionDetailPage({
    super.key,
    required this.transactionId,
    this.transactionService,
  });

  final String transactionId;
  final TransactionService? transactionService;

  @override
  State<TransactionDetailPage> createState() => _TransactionDetailPageState();
}

class _TransactionDetailPageState extends State<TransactionDetailPage> {
  late final TransactionService _transactionService;

  TransactionDetail? _detail;

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _transactionService =
        widget.transactionService ?? TransactionService.createDefault();

    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final detail = await _transactionService.getDetail(
        transactionId: widget.transactionId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _detail = detail;
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
      return _DetailError(message: error, onRetry: _load);
    }

    final detail = _detail;

    if (detail == null) {
      return const SizedBox.shrink();
    }

    final transaction = detail.transaction;

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
              _StatusBadge(status: transaction.status),
            ],
          ),
          const SizedBox(height: 24),
          _AmountSummary(transaction: transaction),
          const SizedBox(height: 16),
          _InformationCard(transaction: transaction),
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
  const _InformationCard({required this.transaction});

  final PaymentTransaction transaction;

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
          _DetailDivider(),
          _DetailRow(label: 'Method', value: transaction.transferType.label),
          _DetailDivider(),
          _DetailRow(label: 'Category', value: transaction.category.label),
          _DetailDivider(),
          _DetailRow(label: 'Reference', value: transaction.reference),
          if (transaction.providerReference != null) ...[
            _DetailDivider(),
            _DetailRow(
              label: 'Provider reference',
              value: transaction.providerReference!,
            ),
          ],
          _DetailDivider(),
          _DetailRow(
            label: 'Created',
            value: _formatDateTime(transaction.createdAt.toLocal()),
          ),
          if (transaction.completedAt != null) ...[
            _DetailDivider(),
            _DetailRow(
              label: 'Completed',
              value: _formatDateTime(transaction.completedAt!.toLocal()),
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
                  event.type.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    event.source.label,
                    if (transition != null) transition,
                  ].join(' • '),
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
  const _StatusBadge({required this.status});

  final TransactionStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
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
