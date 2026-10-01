import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../application/received_transaction_service.dart';
import '../../application/received_transaction_sms_reconciliation_service.dart';
import '../../application/transaction_service.dart';
import '../../application/transaction_sms_reconciliation_service.dart';
import '../../data/models/transaction_history_models.dart';
import '../../data/models/transaction_models.dart';
import '../widgets/history/history_content.dart';
import '../widgets/history/history_filter_controls.dart';
import '../widgets/history/history_header.dart';
import '../widgets/history/history_page_skeleton.dart';
import '../widgets/history/history_sms_reconciliation_card.dart';
import 'received_transaction_detail_page.dart';
import 'record_received_money_page.dart';
import 'transaction_detail_page.dart';

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

  HistoryDirectionFilter _directionFilter = HistoryDirectionFilter.all;

  HistoryStatusFilter _statusFilter = HistoryStatusFilter.all;

  HistoryMethodFilter _methodFilter = HistoryMethodFilter.all;

  bool _isInitialLoading = true;

  bool _isLoadingMore = false;

  String? _errorMessage;

  String? _loadMoreError;

  int _requestGeneration = 0;

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

  void _selectDirection(HistoryDirectionFilter filter) {
    if (_directionFilter == filter) {
      return;
    }

    setState(() {
      _directionFilter = filter;

      if (filter != HistoryDirectionFilter.sent) {
        _methodFilter = HistoryMethodFilter.all;
      }

      if (filter == HistoryDirectionFilter.received &&
          !_statusFilter.supportsReceivedHistory) {
        _statusFilter = HistoryStatusFilter.all;
      }
    });

    unawaited(_loadTransactions(reset: true));
  }

  void _selectStatus(HistoryStatusFilter filter) {
    if (_statusFilter == filter) {
      return;
    }

    setState(() {
      _statusFilter = filter;
    });

    unawaited(_loadTransactions(reset: true));
  }

  void _selectMethod(HistoryMethodFilter filter) {
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
        transferType: _directionFilter == HistoryDirectionFilter.sent
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
          ? HistoryPageSkeleton(
              compact: isCompact,
              showSmsCard: _smsReconciliationService.isSupported,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HistoryHeader(
                  compact: isCompact,
                  onRecordReceived: supportsManualReceivedPaymentEntry
                      ? () {
                          unawaited(_recordReceivedMoney());
                        }
                      : null,
                  onRefresh: () {
                    unawaited(_loadTransactions(reset: true));
                  },
                ),
                if (_smsReconciliationService.isSupported) ...[
                  SizedBox(height: isCompact ? 16 : 18),
                  HistorySmsReconciliationCard(
                    smsReconciliationService: _smsReconciliationService,
                    receivedSmsReconciliationService:
                        _receivedSmsReconciliationService,
                    onHistoryChanged: () {
                      return _loadTransactions(reset: true);
                    },
                  ),
                ],
                SizedBox(height: isCompact ? 22 : 28),
                HistoryFilterControls(
                  searchController: _searchController,
                  direction: _directionFilter,
                  status: _statusFilter,
                  method: _methodFilter,
                  onSearchChanged: _onSearchChanged,
                  onSearchSubmitted: _onSearchSubmitted,
                  onDirectionSelected: _selectDirection,
                  onStatusSelected: _selectStatus,
                  onMethodSelected: _selectMethod,
                ),
                SizedBox(height: isCompact ? 22 : 28),
                HistoryContent(
                  transactions: _transactions,
                  direction: _directionFilter.direction,
                  total: _pagination?.total ?? _transactions.length,
                  compact: isCompact,
                  errorMessage: _errorMessage,
                  loadMoreError: _loadMoreError,
                  hasNextPage: _pagination?.hasNextPage ?? false,
                  isLoadingMore: _isLoadingMore,
                  onRetry: () {
                    unawaited(_loadTransactions(reset: true));
                  },
                  onLoadMore: () {
                    unawaited(_loadTransactions(reset: false));
                  },
                  onTransactionTap: (transaction) {
                    unawaited(_openTransaction(transaction));
                  },
                ),
              ],
            ),
    );
  }
}
