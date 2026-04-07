import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/network/paginated_response.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_modal_dialog.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../expenses/application/expense_service.dart';
import '../../../expenses/data/models/expense_entry.dart';
import '../../../expenses/data/models/expense_list_query.dart';

extension _ExpenseCategoryPresentation on ExpenseCategory {
  dynamic get icon => switch (this) {
    ExpenseCategory.foodDining => HugeIcons.strokeRoundedRestaurant01,
    ExpenseCategory.transport => HugeIcons.strokeRoundedCar01,
    ExpenseCategory.housing => HugeIcons.strokeRoundedHome01,
    ExpenseCategory.loan => HugeIcons.strokeRoundedWallet03,
    ExpenseCategory.utilities => HugeIcons.strokeRoundedPlug01,
    ExpenseCategory.healthcare => HugeIcons.strokeRoundedShield01,
    ExpenseCategory.education => HugeIcons.strokeRoundedBook02,
    ExpenseCategory.entertainment => HugeIcons.strokeRoundedGameController01,
    ExpenseCategory.shopping => HugeIcons.strokeRoundedShoppingBag01,
    ExpenseCategory.personalCare => HugeIcons.strokeRoundedSparkles,
    ExpenseCategory.travel => HugeIcons.strokeRoundedAirplane01,
    ExpenseCategory.savings => HugeIcons.strokeRoundedPiggyBank,
    ExpenseCategory.other => HugeIcons.strokeRoundedMoreHorizontalCircle01,
  };

  Color get color => switch (this) {
    ExpenseCategory.foodDining => const Color(0xFFFFA86B),
    ExpenseCategory.transport => const Color(0xFF7EB8FF),
    ExpenseCategory.housing => AppColors.primary,
    ExpenseCategory.loan => const Color(0xFFFF8E8E),
    ExpenseCategory.utilities => const Color(0xFF7AD7C3),
    ExpenseCategory.healthcare => AppColors.success,
    ExpenseCategory.education => const Color(0xFFC79BFF),
    ExpenseCategory.entertainment => const Color(0xFFFF7AB6),
    ExpenseCategory.shopping => const Color(0xFFFFD36E),
    ExpenseCategory.personalCare => const Color(0xFFA5E06E),
    ExpenseCategory.travel => const Color(0xFF8FD4FF),
    ExpenseCategory.savings => const Color(0xFF6FCF97),
    ExpenseCategory.other => AppColors.textSecondary,
  };
}

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

String _formatLongDate(DateTime value) {
  return '${_monthShort(value.month)} ${value.day}, ${value.year}';
}

