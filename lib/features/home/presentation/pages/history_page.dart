import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_input.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../application/received_transaction_service.dart';
import '../../application/received_transaction_sms_reconciliation_service.dart';
import '../../application/transaction_service.dart';
import '../../application/transaction_sms_reconciliation_service.dart';
import '../../data/models/provider_sms_message.dart';
import '../../data/models/transaction_history_models.dart';
import '../../data/models/transaction_models.dart';
import 'received_transaction_detail_page.dart';
import 'record_received_money_page.dart';
import 'transaction_detail_page.dart';

enum _DirectionFilter {
  all(null, 'All'),
  sent(TransactionHistoryDirection.sent, 'Sent'),
  received(TransactionHistoryDirection.received, 'Received');

  const _DirectionFilter(this.direction, this.label);

  final TransactionHistoryDirection? direction;
  final String label;
}

enum _StatusFilter {
  all(null, 'All statuses'),
  pending(TransactionStatus.pending, 'Pending'),
  processing(TransactionStatus.processing, 'Processing'),
  completed(TransactionStatus.completed, 'Completed'),
  failed(TransactionStatus.failed, 'Failed'),
  cancelled(TransactionStatus.cancelled, 'Cancelled'),
  reversed(TransactionStatus.reversed, 'Reversed');

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
    this.receivedTransactionService,
    this.smsReconciliationService,
    this.receivedSmsReconciliationService,
    this.refreshToken = 0,
  });

  final TransactionService? transactionService;

  final ReceivedTransactionService? receivedTransactionService;

  final TransactionSmsReconciliationService? smsReconciliationService;

  final ReceivedTransactionSmsReconciliationService?
  receivedSmsReconciliationService;

  final int refreshToken;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  static const int _pageSize = 20;

  final TextEditingController _searchController = TextEditingController();

  late final TransactionService _transactionService;

  late final ReceivedTransactionService _receivedTransactionService;

  late final TransactionSmsReconciliationService _smsReconciliationService;

  late final ReceivedTransactionSmsReconciliationService
  _receivedSmsReconciliationService;

  Timer? _searchDebounce;

  List<TransactionHistoryItem> _transactions = const [];

  TransactionPagination? _pagination;

  _DirectionFilter _directionFilter = _DirectionFilter.all;

  _StatusFilter _statusFilter = _StatusFilter.all;

  _MethodFilter _methodFilter = _MethodFilter.all;

  DeviceSmsPermission? _smsPermission;

  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _isSmsSyncing = false;

  String? _errorMessage;
  String? _loadMoreError;

  int _requestGeneration = 0;

  bool get _shouldShowSmsSkeleton {
    final permission = _smsPermission;

    if (permission != null) {
      return permission != DeviceSmsPermission.unsupported;
    }

    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  }

  bool get _shouldShowManualReceivedAction {
    return supportsManualReceivedPaymentEntry;
  }

  List<_StatusFilter> get _availableStatusFilters {
    if (_directionFilter == _DirectionFilter.received) {
      return const [
        _StatusFilter.all,
        _StatusFilter.completed,
        _StatusFilter.reversed,
      ];
    }

    return _StatusFilter.values;
  }

  bool get _shouldShowMethodFilter {
    return _directionFilter == _DirectionFilter.sent;
  }

  @override
  void initState() {
    super.initState();

    _transactionService =
        widget.transactionService ?? TransactionService.createDefault();

    _receivedTransactionService =
        widget.receivedTransactionService ??
        ReceivedTransactionService.createDefault();

    _smsReconciliationService =
        widget.smsReconciliationService ??
        TransactionSmsReconciliationService.createDefault(
          transactionService: _transactionService,
        );

    _receivedSmsReconciliationService =
        widget.receivedSmsReconciliationService ??
        ReceivedTransactionSmsReconciliationService.createDefault(
          receivedTransactionService: _receivedTransactionService,
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
              'Budgetify cannot automatically reconcile MTN MoMo transactions without SMS access.',
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
            'Budgetify could not enable automatic MTN transaction synchronization.',
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
    var outgoing = const SmsReconciliationSummary.empty();

    var incoming = const ReceivedSmsReconciliationSummary.empty();

    var outgoingFailed = false;
    var incomingFailed = false;

    try {
      outgoing = await _smsReconciliationService.reconcile();
    } catch (_) {
      outgoingFailed = true;
    }

    try {
      incoming = await _receivedSmsReconciliationService.reconcile();
    } catch (_) {
      incomingFailed = true;
    }

    if (!mounted) {
      return;
    }

    final hasChanges = outgoing.hasChanges || incoming.hasAcceptedPayments;

    if (hasChanges) {
      await _loadTransactions(reset: true);
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

  Future<void> _recordReceivedMoney() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => RecordReceivedMoneyPage(
          receivedTransactionService: _receivedTransactionService,
        ),
      ),
    );

    if (!mounted || saved != true) {
      return;
    }

    await _loadTransactions(reset: true);

    if (!mounted) {
      return;
    }

    AppToast.success(
      context,
      title: 'Received money saved',
      description:
          'The payment was recorded as manually reported received money.',
    );
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

  void _selectDirection(_DirectionFilter filter) {
    if (_directionFilter == filter) {
      return;
    }

    setState(() {
      _directionFilter = filter;

      if (filter != _DirectionFilter.sent) {
        _methodFilter = _MethodFilter.all;
      }

      if (filter == _DirectionFilter.received &&
          !_isReceivedSupportedStatus(_statusFilter)) {
        _statusFilter = _StatusFilter.all;
      }
    });

    unawaited(_loadTransactions(reset: true));
  }

  bool _isReceivedSupportedStatus(_StatusFilter filter) {
    return filter == _StatusFilter.all ||
        filter == _StatusFilter.completed ||
        filter == _StatusFilter.reversed;
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
      final result = await _transactionService.history(
        page: page,
        limit: _pageSize,
        direction: _directionFilter.direction,
        status: _statusFilter.status,
        transferType: _directionFilter == _DirectionFilter.sent
            ? _methodFilter.transferType
            : null,
        search: _searchController.text.trim(),
      );

      if (!mounted || generation != _requestGeneration) {
        return;
      }

      setState(() {
        _transactions = reset
            ? result.items
            : <TransactionHistoryItem>[..._transactions, ...result.items];

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
          _errorMessage =
              'Could not load your money history. Please try again.';
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

  Future<void> _openTransaction(TransactionHistoryItem transaction) async {
    if (transaction.isSent) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => TransactionDetailPage(
            transactionId: transaction.id,
            transactionService: _transactionService,
            smsReconciliationService: _smsReconciliationService,
          ),
        ),
      );
    } else {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ReceivedTransactionDetailPage(
            receivedTransactionId: transaction.id,
            receivedTransactionService: _receivedTransactionService,
          ),
        ),
      );
    }

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
      child: _isInitialLoading
          ? _HistoryPageSkeleton(
              compact: isCompact,
              showSmsCard: _shouldShowSmsSkeleton,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HistoryHeader(
                  compact: isCompact,
                  onRecordReceived: _shouldShowManualReceivedAction
                      ? () {
                          unawaited(_recordReceivedMoney());
                        }
                      : null,
                  onRefresh: () {
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
                  hintText: 'Search sender, recipient or reference',
                  borderRadius: 999,
                  textInputAction: TextInputAction.search,
                  onChanged: _onSearchChanged,
                  onSubmitted: _onSearchSubmitted,
                ),
                const SizedBox(height: 16),
                _FilterScroller<_DirectionFilter>(
                  values: _DirectionFilter.values,
                  selected: _directionFilter,
                  labelBuilder: (filter) => filter.label,
                  onSelected: _selectDirection,
                ),
                const SizedBox(height: 10),
                _FilterScroller<_StatusFilter>(
                  values: _availableStatusFilters,
                  selected: _statusFilter,
                  labelBuilder: (filter) => filter.label,
                  onSelected: _selectStatus,
                ),
                if (_shouldShowMethodFilter) ...[
                  const SizedBox(height: 10),
                  _FilterScroller<_MethodFilter>(
                    values: _MethodFilter.values,
                    selected: _methodFilter,
                    labelBuilder: (filter) => filter.label,
                    onSelected: _selectMethod,
                  ),
                ],
                SizedBox(height: isCompact ? 22 : 28),
                _buildContent(compact: isCompact),
              ],
            ),
    );
  }

  Widget _buildContent({required bool compact}) {
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
      return _EmptyHistory(direction: _directionFilter);
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
  const _HistoryHeader({
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

  final List<TransactionHistoryItem> transactions;

  final bool compact;

  final ValueChanged<TransactionHistoryItem> onTap;

  @override
  Widget build(BuildContext context) {
    final grouped = <DateTime, List<TransactionHistoryItem>>{};

    for (final transaction in transactions) {
      final local = transaction.activityAt.toLocal();

      final date = DateTime(local.year, local.month, local.day);

      grouped.putIfAbsent(date, () => []);

      grouped[date]!.add(transaction);
    }

    final entries = grouped.entries.toList(growable: false);

    return Column(
      children: [
        for (var index = 0; index < entries.length; index++) ...[
          _DateGroup(
            date: entries[index].key,
            transactions: entries[index].value,
            compact: compact,
            onTap: onTap,
          ),
          if (index < entries.length - 1) SizedBox(height: compact ? 22 : 26),
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

  final List<TransactionHistoryItem> transactions;

  final bool compact;

  final ValueChanged<TransactionHistoryItem> onTap;

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

  final TransactionHistoryItem transaction;

  final bool compact;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final received = transaction.isReceived;

    final accent = _transactionStatusColor(transaction);

    final local = transaction.activityAt.toLocal();

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
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: HugeIcon(
                  icon: received
                      ? HugeIcons.strokeRoundedMoneyReceiveCircle
                      : HugeIcons.strokeRoundedMoneySendSquare,
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
                      transaction.counterpartyDisplayName,
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
                      _subtitleForTransaction(transaction),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _formatTime(local),
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
                    '${received ? '+' : '-'}${_formatAmount(transaction.amount)}',
                    style: TextStyle(
                      fontSize: compact ? 13 : 14,
                      fontWeight: FontWeight.w800,
                      color: received
                          ? AppColors.success
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    transaction.currency,
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 7),
                  _StatusBadge(transaction: transaction),
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
  const _StatusBadge({required this.transaction});

  final TransactionHistoryItem transaction;

  @override
  Widget build(BuildContext context) {
    final needsConfirmation = transaction.needsConfirmation();

    final color = _transactionStatusColor(transaction);

    final label = needsConfirmation
        ? 'Needs confirmation'
        : transaction.status.label;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _HistoryPageSkeleton extends StatelessWidget {
  const _HistoryPageSkeleton({
    required this.compact,
    required this.showSmsCard,
  });

  final bool compact;

  final bool showSmsCard;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SkeletonBox(width: 92, height: 10),
                      const SizedBox(height: 10),
                      _SkeletonBox(
                        width: compact ? 176 : 218,
                        height: compact ? 27 : 32,
                      ),
                      const SizedBox(height: 8),
                      const _SkeletonBox(width: 260, height: 12),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const _SkeletonBox(width: 46, height: 46, radius: 16),
              ],
            ),
            if (showSmsCard) ...[
              SizedBox(height: compact ? 16 : 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    _SkeletonBox(width: 42, height: 42, radius: 14),
                    SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SkeletonBox(width: 170, height: 12),
                          SizedBox(height: 8),
                          _SkeletonBox(width: double.infinity, height: 9),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: compact ? 22 : 28),
            const _SkeletonBox(width: double.infinity, height: 56, radius: 999),
            const SizedBox(height: 16),
            const Row(
              children: [
                _SkeletonBox(width: 48, height: 36, radius: 999),
                SizedBox(width: 7),
                _SkeletonBox(width: 58, height: 36, radius: 999),
                SizedBox(width: 7),
                _SkeletonBox(width: 82, height: 36, radius: 999),
              ],
            ),
            const SizedBox(height: 10),
            const Row(
              children: [
                _SkeletonBox(width: 90, height: 36, radius: 999),
                SizedBox(width: 7),
                _SkeletonBox(width: 72, height: 36, radius: 999),
                SizedBox(width: 7),
                _SkeletonBox(width: 88, height: 36, radius: 999),
              ],
            ),
            SizedBox(height: compact ? 22 : 28),
            const Row(
              children: [
                _SkeletonBox(width: 122, height: 18),
                Spacer(),
                _SkeletonBox(width: 50, height: 11),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(compact ? 22 : 26),
              ),
              child: const Column(
                children: [
                  _HistoryTileSkeleton(),
                  SizedBox(height: 18),
                  _HistoryTileSkeleton(),
                  SizedBox(height: 18),
                  _HistoryTileSkeleton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTileSkeleton extends StatelessWidget {
  const _HistoryTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _SkeletonBox(width: 44, height: 44, radius: 15),
        SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SkeletonBox(width: 135, height: 12),
              SizedBox(height: 7),
              _SkeletonBox(width: 180, height: 9),
              SizedBox(height: 7),
              _SkeletonBox(width: 58, height: 8),
            ],
          ),
        ),
        SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _SkeletonBox(width: 72, height: 13),
            SizedBox(height: 8),
            _SkeletonBox(width: 64, height: 20, radius: 999),
          ],
        ),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.width,
    required this.height,
    this.radius = 6,
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
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(radius),
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

  final _DirectionFilter direction;

  @override
  Widget build(BuildContext context) {
    final description = switch (direction) {
      _DirectionFilter.sent =>
        'Payments you send will appear here once Budgetify records them.',
      _DirectionFilter.received =>
        'Payments you receive will appear here after Budgetify detects or records them.',
      _DirectionFilter.all =>
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

String _subtitleForTransaction(TransactionHistoryItem transaction) {
  final identifier = transaction.counterpartyIdentifier?.trim();

  final prefix = transaction.isReceived ? 'Received' : transaction.methodLabel;

  if (identifier == null || identifier.isEmpty) {
    return prefix;
  }

  return '$prefix • $identifier';
}

Color _transactionStatusColor(TransactionHistoryItem transaction) {
  if (transaction.needsConfirmation()) {
    return AppColors.primaryMuted;
  }

  return switch (transaction.status) {
    TransactionStatus.completed =>
      transaction.isReceived ? AppColors.success : AppColors.primary,

    TransactionStatus.failed ||
    TransactionStatus.cancelled ||
    TransactionStatus.reversed => AppColors.danger,

    TransactionStatus.processing => AppColors.primary,

    TransactionStatus.pending => AppColors.textSecondary,
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
