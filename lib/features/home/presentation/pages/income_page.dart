import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../../../core/network/paginated_response.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_modal_dialog.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../income/application/income_service.dart';
import '../../../income/data/models/income_entry.dart';
import '../../../income/data/models/income_list_query.dart';
import '../../../savings/application/saving_service.dart';

enum _IncomeReceivedFilter { all, received, pending }

extension _IncomeReceivedFilterX on _IncomeReceivedFilter {
  String get label => switch (this) {
    _IncomeReceivedFilter.all => 'All',
    _IncomeReceivedFilter.received => 'Received',
    _IncomeReceivedFilter.pending => 'Pending',
  };
}

extension _IncomeCategoryPresentation on IncomeCategory {
  dynamic get icon => switch (this) {
    IncomeCategory.salary => HugeIcons.strokeRoundedBuilding03,
    IncomeCategory.freelance => HugeIcons.strokeRoundedLaptop,
    IncomeCategory.dividends => HugeIcons.strokeRoundedChartUp,
    IncomeCategory.rental => HugeIcons.strokeRoundedHome01,
    IncomeCategory.sideHustle => HugeIcons.strokeRoundedStars,
    IncomeCategory.other => HugeIcons.strokeRoundedMoney01,
  };

  Color get color => switch (this) {
    IncomeCategory.salary => AppColors.success,
    IncomeCategory.freelance => const Color(0xFF7EB8FF),
    IncomeCategory.dividends => AppColors.primary,
    IncomeCategory.rental => const Color(0xFFC97BFF),
    IncomeCategory.sideHustle => const Color(0xFFFFB86C),
    IncomeCategory.other => const Color(0xFFFF9F9F),
  };
}

// ── RWF formatter ─────────────────────────────────────────────────────────────

String _rwf(double amount) {
  final formatted = amount
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  return 'RWF $formatted';
}

String _rwfCompact(double amount) {
  if (amount >= 1000000) {
    return 'RWF ${(amount / 1000000).toStringAsFixed(1)}M';
  }
  if (amount >= 1000) {
    return 'RWF ${(amount / 1000).toStringAsFixed(0)}k';
  }
  return _rwf(amount);
}

// ── Page ──────────────────────────────────────────────────────────────────────

class IncomePage extends StatefulWidget {
  const IncomePage({super.key, required this.incomeService});

  final IncomeService incomeService;

  @override
  State<IncomePage> createState() => _IncomePageState();
}