String? _resolveCreatorLabel(ExpenseEntry entry) {
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

class ExpensePage extends StatefulWidget {
  const ExpensePage({super.key, required this.expenseService});

  final ExpenseService expenseService;

  @override
  State<ExpensePage> createState() => _ExpensePageState();
}

class _ExpensePageState extends State<ExpensePage>
    with SingleTickerProviderStateMixin {
  static const int _pageSize = 12;

  late final AnimationController _entranceCtrl;
  late final TextEditingController _searchCtrl;
  List<ExpenseCategoryOption> _categoryOptions = const [];
  List<ExpenseEntry> _entries = const [];
  List<ExpenseEntry> _pageEntries = const [];
  bool _isLoading = true;
  String? _loadError;
  Timer? _searchDebounce;
  int _currentPage = 1;
  int _totalItems = 0;
  int _totalPages = 1;
  late int _selectedMonth;
  late int _selectedYear;
  ExpenseCategory? _selectedCategory;
  DateTime? _selectedDateFrom;
  DateTime? _selectedDateTo;
  String _searchInput = '';
  String? _appliedSearch;
  int _loadSequence = 0;

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
    _loadExpenses();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  double get _total => _entries.fold(0, (sum, entry) => sum + entry.amount);

  double get _average => _entries.isEmpty ? 0 : _total / _entries.length;

  ExpenseEntry? get _largestEntry {
    if (_entries.isEmpty) {
      return null;
    }

    final sorted = _entries.toList(growable: false)
      ..sort((left, right) => right.amount.compareTo(left.amount));
    return sorted.first;
  }

  int get _categoryCount =>
      _entries.map((entry) => entry.category).toSet().length;

  bool get _hasExplicitDateFilter =>
      _selectedDateFrom != null || _selectedDateTo != null;

  bool get _hasActiveFilters {
    final now = DateTime.now();

    return _selectedMonth != now.month ||
        _selectedYear != now.year ||
        _selectedCategory != null ||
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

  List<ExpenseCategoryOption> get _effectiveCategoryOptions {
    if (_categoryOptions.isNotEmpty) {
      return _categoryOptions;
    }

    return ExpenseCategory.values
        .map(
          (category) => ExpenseCategoryOption(
            value: category,
            label: category.displayName,
          ),
        )
        .toList(growable: false);
  }

  Future<void> _openAddDialog() async {
    final created = await showDialog<ExpenseEntry>(
      context: context,
      builder: (_) => _ExpenseFormDialog(
        categoryOptions: _effectiveCategoryOptions,
        initialCategory: _selectedCategory ?? ExpenseCategory.foodDining,
        initialDate: _defaultCreateDate(),
        onSubmit:
            ({
              required String label,
              required double amount,
              required ExpenseCategory category,
              required DateTime date,
              String? note,
            }) {
              return widget.expenseService.createExpense(
                label: label,
                amount: amount,
                category: category,
                date: date,
                note: note,
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
    await _loadExpenses();
    if (!mounted) {
      return;
    }

    AppToast.success(
      context,
      title: 'Expense added',
      description: '${created.label} was saved to your expense records.',
    );
  }

  Future<void> _openEditDialog(ExpenseEntry entry) async {
    final updated = await showDialog<ExpenseEntry>(
      context: context,
      builder: (_) => _ExpenseFormDialog(
        entry: entry,
        categoryOptions: _effectiveCategoryOptions,
        onSubmit:
            ({
              required String label,
              required double amount,
              required ExpenseCategory category,
              required DateTime date,
              String? note,
            }) {
              return widget.expenseService.updateExpense(
                expenseId: entry.id,
                label: label,
                amount: amount,
                category: category,
                date: date,
                note: note,
              );
            },
      ),
    );

    if (updated == null || !mounted) {
      return;
    }

    setState(() => _loadError = null);
    await _loadExpenses();
    if (!mounted) {
      return;
    }

    AppToast.success(
      context,
      title: 'Expense updated',
      description: '${updated.label} was updated successfully.',
    );
  }

  Future<void> _confirmDelete(ExpenseEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteConfirmDialog(label: entry.label),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await widget.expenseService.deleteExpense(entry.id);

      if (!mounted) {
        return;
      }

      setState(() {
        if (_pageEntries.length == 1 && _currentPage > 1) {
          _currentPage -= 1;
        }
      });
      await _loadExpenses();
      if (!mounted) {
        return;
      }

      AppToast.success(
        context,
        title: 'Expense removed',
        description: '${entry.label} was removed from your records.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Unable to delete expense',
        description: _readableError(error),
      );
    }
  }

  Future<void> _loadExpenses() async {
    final loadId = ++_loadSequence;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final summaryQuery = _buildExpenseQuery();
      final pageQuery = _buildExpenseQuery(
        page: _currentPage,
        limit: _pageSize,
      );
      final results = await Future.wait<dynamic>([
        if (_categoryOptions.isEmpty)
          widget.expenseService.listExpenseCategories(),
        widget.expenseService.listExpenses(query: summaryQuery),
        widget.expenseService.listExpensesPage(query: pageQuery),
      ]);

      var resultIndex = 0;
      var categories = _categoryOptions;
      if (_categoryOptions.isEmpty) {
        categories = (results[resultIndex++] as List<dynamic>)
            .cast<ExpenseCategoryOption>();
      }

      final entries = (results[resultIndex++] as List<dynamic>)
          .cast<ExpenseEntry>();
      final pageResponse =
          results[resultIndex] as PaginatedResponse<ExpenseEntry>;

      if (!mounted || loadId != _loadSequence) {
        return;
      }

      setState(() {
        _categoryOptions = categories;
        _entries = _sortedEntries(entries);
        _pageEntries = _sortedEntries(pageResponse.items);
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
        _isLoading = false;
        _loadError = message;
        _totalItems = 0;
        _totalPages = 1;
      });

      AppToast.error(
        context,
        title: 'Unable to load expenses',
        description: message,
      );
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
      _loadExpenses();
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
            primary: AppColors.danger,
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
    await _loadExpenses();
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
    await _loadExpenses();
  }

  Future<void> _clearAllFilters() async {
    final now = DateTime.now();
    _searchDebounce?.cancel();
    _searchCtrl.clear();

    setState(() {
      _selectedMonth = now.month;
      _selectedYear = now.year;
      _selectedCategory = null;
      _selectedDateFrom = null;
      _selectedDateTo = null;
      _searchInput = '';
      _appliedSearch = null;
      _currentPage = 1;
    });
    await _loadExpenses();
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
    await _loadExpenses();
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
    await _loadExpenses();
  }

  Future<void> _goToPage(int page) async {
    if (page < 1 || page > _totalPages || page == _currentPage) {
      return;
    }

    setState(() => _currentPage = page);
    await _loadExpenses();
  }

  List<ExpenseEntry> _sortedEntries(List<ExpenseEntry> entries) {
    final sorted = List<ExpenseEntry>.from(entries);
    sorted.sort((left, right) {
      final byDate = right.date.compareTo(left.date);
      if (byDate != 0) {
        return byDate;
      }

      return right.createdAt.compareTo(left.createdAt);
    });

    return List<ExpenseEntry>.unmodifiable(sorted);
  }

  ExpenseListQuery _buildExpenseQuery({int? page, int? limit}) {
    return ExpenseListQuery(
      month: _hasExplicitDateFilter ? null : _selectedMonth,
      year: _hasExplicitDateFilter ? null : _selectedYear,
      category: _selectedCategory,
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

  String _categoryLabel(ExpenseCategory category) {
    for (final option in _effectiveCategoryOptions) {
      if (option.value == category) {
        return option.label;
      }
    }

    return category.displayName;
  }

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
      return _ExpensePageLoading(fade: _fade, slide: _slide);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Staggered(
          fade: _fade(0.0, 0.45),
          slide: _slide(0.0, 0.45),
          child: _ExpenseHeader(
            total: _total,
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
          child: _ExpenseFiltersPanel(
            category: _selectedCategory,
            categoryOptions: _effectiveCategoryOptions,
            dateFrom: _selectedDateFrom,
            dateTo: _selectedDateTo,
            hasActiveFilters: _hasActiveFilters,
            searchController: _searchCtrl,
            searchInput: _searchInput,
            onCategoryChanged: (value) async {
              setState(() {
                _selectedCategory = value;
                _currentPage = 1;
              });
              await _loadExpenses();
            },
            onClearAll: _clearAllFilters,
            onClearDate: _clearDateFilter,
            onDatePicked: _pickFilterDate,
            onSearchChanged: _onSearchChanged,
          ),
        ),
        const SizedBox(height: 14),
        _Staggered(
          fade: _fade(0.22, 0.64),
          slide: _slide(0.22, 0.64),
          child: _ExpenseStatsRow(
            average: _average,
            categoryCount: _categoryCount,
            largestEntry: _largestEntry,
          ),
        ),
        const SizedBox(height: 14),
        _Staggered(
          fade: _fade(0.34, 0.76),
          slide: _slide(0.34, 0.76),
          child: _CategoryBreakdown(
            entries: _entries,
            total: _total,
            categoryLabel: _categoryLabel,
          ),
        ),
        const SizedBox(height: 14),
        _Staggered(
          fade: _fade(0.46, 0.90),
          slide: _slide(0.46, 0.90),
          child: _ExpenseEntriesPanel(
            currentPage: _currentPage,
            entries: _pageEntries,
            totalItems: _totalItems,
            totalPages: _totalPages,
            loadError: _loadError,
            categoryLabel: _categoryLabel,
            onRetry: _loadExpenses,
            onEdit: _openEditDialog,
            onDelete: _confirmDelete,
            onNextPage: () => _goToPage(_currentPage + 1),
            onPreviousPage: () => _goToPage(_currentPage - 1),
          ),
        ),
        const SizedBox(height: 8),
        _Staggered(
          fade: _fade(0.70, 1.0),
          slide: _slide(0.70, 1.0),
          child: const _FooterNote(),
        ),
      ],
    );
  }
}

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

class _ExpensePageLoading extends StatelessWidget {
  const _ExpensePageLoading({required this.fade, required this.slide});

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
            fade: fade(0.16, 0.58),
            slide: slide(0.16, 0.58),
            child: const _LoadingPanel(
              padding: EdgeInsets.all(22),
              child: _LoadingFiltersPanel(),
            ),
          ),
          const SizedBox(height: 14),
          _Staggered(
            fade: fade(0.24, 0.66),
            slide: slide(0.24, 0.66),
            child: const _LoadingStatsRow(),
          ),
          const SizedBox(height: 14),
          _Staggered(
            fade: fade(0.36, 0.78),
            slide: slide(0.36, 0.78),
            child: const _LoadingPanel(
              padding: EdgeInsets.all(20),
              child: _LoadingCategoryPanel(),
            ),
          ),
          const SizedBox(height: 14),
          _Staggered(
            fade: fade(0.48, 0.90),
            slide: slide(0.48, 0.90),
            child: const _LoadingPanel(
              padding: EdgeInsets.all(22),
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
                        SkeletonBox(width: 92, height: 30, radius: 999),
                        SizedBox(width: 10),
                        SkeletonBox(width: 124, height: 30, radius: 999),
                      ],
                    ),
                    SizedBox(height: 18),
                    SkeletonBox(width: 180, height: 30, radius: 18),
                    SizedBox(height: 8),
                    SkeletonBox(height: 12, radius: 12),
                    SizedBox(height: 8),
                    SkeletonBox(width: 230, height: 12, radius: 12),
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
        SkeletonBox(width: 72, height: 14, radius: 12),
        SizedBox(height: 16),
        SkeletonBox(height: 46, radius: 16),
        SizedBox(height: 12),
        SkeletonBox(width: 230, height: 10, radius: 12),
        SizedBox(height: 18),
        SkeletonBox(width: 84, height: 12, radius: 12),
        SizedBox(height: 10),
        SkeletonBox(height: 36, radius: 18),
        SizedBox(height: 10),
        SkeletonBox(height: 36, radius: 18),
      ],
    );
  }
}

class _LoadingStatsRow extends StatelessWidget {
  const _LoadingStatsRow();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = List.generate(
          3,
          (_) => const SizedBox(width: 210, child: _LoadingStatCard()),
        );

        if (constraints.maxWidth < 760) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  cards[i],
                  if (i != cards.length - 1) const SizedBox(width: 10),
                ],
              ],
            ),
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                Expanded(child: cards[i]),
                if (i != cards.length - 1) const SizedBox(width: 10),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _LoadingStatCard extends StatelessWidget {
  const _LoadingStatCard();

  @override
  Widget build(BuildContext context) {
    return _LoadingPanel(
      padding: const EdgeInsets.all(18),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 88, height: 11, radius: 10),
          SizedBox(height: 10),
          SkeletonBox(width: 112, height: 20, radius: 12),
          SizedBox(height: 6),
          SkeletonBox(height: 11, radius: 10),
          SizedBox(height: 6),
          SkeletonBox(width: 124, height: 11, radius: 10),
        ],
      ),
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
        SkeletonBox(width: 148, height: 14, radius: 12),
        SizedBox(height: 8),
        SkeletonBox(width: 220, height: 11, radius: 10),
        SizedBox(height: 18),
        SkeletonBox(height: 44, radius: 18),
        SizedBox(height: 12),
        SkeletonBox(height: 44, radius: 18),
        SizedBox(height: 12),
        SkeletonBox(height: 44, radius: 18),
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
            SkeletonBox(width: 128, height: 16, radius: 12),
            Spacer(),
            SkeletonBox(width: 86, height: 12, radius: 12),
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
        SkeletonBox(width: 44, height: 44, radius: 999),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 120, height: 14, radius: 12),
              SizedBox(height: 8),
              SkeletonBox(width: 180, height: 10, radius: 12),
            ],
          ),
        ),
        SizedBox(width: 12),
        SkeletonBox(width: 72, height: 16, radius: 12),
      ],
    );
  }
}

