import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_input.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../application/transaction_service.dart';
import '../../application/transaction_sms_reconciliation_service.dart';
import '../../data/models/provider_sms_message.dart';
import '../../data/models/transaction_models.dart';
import 'transaction_detail_page.dart';

enum _StatusFilter {
  all(null, 'All'),
  pending(TransactionStatus.pending, 'Pending'),
  processing(TransactionStatus.processing, 'Processing'),
  completed(TransactionStatus.completed, 'Completed'),
  failed(TransactionStatus.failed, 'Failed');

  const _StatusFilter(this.status, this.label);

  final TransactionStatus? status;
  final String label;
}

enum _MethodFilter {
  all(null, 'All methods'),
  momo(TransactionTransferType.momoToMomo, 'MTN MoMo'),
  ekash(TransactionTransferType.momoToEkash, 'eKash'),
  momoPay(TransactionTransferType.momoPay, 'MoMo Pay');

  const _MethodFilter(this.transferType, this.label);

  final TransactionTransferType? transferType;
  final String label;
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
    this.transactionService,
    this.smsReconciliationService,
    this.refreshToken = 0,
  });

  final TransactionService? transactionService;

  final TransactionSmsReconciliationService? smsReconciliationService;

  final int refreshToken;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  static const _pageSize = 20;

  final _searchController = TextEditingController();

  late final TransactionService _transactionService;

  late final TransactionSmsReconciliationService _smsReconciliationService;

  Timer? _searchDebounce;

  List<PaymentTransaction> _transactions = const [];

  TransactionPagination? _pagination;

  _StatusFilter _statusFilter = _StatusFilter.all;

  _MethodFilter _methodFilter = _MethodFilter.all;

  DeviceSmsPermission? _smsPermission;

  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _isSmsSyncing = false;

  String? _errorMessage;
  String? _loadMoreError;

  int _requestGeneration = 0;

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

    unawaited(_loadSmsPermission());

    unawaited(_loadTransactions(reset: true));
  }

  @override
  void didUpdateWidget(covariant HistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.refreshToken != widget.refreshToken) {
      unawaited(_loadTransactions(reset: true));
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();

    _searchController.dispose();

    super.dispose();
  }

  Future<void> _loadSmsPermission() async {
    try {
      final permission = await _smsReconciliationService.checkPermission();

      if (!mounted) {
        return;
      }

      setState(() {
        _smsPermission = permission;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _smsPermission = DeviceSmsPermission.unsupported;
      });
    }
  }

  Future<void> _enableSmsReconciliation() async {
    if (_isSmsSyncing) {
      return;
    }

    setState(() {
      _isSmsSyncing = true;
    });

    try {
      final permission = await _smsReconciliationService.requestPermission();

      if (!mounted) {
        return;
      }

      setState(() {
        _smsPermission = permission;
      });

      if (permission != DeviceSmsPermission.granted) {
        AppToast.error(
          context,
          title: 'SMS access not enabled',
          description:
              'Budgetify cannot automatically confirm MoMo transactions without SMS access.',
        );

        return;
      }

      await _syncTransactionSms(showResult: true);
    } catch (_) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'SMS access unavailable',
        description:
            'Budgetify could not enable automatic transaction confirmation.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSmsSyncing = false;
        });
      }
    }
  }

  Future<void> _syncSmsFromHistory() async {
    if (_isSmsSyncing) {
      return;
    }

    setState(() {
      _isSmsSyncing = true;
    });

    try {
      await _syncTransactionSms(showResult: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSmsSyncing = false;
        });
      }
    }
  }

  Future<void> _syncTransactionSms({required bool showResult}) async {
    try {
      final result = await _smsReconciliationService.reconcile();

      if (!mounted) {
        return;
      }

      if (result.hasChanges) {
        await _loadTransactions(reset: true);
      }

      if (!mounted || !showResult) {
        return;
      }

      AppToast.info(
        context,
        title: result.hasChanges
            ? 'Transactions updated'
            : 'Everything is up to date',
        description: result.hasChanges
            ? '${result.matchedTransactions} transaction${result.matchedTransactions == 1 ? '' : 's'} confirmed from MTN MoMo messages.'
            : 'No new transaction confirmations were found.',
      );
    } catch (_) {
      if (!mounted || !showResult) {
        return;
      }

      AppToast.error(
        context,
        title: 'Could not sync transactions',
        description:
            'Budgetify could not check recent MTN MoMo transaction messages.',
      );
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_loadTransactions(reset: true));
    });
  }

  void _onSearchSubmitted(String value) {
    _searchDebounce?.cancel();

    unawaited(_loadTransactions(reset: true));
  }

  void _selectStatus(_StatusFilter filter) {
    if (_statusFilter == filter) {
      return;
    }

    setState(() {
      _statusFilter = filter;
    });

    unawaited(_loadTransactions(reset: true));
  }

  void _selectMethod(_MethodFilter filter) {
    if (_methodFilter == filter) {
      return;
    }

    setState(() {
      _methodFilter = filter;
    });

    unawaited(_loadTransactions(reset: true));
  }

  Future<void> _loadTransactions({required bool reset}) async {
    if (!reset) {
      if (_isLoadingMore) {
        return;
      }

      if (!(_pagination?.hasNextPage ?? false)) {
        return;
      }
    }

    final generation = reset ? ++_requestGeneration : _requestGeneration;

    final page = reset ? 1 : (_pagination?.page ?? 0) + 1;

    if (reset) {
      setState(() {
        _isInitialLoading = true;

        _errorMessage = null;
        _loadMoreError = null;

        _transactions = const [];
        _pagination = null;
      });
    } else {
      setState(() {
        _isLoadingMore = true;
        _loadMoreError = null;
      });
    }

    try {
      final result = await _transactionService.list(
        page: page,
        limit: _pageSize,
        status: _statusFilter.status,
        transferType: _methodFilter.transferType,
        search: _searchController.text.trim(),
      );

      if (!mounted || generation != _requestGeneration) {
        return;
      }

      setState(() {
        _transactions = reset
            ? result.items
            : <PaymentTransaction>[..._transactions, ...result.items];

        _pagination = result.pagination;

        _errorMessage = null;
        _loadMoreError = null;
      });
    } on ApiException catch (error) {
      if (!mounted || generation != _requestGeneration) {
        return;
      }

      setState(() {
        if (reset) {
          _errorMessage = error.message;
        } else {
          _loadMoreError = error.message;
        }
      });
    } catch (_) {
      if (!mounted || generation != _requestGeneration) {
        return;
      }

      setState(() {
        if (reset) {
          _errorMessage = 'Could not load your transactions. Please try again.';
        } else {
          _loadMoreError = 'Could not load more transactions.';
        }
      });
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() {
          _isInitialLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _openTransaction(PaymentTransaction transaction) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TransactionDetailPage(
          transactionId: transaction.id,
          transactionService: _transactionService,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadTransactions(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    final isCompact = width < 700;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 0 : 4,
        vertical: isCompact ? 4 : 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HistoryHeader(
            compact: isCompact,
            onRefresh: _isInitialLoading
                ? null
                : () {
                    unawaited(_loadTransactions(reset: true));
                  },
          ),
          if (_smsPermission != null &&
              _smsPermission != DeviceSmsPermission.unsupported) ...[
            SizedBox(height: isCompact ? 16 : 18),
            _SmsReconciliationCard(
              permission: _smsPermission!,
              isSyncing: _isSmsSyncing,
              onEnable: () {
                unawaited(_enableSmsReconciliation());
              },
              onSync: () {
                unawaited(_syncSmsFromHistory());
              },
            ),
          ],
          SizedBox(height: isCompact ? 22 : 28),
          AppInput(
            controller: _searchController,
            hintText: 'Search recipient or reference',
            borderRadius: 999,
            textInputAction: TextInputAction.search,
            onChanged: _onSearchChanged,
            onSubmitted: _onSearchSubmitted,
          ),
          const SizedBox(height: 16),
          _FilterScroller<_StatusFilter>(
            values: _StatusFilter.values,
            selected: _statusFilter,
            labelBuilder: (filter) => filter.label,
            onSelected: _selectStatus,
          ),
          const SizedBox(height: 10),
          _FilterScroller<_MethodFilter>(
            values: _MethodFilter.values,
            selected: _methodFilter,
            labelBuilder: (filter) => filter.label,
            onSelected: _selectMethod,
          ),
          SizedBox(height: isCompact ? 22 : 28),
          _buildContent(compact: isCompact),
        ],
      ),
    );
  }

  Widget _buildContent({required bool compact}) {
    if (_isInitialLoading) {
      return const _HistoryLoading();
    }

    final error = _errorMessage;

    if (error != null && _transactions.isEmpty) {
      return _HistoryError(
        message: error,
        onRetry: () {
          unawaited(_loadTransactions(reset: true));
        },
      );
    }

    if (_transactions.isEmpty) {
      return const _EmptyHistory();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HistoryCount(
          loaded: _transactions.length,
          total: _pagination?.total ?? _transactions.length,
        ),
        const SizedBox(height: 16),
        _TransactionHistory(
          transactions: _transactions,
          compact: compact,
          onTap: _openTransaction,
        ),
        if (_loadMoreError != null) ...[
          const SizedBox(height: 14),
          Text(
            _loadMoreError!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppColors.danger),
          ),
        ],
        if (_pagination?.hasNextPage ?? false) ...[
          const SizedBox(height: 18),
          Center(
            child: _LoadMoreButton(
              isLoading: _isLoadingMore,
              onPressed: _isLoadingMore
                  ? null
                  : () {
                      unawaited(_loadTransactions(reset: false));
                    },
            ),
          ),
        ],
      ],
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({required this.compact, required this.onRefresh});

  final bool compact;
  final VoidCallback? onRefresh;

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
                'Track outgoing transfers recorded by Budgetify.',
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
        Tooltip(
          message: 'Refresh transactions',
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onRefresh,
              borderRadius: BorderRadius.circular(16),
              child: const SizedBox(
                width: 46,
                height: 46,
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedTransactionHistory,
                    size: 21,
                    strokeWidth: 1.8,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SmsReconciliationCard extends StatelessWidget {
  const _SmsReconciliationCard({
    required this.permission,
    required this.isSyncing,
    required this.onEnable,
    required this.onSync,
  });

  final DeviceSmsPermission permission;
  final bool isSyncing;
  final VoidCallback onEnable;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
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
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.11),
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
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enabled
                      ? 'Automatic confirmation on'
                      : 'Confirm transactions automatically',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  enabled
                      ? 'Budgetify checks recent MTN MoMo transaction messages when the app resumes.'
                      : 'Allow Budgetify to read transaction SMS so sent payments can update automatically.',
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
            onPressed: isSyncing
                ? null
                : enabled
                ? onSync
                : onEnable,
            child: isSyncing
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

class _FilterScroller<T> extends StatelessWidget {
  const _FilterScroller({
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;

  final String Function(T value) labelBuilder;

  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < values.length; index++) ...[
            if (index > 0) const SizedBox(width: 7),
            _FilterPill(
              label: labelBuilder(values[index]),
              selected: values[index] == selected,
              onTap: () {
                onSelected(values[index]);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label filter',
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.13)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
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

class _TransactionHistory extends StatelessWidget {
  const _TransactionHistory({
    required this.transactions,
    required this.compact,
    required this.onTap,
  });

  final List<PaymentTransaction> transactions;

  final bool compact;

  final ValueChanged<PaymentTransaction> onTap;

  @override
  Widget build(BuildContext context) {
    final grouped = <DateTime, List<PaymentTransaction>>{};

    for (final transaction in transactions) {
      final local = transaction.createdAt.toLocal();

      final date = DateTime(local.year, local.month, local.day);

      grouped.putIfAbsent(date, () => []);

      grouped[date]!.add(transaction);
    }

    return Column(
      children: [
        for (final entry in grouped.entries) ...[
          _DateGroup(
            date: entry.key,
            transactions: entry.value,
            compact: compact,
            onTap: onTap,
          ),
          if (entry.key != grouped.keys.last)
            SizedBox(height: compact ? 22 : 26),
        ],
      ],
    );
  }
}

class _DateGroup extends StatelessWidget {
  const _DateGroup({
    required this.date,
    required this.transactions,
    required this.compact,
    required this.onTap,
  });

  final DateTime date;

  final List<PaymentTransaction> transactions;

  final bool compact;

  final ValueChanged<PaymentTransaction> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _formatDate(date),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(compact ? 22 : 26),
          ),
          child: Column(
            children: [
              for (var index = 0; index < transactions.length; index++) ...[
                _TransactionTile(
                  transaction: transactions[index],
                  compact: compact,
                  onTap: () {
                    onTap(transactions[index]);
                  },
                ),
                if (index < transactions.length - 1)
                  Padding(
                    padding: EdgeInsets.only(left: compact ? 66 : 74),
                    child: Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.045),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.compact,
    required this.onTap,
  });

  final PaymentTransaction transaction;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _statusColor(transaction.status);

    final date = transaction.createdAt.toLocal();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 18,
            vertical: compact ? 14 : 16,
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 42 : 46,
                height: compact ? 42 : 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.center,
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedMoneySendSquare,
                  size: 19,
                  strokeWidth: 1.8,
                  color: accent,
                ),
              ),
              SizedBox(width: compact ? 12 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.recipientDisplayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${transaction.transferType.label} • ${transaction.receiverIdentifier}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _formatTime(date),
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.textSecondary.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '-${_formatAmount(transaction.amount)}',
                    style: TextStyle(
                      fontSize: compact ? 13 : 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'RWF',
                    style: TextStyle(
                      fontSize: 9,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 7),
                  _StatusBadge(status: transaction.status),
                ],
              ),
            ],
          ),
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _HistoryLoading extends StatelessWidget {
  const _HistoryLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 70),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(
              strokeWidth: 2.2,
              color: AppColors.primary,
            ),
            SizedBox(height: 14),
            Text(
              'Loading transactions...',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
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
              fontSize: 15,
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
          TextButton(
            onPressed: onRetry,
            child: const Text(
              'Try again',
              style: TextStyle(
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

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 46),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Column(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedTransactionHistory,
            size: 30,
            strokeWidth: 1.7,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: 16),
          Text(
            'No transactions found',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Your transactions will appear here once you start sending money.',
            textAlign: TextAlign.center,
            style: TextStyle(
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

String _formatDate(DateTime date) {
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

  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _formatTime(DateTime date) {
  final hour = date.hour == 0
      ? 12
      : date.hour > 12
      ? date.hour - 12
      : date.hour;

  final minute = date.minute.toString().padLeft(2, '0');

  final period = date.hour >= 12 ? 'PM' : 'AM';

  return '$hour:$minute $period';
}