class _IncomePageState extends State<IncomePage>
    with SingleTickerProviderStateMixin {
  static const int _pageSize = 12;
  final SavingService _savingService = SavingService.createDefault();

  late final AnimationController _entranceCtrl;
  late final TextEditingController _searchCtrl;
  List<IncomeEntry> _entries = const [];
  List<IncomeEntry> _pageEntries = const [];
  IncomeSummary? _summary;
  bool _isLoading = true;
  String? _loadError;
  IncomeEntry? _detailsEntry;
  IncomeDetail? _detailEntry;
  bool _isLoadingDetail = false;
  bool _isReversingAllocation = false;
  String? _highlightAllocationId;
  Timer? _searchDebounce;
  String? _busyReceivedId;
  int _currentPage = 1;
  int _totalItems = 0;
  int _totalPages = 1;
  late int _selectedMonth;
  late int _selectedYear;
  IncomeCategory? _selectedCategory;
  _IncomeReceivedFilter _selectedReceived = _IncomeReceivedFilter.all;
  DateTime? _selectedDateFrom;
  DateTime? _selectedDateTo;
  String _searchInput = '';
  String? _appliedSearch;
  int _loadSequence = 0;
  _BlockedIncomeActionState? _blockedAction;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..forward();
    _searchCtrl = TextEditingController();
    _loadIncome();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  // ── Computed ─────────────────────────────────────────────────────────────────

  double get _total => _summary?.totalIncomeRwf ?? 0;

  double get _receivedTotal => _summary?.receivedIncomeRwf ?? 0;

  double get _availableMoneyNow => _summary?.availableMoneyNowRwf ?? 0;

  bool get _hasExplicitDateFilter =>
      _selectedDateFrom != null || _selectedDateTo != null;

  bool get _hasActiveFilters {
    final now = DateTime.now();

    return _selectedMonth != now.month ||
        _selectedYear != now.year ||
        _selectedCategory != null ||
        _selectedReceived != _IncomeReceivedFilter.all ||
        _appliedSearch != null ||
        _hasExplicitDateFilter;
  }

  bool get _canGoToNextMonth {
    final now = DateTime.now();
    return _selectedYear < now.year ||
        (_selectedYear == now.year && _selectedMonth < now.month);
  }

  String get _periodLabel {
    if (_hasExplicitDateFilter) {
      return 'Custom range';
    }

    return '${_monthLabel(_selectedMonth)} $_selectedYear';
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────────

  Future<void> _openAddDialog() async {
    final entry = await showDialog<IncomeEntry>(
      context: context,
      builder: (_) => _IncomeFormDialog(
        initialCategory: _selectedCategory ?? IncomeCategory.salary,
        initialDate: _defaultCreateDate(),
        initialReceived: false,
        onSubmit:
            ({
              required String label,
              required double amount,
              required IncomeCategory category,
              required DateTime date,
              required bool received,
            }) {
              return widget.incomeService.createIncome(
                label: label,
                amount: amount,
                category: category,
                date: date,
                received: received,
              );
            },
      ),
    );

    if (entry == null || !mounted) {
      return;
    }

    setState(() {
      _currentPage = 1;
      _loadError = null;
    });
    await _loadIncome();
    if (!mounted) {
      return;
    }

    AppToast.success(
      context,
      title: 'Income added',
      description: '${entry.label} was saved to your income records.',
    );
  }

  Future<void> _openEditDialog(IncomeEntry entry) async {
    if (entry.allocatedToSavingsRwf > 0) {
      setState(() {
        _blockedAction = _BlockedIncomeActionState(
          entry: entry,
          action: _BlockedIncomeAction.edit,
        );
      });
      return;
    }

    final updated = await showDialog<IncomeEntry>(
      context: context,
      builder: (_) => _IncomeFormDialog(
        entry: entry,
        initialReceived: entry.received,
        onOpenRecovery: () => _openDetailsDialog(entry, highlightFirstActive: true),
        onSubmit:
            ({
              required String label,
              required double amount,
              required IncomeCategory category,
              required DateTime date,
              required bool received,
            }) {
              return widget.incomeService.updateIncome(
                incomeId: entry.id,
                label: label,
                amount: amount,
                category: category,
                date: date,
                received: received,
              );
            },
      ),
    );

    if (updated == null || !mounted) {
      return;
    }

    setState(() => _loadError = null);
    await _loadIncome();
    if (!mounted) {
      return;
    }

    AppToast.success(
      context,
      title: 'Income updated',
      description: '${updated.label} was updated successfully.',
    );
  }

  Future<void> _openRecordNextMonthDialog(IncomeEntry entry) async {
    final nextMonthDate = _shiftToNextMonth(entry.date);
    final created = await showDialog<IncomeEntry>(
      context: context,
      builder: (_) => _IncomeFormDialog(
        title: 'Record for next month',
        subtitle: 'Start from the current entry and adjust anything you need.',
        submitLabel: 'Add income',
        initialLabel: entry.label,
        initialAmount: entry.amount,
        initialCategory: entry.category,
        initialDate: nextMonthDate,
        initialReceived: false,
        onSubmit:
            ({
              required String label,
              required double amount,
              required IncomeCategory category,
              required DateTime date,
              required bool received,
            }) {
              return widget.incomeService.createIncome(
                label: label,
                amount: amount,
                category: category,
                date: date,
                received: received,
              );
            },
      ),
    );

    if (created == null || !mounted) {
      return;
    }

    setState(() {
      _currentPage = 1;
      _loadError = null;
    });
    await _loadIncome();
    if (!mounted) {
      return;
    }

    AppToast.success(
      context,
      title: 'Next month income prepared',
      description: '${created.label} was recorded for the next month.',
    );
  }

  Future<void> _confirmDelete(IncomeEntry entry) async {
    if (entry.allocatedToSavingsRwf > 0) {
      setState(() {
        _blockedAction = _BlockedIncomeActionState(
          entry: entry,
          action: _BlockedIncomeAction.delete,
        );
      });
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteConfirmDialog(label: entry.label),
    );
    if (confirmed == true) {
      try {
        await widget.incomeService.deleteIncome(entry.id);

        if (!mounted) {
          return;
        }

        setState(() {
          if (_pageEntries.length == 1 && _currentPage > 1) {
            _currentPage -= 1;
          }
        });
        await _loadIncome();
        if (!mounted) {
          return;
        }

        AppToast.success(
          context,
          title: 'Income removed',
          description: '${entry.label} was removed from your records.',
        );
      } catch (error) {
        if (!mounted) {
          return;
        }

        AppToast.error(
          context,
          title: 'Unable to delete income',
          description: _readableError(error),
        );
      }
    }
  }

  Future<void> _loadIncome() async {
    final loadId = ++_loadSequence;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final summaryQuery = _buildIncomeQuery();
      final pageQuery = _buildIncomeQuery(page: _currentPage, limit: _pageSize);
      final results = await Future.wait([
        widget.incomeService.listIncome(query: summaryQuery),
        widget.incomeService.listIncomePage(query: pageQuery),
        widget.incomeService.getIncomeSummary(query: summaryQuery),
      ]);
      final entries = results[0] as List<IncomeEntry>;
      final pageResponse = results[1] as PaginatedResponse<IncomeEntry>;
      final summary = results[2] as IncomeSummary;

      if (!mounted || loadId != _loadSequence) {
        return;
      }

      setState(() {
        _entries = _sortedEntries(entries);
        _pageEntries = _sortedEntries(pageResponse.items);
        _summary = summary;
        _totalItems = pageResponse.meta.totalItems;
        _totalPages = pageResponse.meta.totalPages;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || loadId != _loadSequence) {
        return;
      }

      final message = _readableError(error);
      setState(() {
        _entries = const [];
        _pageEntries = const [];
        _summary = null;
        _isLoading = false;
        _loadError = message;
        _totalItems = 0;
        _totalPages = 1;
      });

      AppToast.error(
        context,
        title: 'Unable to load income',
        description: message,
      );
    }
  }

  Future<void> _toggleReceived(IncomeEntry entry) async {
    if (entry.received && entry.allocatedToSavingsRwf > 0) {
      setState(() {
        _blockedAction = _BlockedIncomeActionState(
          entry: entry,
          action: _BlockedIncomeAction.edit,
        );
      });
      return;
    }

    setState(() => _busyReceivedId = entry.id);

    try {
      await widget.incomeService.updateIncome(
        incomeId: entry.id,
        label: entry.label,
        amount: entry.amount,
        category: entry.category,
        date: entry.date,
        received: !entry.received,
      );

      if (!mounted) {
        return;
      }

      await _loadIncome();
      if (!mounted) {
        return;
      }

      AppToast.success(
        context,
        title: !entry.received
            ? 'Income marked received'
            : 'Income marked pending',
        description: '${entry.label} was updated successfully.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Unable to update received state',
        description: _readableError(error),
      );
    } finally {
      if (mounted) {
        setState(() => _busyReceivedId = null);
      }
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    setState(() => _searchInput = value);

    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }

      final trimmed = value.trim();
      setState(() {
        _appliedSearch = trimmed.length >= 3 ? trimmed : null;
        _currentPage = 1;
      });
      _loadIncome();
    });
  }

  Future<void> _pickFilterDate({required bool isFrom}) async {
    final initialDate = isFrom
        ? (_selectedDateFrom ?? DateTime.now())
        : (_selectedDateTo ?? _selectedDateFrom ?? DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.success,
            onPrimary: AppColors.background,
            surface: AppColors.surfaceElevated,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      if (isFrom) {
        _selectedDateFrom = picked;
        if (_selectedDateTo != null && _selectedDateTo!.isBefore(picked)) {
          _selectedDateTo = picked;
        }
      } else {
        _selectedDateTo = picked;
        if (_selectedDateFrom != null && _selectedDateFrom!.isAfter(picked)) {
          _selectedDateFrom = picked;
        }
      }
      _currentPage = 1;
    });
    await _loadIncome();
  }

  Future<void> _clearDateFilter({required bool isFrom}) async {
    setState(() {
      if (isFrom) {
        _selectedDateFrom = null;
      } else {
        _selectedDateTo = null;
      }
      _currentPage = 1;
    });
    await _loadIncome();
  }

  Future<void> _clearAllFilters() async {
    final now = DateTime.now();
    _searchDebounce?.cancel();
    _searchCtrl.clear();

    setState(() {
      _selectedMonth = now.month;
      _selectedYear = now.year;
      _selectedCategory = null;
      _selectedReceived = _IncomeReceivedFilter.all;
      _selectedDateFrom = null;
      _selectedDateTo = null;
      _searchInput = '';
      _appliedSearch = null;
      _currentPage = 1;
    });
    await _loadIncome();
  }

  Future<void> _goToPreviousMonth() async {
    setState(() {
      if (_selectedMonth == 1) {
        _selectedMonth = 12;
        _selectedYear -= 1;
      } else {
        _selectedMonth -= 1;
      }
      _currentPage = 1;
    });
    await _loadIncome();
  }

  Future<void> _goToNextMonth() async {
    if (!_canGoToNextMonth) {
      return;
    }

    setState(() {
      if (_selectedMonth == 12) {
        _selectedMonth = 1;
        _selectedYear += 1;
      } else {
        _selectedMonth += 1;
      }
      _currentPage = 1;
    });
    await _loadIncome();
  }

  Future<void> _goToPage(int page) async {
    if (page < 1 || page > _totalPages || page == _currentPage) {
      return;
    }

    setState(() => _currentPage = page);
    await _loadIncome();
  }

  List<IncomeEntry> _sortedEntries(List<IncomeEntry> entries) {
    final sorted = entries.toList(growable: false);
    sorted.sort((left, right) {
      final byDate = right.date.compareTo(left.date);
      if (byDate != 0) {
        return byDate;
      }

      return right.createdAt.compareTo(left.createdAt);
    });

    return sorted;
  }

  Future<void> _openDetailsDialog(
    IncomeEntry entry, {
    bool highlightFirstActive = false,
  }) async {
    setState(() {
      _detailsEntry = entry;
      _detailEntry = null;
      _isLoadingDetail = true;
      _highlightAllocationId = null;
    });

    try {
      final detail = await widget.incomeService.getIncomeById(entry.id);
      if (!mounted) {
        return;
      }

      setState(() {
        _detailsEntry = detail;
        _detailEntry = detail;
        _isLoadingDetail = false;
        _highlightAllocationId = highlightFirstActive
            ? _firstActiveAllocationId(detail)
            : null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingDetail = false;
      });

      AppToast.error(
        context,
        title: 'Unable to load income details',
        description: _readableError(error),
      );
    }
  }

  String? _firstActiveAllocationId(IncomeDetail detail) {
    for (final allocation in detail.savingAllocations) {
      if (!allocation.isReversed) {
        return allocation.id;
      }
    }

    return null;
  }

  void _closeDetailsDialog() {
    setState(() {
      _detailsEntry = null;
      _detailEntry = null;
      _isLoadingDetail = false;
      _isReversingAllocation = false;
      _highlightAllocationId = null;
    });
  }

  Future<void> _reverseAllocation(
    IncomeEntry entry,
    IncomeSavingAllocation allocation,
  ) async {
    setState(() => _isReversingAllocation = true);

    try {
      await _savingService.reverseSavingDeposit(
        savingId: allocation.savingId,
        transactionId: allocation.transactionId,
      );

      if (!mounted) {
        return;
      }

      await _openDetailsDialog(entry);
      await _loadIncome();
      if (!mounted) {
        return;
      }

      AppToast.success(
        context,
        title: 'Allocation reversed',
        description:
            '${allocation.savingLabel} no longer uses money from ${entry.label}.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Unable to reverse allocation',
        description: _readableError(error),
      );
    } finally {
      if (mounted) {
        setState(() => _isReversingAllocation = false);
      }
    }
  }

  IncomeListQuery _buildIncomeQuery({int? page, int? limit}) {
    return IncomeListQuery(
      month: _hasExplicitDateFilter ? null : _selectedMonth,
      year: _hasExplicitDateFilter ? null : _selectedYear,
      category: _selectedCategory,
      received: switch (_selectedReceived) {
        _IncomeReceivedFilter.all => null,
        _IncomeReceivedFilter.received => true,
        _IncomeReceivedFilter.pending => false,
      },
      search: _appliedSearch,
      dateFrom: _selectedDateFrom == null
          ? null
          : _formatDateOnly(_selectedDateFrom!),
      dateTo: _selectedDateTo == null
          ? null
          : _formatDateOnly(_selectedDateTo!),
      page: page,
      limit: limit,
    );
  }

  String _formatDateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String _monthLabel(int month) {
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

    return months[month - 1];
  }

  DateTime _defaultCreateDate() {
    if (_hasExplicitDateFilter) {
      return _selectedDateFrom ?? DateTime.now();
    }

    final now = DateTime.now();
    if (_selectedMonth == now.month && _selectedYear == now.year) {
      return now;
    }

    return DateTime(_selectedYear, _selectedMonth, 1);
  }

  DateTime _shiftToNextMonth(DateTime source) {
    final targetMonth = source.month == 12 ? 1 : source.month + 1;
    final targetYear = source.month == 12 ? source.year + 1 : source.year;
    final lastDayOfTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;
    final targetDay = source.day > lastDayOfTargetMonth
        ? lastDayOfTargetMonth
        : source.day;

    return DateTime(targetYear, targetMonth, targetDay);
  }

  String _readableError(Object error) {
    final message = error.toString().trim();

    if (message.startsWith('Exception: ')) {
      return message.replaceFirst('Exception: ', '');
    }

    if (message.startsWith('StateError: ')) {
      return message.replaceFirst('StateError: ', '');
    }

    return message;
  }

  // ── Animation helpers ─────────────────────────────────────────────────────────

  Animation<double> _fade(double start, double end) => CurvedAnimation(
    parent: _entranceCtrl,
    curve: Interval(start, end, curve: Curves.easeOut),
  );

  Animation<Offset> _slide(double start, double end) =>
      Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _entranceCtrl,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _IncomePageLoading(fade: _fade, slide: _slide);
    }

    final total = _total;
    final receivedTotal = _receivedTotal;
    final availableMoneyNow = _availableMoneyNow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Staggered(
          fade: _fade(0.0, 0.45),
          slide: _slide(0.0, 0.45),
          child: _IncomeHeader(
            total: total,
            entryCount: _entries.length,
            periodLabel: _periodLabel,
            canGoNextMonth: _canGoToNextMonth,
            onAdd: _openAddDialog,
            onNextMonth: _goToNextMonth,
            onPreviousMonth: _goToPreviousMonth,
          ),
        ),
        const SizedBox(height: 14),

        _Staggered(
          fade: _fade(0.12, 0.55),
          slide: _slide(0.12, 0.55),
          child: _IncomeFiltersPanel(
            category: _selectedCategory,
            dateFrom: _selectedDateFrom,
            dateTo: _selectedDateTo,
            hasActiveFilters: _hasActiveFilters,
            received: _selectedReceived,
            searchController: _searchCtrl,
            searchInput: _searchInput,
            onCategoryChanged: (value) async {
              setState(() {
                _selectedCategory = value;
                _currentPage = 1;
              });
              await _loadIncome();
            },
            onClearAll: _clearAllFilters,
            onClearDate: _clearDateFilter,
            onDatePicked: _pickFilterDate,
            onReceivedChanged: (value) async {
              setState(() {
                _selectedReceived = value;
                _currentPage = 1;
              });
              await _loadIncome();
            },
            onSearchChanged: _onSearchChanged,
          ),
        ),
        const SizedBox(height: 14),

        _Staggered(
          fade: _fade(0.20, 0.62),
          slide: _slide(0.20, 0.62),
          child: _BreakdownRow(
            activeTotal: receivedTotal,
            passiveTotal: availableMoneyNow,
            total: receivedTotal > 0 ? receivedTotal : total,
            leftLabel: 'Received cash',
            leftSublabel: 'Money already collected',
            rightLabel: 'Available now',
            rightSublabel: 'Received minus expenses and savings',
          ),
        ),
        const SizedBox(height: 14),

        _Staggered(
          fade: _fade(0.34, 0.72),
          slide: _slide(0.34, 0.72),
          child: _CategoryBars(entries: _entries, total: total),
        ),
        const SizedBox(height: 14),

        _Staggered(
          fade: _fade(0.48, 0.88),
          slide: _slide(0.48, 0.88),
          child: _EntryList(
            busyReceivedId: _busyReceivedId,
            currentPage: _currentPage,
            entries: _pageEntries,
            total: total,
            totalItems: _totalItems,
            totalPages: _totalPages,
            loadError: _loadError,
            onDetails: _openDetailsDialog,
            onNextPage: () => _goToPage(_currentPage + 1),
            onPreviousPage: () => _goToPage(_currentPage - 1),
            onRecordNextMonth: _openRecordNextMonthDialog,
            onRetry: _loadIncome,
            onEdit: _openEditDialog,
            onDelete: _confirmDelete,
            onToggleReceived: _toggleReceived,
          ),
        ),
        const SizedBox(height: 8),

        _Staggered(
          fade: _fade(0.70, 1.0),
          slide: _slide(0.70, 1.0),
          child: const _FooterNote(),
        ),
        if (_detailsEntry != null)
          _IncomeDetailsSheet(
            entry: _detailsEntry!,
            detail: _detailEntry,
            highlightAllocationId: _highlightAllocationId,
            isLoading: _isLoadingDetail,
            isReversingAllocation: _isReversingAllocation,
            onClose: _closeDetailsDialog,
            onReverseAllocation: _reverseAllocation,
          ),
        if (_blockedAction != null)
          _BlockedIncomeActionDialog(
            action: _blockedAction!.action,
            entry: _blockedAction!.entry,
            onCancel: () => setState(() => _blockedAction = null),
            onReviewAllocations: () async {
              final entry = _blockedAction!.entry;
              setState(() => _blockedAction = null);
              await _openDetailsDialog(entry, highlightFirstActive: true);
            },
          ),
      ],
    );
  }
}