class _ExpenseHeader extends StatefulWidget {
  const _ExpenseHeader({
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
  final Future<void> Function() onAdd;
  final Future<void> Function() onNextMonth;
  final Future<void> Function() onPreviousMonth;

  @override
  State<_ExpenseHeader> createState() => _ExpenseHeaderState();
}

class _ExpenseHeaderState extends State<_ExpenseHeader>
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
                  AppColors.danger.withValues(alpha: 0.15),
                  Colors.white.withValues(alpha: 0.07),
                  AppColors.danger.withValues(alpha: 0.04),
                ],
                stops: [0.0, _shimmer.value, 1.0],
              ),
              border: Border.all(
                color: AppColors.danger.withValues(alpha: 0.30),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.danger.withValues(alpha: 0.10),
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
                                      icon: HugeIcons.strokeRoundedWallet02,
                                      size: 15,
                                      color: AppColors.danger,
                                      strokeWidth: 1.8,
                                    ),
                                    SizedBox(width: 7),
                                    Text(
                                      'Expense',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: _MonthStepper(
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
                            'Expense',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontSize: isCompact ? 26 : 30,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Track spending with the same filters, pagination, and creator history you already use on web.',
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
                    _AddExpenseButton(onTap: widget.onAdd),
                  ],
                ),
                const SizedBox(height: 22),
                const _GradientDivider(color: AppColors.danger),
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
                        color: AppColors.danger.withValues(alpha: 0.12),
                        border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const HugeIcon(
                            icon: HugeIcons.strokeRoundedArrowDownLeft01,
                            size: 12,
                            color: AppColors.danger,
                            strokeWidth: 2,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${widget.entryCount} records',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.danger,
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

class _MonthStepper extends StatelessWidget {
  const _MonthStepper({
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
              : AppColors.danger.withValues(alpha: 0.12),
          border: Border.all(
            color: isDisabled
                ? Colors.white.withValues(alpha: 0.06)
                : AppColors.danger.withValues(alpha: 0.16),
          ),
        ),
        child: Center(
          child: HugeIcon(
            icon: icon,
            size: 13,
            color: isDisabled
                ? AppColors.textSecondary.withValues(alpha: 0.35)
                : AppColors.danger,
            strokeWidth: 1.9,
          ),
        ),
      ),
    );
  }
}

