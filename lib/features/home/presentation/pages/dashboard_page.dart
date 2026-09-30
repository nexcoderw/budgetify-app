import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../application/transaction_analytics_period.dart';
import '../../application/transaction_service.dart';
import '../../data/models/transaction_analytics_models.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    this.transactionService,
    this.refreshToken = 0,
  });

  final TransactionService? transactionService;

  final int refreshToken;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final TransactionService _transactionService;

  TransactionAnalyticsPeriodPreset _selectedPeriod =
      TransactionAnalyticsPeriodPreset.thisMonth;

  TransactionAnalytics? _analytics;

  String? _errorMessage;

  bool _isLoading = true;

  int _requestId = 0;

  @override
  void initState() {
    super.initState();

    _transactionService =
        widget.transactionService ?? TransactionService.createDefault();

    unawaited(_loadAnalytics());
  }

  @override
  void didUpdateWidget(covariant DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.refreshToken != widget.refreshToken) {
      unawaited(_loadAnalytics(preserveCurrent: true));
    }
  }

  Future<void> _loadAnalytics({bool preserveCurrent = false}) async {
    final requestId = ++_requestId;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;

        if (!preserveCurrent) {
          _analytics = null;
        }
      });
    }

    final range = _selectedPeriod.rangeFor(DateTime.now());

    try {
      final analytics = await _transactionService.analytics(
        from: range.from,
        to: range.to,
      );

      if (!mounted || requestId != _requestId) {
        return;
      }

      setState(() {
        _analytics = analytics;
        _errorMessage = null;
      });
    } on ApiException catch (error) {
      if (!mounted || requestId != _requestId) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) {
        return;
      }

      setState(() {
        _errorMessage = 'Could not load your transaction analytics.';
      });
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _selectPeriod(TransactionAnalyticsPeriodPreset period) {
    if (period == _selectedPeriod) {
      return;
    }

    setState(() {
      _selectedPeriod = period;
    });

    unawaited(_loadAnalytics());
  }

  @override
  Widget build(BuildContext context) {
    final analytics = _analytics;

    if (_isLoading && analytics == null) {
      return const _DashboardSkeleton();
    }

    if (analytics == null) {
      return _DashboardError(
        message: _errorMessage ?? 'Could not load transaction analytics.',
        onRetry: () {
          unawaited(_loadAnalytics());
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DashboardHeader(
          selectedPeriod: _selectedPeriod,
          analytics: analytics,
          isLoading: _isLoading,
          onPeriodSelected: _selectPeriod,
          onRefresh: () {
            unawaited(_loadAnalytics(preserveCurrent: true));
          },
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 14),
          _RefreshErrorBanner(message: _errorMessage!),
        ],
        const SizedBox(height: 18),
        _SummarySection(analytics: analytics),
        const SizedBox(height: 16),
        _StatusSection(summary: analytics.summary),
        const SizedBox(height: 16),
        _ConfirmationSection(confirmation: analytics.confirmation),
        const SizedBox(height: 16),
        _CategorySection(
          categories: analytics.categories,
          currency: analytics.currency,
        ),
        const SizedBox(height: 16),
        _TransferTypeSection(
          transferTypes: analytics.transferTypes,
          currency: analytics.currency,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.selectedPeriod,
    required this.analytics,
    required this.isLoading,
    required this.onPeriodSelected,
    required this.onRefresh,
  });

  final TransactionAnalyticsPeriodPreset selectedPeriod;

  final TransactionAnalytics analytics;

  final bool isLoading;

  final ValueChanged<TransactionAnalyticsPeriodPreset> onPeriodSelected;

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DASHBOARD',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 7),
                  Text(
                    'Your money activity',
                    style: TextStyle(
                      fontSize: 27,
                      height: 1.08,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: isLoading ? null : onRefresh,
              child: Text(isLoading ? 'Refreshing...' : 'Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _formatPeriodRange(analytics.period),
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              for (
                var index = 0;
                index < TransactionAnalyticsPeriodPreset.values.length;
                index++
              ) ...[
                if (index > 0) const SizedBox(width: 8),
                _PeriodChip(
                  period: TransactionAnalyticsPeriodPreset.values[index],
                  selected:
                      TransactionAnalyticsPeriodPreset.values[index] ==
                      selectedPeriod,
                  onTap: onPeriodSelected,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.period,
    required this.selected,
    required this.onTap,
  });

  final TransactionAnalyticsPeriodPreset period;

  final bool selected;

  final ValueChanged<TransactionAnalyticsPeriodPreset> onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: period.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            onTap(period);
          },
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.16)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.32)
                    : AppColors.border,
              ),
            ),
            child: Text(
              period.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.analytics});

  final TransactionAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final summary = analytics.summary;

    final comparison = analytics.comparison;

    return GlassPanel(
      blur: 22,
      opacity: 0.07,
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 720 ? 4 : 2;

          const gap = 10.0;

          final width =
              (constraints.maxWidth - (gap * (columns - 1))) / columns;

          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              SizedBox(
                width: width,
                child: _SummaryMetric(
                  label: 'Sent',
                  value:
                      '${_formatAmount(summary.sentAmount)} ${analytics.currency}',
                  icon: HugeIcons.strokeRoundedMoneySendSquare,
                  changePercentage: comparison.sentAmountChangePercentage,
                ),
              ),
              SizedBox(
                width: width,
                child: _SummaryMetric(
                  label: 'Fees',
                  value:
                      '${_formatAmount(summary.feesPaid)} ${analytics.currency}',
                  icon: HugeIcons.strokeRoundedWallet02,
                  changePercentage: comparison.feesPaidChangePercentage,
                ),
              ),
              SizedBox(
                width: width,
                child: _SummaryMetric(
                  label: 'Total debited',
                  value:
                      '${_formatAmount(summary.totalDebited)} ${analytics.currency}',
                  icon: HugeIcons.strokeRoundedMoneyReceiveCircle,
                  changePercentage: comparison.totalDebitedChangePercentage,
                ),
              ),
              SizedBox(
                width: width,
                child: _SummaryMetric(
                  label: 'Completed',
                  value: summary.completedTransactions.toString(),
                  icon: HugeIcons.strokeRoundedTransactionHistory,
                  changePercentage:
                      comparison.completedTransactionsChangePercentage,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.changePercentage,
  });

  final String label;
  final String value;
  final dynamic icon;
  final double? changePercentage;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 126),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.055)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: HugeIcon(
                  icon: icon,
                  size: 16,
                  strokeWidth: 1.8,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.35,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _formatComparison(changePercentage),
            style: const TextStyle(fontSize: 8, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _StatusSection extends StatelessWidget {
  const _StatusSection({required this.summary});

  final TransactionAnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      title: 'Transaction status',
      subtitle: 'Current lifecycle state for this period',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _StatusMetric(
            label: 'Completed',
            value: summary.completedTransactions,
            color: AppColors.success,
          ),
          _StatusMetric(
            label: 'Needs confirmation',
            value: summary.needsConfirmation,
            color: AppColors.primary,
            detail:
                '${summary.pendingTransactions} pending • ${summary.processingTransactions} processing',
          ),
          _StatusMetric(
            label: 'Failed',
            value: summary.failedTransactions,
            color: AppColors.danger,
          ),
          _StatusMetric(
            label: 'Cancelled',
            value: summary.cancelledTransactions,
            color: AppColors.textSecondary,
          ),
          _StatusMetric(
            label: 'Reversed',
            value: summary.reversedTransactions,
            color: AppColors.primaryMuted,
          ),
        ],
      ),
    );
  }
}

