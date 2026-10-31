import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/app_dropdown.dart';
import '../../application/financial_message_import_service.dart';
import '../../data/models/financial_message_import.dart';
import '../../data/models/financial_message_pilot_summary.dart';
import '../widgets/financial_message_pilot_card.dart';
import '../widgets/financial_message_review_sheet.dart';
import 'iphone_shortcut_setup_page.dart';

class FinancialMessageImportsPage extends StatefulWidget {
  const FinancialMessageImportsPage({super.key, this.service});

  final FinancialMessageImportService? service;

  @override
  State<FinancialMessageImportsPage> createState() =>
      _FinancialMessageImportsPageState();
}

class _FinancialMessageImportsPageState
    extends State<FinancialMessageImportsPage> {
  late final FinancialMessageImportService _service;
  FinancialMessageImportStatus _status = FinancialMessageImportStatus.pending;
  List<FinancialMessageImport> _items = const [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _changed = false;
  String? _error;
  FinancialMessagePilotSummary? _pilotSummary;
  bool _loadingPilot = true;
  bool _pilotError = false;
  int _page = 1;
  int _total = 0;
  bool _hasNextPage = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? FinancialMessageImportService.createDefault();
    unawaited(_load(reset: true));
    unawaited(_loadPilot());
  }

  Future<void> _loadPilot() async {
    setState(() {
      _loadingPilot = true;
      _pilotError = false;
    });
    try {
      final summary = await _service.pilotSummary();
      if (!mounted) {
        return;
      }
      setState(() => _pilotSummary = summary);
    } catch (_) {
      if (mounted) {
        setState(() => _pilotError = true);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingPilot = false);
      }
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_load(reset: true), _loadPilot()]);
  }

  Future<void> _load({required bool reset}) async {
    if (!reset && (_loadingMore || !_hasNextPage)) {
      return;
    }
    final generation = reset ? ++_generation : _generation;
    final page = reset ? 1 : _page + 1;
    setState(() {
      if (reset) {
        _loading = true;
        _error = null;
        _total = 0;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final result = await _service.list(status: _status, page: page);
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _items = reset ? result.items : [..._items, ...result.items];
        _page = result.page;
        _total = result.total;
        _hasNextPage = result.hasNextPage;
      });
    } catch (error) {
      if (!mounted || generation != _generation) {
        return;
      }
      setState(
        () => _error = error is ApiException
            ? error.message
            : 'Could not load imported messages.',
      );
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _selectStatus(FinancialMessageImportStatus status) {
    if (status == _status) {
      return;
    }
    setState(() => _status = status);
    unawaited(_load(reset: true));
  }

  Future<void> _open(FinancialMessageImport item) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          FinancialMessageReviewSheet(importId: item.id, service: _service),
    );
    if (!mounted || changed != true) {
      return;
    }
    _changed = true;
    await _refresh();
  }

  void _close() => Navigator.of(context).pop(_changed);

  Future<void> _openSetup() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => IphoneShortcutSetupPage(
          currentShortcutVersion: _pilotSummary?.currentShortcutVersion ?? 1,
          shortcutInstallUrl: _pilotSummary?.shortcutInstallUrl,
        ),
      ),
    );
    if (mounted) {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _close();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(
                onBack: _close,
                onRefresh: () => unawaited(_refresh()),
                onSetup: () => unawaited(_openSetup()),
              ),
              _ImportsHeader(
                selected: _status,
                total: _total,
                loading: _loading,
                onSelected: _selectStatus,
              ),
              if (_status == FinancialMessageImportStatus.pending)
                FinancialMessagePilotCard(
                  summary: _pilotSummary,
                  loading: _loadingPilot,
                  hasError: _pilotError,
                  onRetry: () => unawaited(_loadPilot()),
                  onUpdateShortcut: () => unawaited(_openSetup()),
                ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const _LoadingList();
    }
    if (_error != null) {
      return _PageState(
        icon: Icons.cloud_off_rounded,
        title: 'Imports unavailable',
        detail: _error!,
        actionLabel: 'Try again',
        onAction: () => unawaited(_load(reset: true)),
      );
    }
    if (_items.isEmpty) {
      return _PageState(
        icon: Icons.mark_email_read_outlined,
        title: _status == FinancialMessageImportStatus.pending
            ? 'Nothing waiting for review'
            : 'No ${_status.label.toLowerCase()} imports',
        detail: _status == FinancialMessageImportStatus.pending
            ? 'New iPhone Shortcut imports will appear here before they affect your records.'
            : 'Imported messages with this status will appear here.',
        actionLabel: _status == FinancialMessageImportStatus.pending
            ? 'Set up iPhone import'
            : null,
        onAction: _status == FinancialMessageImportStatus.pending
            ? () => unawaited(_openSetup())
            : null,
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        itemCount: _items.length + (_hasNextPage ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return Center(
              child: TextButton(
                onPressed: _loadingMore
                    ? null
                    : () => unawaited(_load(reset: false)),
                child: Text(_loadingMore ? 'Loading…' : 'Load more'),
              ),
            );
          }
          return _ImportRow(item: _items[index], onTap: _open);
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onBack,
    required this.onRefresh,
    required this.onSetup,
  });
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
    child: Row(
      children: [
        AppBackButton(onBack: onBack),
        const Spacer(),
        AppDropdown<String>(
          tooltip: 'Import actions',
          icon: Icons.more_horiz_rounded,
          onSelected: (action) {
            if (action == 'refresh') {
              onRefresh();
            } else {
              onSetup();
            }
          },
          items: const [
            AppDropdownItem(
              value: 'refresh',
              label: 'Refresh imports',
              icon: Icons.refresh_rounded,
            ),
            AppDropdownItem(
              value: 'setup',
              label: 'iPhone Shortcut setup',
              icon: Icons.tune_rounded,
            ),
          ],
        ),
      ],
    ),
  );
}