enum _BlockedIncomeAction { edit, delete }

class _BlockedIncomeActionState {
  const _BlockedIncomeActionState({required this.entry, required this.action});

  final IncomeEntry entry;
  final _BlockedIncomeAction action;
}

class _IncomePageLoading extends StatelessWidget {
  const _IncomePageLoading({required this.fade, required this.slide});

  final Animation<double> Function(double, double) fade;
  final Animation<Offset> Function(double, double) slide;

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Staggered(
            fade: fade(0.0, 0.45),
            slide: slide(0.0, 0.45),
            child: const _LoadingHeroPanel(),
          ),
          const SizedBox(height: 14),
          _Staggered(
            fade: fade(0.12, 0.55),
            slide: slide(0.12, 0.55),
            child: const _LoadingPanel(
              padding: EdgeInsets.all(22),
              child: _LoadingFiltersPanel(),
            ),
          ),
          const SizedBox(height: 14),
          _Staggered(
            fade: fade(0.20, 0.62),
            slide: slide(0.20, 0.62),
            child: Row(
              children: const [
                Expanded(
                  child: _LoadingPanel(
                    padding: EdgeInsets.all(20),
                    child: _LoadingMetricCard(),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _LoadingPanel(
                    padding: EdgeInsets.all(20),
                    child: _LoadingMetricCard(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Staggered(
            fade: fade(0.34, 0.72),
            slide: slide(0.34, 0.72),
            child: const _LoadingPanel(
              padding: EdgeInsets.all(24),
              child: _LoadingCategoryPanel(),
            ),
          ),
          const SizedBox(height: 14),
          _Staggered(
            fade: fade(0.48, 0.88),
            slide: slide(0.48, 0.88),
            child: const _LoadingPanel(
              padding: EdgeInsets.all(24),
              child: _LoadingEntriesPanel(),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel({required this.padding, required this.child});

  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: padding,
      borderRadius: BorderRadius.circular(28),
      blur: 24,
      opacity: 0.12,
      child: child,
    );
  }
}

class _LoadingHeroPanel extends StatelessWidget {
  const _LoadingHeroPanel();

  @override
  Widget build(BuildContext context) {
    return _LoadingPanel(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SkeletonBox(width: 86, height: 30, radius: 999),
                        SizedBox(width: 10),
                        SkeletonBox(width: 124, height: 30, radius: 999),
                      ],
                    ),
                    SizedBox(height: 18),
                    SkeletonBox(width: 170, height: 30, radius: 18),
                    SizedBox(height: 8),
                    SkeletonBox(height: 12, radius: 12),
                    SizedBox(height: 8),
                    SkeletonBox(width: 220, height: 12, radius: 12),
                  ],
                ),
              ),
              SizedBox(width: 16),
              SkeletonBox(width: 46, height: 46, radius: 999),
            ],
          ),
          SizedBox(height: 22),
          SkeletonBox(height: 1, radius: 999),
          SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 128, height: 11, radius: 10),
                    SizedBox(height: 6),
                    SkeletonBox(width: 210, height: 34, radius: 18),
                  ],
                ),
              ),
              SizedBox(width: 12),
              SkeletonBox(width: 96, height: 28, radius: 10),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingFiltersPanel extends StatelessWidget {
  const _LoadingFiltersPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Row(
          children: [
            SkeletonBox(width: 70, height: 14, radius: 12),
            Spacer(),
            SkeletonBox(width: 62, height: 12, radius: 12),
          ],
        ),
        SizedBox(height: 16),
        SkeletonBox(height: 46, radius: 16),
        SizedBox(height: 12),
        SkeletonBox(width: 220, height: 10, radius: 12),
        SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: SkeletonBox(height: 40, radius: 16)),
            SizedBox(width: 10),
            Expanded(child: SkeletonBox(height: 40, radius: 16)),
          ],
        ),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: SkeletonBox(height: 44, radius: 16)),
            SizedBox(width: 10),
            Expanded(child: SkeletonBox(height: 44, radius: 16)),
          ],
        ),
      ],
    );
  }
}

