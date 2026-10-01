import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../../core/theme/app_colors.dart';

class HistoryHeader extends StatelessWidget {
  const HistoryHeader({
    super.key,
    required this.compact,
    required this.onRefresh,
    this.onRecordReceived,
  });

  final bool compact;

  final VoidCallback onRefresh;

  final VoidCallback? onRecordReceived;

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
                'TRANSACTIONS',
                style: TextStyle(
                  fontSize: 10,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: AppColors.primary.withValues(alpha: 0.92),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Money history',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: compact ? 26 : 32,
                  height: 1.05,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.9,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Track money you send and receive in one timeline.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (onRecordReceived != null) ...[
          _HistoryHeaderAction(
            tooltip: 'Record received money',
            icon: HugeIcons.strokeRoundedMoneyReceiveCircle,
            onTap: onRecordReceived!,
          ),
          const SizedBox(width: 8),
        ],
        _HistoryHeaderAction(
          tooltip: 'Refresh transactions',
          icon: HugeIcons.strokeRoundedTransactionHistory,
          onTap: onRefresh,
        ),
      ],
    );
  }
}

class _HistoryHeaderAction extends StatelessWidget {
  const _HistoryHeaderAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;

  final List<List<dynamic>> icon;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 46,
            height: 46,
            child: Center(
              child: HugeIcon(
                icon: icon,
                size: 21,
                strokeWidth: 1.8,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
