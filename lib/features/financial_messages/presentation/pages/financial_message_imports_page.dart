import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
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
      MaterialPageRoute<void>(builder: (_) => const IphoneShortcutSetupPage()),
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
              _StatusFilters(selected: _status, onSelected: _selectStatus),
              if (_status == FinancialMessageImportStatus.pending)
                FinancialMessagePilotCard(
                  summary: _pilotSummary,
                  loading: _loadingPilot,
                  hasError: _pilotError,
                  onRetry: () => unawaited(_loadPilot()),
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
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
    child: Row(
      children: [
        IconButton.filledTonal(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Message review',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              Text(
                'Verify iPhone imports before recording',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          tooltip: 'Set up iPhone import',
          onPressed: onSetup,
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    ),
  );
}

class _StatusFilters extends StatelessWidget {
  const _StatusFilters({required this.selected, required this.onSelected});
  final FinancialMessageImportStatus selected;
  final ValueChanged<FinancialMessageImportStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    const options = [
      FinancialMessageImportStatus.pending,
      FinancialMessageImportStatus.confirmed,
      FinancialMessageImportStatus.dismissed,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          for (final status in options) ...[
            ChoiceChip(
              label: Text(status.label),
              selected: selected == status,
              onSelected: (_) => onSelected(status),
              showCheckmark: false,
              side: BorderSide.none,
              labelStyle: const TextStyle(fontSize: 12),
            ),
            const SizedBox(width: 8),
          ],
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
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      onTap: () => onTap(item),
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.south_west_rounded,
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
                      fontSize: 14,
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
                      fontSize: 11,
                    ),
                  ),
                  if (item.needsAttention) ...[
                    const SizedBox(height: 5),
                    const Text(
                      'Details need review',
                      style: TextStyle(
                        color: AppColors.primaryMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              item.amount == null ? '—' : '${_formatAmount(item.amount!)} RWF',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    ),
  );
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();
  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.all(18),
    itemCount: 6,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (_, _) => Container(
      height: 76,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
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
