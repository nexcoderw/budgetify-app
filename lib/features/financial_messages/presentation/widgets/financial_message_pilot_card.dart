import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/financial_message_pilot_summary.dart';

class FinancialMessagePilotCard extends StatelessWidget {
  const FinancialMessagePilotCard({
    super.key,
    required this.summary,
    required this.loading,
    required this.hasError,
    required this.onRetry,
    required this.onUpdateShortcut,
  });

  final FinancialMessagePilotSummary? summary;
  final bool loading;
  final bool hasError;
  final VoidCallback onRetry;
  final VoidCallback onUpdateShortcut;

  @override
  Widget build(BuildContext context) {
    if (loading && summary == null) {
      return const _PilotCardShell(
        child: SizedBox(
          height: 54,
          child: Center(child: LinearProgressIndicator()),
        ),
      );
    }
    if (hasError && summary == null) {
      return _PilotCardShell(
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Pilot health is temporarily unavailable.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }
    final data = summary;
    if (data == null) {
      return const SizedBox.shrink();
    }

    final health = switch (data.health) {
      FinancialMessagePilotHealth.healthy => (
        'Healthy',
        const Color(0xFF65C89B),
      ),
      FinancialMessagePilotHealth.needsAttention => (
        'Review needed',
        const Color(0xFFFFB86B),
      ),
      FinancialMessagePilotHealth.insufficientData => (
        'Collecting data',
        AppColors.textSecondary,
      ),
    };

    return _PilotCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'iPhone import · ${data.mode}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: health.$2.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  health.$1,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: health.$2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Metric(
                value: data.total,
                label: '${data.windowDays}-day imports',
              ),
              _Metric(value: data.confirmed, label: 'Recorded'),
              _Metric(value: data.needsReview, label: 'Needs review'),
            ],
          ),
          if (data.hasOutdatedShortcuts) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(11, 8, 6, 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB86B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'A connected Shortcut needs an update.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onUpdateShortcut,
                    child: const Text('Update'),
                  ),
                ],
              ),
            ),
          ],
          if (data.providers.isNotEmpty) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: data.providers
                    .map(
                      (provider) => Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${provider.label} · ${provider.parseRatePercent}% · ${_readinessLabel(provider.readiness)}',
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _readinessLabel(FinancialMessageProviderReadiness readiness) {
  return switch (readiness) {
    FinancialMessageProviderReadiness.monitoring => 'monitoring',
    FinancialMessageProviderReadiness.readyToEnable => 'ready',
    FinancialMessageProviderReadiness.needsAttention => 'review',
    FinancialMessageProviderReadiness.insufficientData => 'collecting',
  };
}

class _PilotCardShell extends StatelessWidget {
  const _PilotCardShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(18, 12, 18, 4),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
    ),
    child: child,
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}