class _AddExpenseButton extends StatefulWidget {
  const _AddExpenseButton({required this.onTap});

  final Future<void> Function() onTap;

  @override
  State<_AddExpenseButton> createState() => _AddExpenseButtonState();
}

class _AddExpenseButtonState extends State<_AddExpenseButton> {
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
            color: AppColors.danger.withValues(alpha: 0.18),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: AppColors.danger.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedAdd01,
              size: 20,
              color: AppColors.danger,
              strokeWidth: 2,
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpenseFiltersPanel extends StatelessWidget {
  const _ExpenseFiltersPanel({
    required this.category,
    required this.categoryOptions,
    required this.dateFrom,
    required this.dateTo,
    required this.hasActiveFilters,
    required this.searchController,
    required this.searchInput,
    required this.onCategoryChanged,
    required this.onClearAll,
    required this.onClearDate,
    required this.onDatePicked,
    required this.onSearchChanged,
  });

  final ExpenseCategory? category;
  final List<ExpenseCategoryOption> categoryOptions;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final bool hasActiveFilters;
  final TextEditingController searchController;
  final String searchInput;
  final Future<void> Function(ExpenseCategory? value) onCategoryChanged;
  final Future<void> Function() onClearAll;
  final Future<void> Function({required bool isFrom}) onClearDate;
  final Future<void> Function({required bool isFrom}) onDatePicked;
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
                      color: AppColors.danger.withValues(alpha: 0.9),
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
              hintText: 'Search expense label, note, or category',
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
                  color: AppColors.danger.withValues(alpha: 0.45),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            searchInput.isNotEmpty && searchInput.trim().length < 3
                ? 'Type at least 3 characters to apply search.'
                : 'Month, search, category, chosen date range, and pagination match the web filters.',
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
              ...categoryOptions.map(
                (option) => _FilterChoiceChip(
                  label: option.label,
                  isSelected: category == option.value,
                  accent: option.value.color,
                  onTap: () => onCategoryChanged(option.value),
                ),
              ),
            ],
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
    this.accent = AppColors.danger,
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
    final displayValue = value == null ? 'Pick date' : _formatLongDate(value!);

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

class _ExpenseStatsRow extends StatelessWidget {
  const _ExpenseStatsRow({
    required this.average,
    required this.categoryCount,
    required this.largestEntry,
  });

