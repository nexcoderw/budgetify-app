import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../data/models/transaction_history_models.dart';
import 'history_transaction_list.dart';

class HistoryContent extends StatelessWidget {
  const HistoryContent({
    super.key,
    required this.transactions,
    required this.direction,
    required this.total,
    required this.compact,
    required this.errorMessage,
    required this.loadMoreError,
    required this.hasNextPage,
    required this.isLoadingMore,
    required this.onRetry,
    required this.onLoadMore,
    required this.onTransactionTap,
  });

  final List<TransactionHistoryItem> transactions;

  final TransactionHistoryDirection? direction;

  final int total;

  final bool compact;

  final String? errorMessage;

  final String? loadMoreError;

  final bool hasNextPage;

  final bool isLoadingMore;

  final VoidCallback onRetry;

  final VoidCallback onLoadMore;

  final ValueChanged<TransactionHistoryItem> onTransactionTap;

  @override
  Widget build(BuildContext context) {
    final error = errorMessage;

    if (error != null && transactions.isEmpty) {
      return _HistoryError(message: error, onRetry: onRetry);
    }

    if (transactions.isEmpty) {
      return _EmptyHistory(direction: direction);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HistoryCount(loaded: transactions.length, total: total),
        const SizedBox(height: 16),
        HistoryTransactionList(
          transactions: transactions,
          compact: compact,
          onTap: onTransactionTap,
        ),
        if (loadMoreError != null) ...[
          const SizedBox(height: 14),
          Text(
            loadMoreError!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppColors.danger),
          ),
        ],
        if (hasNextPage) ...[
          const SizedBox(height: 18),
          Center(
            child: _LoadMoreButton(
              isLoading: isLoadingMore,
              onPressed: isLoadingMore ? null : onLoadMore,
            ),
          ),
        ],
      ],
    );
  }
}

class _HistoryCount extends StatelessWidget {
  const _HistoryCount({required this.loaded, required this.total});

  final int loaded;

  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Recent activity',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        Text(
          '$loaded of $total',
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.message, required this.onRetry});

  final String message;

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedTransactionHistory,
            size: 28,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 14),
          const Text(
            'Could not load history',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.direction});

  final TransactionHistoryDirection? direction;

  @override
  Widget build(BuildContext context) {
    final description = switch (direction) {
      TransactionHistoryDirection.sent =>
        'Payments you send will appear here once Budgetify records them.',

      TransactionHistoryDirection.received =>
        'Payments you receive will appear here after Budgetify detects or records them.',

      null =>
        'Money you send and receive will appear here once transactions are recorded.',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 46),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedTransactionHistory,
            size: 30,
            strokeWidth: 1.7,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          const Text(
            'No transactions found',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({required this.isLoading, required this.onPressed});

  final bool isLoading;

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      ),
      child: isLoading
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          : const Text(
              'Load more',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
    );
  }
}