class _LoadingMetricCard extends StatelessWidget {
  const _LoadingMetricCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        SkeletonBox(width: 72, height: 12, radius: 12),
        SizedBox(height: 16),
        SkeletonBox(width: 118, height: 26, radius: 16),
        SizedBox(height: 8),
        SkeletonBox(width: 150, height: 10, radius: 12),
        SizedBox(height: 14),
        SkeletonBox(height: 4, radius: 999),
        SizedBox(height: 10),
        SkeletonBox(width: 96, height: 10, radius: 12),
      ],
    );
  }
}

class _LoadingCategoryPanel extends StatelessWidget {
  const _LoadingCategoryPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        SkeletonBox(width: 120, height: 16, radius: 12),
        SizedBox(height: 24),
        SkeletonBox(height: 16, radius: 14),
        SizedBox(height: 16),
        SkeletonBox(height: 16, radius: 14),
        SizedBox(height: 16),
        SkeletonBox(height: 16, radius: 14),
      ],
    );
  }
}

class _LoadingEntriesPanel extends StatelessWidget {
  const _LoadingEntriesPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        Row(
          children: [
            SkeletonBox(width: 120, height: 16, radius: 12),
            Spacer(),
            SkeletonBox(width: 74, height: 12, radius: 12),
          ],
        ),
        SizedBox(height: 20),
        _LoadingEntryRow(),
        SizedBox(height: 14),
        _LoadingEntryRow(),
        SizedBox(height: 14),
        _LoadingEntryRow(),
      ],
    );
  }
}

class _LoadingEntryRow extends StatelessWidget {
  const _LoadingEntryRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        SkeletonBox(width: 40, height: 40, radius: 999),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 150, height: 14, radius: 12),
              SizedBox(height: 8),
              SkeletonBox(width: 88, height: 11, radius: 12),
            ],
          ),
        ),
        SizedBox(width: 12),
        SkeletonBox(width: 84, height: 14, radius: 12),
      ],
    );
  }
}

// ── Staggered wrapper ─────────────────────────────────────────────────────────

class _Staggered extends StatelessWidget {
  const _Staggered({
    required this.fade,
    required this.slide,
    required this.child,
  });

  final Animation<double> fade;
  final Animation<Offset> slide;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _IncomeHeader extends StatefulWidget {
  const _IncomeHeader({
    required this.total,
    required this.entryCount,
    required this.periodLabel,
    required this.canGoNextMonth,
    required this.onAdd,
    required this.onNextMonth,
    required this.onPreviousMonth,
  });

  final double total;
  final int entryCount;
  final String periodLabel;
  final bool canGoNextMonth;
  final VoidCallback onAdd;
  final Future<void> Function() onNextMonth;
  final Future<void> Function() onPreviousMonth;

  @override
  State<_IncomeHeader> createState() => _IncomeHeaderState();
}

class _IncomeHeaderState extends State<_IncomeHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 760;

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: AnimatedBuilder(
          animation: _shimmer,
          builder: (context, _) => Container(
            padding: EdgeInsets.all(isCompact ? 22 : 28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.success.withValues(alpha: 0.15),
                  Colors.white.withValues(alpha: 0.07),
                  AppColors.success.withValues(alpha: 0.04),
                ],
                stops: [0.0, _shimmer.value, 1.0],
              ),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.30),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.10),
                  blurRadius: 48,
                  offset: const Offset(0, 20),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
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
                          Row(
                            children: [
                              GlassBadge(
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    HugeIcon(
                                      icon: HugeIcons
                                          .strokeRoundedMoneyReceiveCircle,
                                      size: 15,
                                      color: AppColors.success,
                                      strokeWidth: 1.8,
                                    ),
                                    SizedBox(width: 7),
                                    Text(
                                      'Income',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.success,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: _MonthStepperBadge(
                                  label: widget.periodLabel,
                                  canGoNext: widget.canGoNextMonth,
                                  onNext: widget.onNextMonth,
                                  onPrevious: widget.onPreviousMonth,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Income',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontSize: isCompact ? 26 : 30,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Track and manage all your income sources in one place.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.55,
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.85,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    _AddButton(onTap: widget.onAdd),
                  ],
                ),
                const SizedBox(height: 22),
                _GradientDivider(color: AppColors.success),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total in ${widget.periodLabel}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.7,
                              ),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _AnimatedCounter(
                            value: widget.total,
                            style: TextStyle(
                              fontSize: isCompact ? 30 : 36,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: -1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: AppColors.success.withValues(alpha: 0.12),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const HugeIcon(
                            icon: HugeIcons.strokeRoundedArrowUpRight01,
                            size: 12,
                            color: AppColors.success,
                            strokeWidth: 2,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${widget.entryCount} sources',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatefulWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.success.withValues(alpha: 0.18),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.success.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedAdd01,
              size: 20,
              color: AppColors.success,
              strokeWidth: 2,
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthStepperBadge extends StatelessWidget {
  const _MonthStepperBadge({
    required this.label,
    required this.canGoNext,
    required this.onNext,
    required this.onPrevious,
  });

  final String label;
  final bool canGoNext;
  final Future<void> Function() onNext;
  final Future<void> Function() onPrevious;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MonthStepperButton(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            onTap: onPrevious,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          _MonthStepperButton(
            icon: HugeIcons.strokeRoundedArrowRight01,
            isDisabled: !canGoNext,
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

class _MonthStepperButton extends StatelessWidget {
  const _MonthStepperButton({
    required this.icon,
    required this.onTap,
    this.isDisabled = false,
  });

  final dynamic icon;
  final Future<void> Function() onTap;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isDisabled ? null : () => onTap(),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDisabled
              ? Colors.white.withValues(alpha: 0.03)
              : AppColors.success.withValues(alpha: 0.12),
          border: Border.all(
            color: isDisabled
                ? Colors.white.withValues(alpha: 0.06)
                : AppColors.success.withValues(alpha: 0.16),
          ),
        ),
        child: Center(
          child: HugeIcon(
            icon: icon,
            size: 13,
            color: isDisabled
                ? AppColors.textSecondary.withValues(alpha: 0.35)
                : AppColors.success,
            strokeWidth: 1.9,
          ),
        ),
      ),
    );
  }
}

class _IncomeFiltersPanel extends StatelessWidget {
  const _IncomeFiltersPanel({
    required this.category,
    required this.dateFrom,
    required this.dateTo,
    required this.hasActiveFilters,
    required this.received,
    required this.searchController,
    required this.searchInput,
    required this.onCategoryChanged,
    required this.onClearAll,
    required this.onClearDate,
    required this.onDatePicked,
    required this.onReceivedChanged,
    required this.onSearchChanged,
  });

  final IncomeCategory? category;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final bool hasActiveFilters;
  final _IncomeReceivedFilter received;
  final TextEditingController searchController;
  final String searchInput;
  final Future<void> Function(IncomeCategory? value) onCategoryChanged;
  final Future<void> Function() onClearAll;
  final Future<void> Function({required bool isFrom}) onClearDate;
  final Future<void> Function({required bool isFrom}) onDatePicked;
  final Future<void> Function(_IncomeReceivedFilter value) onReceivedChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(28),
      blur: 24,
      opacity: 0.12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Filters',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (hasActiveFilters)
                GestureDetector(
                  onTap: () => onClearAll(),
                  child: Text(
                    'Clear all',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success.withValues(alpha: 0.9),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'Search income label or category',
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedSearch01,
                  size: 16,
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                  strokeWidth: 1.8,
                ),
              ),
              suffixIcon: searchInput.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        searchController.clear();
                        onSearchChanged('');
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedCancel01,
                          size: 16,
                          color: AppColors.textSecondary.withValues(alpha: 0.6),
                          strokeWidth: 1.8,
                        ),
                      ),
                    )
                  : null,
              hintStyle: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary.withValues(alpha: 0.42),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: AppColors.success.withValues(alpha: 0.45),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            searchInput.isNotEmpty && searchInput.trim().length < 3
                ? 'Type at least 3 characters to apply search.'
                : 'Category, received state, and chosen dates use the same API filters as web.',
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: AppColors.textSecondary.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Category',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChoiceChip(
                label: 'All',
                isSelected: category == null,
                onTap: () => onCategoryChanged(null),
              ),
              ...IncomeCategory.values.map(
                (item) => _FilterChoiceChip(
                  label: item.displayName,
                  isSelected: category == item,
                  accent: item.color,
                  onTap: () => onCategoryChanged(item),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Received state',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _IncomeReceivedFilter.values
                .map(
                  (item) => _FilterChoiceChip(
                    label: item.label,
                    isSelected: received == item,
                    accent: item == _IncomeReceivedFilter.pending
                        ? const Color(0xFFFFB86C)
                        : AppColors.success,
                    onTap: () => onReceivedChanged(item),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 16),
          const Text(
            'Chosen dates',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _DateFilterButton(
                  label: 'From',
                  value: dateFrom,
                  onClear: dateFrom == null
                      ? null
                      : () => onClearDate(isFrom: true),
                  onTap: () => onDatePicked(isFrom: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateFilterButton(
                  label: 'To',
                  value: dateTo,
                  onClear: dateTo == null
                      ? null
                      : () => onClearDate(isFrom: false),
                  onTap: () => onDatePicked(isFrom: false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChoiceChip extends StatelessWidget {
  const _FilterChoiceChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.accent = AppColors.success,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: isSelected
              ? accent.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: isSelected
                ? accent.withValues(alpha: 0.34)
                : Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isSelected ? accent : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _DateFilterButton extends StatelessWidget {
  const _DateFilterButton({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final displayValue = value == null
        ? 'Pick date'
        : '${_monthShort(value!.month)} ${value!.day}, ${value!.year}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary.withValues(alpha: 0.58),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayValue,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedCancel01,
                  size: 14,
                  color: AppColors.textSecondary.withValues(alpha: 0.56),
                  strokeWidth: 1.8,
                ),
              )
            else
              HugeIcon(
                icon: HugeIcons.strokeRoundedCalendar03,
                size: 15,
                color: AppColors.textSecondary.withValues(alpha: 0.56),
                strokeWidth: 1.8,
              ),
          ],
        ),
      ),
    );
  }
}

String _monthShort(int month) {
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

  return months[month - 1];
}

// ── Breakdown row (Active / Passive) ──────────────────────────────────────────

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.activeTotal,
    required this.passiveTotal,
    required this.total,
    required this.leftLabel,
    required this.leftSublabel,
    required this.rightLabel,
    required this.rightSublabel,
  });

  final double activeTotal;
  final double passiveTotal;
  final double total;
  final String leftLabel;
  final String leftSublabel;
  final String rightLabel;
  final String rightSublabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TypeCard(
            label: leftLabel,
            sublabel: leftSublabel,
            amount: activeTotal,
            percentage: total > 0 ? activeTotal / total * 100 : 0,
            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
            accentColor: AppColors.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TypeCard(
            label: rightLabel,
            sublabel: rightSublabel,
            amount: passiveTotal,
            percentage: total > 0 ? passiveTotal / total * 100 : 0,
            icon: HugeIcons.strokeRoundedClock01,
            accentColor: const Color(0xFFFFB86C),
          ),
        ),
      ],
    );
  }
}