class _StatusMetric extends StatelessWidget {
  const _StatusMetric({
    required this.label,
    required this.value,
    required this.color,
    this.detail,
  });

  final String label;
  final int value;
  final Color color;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(
              detail!,
              style: const TextStyle(
                fontSize: 7.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConfirmationSection extends StatelessWidget {
  const _ConfirmationSection({required this.confirmation});

  final TransactionAnalyticsConfirmation confirmation;

  @override
  Widget build(BuildContext context) {
    final total = confirmation.total;

    final providerShare = total == 0
        ? 0.0
        : confirmation.providerConfirmed / total;

    return _DashboardCard(
      title: 'Confirmation source',
      subtitle: 'How completed payments were confirmed',
      child: total == 0
          ? const _EmptyBreakdown(
              message: 'No completed transactions in this period.',
            )
          : Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: providerShare,
                    minHeight: 8,
                    backgroundColor: AppColors.primaryMuted.withValues(
                      alpha: 0.22,
                    ),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _ConfirmationRow(
                  label: 'Confirmed from provider',
                  value: confirmation.providerConfirmed,
                ),
                const SizedBox(height: 10),
                _ConfirmationRow(
                  label: 'Manually confirmed',
                  value: confirmation.manuallyConfirmed,
                ),
                if (confirmation.unclassified > 0) ...[
                  const SizedBox(height: 10),
                  _ConfirmationRow(
                    label: 'Unclassified',
                    value: confirmation.unclassified,
                  ),
                ],
              ],
            ),
    );
  }
}

class _ConfirmationRow extends StatelessWidget {
  const _ConfirmationRow({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.categories, required this.currency});

  final List<TransactionCategoryAnalytics> categories;