class _ImportsHeader extends StatelessWidget {
  const _ImportsHeader({
    required this.selected,
    required this.total,
    required this.loading,
    required this.onSelected,
  });

  final FinancialMessageImportStatus selected;
  final int total;
  final bool loading;
  final ValueChanged<FinancialMessageImportStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    const options = [
      FinancialMessageImportStatus.pending,
      FinancialMessageImportStatus.confirmed,
      FinancialMessageImportStatus.dismissed,
    ];
    final description = switch (selected) {
      FinancialMessageImportStatus.pending =>
        'Check each message before it changes your records.',
      FinancialMessageImportStatus.confirmed =>
        'Messages already added to your financial records.',
      FinancialMessageImportStatus.dismissed =>
        'Messages you chose not to add to your records.',
      FinancialMessageImportStatus.expired =>
        'Messages that expired before they were reviewed.',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
      child: Column(
        children: [
          const Text(
            'Payment message inbox',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              height: 1.25,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final status in options)
                ChoiceChip(
                  label: Text(status.label),
                  selected: selected == status,
                  onSelected: (_) => onSelected(status),
                  showCheckmark: false,
                  backgroundColor: AppColors.surface,
                  selectedColor: AppColors.primary,
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected == status
                        ? AppColors.background
                        : AppColors.textSecondary,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(
              loading
                  ? 'Loading imports…'
                  : '$total ${total == 1 ? 'message' : 'messages'}',
              key: ValueKey((loading, selected, total)),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportRow extends StatelessWidget {
  const _ImportRow({required this.item, required this.onTap});
  final FinancialMessageImport item;
  final ValueChanged<FinancialMessageImport> onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Review ${item.sourceLabel} message from ${item.senderLabel}',
    child: Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onTap(item),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 14, 13, 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _sourceIcon(item),
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.senderLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.sourceLabel} · ${_shortDate(item.messageReceivedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                    if (item.needsAttention) ...[
                      const SizedBox(height: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryMuted.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Review details',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 118),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      item.amount == null
                          ? 'Amount pending'
                          : '${_formatAmount(item.amount!)} RWF',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: item.amount == null ? 10 : 13,
                        fontWeight: FontWeight.w800,
                        color: item.amount == null
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();
  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
    itemCount: 6,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (_, index) => Container(
      height: index.isEven ? 82 : 76,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 118,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 86,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 68,
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PageState extends StatelessWidget {
  const _PageState({
    required this.icon,
    required this.title,
    required this.detail,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 34, color: AppColors.textSecondary),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          if (onAction != null) ...[
            const SizedBox(height: 10),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}

String _shortDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _formatAmount(String value) {
  final whole = value.split('.').first;
  return whole.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
}

IconData _sourceIcon(FinancialMessageImport item) {
  final source = item.providerCode ?? item.sourceHint;
  if (source.contains('BANK')) {
    return Icons.account_balance_rounded;
  }
  if (source.contains('MOMO') || source.contains('MONEY')) {
    return Icons.account_balance_wallet_rounded;
  }
  return Icons.mark_email_unread_outlined;
}
