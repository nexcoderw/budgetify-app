import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../home/presentation/widgets/record_received_money/received_date_sheet.dart';
import '../../application/income_service.dart';
import '../../data/models/income.dart';

class IncomePaymentSheet extends StatefulWidget {
  const IncomePaymentSheet({
    super.key,
    required this.service,
    required this.income,
  });
  final IncomeService service;
  final IncomeRecord income;
  @override
  State<IncomePaymentSheet> createState() => _IncomePaymentSheetState();
}

class _IncomePaymentSheetState extends State<IncomePaymentSheet> {
  final List<Map<String, dynamic>> _items = [];
  int _page = 0;
  bool _loading = false;
  bool _saving = false;
  bool _hasMore = true;
  String? _selected;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.service.payments(widget.income.id, _page + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(
          (result['items'] as List).map(
            (item) => Map<String, dynamic>.from(item as Map),
          ),
        );
        _hasMore = result['hasNextPage'] as bool;
        _page++;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Could not load received payments.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _link() async {
    if (_selected == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.link(widget.income.id, _selected!);
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error is ApiException
              ? error.message
              : 'Could not link this payment.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: FractionallySizedBox(
      heightFactor: 0.8,
      child: Material(
        color: AppColors.backgroundSecondary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Link received payment',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close payment selection',
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Unlinked payments matching ${formatIncomeAmount(widget.income.amount)} RWF. Linking updates this income, without adding another payment.',
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    if (!_loading && _items.isEmpty && _error == null)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No matching payments yet. Sync received payments in History, then try again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    for (final item in _items)
                      ListTile(
                        onTap: _saving
                            ? null
                            : () => setState(
                                () => _selected = item['id'] as String,
                              ),
                        selected: _selected == item['id'],
                        selectedTileColor: AppColors.surfaceElevated,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: Text(
                          (item['senderName'] ??
                                  item['senderIdentifier'] ??
                                  'Received payment')
                              as String,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '${formatReceivedDate(DateTime.parse(item['occurredAt'] as String).toLocal())}\n${item['reference']}',
                          style: const TextStyle(
                            fontSize: 10,
                            height: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        trailing: Icon(
                          _selected == item['id']
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    if (_hasMore && !_loading)
                      TextButton(
                        onPressed: _saving ? null : _load,
                        child: Text(
                          _error == null ? 'Load more payments' : 'Try again',
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: SizedBox(
                    width: 220,
                    child: AppButton(
                      label: 'Link payment',
                      iconWidget: const Icon(Icons.link_rounded),
                      size: AppButtonSize.sm,
                      isLoading: _saving,
                      onPressed: _selected == null || _saving ? null : _link,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