  final String currency;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      title: 'Spending by category',
      subtitle: 'Completed transfer amounts only',
      child: categories.isEmpty
          ? const _EmptyBreakdown(
              message: 'No completed payments to categorize yet.',
            )
          : Column(
              children: [
                for (var index = 0; index < categories.length; index++) ...[
                  if (index > 0) const SizedBox(height: 14),
                  _BreakdownRow(
                    label: categories[index].category.label,
                    amount: categories[index].sentAmount,
                    currency: currency,
                    transactions: categories[index].transactions,
                    percentage: categories[index].percentage,
                  ),
                ],
              ],
            ),
    );
  }
}

class _TransferTypeSection extends StatelessWidget {
  const _TransferTypeSection({
    required this.transferTypes,
    required this.currency,
  });

  final List<TransactionTransferTypeAnalytics> transferTypes;

  final String currency;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      title: 'Payment methods',
      subtitle: 'How your completed transfers were sent',
      child: transferTypes.isEmpty
          ? const _EmptyBreakdown(
              message: 'No completed payment methods to show yet.',
            )
          : Column(
              children: [
                for (var index = 0; index < transferTypes.length; index++) ...[
                  if (index > 0) const SizedBox(height: 14),
                  _BreakdownRow(
                    label: transferTypes[index].transferType.label,
                    amount: transferTypes[index].sentAmount,
                    currency: currency,
                    transactions: transferTypes[index].transactions,
                    percentage: transferTypes[index].percentage,
                  ),
                ],
              ],
            ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.amount,
    required this.currency,
    required this.transactions,
    required this.percentage,
  });

  final String label;
  final int amount;
  final String currency;
  final int transactions;
  final double percentage;

  @override
  Widget build(BuildContext context) {
    final progress = (percentage.clamp(0, 100) / 100).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${_formatAmount(amount)} $currency',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: Text(
                '$transactions ${transactions == 1 ? 'transaction' : 'transactions'}',
                style: const TextStyle(
                  fontSize: 8,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Text(
              _formatPercentage(percentage),
              style: const TextStyle(
                fontSize: 8,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppColors.surfaceElevated,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

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
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _EmptyBreakdown extends StatelessWidget {
  const _EmptyBreakdown({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 10,
          height: 1.45,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _RefreshErrorBanner extends StatelessWidget {
  const _RefreshErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$message Showing the last loaded analytics.',
        style: const TextStyle(
          fontSize: 9,
          height: 1.45,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedDashboardSquare02,
              size: 30,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 14),
            const Text(
              'Analytics unavailable',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SkeletonBlock(width: 86, height: 10),
        const SizedBox(height: 10),
        const _SkeletonBlock(width: 220, height: 30),
        const SizedBox(height: 8),
        const _SkeletonBlock(width: 150, height: 11),
        const SizedBox(height: 22),
        Row(
          children: [
            for (var index = 0; index < 4; index++) ...[
              if (index > 0) const SizedBox(width: 8),
              const _SkeletonBlock(width: 74, height: 34, radius: 999),
            ],
          ],
        ),
        const SizedBox(height: 20),
        const _SkeletonBlock(width: double.infinity, height: 286, radius: 28),
        const SizedBox(height: 16),
        const _SkeletonBlock(width: double.infinity, height: 180, radius: 24),
        const SizedBox(height: 16),
        const _SkeletonBlock(width: double.infinity, height: 220, radius: 24),
      ],
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    required this.width,
    required this.height,
    this.radius = 10,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

String _formatComparison(double? percentage) {
  if (percentage == null) {
    return 'New vs previous period';
  }

  if (percentage == 0) {
    return 'No change vs previous period';
  }

  final prefix = percentage > 0 ? '+' : '';

  return '$prefix${_formatPercentage(percentage)} vs previous period';
}

String _formatPercentage(double value) {
  final isWhole = value == value.roundToDouble();

  return '${value.toStringAsFixed(isWhole ? 0 : 1)}%';
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

String _formatPeriodRange(TransactionAnalyticsPeriod period) {
  final from = period.from.toLocal();

  final to = period.to.toLocal();

  if (from.year == to.year && from.month == to.month && from.day == to.day) {
    return '${_shortDate(from)} • ${_shortTime(to)}';
  }

  if (from.year == to.year) {
    return '${from.day} ${_month(from.month)} – ${to.day} ${_month(to.month)} ${to.year}';
  }

  return '${from.day} ${_month(from.month)} ${from.year} – ${to.day} ${_month(to.month)} ${to.year}';
}

String _shortDate(DateTime date) {
  return '${date.day} ${_month(date.month)} ${date.year}';
}

String _shortTime(DateTime date) {
  final hour = date.hour == 0
      ? 12
      : date.hour > 12
      ? date.hour - 12
      : date.hour;

  final minute = date.minute.toString().padLeft(2, '0');

  final period = date.hour >= 12 ? 'PM' : 'AM';

  return '$hour:$minute $period';
}

String _month(int month) {
  const months = <String>[
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

  return months[month - 1];
}