class _TypeCard extends StatefulWidget {
  const _TypeCard({
    required this.label,
    required this.sublabel,
    required this.amount,
    required this.percentage,
    required this.icon,
    required this.accentColor,
  });

  final String label;
  final String sublabel;
  final double amount;
  final double percentage;
  final dynamic icon;
  final Color accentColor;

  @override
  State<_TypeCard> createState() => _TypeCardState();
}

class _TypeCardState extends State<_TypeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_TypeCard old) {
    super.didUpdateWidget(old);
    if (old.amount != widget.amount) {
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.accentColor.withValues(alpha: 0.11),
                    Colors.white.withValues(alpha: 0.05),
                  ],
                ),
                border: Border.all(
                  color: widget.accentColor.withValues(alpha: 0.24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.accentColor.withValues(alpha: 0.07),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          widget.label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.9,
                            ),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.accentColor.withValues(alpha: 0.15),
                        ),
                        child: Center(
                          child: HugeIcon(
                            icon: widget.icon,
                            size: 14,
                            color: widget.accentColor,
                            strokeWidth: 1.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AnimatedBuilder(
                    animation: _anim,
                    builder: (context, _) {
                      final v = _anim.value * widget.amount;
                      return Text(
                        _rwfCompact(v),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: widget.accentColor,
                          letterSpacing: -0.4,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.sublabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 10),
                  AnimatedBuilder(
                    animation: _anim,
                    builder: (context, _) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: SizedBox(
                          height: 3,
                          child: LinearProgressIndicator(
                            value: (widget.percentage / 100) * _anim.value,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.08,
                            ),
                            valueColor: AlwaysStoppedAnimation(
                              widget.accentColor,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 5),
                  AnimatedBuilder(
                    animation: _anim,
                    builder: (context, _) {
                      final pct = widget.percentage * _anim.value;
                      return Text(
                        '${pct.toStringAsFixed(0)}% of total',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: widget.accentColor.withValues(alpha: 0.7),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Category bars ─────────────────────────────────────────────────────────────

class _CategoryBars extends StatelessWidget {
  const _CategoryBars({required this.entries, required this.total});

  final List<IncomeEntry> entries;
  final double total;

  Map<IncomeCategory, double> get _byCategory {
    final map = <IncomeCategory, double>{};
    for (final e in entries) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return Map.fromEntries(
      map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 760;
    final byCategory = _byCategory;

    return GlassPanel(
      padding: EdgeInsets.all(isCompact ? 20 : 26),
      borderRadius: BorderRadius.circular(28),
      blur: 24,
      opacity: 0.12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.14),
                ),
                child: const Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedBarChart,
                    size: 16,
                    color: AppColors.primary,
                    strokeWidth: 1.8,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'By category',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          if (byCategory.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: _EmptyHint(
                message: 'Add income entries to see category breakdown.',
              ),
            )
          else ...[
            const SizedBox(height: 20),
            for (final entry in byCategory.entries)
              _CategoryBar(
                category: entry.key,
                amount: entry.value,
                total: total,
              ),
          ],
        ],
      ),
    );
  }
}

class _CategoryBar extends StatefulWidget {
  const _CategoryBar({
    required this.category,
    required this.amount,
    required this.total,
  });

  final IncomeCategory category;
  final double amount;
  final double total;

  @override
  State<_CategoryBar> createState() => _CategoryBarState();
}

class _CategoryBarState extends State<_CategoryBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_CategoryBar old) {
    super.didUpdateWidget(old);
    if (old.amount != widget.amount || old.total != widget.total) {
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ratio = widget.total > 0 ? widget.amount / widget.total : 0.0;
    final color = widget.category.color;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.14),
            ),
            child: Center(
              child: HugeIcon(
                icon: widget.category.icon,
                size: 14,
                color: color,
                strokeWidth: 1.8,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.category.displayName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _rwfCompact(widget.amount),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                AnimatedBuilder(
                  animation: _anim,
                  builder: (context, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: SizedBox(
                      height: 4,
                      child: Row(
                        children: [
                          Expanded(
                            flex: (ratio * _anim.value * 1000).round(),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [color, color.withValues(alpha: 0.6)],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: ((1 - ratio * _anim.value) * 1000)
                                .round()
                                .clamp(1, 1000),
                            child: Container(
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Entry list ────────────────────────────────────────────────────────────────

class _EntryList extends StatelessWidget {
  const _EntryList({
    required this.busyReceivedId,
    required this.currentPage,
    required this.entries,
    required this.total,
    required this.totalItems,
    required this.totalPages,
    required this.loadError,
    required this.onDetails,
    required this.onNextPage,
    required this.onPreviousPage,
    required this.onRecordNextMonth,
    required this.onRetry,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleReceived,
  });

  final String? busyReceivedId;
  final int currentPage;
  final List<IncomeEntry> entries;
  final double total;
  final int totalItems;
  final int totalPages;
  final String? loadError;
  final void Function(IncomeEntry) onDetails;
  final Future<void> Function() onNextPage;
  final Future<void> Function() onPreviousPage;
  final void Function(IncomeEntry) onRecordNextMonth;
  final Future<void> Function() onRetry;
  final void Function(IncomeEntry) onEdit;
  final void Function(IncomeEntry) onDelete;
  final Future<void> Function(IncomeEntry) onToggleReceived;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 760;

    return GlassPanel(
      padding: EdgeInsets.all(isCompact ? 20 : 26),
      borderRadius: BorderRadius.circular(28),
      blur: 24,
      opacity: 0.12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success.withValues(alpha: 0.14),
                ),
                child: const Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedListView,
                    size: 16,
                    color: AppColors.success,
                    strokeWidth: 1.8,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Income ledger',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '$totalItems records',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (loadError != null && entries.isEmpty)
            _LoadErrorHint(message: loadError!, onRetry: onRetry)
          else if (entries.isEmpty)
            _EmptyHint(message: 'No income entries yet. Tap + to add one.')
          else
            ...List.generate(entries.length, (i) {
              return _EntryRow(
                entry: entries[i],
                total: total,
                busyReceivedId: busyReceivedId,
                isLast: i == entries.length - 1,
                index: i,
                onDetails: onDetails,
                onEdit: onEdit,
                onDelete: onDelete,
                onRecordNextMonth: onRecordNextMonth,
                onToggleReceived: onToggleReceived,
              );
            }),
          if (entries.isNotEmpty) ...[
            const SizedBox(height: 18),
            _PaginationRow(
              currentPage: currentPage,
              totalItems: totalItems,
              totalPages: totalPages,
              onNextPage: onNextPage,
              onPreviousPage: onPreviousPage,
            ),
          ],
        ],
      ),
    );
  }
}

class _EntryRow extends StatefulWidget {
  const _EntryRow({
    required this.entry,
    required this.total,
    required this.busyReceivedId,
    required this.isLast,
    required this.index,
    required this.onDetails,
    required this.onEdit,
    required this.onDelete,
    required this.onRecordNextMonth,
    required this.onToggleReceived,
  });

  final IncomeEntry entry;
  final double total;
  final String? busyReceivedId;
  final bool isLast;
  final int index;
  final void Function(IncomeEntry) onDetails;
  final void Function(IncomeEntry) onEdit;
  final void Function(IncomeEntry) onDelete;
  final void Function(IncomeEntry) onRecordNextMonth;
  final Future<void> Function(IncomeEntry) onToggleReceived;

  @override
  State<_EntryRow> createState() => _EntryRowState();
}

class _EntryRowState extends State<_EntryRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    Future.delayed(Duration(milliseconds: 60 + widget.index * 60), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) {
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
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.entry.category.color;
    final creatorLabel = _resolveCreatorLabel(widget.entry);
    final updatingReceived = widget.busyReceivedId == widget.entry.id;

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) => FadeTransition(
        opacity: _anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.04, 0),
            end: Offset.zero,
          ).animate(_anim),
          child: child,
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.14),
                      border: Border.all(color: color.withValues(alpha: 0.22)),
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: widget.entry.category.icon,
                        size: 18,
                        color: color,
                        strokeWidth: 1.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.entry.label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.entry.category.displayName,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.65,
                            ),
                          ),
                        ),
                        if (creatorLabel != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Added by $creatorLabel',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.54,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                        Text(
                          _rwfCompact(widget.entry.amountRwf),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: switch (widget.entry.allocationStatus) {
                              IncomeAllocationStatus.fullyAllocated =>
                                AppColors.primary.withValues(alpha: 0.14),
                              IncomeAllocationStatus.partiallyAllocated =>
                                const Color(0xFFFFB86C).withValues(alpha: 0.14),
                              IncomeAllocationStatus.unallocated =>
                                AppColors.success.withValues(alpha: 0.12),
                            },
                            border: Border.all(
                              color: switch (widget.entry.allocationStatus) {
                                IncomeAllocationStatus.fullyAllocated =>
                                  AppColors.primary.withValues(alpha: 0.25),
                                IncomeAllocationStatus.partiallyAllocated =>
                                  const Color(0xFFFFB86C).withValues(alpha: 0.25),
                                IncomeAllocationStatus.unallocated =>
                                  AppColors.success.withValues(alpha: 0.20),
                              },
                            ),
                          ),
                          child: Text(
                            widget.entry.allocationStatus.displayName,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: switch (widget.entry.allocationStatus) {
                                IncomeAllocationStatus.fullyAllocated =>
                                  AppColors.primary,
                                IncomeAllocationStatus.partiallyAllocated =>
                                  const Color(0xFFFFB86C),
                                IncomeAllocationStatus.unallocated =>
                                  AppColors.success,
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowDown01,
                          size: 12,
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                          strokeWidth: 2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expandable detail row
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.white.withValues(alpha: 0.04),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _DetailItem(
                                  label: 'Amount',
                                  value: _rwf(widget.entry.amountRwf),
                                ),
                                const SizedBox(height: 4),
                                _DetailItem(
                                  label: 'Date',
                                  value: _formatDate(widget.entry.date),
                                ),
                                const SizedBox(height: 4),
                                _DetailItem(
                                  label: 'Status',
                                  value: widget.entry.received
                                      ? 'Received'
                                      : 'Pending',
                                ),
                                const SizedBox(height: 4),
                                _DetailItem(
                                  label: 'Parked in savings',
                                  value: _rwf(widget.entry.allocatedToSavingsRwf),
                                ),
                                const SizedBox(height: 4),
                                _DetailItem(
                                  label: 'Still free',
                                  value: _rwf(widget.entry.remainingAvailableRwf),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _ReceivedToggleChip(
                                isBusy: updatingReceived,
                                received: widget.entry.received,
                                onTap: () =>
                                    widget.onToggleReceived(widget.entry),
                              ),
                              _ActionIcon(
                                icon: HugeIcons.strokeRoundedView,
                                color: AppColors.textPrimary,
                                tooltip: 'Details',
                                onTap: () => widget.onDetails(widget.entry),
                              ),
                              _ActionIcon(
                                icon: HugeIcons.strokeRoundedPencil,
                                color: const Color(0xFF7EB8FF),
                                tooltip: 'Edit',
                                onTap: () => widget.onEdit(widget.entry),
                              ),
                              _ActionIcon(
                                icon: HugeIcons.strokeRoundedCalendar03,
                                color: AppColors.success,
                                tooltip: 'Record for next month',
                                onTap: () =>
                                    widget.onRecordNextMonth(widget.entry),
                              ),
                              _ActionIcon(
                                icon: HugeIcons.strokeRoundedDelete01,
                                color: AppColors.danger,
                                tooltip: 'Delete',
                                onTap: () => widget.onDelete(widget.entry),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          if (!widget.isLast)
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String? _resolveCreatorLabel(IncomeEntry entry) {
    final creator = entry.createdBy;
    if (creator == null) {
      return null;
    }

    final firstName = creator.firstName?.trim();
    final lastName = creator.lastName?.trim();
    final fullName = [
      firstName,
      lastName,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' ');

    return fullName.isEmpty ? 'partner' : fullName;
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary.withValues(alpha: 0.6),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ActionIcon extends StatefulWidget {
  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final dynamic icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_ActionIcon> createState() => _ActionIconState();
}

class _ActionIconState extends State<_ActionIcon> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: 0.12),
            border: Border.all(color: widget.color.withValues(alpha: 0.2)),
          ),
          child: Center(
            child: HugeIcon(
              icon: widget.icon,
              size: 15,
              color: widget.color,
              strokeWidth: 1.8,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReceivedToggleChip extends StatelessWidget {
  const _ReceivedToggleChip({
    required this.isBusy,
    required this.received,
    required this.onTap,
  });

  final bool isBusy;
  final bool received;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final accent = received ? AppColors.success : const Color(0xFFFFB86C);

    return GestureDetector(
      onTap: isBusy ? null : () => onTap(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: accent.withValues(alpha: 0.14),
          border: Border.all(color: accent.withValues(alpha: 0.24)),
        ),
        child: isBusy
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              )
            : Text(
                received ? 'Received' : 'Pending',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
      ),
    );
  }
}

class _PaginationRow extends StatelessWidget {
  const _PaginationRow({
    required this.currentPage,
    required this.totalItems,
    required this.totalPages,
    required this.onNextPage,
    required this.onPreviousPage,
  });

  final int currentPage;
  final int totalItems;
  final int totalPages;
  final Future<void> Function() onNextPage;
  final Future<void> Function() onPreviousPage;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PagerButton(
          label: 'Previous',
          isDisabled: currentPage <= 1,
          onTap: onPreviousPage,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Page $currentPage of $totalPages · $totalItems rows',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary.withValues(alpha: 0.65),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _PagerButton(
          label: 'Next',
          isDisabled: currentPage >= totalPages,
          onTap: onNextPage,
        ),
      ],
    );
  }
}

class _PagerButton extends StatelessWidget {
  const _PagerButton({
    required this.label,
    required this.isDisabled,
    required this.onTap,
  });

  final String label;
  final bool isDisabled;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isDisabled ? null : () => onTap(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: isDisabled
              ? Colors.white.withValues(alpha: 0.03)
              : AppColors.success.withValues(alpha: 0.12),
          border: Border.all(
            color: isDisabled
                ? Colors.white.withValues(alpha: 0.08)
                : AppColors.success.withValues(alpha: 0.20),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isDisabled
                ? AppColors.textSecondary.withValues(alpha: 0.36)
                : AppColors.success,
          ),
        ),
      ),
    );
  }
}

// ── Form dialog (Add / Edit) ──────────────────────────────────────────────────

class _IncomeFormDialog extends StatefulWidget {
  const _IncomeFormDialog({
    required this.onSubmit,
    this.entry,
    this.onOpenRecovery,
    this.initialLabel,
    this.initialAmount,
    this.initialCategory,
    this.initialDate,
    this.initialReceived = false,
    this.title,
    this.subtitle,
    this.submitLabel,
  });

  final IncomeEntry? entry;
  final Future<void> Function()? onOpenRecovery;
  final String? initialLabel;
  final double? initialAmount;
  final IncomeCategory? initialCategory;
  final DateTime? initialDate;
  final bool initialReceived;
  final String? title;
  final String? subtitle;
  final String? submitLabel;
  final Future<IncomeEntry> Function({
    required String label,
    required double amount,
    required IncomeCategory category,
    required DateTime date,
    required bool received,
  })
  onSubmit;

  @override
  State<_IncomeFormDialog> createState() => _IncomeFormDialogState();
}

class _IncomeFormDialogState extends State<_IncomeFormDialog>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _labelCtrl;
  late final TextEditingController _amountCtrl;
  late IncomeCategory _category;
  late DateTime _date;
  late bool _received;
  late final AnimationController _animCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  bool get _isEditing => widget.entry != null;
  bool get _hasSavingAllocations =>
      (widget.entry?.allocatedToSavingsRwf ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(
      text: widget.entry?.label ?? widget.initialLabel ?? '',
    );
    _amountCtrl = TextEditingController(
      text:
          widget.entry?.amount.toStringAsFixed(0) ??
          widget.initialAmount?.toStringAsFixed(0) ??
          '',
    );
    _category =
        widget.entry?.category ??
        widget.initialCategory ??
        IncomeCategory.salary;
    _date = widget.entry?.date ?? widget.initialDate ?? DateTime.now();
    _received = widget.entry?.received ?? widget.initialReceived;

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _scaleAnim = Tween<double>(
      begin: 0.90,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _amountCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    if (_isSubmitting) {
      return;
    }

    final latestSelectableDate = DateTime.now().add(
      const Duration(days: 365 * 10),
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: latestSelectableDate,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.success,
            onPrimary: AppColors.background,
            surface: AppColors.surfaceElevated,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) return;

    setState(() => _isSubmitting = true);

    try {
      final result = await widget.onSubmit(
        label: _labelCtrl.text.trim(),
        amount: amount,
        category: _category,
        date: _date,
        received: _received,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: _isEditing ? 'Unable to update income' : 'Unable to add income',
        description: _readableError(error),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _readableError(Object error) {
    final message = error.toString().trim();

    if (message.startsWith('Exception: ')) {
      return message.replaceFirst('Exception: ', '');
    }

    if (message.startsWith('StateError: ')) {
      return message.replaceFirst('StateError: ', '');
    }

    return message;
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 600;
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
    final dateLabel = '${months[_date.month - 1]} ${_date.day}, ${_date.year}';

    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AppModalDialog(
          maxWidth: 460,
          padding: const EdgeInsets.all(28),
          insetPadding: EdgeInsets.symmetric(
            horizontal: isCompact ? 16 : 40,
            vertical: 24,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dialog header
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.success.withValues(alpha: 0.16),
                        ),
                        child: Center(
                          child: HugeIcon(
                            icon: _isEditing
                                ? HugeIcons.strokeRoundedPencil
                                : HugeIcons.strokeRoundedMoneyAdd01,
                            size: 18,
                            color: AppColors.success,
                            strokeWidth: 1.8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title ??
                                  (_isEditing ? 'Edit income' : 'Add income'),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              widget.subtitle ??
                                  (_isEditing
                                      ? 'Update the details below'
                                      : 'Fill in the details below'),
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppModalCloseButton(
                        onTap: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _GradientDivider(color: AppColors.success),
                  const SizedBox(height: 24),

                  // Source label
                  _FieldLabel(label: 'Source name'),
                  const SizedBox(height: 8),
                  _GlassField(
                    controller: _labelCtrl,
                    hint: 'e.g. Monthly Salary',
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Please enter a source name'
                        : null,
                  ),
                  const SizedBox(height: 18),

                  // Amount
                  _FieldLabel(label: 'Amount (RWF)'),
                  const SizedBox(height: 8),
                  _GlassField(
                    controller: _amountCtrl,
                    hint: 'e.g. 450000',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    prefixText: 'RWF ',
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter an amount';
                      }
                      final n = double.tryParse(v.replaceAll(',', ''));
                      if (n == null || n <= 0) {
                        return 'Enter a valid amount';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  // Category
                  _FieldLabel(label: 'Category'),
                  const SizedBox(height: 8),
                  _CategoryPicker(
                    selected: _category,
                    onChanged: (c) => setState(() => _category = c),
                  ),
                  const SizedBox(height: 18),

                  _FieldLabel(label: 'Received state'),
                  const SizedBox(height: 8),
                  _ReceivedStatePicker(
                    received: _received,
                    disablePending: _hasSavingAllocations,
                    onChanged: (value) => setState(() => _received = value),
                  ),
                  if (_hasSavingAllocations) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: const Color(0xFFFFB86C).withValues(alpha: 0.10),
                        border: Border.all(
                          color: const Color(0xFFFFB86C).withValues(alpha: 0.20),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'This income already funds savings. You can still update the label and date, but to mark it pending again or reduce it, first reverse the linked saving allocation.',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.5,
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.92,
                              ),
                            ),
                          ),
                          if (widget.onOpenRecovery != null) ...[
                            const SizedBox(height: 10),
                            _DialogButton(
                              label: 'Review linked allocations',
                              isPrimary: false,
                              onTap: widget.onOpenRecovery!,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),

                  // Date
                  _FieldLabel(label: 'Date'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.white.withValues(alpha: 0.06),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedCalendar03,
                            size: 16,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.7,
                            ),
                            strokeWidth: 1.8,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            dateLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedArrowDown01,
                            size: 14,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.5,
                            ),
                            strokeWidth: 1.8,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: _DialogButton(
                          label: 'Cancel',
                          isPrimary: false,
                          isDisabled: _isSubmitting,
                          onTap: () async {
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DialogButton(
                          label:
                              widget.submitLabel ??
                              (_isEditing ? 'Save changes' : 'Add income'),
                          isPrimary: true,
                          isLoading: _isSubmitting,
                          onTap: _submit,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Category picker ───────────────────────────────────────────────────────────

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.selected, required this.onChanged});

  final IncomeCategory selected;
  final void Function(IncomeCategory) onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: IncomeCategory.values.map((cat) {
        final isSelected = cat == selected;
        final color = cat.color;
        return GestureDetector(
          onTap: () => onChanged(cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isSelected
                  ? color.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: isSelected
                    ? color.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(
                  icon: cat.icon,
                  size: 13,
                  color: isSelected ? color : AppColors.textSecondary,
                  strokeWidth: 1.8,
                ),
                const SizedBox(width: 6),
                Text(
                  cat.displayName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? color : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ReceivedStatePicker extends StatelessWidget {
  const _ReceivedStatePicker({
    required this.received,
    required this.onChanged,
    this.disablePending = false,
  });

  final bool received;
  final ValueChanged<bool> onChanged;
  final bool disablePending;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ReceivedStateChoice(
          label: 'Received',
          isSelected: received,
          color: AppColors.success,
          onTap: () => onChanged(true),
        ),
        _ReceivedStateChoice(
          label: 'Pending',
          isSelected: !received,
          isDisabled: disablePending,
          color: const Color(0xFFFFB86C),
          onTap: () => onChanged(false),
        ),
      ],
    );
  }
}

class _ReceivedStateChoice extends StatelessWidget {
  const _ReceivedStateChoice({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
    this.isDisabled = false,
  });

  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isSelected
              ? color.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.42)
                : Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDisabled
                ? AppColors.textSecondary.withValues(alpha: 0.35)
                : isSelected
                ? color
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _IncomeDetailsSheet extends StatelessWidget {
  const _IncomeDetailsSheet({
    required this.entry,
    required this.detail,
    required this.highlightAllocationId,
    required this.isLoading,
    required this.isReversingAllocation,
    required this.onClose,
    required this.onReverseAllocation,
  });

  final IncomeEntry entry;
  final IncomeDetail? detail;
  final String? highlightAllocationId;
  final bool isLoading;
  final bool isReversingAllocation;
  final VoidCallback onClose;
  final Future<void> Function(IncomeEntry entry, IncomeSavingAllocation allocation)
  onReverseAllocation;

  @override
  Widget build(BuildContext context) {
    final source = detail ?? entry;

    return FadeTransition(
      opacity: const AlwaysStoppedAnimation(1),
      child: AppModalDialog(
        maxWidth: 520,
        padding: const EdgeInsets.all(24),
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.label,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${source.category.displayName} • ${_formatSheetDate(source.date)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
                AppModalCloseButton(onTap: onClose),
              ],
            ),
            const SizedBox(height: 18),
            _GradientDivider(color: AppColors.success),
            const SizedBox(height: 18),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.success),
                  ),
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: _SheetStat(
                      label: 'Recorded amount',
                      value: _rwf(source.amountRwf),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SheetStat(
                      label: 'Parked in savings',
                      value: _rwf(source.allocatedToSavingsRwf),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SheetStat(
                      label: 'Still free',
                      value: _rwf(source.remainingAvailableRwf),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withValues(alpha: 0.04),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cash state',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      source.received ? 'Received cash' : 'Scheduled only',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      source.received
                          ? 'This money is already in hand. The free amount can still be spent or moved into savings.'
                          : 'This income is planned, but it should not count as money you already have until it is marked received.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: AppColors.textSecondary.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Saving allocations',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              if (detail == null || detail!.savingAllocations.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withValues(alpha: 0.04),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Text(
                    'No part of this income has been linked to a saving bucket yet.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.textSecondary.withValues(alpha: 0.78),
                    ),
                  ),
                )
              else
                ...detail!.savingAllocations.map(
                  (allocation) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AllocationCard(
                      allocation: allocation,
                      highlight: allocation.id == highlightAllocationId,
                      isBusy: isReversingAllocation,
                      onReverse: allocation.isReversed
                          ? null
                          : () => onReverseAllocation(entry, allocation),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatSheetDate(DateTime value) =>
      '${_monthShort(value.month)} ${value.day}, ${value.year}';
}

class _BlockedIncomeActionDialog extends StatelessWidget {
  const _BlockedIncomeActionDialog({
    required this.action,
    required this.entry,
    required this.onCancel,
    required this.onReviewAllocations,
  });

  final _BlockedIncomeAction action;
  final IncomeEntry entry;
  final VoidCallback onCancel;
  final Future<void> Function() onReviewAllocations;

  @override
  Widget build(BuildContext context) {
    return AppModalDialog(
      maxWidth: 420,
      padding: const EdgeInsets.all(24),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            action == _BlockedIncomeAction.delete
                ? 'This income cannot be deleted yet'
                : 'Some income changes are blocked',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${entry.label} already funds one or more saving buckets. To ${action == _BlockedIncomeAction.delete ? 'delete' : 'change this income freely'}, first reverse the linked saving allocation.',
            style: TextStyle(
              fontSize: 12,
              height: 1.55,
              color: AppColors.textSecondary.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailItem(
                  label: 'Allocated now',
                  value: _rwf(entry.allocatedToSavingsRwf),
                ),
                const SizedBox(height: 4),
                _DetailItem(
                  label: 'Still free',
                  value: _rwf(entry.remainingAvailableRwf),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _DialogButton(
                  label: 'Cancel',
                  isPrimary: false,
                  onTap: () async => onCancel(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DialogButton(
                  label: 'Review allocations',
                  isPrimary: true,
                  onTap: onReviewAllocations,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SheetStat extends StatelessWidget {
  const _SheetStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AllocationCard extends StatelessWidget {
  const _AllocationCard({
    required this.allocation,
    required this.highlight,
    required this.isBusy,
    required this.onReverse,
  });

  final IncomeSavingAllocation allocation;
  final bool highlight;
  final bool isBusy;
  final Future<void> Function()? onReverse;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: highlight
            ? AppColors.primary.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: highlight
              ? AppColors.primary.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (highlight)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Reverse this allocation to unblock the income',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary.withValues(alpha: 0.92),
                ),
              ),
            ),
          if (allocation.isReversed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Reversed allocation',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFFB86C).withValues(alpha: 0.92),
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      allocation.savingLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Deposited ${_monthShort(allocation.transactionDate.month)} ${allocation.transactionDate.day}, ${allocation.transactionDate.year}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary.withValues(alpha: 0.68),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _rwf(allocation.amountRwf),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          if (allocation.note != null && allocation.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              allocation.note!,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: AppColors.textSecondary.withValues(alpha: 0.82),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: _DialogButton(
              label: allocation.isReversed
                  ? 'Already reversed'
                  : isBusy
                  ? 'Reversing...'
                  : 'Reverse allocation',
              isPrimary: true,
              isDisabled: allocation.isReversed || onReverse == null || isBusy,
              onTap: onReverse ?? () async {},
            ),
          ),
        ],
      ),
    );
  }
}

// ── Delete confirm dialog ─────────────────────────────────────────────────────

class _DeleteConfirmDialog extends StatefulWidget {
  const _DeleteConfirmDialog({required this.label});
  final String label;

  @override
  State<_DeleteConfirmDialog> createState() => _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends State<_DeleteConfirmDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scaleAnim = Tween<double>(
      begin: 0.88,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AppModalDialog(
          maxWidth: 380,
          padding: const EdgeInsets.all(28),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 40,
            vertical: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.danger.withValues(alpha: 0.14),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.3),
                  ),
                ),
                child: const Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedDelete01,
                    size: 24,
                    color: AppColors.danger,
                    strokeWidth: 1.8,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Remove income entry?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '"${widget.label}" will be permanently removed from your records.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _DialogButton(
                      label: 'Keep it',
                      isPrimary: false,
                      onTap: () async {
                        Navigator.of(context).pop(false);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DialogButton(
                      label: 'Delete',
                      isPrimary: true,
                      isDanger: true,
                      onTap: () async {
                        Navigator.of(context).pop(true);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared dialog widgets ─────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary.withValues(alpha: 0.9),
        letterSpacing: 0.2,
      ),
    );
  }
}

class _GlassField extends StatelessWidget {
  const _GlassField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.prefixText,
    this.validator,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? prefixText;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(
        fontSize: 13,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        prefixText: prefixText,
        prefixStyle: const TextStyle(
          fontSize: 13,
          color: AppColors.success,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary.withValues(alpha: 0.4),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.success.withValues(alpha: 0.5),
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.danger.withValues(alpha: 0.5),
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.danger.withValues(alpha: 0.7),
          ),
        ),
        errorStyle: const TextStyle(fontSize: 11, color: AppColors.danger),
      ),
    );
  }
}

class _DialogButton extends StatefulWidget {
  const _DialogButton({
    required this.label,
    required this.isPrimary,
    required this.onTap,
    this.isDanger = false,
    this.isLoading = false,
    this.isDisabled = false,
  });

  final String label;
  final bool isPrimary;
  final bool isDanger;
  final bool isLoading;
  final bool isDisabled;
  final Future<void> Function() onTap;

  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.isDanger ? AppColors.danger : AppColors.success;
    final isInteractive = !widget.isLoading && !widget.isDisabled;

    return GestureDetector(
      onTapDown: isInteractive ? (_) => setState(() => _pressed = true) : null,
      onTapUp: isInteractive
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap();
            }
          : null,
      onTapCancel: isInteractive
          ? () => setState(() => _pressed = false)
          : null,
      child: AnimatedScale(
        scale: _pressed && isInteractive ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: AppModalActionButton(
          label: widget.label,
          isPrimary: widget.isPrimary,
          isLoading: widget.isLoading,
          onPressed: isInteractive ? () => widget.onTap() : null,
          primaryColor: accent,
          primaryForegroundColor: AppColors.background,
          outlineForegroundColor: AppColors.textSecondary.withValues(
            alpha: isInteractive ? 1 : 0.55,
          ),
        ),
      ),
    );
  }
}

// ── Animated counter ──────────────────────────────────────────────────────────

class _AnimatedCounter extends StatefulWidget {
  const _AnimatedCounter({required this.value, required this.style});
  final double value;
  final TextStyle style;

  @override
  State<_AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<_AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  double _previous = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_AnimatedCounter old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _previous = old.value;
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final v = _previous + _anim.value * (widget.value - _previous);
        return Text(_rwf(v), style: widget.style);
      },
    );
  }
}

// ── Gradient divider ──────────────────────────────────────────────────────────

class _GradientDivider extends StatelessWidget {
  const _GradientDivider({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            color.withValues(alpha: 0.22),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

// ── Empty hint ────────────────────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedMoneyReceiveCircle,
            size: 36,
            color: AppColors.textSecondary.withValues(alpha: 0.25),
            strokeWidth: 1.5,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary.withValues(alpha: 0.45),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadErrorHint extends StatelessWidget {
  const _LoadErrorHint({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedAlert02,
            size: 34,
            color: AppColors.danger.withValues(alpha: 0.75),
            strokeWidth: 1.6,
          ),
          const SizedBox(height: 14),
          Text(
            'Income sync is temporarily unavailable',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary.withValues(alpha: 0.75),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 18),
          _RetryButton(onTap: onRetry),
        ],
      ),
    );
  }
}

class _RetryButton extends StatefulWidget {
  const _RetryButton({required this.onTap});

  final Future<void> Function() onTap;

  @override
  State<_RetryButton> createState() => _RetryButtonState();
}

class _RetryButtonState extends State<_RetryButton> {
  bool _pressed = false;
  bool _isLoading = false;

  Future<void> _handleTap() async {
    if (_isLoading) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      await widget.onTap();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _isLoading ? null : (_) => setState(() => _pressed = true),
      onTapUp: _isLoading
          ? null
          : (_) {
              setState(() => _pressed = false);
              _handleTap();
            },
      onTapCancel: _isLoading ? null : () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: AppColors.success.withValues(alpha: 0.14),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.28),
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _isLoading
                ? const SizedBox(
                    key: ValueKey('retry-loading'),
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.success,
                      ),
                    ),
                  )
                : const Text(
                    'Retry sync',
                    key: ValueKey('retry-label'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Footer ────────────────────────────────────────────────────────────────────

class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text(
          'Live income sync · secured to your account session',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary.withValues(alpha: 0.4),
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}