  final double average;
  final int categoryCount;
  final ExpenseEntry? largestEntry;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final children = [
          _MetricCard(
            label: 'Average spend',
            value: _rwfCompact(average),
            detail: 'Per recorded expense',
            accent: const Color(0xFFFFA86B),
          ),
          _MetricCard(
            label: 'Largest expense',
            value: largestEntry == null
                ? 'No entries'
                : _rwfCompact(largestEntry!.amount),
            detail: largestEntry?.label ?? 'Record your first expense',
            accent: AppColors.danger,
          ),
          _MetricCard(
            label: 'Categories used',
            value: '$categoryCount',
            detail: categoryCount == 1
                ? 'Category active'
                : 'Categories active',
            accent: const Color(0xFF7EB8FF),
          ),
        ];

        if (constraints.maxWidth < 760) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    SizedBox(width: 210, child: children[i]),
                    if (i != children.length - 1) const SizedBox(width: 10),
                  ],
                ],
              ),
            ),
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                Expanded(child: children[i]),
                if (i != children.length - 1) const SizedBox(width: 10),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.accent,
  });

  final String label;
  final String value;
  final String detail;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      borderRadius: BorderRadius.circular(24),
      blur: 22,
      opacity: 0.11,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              detail,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary.withValues(alpha: 0.6),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({
    required this.entries,
    required this.total,
    required this.categoryLabel,
  });

  final List<ExpenseEntry> entries;
  final double total;
  final String Function(ExpenseCategory category) categoryLabel;

  @override
  Widget build(BuildContext context) {
    final totals = <ExpenseCategory, double>{};
    for (final entry in entries) {
      totals.update(
        entry.category,
        (value) => value + entry.amount,
        ifAbsent: () => entry.amount,
      );
    }

    final ranked = totals.entries.toList(growable: false)
      ..sort((left, right) => right.value.compareTo(left.value));

    return GlassPanel(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(28),
      blur: 24,
      opacity: 0.12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top categories this month',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'A quick ranking of where this month’s money has gone.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          if (ranked.isEmpty)
            const _EmptyHint(message: 'No expense data yet for this period.')
          else
            Column(
              children: ranked
                  .take(4)
                  .map((item) {
                    final share = total <= 0
                        ? 0
                        : (item.value / total).clamp(0, 1);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: item.key.color.withValues(alpha: 0.12),
                                  border: Border.all(
                                    color: item.key.color.withValues(
                                      alpha: 0.20,
                                    ),
                                  ),
                                ),
                                child: Center(
                                  child: HugeIcon(
                                    icon: item.key.icon,
                                    size: 14,
                                    color: item.key.color,
                                    strokeWidth: 1.8,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  categoryLabel(item.key),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                _rwfCompact(item.value),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: item.key.color,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              minHeight: 8,
                              value: share.toDouble(),
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.06,
                              ),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                item.key.color,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${(share * 100).toStringAsFixed(0)}% of current spend',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.56,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _ExpenseEntriesPanel extends StatelessWidget {
  const _ExpenseEntriesPanel({
    required this.currentPage,
    required this.entries,
    required this.totalItems,
    required this.totalPages,
    required this.loadError,
    required this.categoryLabel,
    required this.onRetry,
    required this.onEdit,
    required this.onDelete,
    required this.onNextPage,
    required this.onPreviousPage,
  });

  final int currentPage;
  final List<ExpenseEntry> entries;
  final int totalItems;
  final int totalPages;
  final String? loadError;
  final String Function(ExpenseCategory category) categoryLabel;
  final Future<void> Function() onRetry;
  final Future<void> Function(ExpenseEntry entry) onEdit;
  final Future<void> Function(ExpenseEntry entry) onDelete;
  final Future<void> Function() onNextPage;
  final Future<void> Function() onPreviousPage;

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
              const Expanded(
                child: Text(
                  'Expense entries',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '$totalItems rows',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (loadError != null)
            _ErrorState(message: loadError!, onRetry: onRetry)
          else if (entries.isEmpty)
            const _EmptyHint(message: 'No expenses match these filters yet.')
          else
            Column(
              children: [
                for (var i = 0; i < entries.length; i++)
                  _ExpenseEntryTile(
                    entry: entries[i],
                    isLast: i == entries.length - 1,
                    categoryLabel: categoryLabel,
                    onDelete: onDelete,
                    onEdit: onEdit,
                  ),
              ],
            ),
          if (loadError == null && entries.isNotEmpty && totalPages > 1) ...[
            const SizedBox(height: 16),
            _GradientDivider(color: AppColors.danger),
            const SizedBox(height: 16),
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppColors.danger.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Unable to load expenses',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 12,
              height: 1.55,
              color: AppColors.textSecondary.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => onRetry(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: AppColors.danger.withValues(alpha: 0.12),
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.22),
                ),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseEntryTile extends StatefulWidget {
  const _ExpenseEntryTile({
    required this.entry,
    required this.isLast,
    required this.categoryLabel,
    required this.onEdit,
    required this.onDelete,
  });

  final ExpenseEntry entry;
  final bool isLast;
  final String Function(ExpenseCategory category) categoryLabel;
  final Future<void> Function(ExpenseEntry entry) onEdit;
  final Future<void> Function(ExpenseEntry entry) onDelete;

  @override
  State<_ExpenseEntryTile> createState() => _ExpenseEntryTileState();
}

class _ExpenseEntryTileState extends State<_ExpenseEntryTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.entry.category.color;
    final creatorLabel = _resolveCreatorLabel(widget.entry);

    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.12),
                    border: Border.all(color: color.withValues(alpha: 0.18)),
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
                        widget.categoryLabel(widget.entry.category),
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
                      _rwfCompact(widget.entry.amount),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color,
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
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    width: double.infinity,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: [
                            _DetailItem(
                              label: 'Amount',
                              value: _rwf(widget.entry.amount),
                            ),
                            _DetailItem(
                              label: 'Date',
                              value: _formatLongDate(widget.entry.date),
                            ),
                          ],
                        ),
                        if (widget.entry.note != null &&
                            widget.entry.note!.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.white.withValues(alpha: 0.03),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                            child: Text(
                              widget.entry.note!.trim(),
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _ActionIcon(
                              icon: HugeIcons.strokeRoundedPencil,
                              color: const Color(0xFF7EB8FF),
                              tooltip: 'Edit',
                              onTap: () => widget.onEdit(widget.entry),
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
    );
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
            border: Border.all(color: widget.color.withValues(alpha: 0.20)),
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
              : AppColors.danger.withValues(alpha: 0.12),
          border: Border.all(
            color: isDisabled
                ? Colors.white.withValues(alpha: 0.08)
                : AppColors.danger.withValues(alpha: 0.20),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isDisabled
                ? AppColors.textSecondary.withValues(alpha: 0.36)
                : AppColors.danger,
          ),
        ),
      ),
    );
  }
}

class _ExpenseFormDialog extends StatefulWidget {
  const _ExpenseFormDialog({
    required this.categoryOptions,
    required this.onSubmit,
    this.entry,
    this.initialCategory,
    this.initialDate,
  });

  final ExpenseEntry? entry;
  final List<ExpenseCategoryOption> categoryOptions;
  final ExpenseCategory? initialCategory;
  final DateTime? initialDate;
  final Future<ExpenseEntry> Function({
    required String label,
    required double amount,
    required ExpenseCategory category,
    required DateTime date,
    String? note,
  })
  onSubmit;

  @override
  State<_ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<_ExpenseFormDialog>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _labelCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  late ExpenseCategory _category;
  late DateTime _date;
  late final AnimationController _animCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.entry?.label ?? '');
    _amountCtrl = TextEditingController(
      text: widget.entry?.amount.toStringAsFixed(0) ?? '',
    );
    _noteCtrl = TextEditingController(text: widget.entry?.note ?? '');
    _category =
        widget.entry?.category ??
        widget.initialCategory ??
        ExpenseCategory.foodDining;
    _date = widget.entry?.date ?? widget.initialDate ?? DateTime.now();

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
    _noteCtrl.dispose();
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
            primary: AppColors.danger,
            onPrimary: AppColors.background,
            surface: AppColors.surfaceElevated,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final result = await widget.onSubmit(
        label: _labelCtrl.text.trim(),
        amount: amount,
        category: _category,
        date: _date,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
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
        title: _isEditing
            ? 'Unable to update expense'
            : 'Unable to add expense',
        description: _readableError(error),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    final dateLabel = _formatLongDate(_date);

    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AppModalDialog(
          maxWidth: 470,
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
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.danger.withValues(alpha: 0.16),
                        ),
                        child: Center(
                          child: HugeIcon(
                            icon: _isEditing
                                ? HugeIcons.strokeRoundedPencil
                                : HugeIcons.strokeRoundedWallet02,
                            size: 18,
                            color: AppColors.danger,
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
                              _isEditing ? 'Edit expense' : 'Add expense',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              _isEditing
                                  ? 'Update the details below'
                                  : 'Fill in the details below',
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
                  const _GradientDivider(color: AppColors.danger),
                  const SizedBox(height: 24),
                  const _FieldLabel(label: 'Expense label'),
                  const SizedBox(height: 8),
                  _GlassField(
                    controller: _labelCtrl,
                    hint: 'e.g. Kigali Market groceries',
                    accent: AppColors.danger,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Please enter an expense label'
                        : null,
                  ),
                  const SizedBox(height: 18),
                  const _FieldLabel(label: 'Amount (RWF)'),
                  const SizedBox(height: 8),
                  _GlassField(
                    controller: _amountCtrl,
                    hint: 'e.g. 12500',
                    accent: AppColors.danger,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    prefixText: 'RWF ',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter an amount';
                      }

                      final parsed = double.tryParse(value.replaceAll(',', ''));
                      if (parsed == null || parsed <= 0) {
                        return 'Enter a valid amount';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  const _FieldLabel(label: 'Category'),
                  const SizedBox(height: 8),
                  _CategoryPicker(
                    options: widget.categoryOptions,
                    selected: _category,
                    onChanged: (category) =>
                        setState(() => _category = category),
                  ),
                  const SizedBox(height: 18),
                  const _FieldLabel(label: 'Date'),
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
                  const SizedBox(height: 18),
                  const _FieldLabel(label: 'Note'),
                  const SizedBox(height: 8),
                  _GlassField(
                    controller: _noteCtrl,
                    hint: 'Optional context for this expense',
                    accent: AppColors.danger,
                    maxLines: 4,
                    minLines: 3,
                  ),
                  const SizedBox(height: 28),
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
                          label: _isEditing ? 'Save changes' : 'Add expense',
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

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<ExpenseCategoryOption> options;
  final ExpenseCategory selected;
  final ValueChanged<ExpenseCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map((option) {
            final category = option.value;
            final isSelected = category == selected;
            final color = category.color;
            return GestureDetector(
              onTap: () => onChanged(category),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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
                      icon: category.icon,
                      size: 13,
                      color: isSelected ? color : AppColors.textSecondary,
                      strokeWidth: 1.8,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      option.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected ? color : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

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
                'Remove expense entry?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '"${widget.label}" will be permanently removed from your expense records.',
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
    required this.accent,
    this.keyboardType,
    this.inputFormatters,
    this.prefixText,
    this.validator,
    this.maxLines = 1,
    this.minLines,
  });

  final TextEditingController controller;
  final String hint;
  final Color accent;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? prefixText;
  final String? Function(String?)? validator;
  final int? maxLines;
  final int? minLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      minLines: minLines,
      maxLines: maxLines,
      style: const TextStyle(
        fontSize: 13,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        prefixText: prefixText,
        prefixStyle: TextStyle(
          fontSize: 13,
          color: accent,
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
          borderSide: BorderSide(color: accent.withValues(alpha: 0.5)),
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
    this.isDisabled = false,
    this.isLoading = false,
    this.isDanger = false,
  });

  final String label;
  final bool isPrimary;
  final Future<void> Function() onTap;
  final bool isDisabled;
  final bool isLoading;
  final bool isDanger;

  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.isDanger ? AppColors.danger : AppColors.danger;

    return GestureDetector(
      onTapDown: (_) {
        if (!widget.isDisabled && !widget.isLoading) {
          setState(() => _pressed = true);
        }
      },
      onTapUp: (_) async {
        if (widget.isDisabled || widget.isLoading) {
          return;
        }
        setState(() => _pressed = false);
        await widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.97 : 1.0,
        child: AppModalActionButton(
          label: widget.label,
          isPrimary: widget.isPrimary,
          isLoading: widget.isLoading,
          onPressed: widget.isDisabled || widget.isLoading
              ? null
              : () => widget.onTap(),
          primaryColor: primaryColor,
          primaryForegroundColor: AppColors.background,
          outlineForegroundColor: AppColors.textPrimary,
        ),
      ),
    );
  }
}

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
  void didUpdateWidget(_AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previous = oldWidget.value;
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
        final value = _previous + _anim.value * (widget.value - _previous);
        return Text(_rwf(value), style: widget.style);
      },
    );
  }
}

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
            icon: HugeIcons.strokeRoundedWallet02,
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

class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text(
          'Live expense sync · secured to your account session',
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
