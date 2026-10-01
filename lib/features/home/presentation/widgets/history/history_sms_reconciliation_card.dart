import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/app_toast.dart';
import '../../../application/received_transaction_sms_reconciliation_service.dart';
import '../../../application/transaction_sms_reconciliation_service.dart';
import '../../../data/models/provider_sms_message.dart';

class HistorySmsReconciliationCard extends StatefulWidget {
  const HistorySmsReconciliationCard({
    super.key,
    required this.smsReconciliationService,
    required this.receivedSmsReconciliationService,
    required this.onHistoryChanged,
  });

  final TransactionSmsReconciliationService smsReconciliationService;

  final ReceivedTransactionSmsReconciliationService
  receivedSmsReconciliationService;

  final Future<void> Function() onHistoryChanged;

  @override
  State<HistorySmsReconciliationCard> createState() =>
      _HistorySmsReconciliationCardState();
}

class _HistorySmsReconciliationCardState
    extends State<HistorySmsReconciliationCard> {
  DeviceSmsPermission? _permission;

  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();

    unawaited(_loadPermission());
  }

  @override
  void didUpdateWidget(covariant HistorySmsReconciliationCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.smsReconciliationService != widget.smsReconciliationService) {
      unawaited(_loadPermission());
    }
  }

  Future<void> _loadPermission() async {
    try {
      final permission = await widget.smsReconciliationService
          .checkPermission();

      if (!mounted) {
        return;
      }

      setState(() {
        _permission = permission;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _permission = DeviceSmsPermission.unsupported;
      });
    }
  }

  Future<void> _enable() async {
    if (_isSyncing) {
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      final permission = await widget.smsReconciliationService
          .requestPermission();

      if (!mounted) {
        return;
      }

      setState(() {
        _permission = permission;
      });

      if (permission != DeviceSmsPermission.granted) {
        AppToast.error(
          context,
          title: 'SMS access not enabled',
          description:
              'Budgetify cannot automatically reconcile MTN MoMo transactions without SMS access.',
        );

        return;
      }

      await _sync(showResult: true);
    } catch (_) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'SMS access unavailable',
        description:
            'Budgetify could not enable automatic MTN transaction synchronization.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  Future<void> _syncFromCard() async {
    if (_isSyncing) {
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      await _sync(showResult: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  Future<void> _sync({required bool showResult}) async {
    var outgoing = const SmsReconciliationSummary.empty();

    var incoming = const ReceivedSmsReconciliationSummary.empty();

    var outgoingFailed = false;

    var incomingFailed = false;

    try {
      outgoing = await widget.smsReconciliationService.reconcile();
    } catch (_) {
      outgoingFailed = true;
    }

    try {
      incoming = await widget.receivedSmsReconciliationService.reconcile();
    } catch (_) {
      incomingFailed = true;
    }

    if (!mounted) {
      return;
    }

    final hasChanges = outgoing.hasChanges || incoming.hasAcceptedPayments;

    if (hasChanges) {
      await widget.onHistoryChanged();
    }

    if (!mounted || !showResult) {
      return;
    }

    if (outgoingFailed && incomingFailed) {
      AppToast.error(
        context,
        title: 'Could not sync transactions',
        description:
            'Budgetify could not check recent MTN MoMo transaction messages.',
      );

      return;
    }

    final uncertainCount =
        outgoing.ambiguousMessages + incoming.conflictingMessages;

    final failedCount = outgoing.failedUpdates + incoming.failedUpdates;

    final hasAttentionNeeded =
        outgoingFailed ||
        incomingFailed ||
        uncertainCount > 0 ||
        failedCount > 0;

    if (hasAttentionNeeded) {
      final parts = <String>[
        if (outgoing.matchedTransactions > 0)
          '${outgoing.matchedTransactions} sent updated',
        if (incoming.acceptedPayments > 0)
          '${incoming.acceptedPayments} received processed',
        if (uncertainCount > 0) '$uncertainCount uncertain',
        if (failedCount > 0) '$failedCount could not be updated',
        if (outgoingFailed) 'sent-payment sync unavailable',
        if (incomingFailed) 'received-payment sync unavailable',
      ];

      AppToast.info(
        context,
        title: 'Transaction review needed',
        description:
            '${parts.join(', ')}. Budgetify left uncertain evidence unchanged.',
      );

      return;
    }

    AppToast.info(
      context,
      title: hasChanges ? 'Money history updated' : 'Everything is up to date',
      description: hasChanges
          ? 'Budgetify synchronized reliable sent and received MTN transaction evidence.'
          : 'No new reliable transaction evidence was found.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final permission = _permission;

    if (permission == null || permission == DeviceSmsPermission.unsupported) {
      return const SizedBox.shrink();
    }

    final enabled = permission == DeviceSmsPermission.granted;

    final accent = enabled ? AppColors.success : AppColors.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: enabled
            ? AppColors.success.withValues(alpha: 0.06)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(14),
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedTransactionHistory,
              size: 19,
              strokeWidth: 1.8,
              color: accent,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enabled
                      ? 'Automatic transaction sync on'
                      : 'Sync MTN transactions automatically',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  enabled
                      ? 'Budgetify checks recent MTN MoMo messages for sent and received payments when the app resumes.'
                      : 'Allow Budgetify to read transaction SMS so sent and received payments can update automatically.',
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (!enabled) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Raw SMS text is never uploaded to the Budgetify API.',
                    style: TextStyle(
                      fontSize: 9,
                      height: 1.4,
                      color: AppColors.textSecondary.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: _isSyncing
                ? null
                : enabled
                ? () {
                    unawaited(_syncFromCard());
                  }
                : () {
                    unawaited(_enable());
                  },
            child: _isSyncing
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : Text(
                    enabled ? 'Sync' : 'Enable',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
