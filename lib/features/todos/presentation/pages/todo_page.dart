import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/network/paginated_response.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../expenses/application/expense_service.dart';
import '../../../expenses/data/models/expense_entry.dart';
import '../../application/todo_service.dart';
import '../../data/models/todo_item.dart';
import '../../data/models/todo_list_query.dart';
import '../../data/models/todo_upload_image.dart';
import '../todo_utils.dart';
import '../widgets/todo_delete_dialog.dart';
import '../widgets/todo_expense_dialog.dart';
import '../widgets/todo_form_dialog.dart';
import '../widgets/todo_item_card.dart';

enum _TodoDoneFilter { all, done, notDone }

extension _TodoDoneFilterX on _TodoDoneFilter {
  String get label => switch (this) {
    _TodoDoneFilter.all => 'All',
    _TodoDoneFilter.done => 'Done',
    _TodoDoneFilter.notDone => 'Open',
  };
}

class TodoPage extends StatefulWidget {
  const TodoPage({
    super.key,
    required this.todoService,
    required this.expenseService,
    this.embedded = false,
  });

  final TodoService todoService;
  final ExpenseService expenseService;
  final bool embedded;

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage>
    with SingleTickerProviderStateMixin {
  static const int _pageSize = 12;

  late final AnimationController _entranceCtrl;
  late final TextEditingController _searchCtrl;
  List<TodoItem> _entries = const <TodoItem>[];
  List<TodoItem> _pageEntries = const <TodoItem>[];
  List<ExpenseCategoryOption> _expenseCategories =
      const <ExpenseCategoryOption>[];
  bool _isLoading = true;
  String? _loadError;
  String? _expenseCategoriesError;
  Timer? _searchDebounce;
  String? _doneBusyId;
  String? _recordExpenseBusyId;
  int _currentPage = 1;
  int _totalItems = 0;
  int _totalPages = 1;
  TodoPriority? _selectedPriority;
  TodoFrequency? _selectedFrequency;
  _TodoDoneFilter _selectedDone = _TodoDoneFilter.all;
  DateTime? _selectedDateFrom;
  DateTime? _selectedDateTo;
  String _searchInput = '';
  String? _appliedSearch;
  int _loadSequence = 0;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _searchCtrl = TextEditingController();
    _loadTodoDependencies();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  double get _plannedTotal =>
      _entries.fold(0, (sum, entry) => sum + entry.price);

  int get _doneCount => _entries.where((entry) => entry.done).length;

  int get _openCount => (_entries.length - _doneCount).clamp(0, 1000000);

  int get _topPriorityCount => _entries
      .where((entry) => entry.priority == TodoPriority.topPriority)
      .length;

  int get _withImagesCount =>
      _entries.where((entry) => entry.imageCount > 0).length;

  int get _recurringCount => _entries.where(isRecurringTodo).length;

  int get _completionShare =>
      _entries.isEmpty ? 0 : ((_doneCount / _entries.length) * 100).round();

  TodoItem? get _latestEntry => _entries.isEmpty ? null : _entries.first;

  bool get _hasExplicitDateFilter =>
      _selectedDateFrom != null || _selectedDateTo != null;

  bool get _hasActiveFilters =>
      _selectedPriority != null ||
      _selectedFrequency != null ||
      _selectedDone != _TodoDoneFilter.all ||
      _appliedSearch != null ||
      _hasExplicitDateFilter;

  Future<void> _loadTodoDependencies() async {
    await Future.wait<void>(<Future<void>>[
      _loadTodos(),
      _loadExpenseCategories(),
    ]);
  }

  Future<void> _loadExpenseCategories() async {
    try {
      final categories = await widget.expenseService.listExpenseCategories();
      if (!mounted) {
        return;
      }

      setState(() {
        _expenseCategories = categories;
        _expenseCategoriesError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _expenseCategories = const <ExpenseCategoryOption>[];
        _expenseCategoriesError = _readableError(error);
      });
    }
  }

  Future<void> _loadTodos() async {
    final loadId = ++_loadSequence;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final summaryQuery = _buildTodoQuery();
      final pageQuery = _buildTodoQuery(page: _currentPage, limit: _pageSize);
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        widget.todoService.listTodos(query: summaryQuery),
        widget.todoService.listTodosPage(query: pageQuery),
      ]);

      final entries = (results[0] as List<dynamic>).cast<TodoItem>();
      final pageResponse = results[1] as PaginatedResponse<TodoItem>;

      if (!mounted || loadId != _loadSequence) {
        return;
      }

      setState(() {
        _entries = _sortTodos(entries);
        _pageEntries = _sortTodos(pageResponse.items);
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
        _entries = const <TodoItem>[];
        _pageEntries = const <TodoItem>[];
        _isLoading = false;
        _loadError = message;
        _totalItems = 0;
        _totalPages = 1;
      });

      AppToast.error(
        context,
        title: 'Unable to load todos',
        description: message,
      );
    }
  }

  TodoListQuery _buildTodoQuery({int? page, int? limit}) {
    return TodoListQuery(
      frequency: _selectedFrequency,
      priority: _selectedPriority,
      done: switch (_selectedDone) {
        _TodoDoneFilter.all => null,
        _TodoDoneFilter.done => true,
        _TodoDoneFilter.notDone => false,
      },
      search: _appliedSearch,
      dateFrom: _selectedDateFrom == null
          ? null
          : formatDateOnly(_selectedDateFrom!),
      dateTo: _selectedDateTo == null ? null : formatDateOnly(_selectedDateTo!),
      page: page,
      limit: limit,
    );
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
            primary: AppColors.primary,
            onPrimary: AppColors.background,
            surface: AppColors.surfaceElevated,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );

    if (picked == null) {
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
    await _loadTodos();
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
    await _loadTodos();
  }

  Future<void> _clearAllFilters() async {
    _searchDebounce?.cancel();
    _searchCtrl.clear();
    setState(() {
      _selectedPriority = null;
      _selectedFrequency = null;
      _selectedDone = _TodoDoneFilter.all;
      _selectedDateFrom = null;
      _selectedDateTo = null;
      _searchInput = '';
      _appliedSearch = null;
      _currentPage = 1;
    });
    await _loadTodos();
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
      _loadTodos();
    });
  }

  Future<void> _goToPage(int page) async {
    if (page < 1 || page > _totalPages || page == _currentPage) {
      return;
    }

    setState(() => _currentPage = page);
    await _loadTodos();
  }

  Future<void> _openCreateDialog() async {
    final created = await showDialog<TodoItem>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.68),
      builder: (_) => TodoFormDialog(
        onSubmit:
            ({
              required String name,
              required double price,
              required TodoPriority priority,
              required bool done,
              required TodoFrequency frequency,
              required String startDate,
              required String endDate,
              required List<int> frequencyDays,
              required List<String> occurrenceDates,
              String? primaryImageId,
              required List<TodoUploadImage> newImages,
            }) {
              return widget.todoService.createTodo(
                name: name,
                price: price,
                priority: priority,
                done: done,
                frequency: frequency,
                startDate: startDate,
                endDate: endDate,
                frequencyDays: frequencyDays,
                occurrenceDates: occurrenceDates,
                images: newImages,
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
    await _loadTodos();
    if (!mounted) {
      return;
    }

    AppToast.success(
      context,
      title: 'Todo created',
      description: '${created.name} is now on your board.',
    );
  }

  Future<void> _openEditDialog(TodoItem entry) async {
    final updated = await showDialog<TodoItem>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.68),
      builder: (_) => TodoFormDialog(
        todo: entry,
        onSubmit:
            ({
              required String name,
              required double price,
              required TodoPriority priority,
              required bool done,
              required TodoFrequency frequency,
              required String startDate,
              required String endDate,
              required List<int> frequencyDays,
              required List<String> occurrenceDates,
              String? primaryImageId,
              required List<TodoUploadImage> newImages,
            }) {
              return widget.todoService.updateTodo(
                todoId: entry.id,
                name: name,
                price: price,
                priority: priority,
                done: done,
                frequency: frequency,
                startDate: startDate,
                endDate: endDate,
                frequencyDays: frequencyDays,
                occurrenceDates: occurrenceDates,
                primaryImageId: primaryImageId,
                images: newImages,
              );
            },
      ),
    );

    if (updated == null || !mounted) {
      return;
    }

    await _loadTodos();
    if (!mounted) {
      return;
    }

    AppToast.success(
      context,
      title: 'Todo updated',
      description: '${updated.name} was updated successfully.',
    );
  }

  Future<void> _confirmDelete(TodoItem entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.68),
      builder: (_) => TodoDeleteDialog(
        todoName: entry.name,
        imageCount: entry.images.length,
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await widget.todoService.deleteTodo(entry.id);
      if (!mounted) {
        return;
      }

      if (_pageEntries.length == 1 && _currentPage > 1) {
        setState(() => _currentPage -= 1);
      }
      await _loadTodos();
      if (!mounted) {
        return;
      }

      AppToast.success(
        context,
        title: 'Todo deleted',
        description: '${entry.name} was removed from your board.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Unable to delete todo',
        description: _readableError(error),
      );
    }
  }

  Future<void> _toggleDone(TodoItem entry) async {
    setState(() => _doneBusyId = entry.id);

    try {
      await widget.todoService.updateTodo(todoId: entry.id, done: !entry.done);
      if (!mounted) {
        return;
      }

      await _loadTodos();
      if (!mounted) {
        return;
      }

      AppToast.success(
        context,
        title: entry.done ? 'Todo reopened' : 'Todo marked done',
        description: '${entry.name} was updated successfully.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Unable to update todo state',
        description: _readableError(error),
      );
    } finally {
      if (mounted) {
        setState(() => _doneBusyId = null);
      }
    }
  }

  Future<void> _openExpenseDialog(TodoItem entry) async {
    if (_expenseCategories.isEmpty) {
      AppToast.info(
        context,
        title: 'Expense categories unavailable',
        description:
            _expenseCategoriesError ??
            'Refresh and try again when categories are available.',
      );
      return;
    }

    if (!canRecordTodoExpense(entry)) {
      AppToast.info(
        context,
        title: 'No expense can be recorded',
        description: isRecurringTodo(entry)
            ? 'This recurring todo has no remaining budget or occurrence left.'
            : 'This todo is already complete.',
      );
      return;
    }

    final recorded = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.68),
      builder: (_) => TodoExpenseDialog(
        entry: entry,
        categories: _expenseCategories,
        onSubmit:
            ({
              required double amount,
              required ExpenseCategory category,
              required String date,
            }) async {
              setState(() => _recordExpenseBusyId = entry.id);
              var expenseCreated = false;

              try {
                await widget.expenseService.createExpense(
                  label: entry.name.trim(),
                  amount: amount,
                  category: category,
                  date: parseDateOnly(date),
                );
                expenseCreated = true;

                if (isRecurringTodo(entry)) {
                  await widget.todoService.updateTodo(
                    todoId: entry.id,
                    deductAmount: amount,
                    recordedOccurrenceDate: date,
                  );
                } else {
                  await widget.todoService.updateTodo(
                    todoId: entry.id,
                    done: true,
                  );
                }
              } catch (error) {
                if (expenseCreated) {
                  await _loadTodos();
                }
                rethrow;
              } finally {
                if (mounted) {
                  setState(() => _recordExpenseBusyId = null);
                }
              }
            },
      ),
    );

    if (!mounted || recorded != true) {
      return;
    }

    await _loadTodos();
    if (!mounted) {
      return;
    }

    AppToast.success(
      context,
      title: 'Expense recorded',
      description: isRecurringTodo(entry)
          ? 'Recurring budget was updated successfully.'
          : 'Expense recorded and todo marked as done.',
    );
  }

  List<TodoItem> _sortTodos(List<TodoItem> entries) {
    final sorted = List<TodoItem>.from(entries)
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return List<TodoItem>.unmodifiable(sorted);
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
      return _TodoPageLoading(
        fade: _fade,
        slide: _slide,
        embedded: widget.embedded,
      );
    }

    final horizontalPadding = widget.embedded ? 0.0 : 18.0;

    final content = RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceElevated,
      onRefresh: _loadTodoDependencies,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          20,
          horizontalPadding,
          28,
        ),
        children: [
          _Staggered(
            fade: _fade(0.0, 0.42),
            slide: _slide(0.0, 0.42),
            child: _TodoHeader(
              plannedTotal: _plannedTotal,
              totalCount: _entries.length,
              onAdd: _openCreateDialog,
              showBackButton: !widget.embedded,
            ),
          ),
          const SizedBox(height: 14),
          _Staggered(
            fade: _fade(0.12, 0.56),
            slide: _slide(0.12, 0.56),
            child: _TodoHero(
              plannedTotal: _plannedTotal,
              openCount: _openCount,
              recurringCount: _recurringCount,
              topPriorityCount: _topPriorityCount,
              totalCount: _entries.length,
            ),
          ),
          const SizedBox(height: 14),
          _Staggered(
            fade: _fade(0.24, 0.68),
            slide: _slide(0.24, 0.68),
            child: _TodoStatsRow(
              completionShare: _completionShare,
              doneCount: _doneCount,
              latestEntry: _latestEntry,
              withImagesCount: _withImagesCount,
            ),
          ),
          const SizedBox(height: 14),
          _Staggered(
            fade: _fade(0.32, 0.76),
            slide: _slide(0.32, 0.76),
            child: _TodoFiltersPanel(
              dateFrom: _selectedDateFrom,
              dateTo: _selectedDateTo,
              done: _selectedDone,
              frequency: _selectedFrequency,
              hasActiveFilters: _hasActiveFilters,
              priority: _selectedPriority,
              searchController: _searchCtrl,
              searchInput: _searchInput,
              onClearAll: _clearAllFilters,
              onClearDate: _clearDateFilter,
              onDatePicked: _pickFilterDate,
              onDoneChanged: (value) async {
                setState(() {
                  _selectedDone = value;
                  _currentPage = 1;
                });
                await _loadTodos();
              },
              onFrequencyChanged: (value) async {
                setState(() {
                  _selectedFrequency = value;
                  _currentPage = 1;
                });
                await _loadTodos();
              },
              onPriorityChanged: (value) async {
                setState(() {
                  _selectedPriority = value;
                  _currentPage = 1;
                });
                await _loadTodos();
              },
              onSearchChanged: _onSearchChanged,
            ),
          ),
          const SizedBox(height: 14),
          _Staggered(
            fade: _fade(0.44, 0.92),
            slide: _slide(0.44, 0.92),
            child: _TodoEntriesPanel(
              currentPage: _currentPage,
              entries: _pageEntries,
              totalItems: _totalItems,
              totalPages: _totalPages,
              loadError: _loadError,
              doneBusyId: _doneBusyId,
              recordExpenseBusyId: _recordExpenseBusyId,
              onDelete: _confirmDelete,
              onEdit: _openEditDialog,
              onNextPage: () => _goToPage(_currentPage + 1),
              onPreviousPage: () => _goToPage(_currentPage - 1),
              onRecordExpense: _openExpenseDialog,
              onRetry: _loadTodos,
              onToggleDone: _toggleDone,
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: content),
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

class _TodoPageLoading extends StatelessWidget {
  const _TodoPageLoading({
    required this.fade,
    required this.slide,
    required this.embedded,
  });

  final Animation<double> Function(double, double) fade;
  final Animation<Offset> Function(double, double) slide;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = embedded ? 0.0 : 18.0;

    final content = SkeletonLoader(
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          20,
          horizontalPadding,
          28,
        ),
        children: [
          _Staggered(
            fade: fade(0.0, 0.42),
            slide: slide(0.0, 0.42),
            child: _LoadingHeaderPanel(showBackButton: !embedded),
          ),
          const SizedBox(height: 14),
          _Staggered(
            fade: fade(0.14, 0.58),
            slide: slide(0.14, 0.58),
            child: const _LoadingHeroPanel(),
          ),
          const SizedBox(height: 14),
          _Staggered(
            fade: fade(0.28, 0.72),
            slide: slide(0.28, 0.72),
            child: const _LoadingStatsRow(),
          ),
          const SizedBox(height: 14),
          _Staggered(
            fade: fade(0.38, 0.82),
            slide: slide(0.38, 0.82),
            child: const _LoadingPanel(
              padding: EdgeInsets.all(20),
              child: _LoadingFiltersPanel(),
            ),
          ),
          const SizedBox(height: 14),
          _Staggered(
            fade: fade(0.50, 0.92),
            slide: slide(0.50, 0.92),
            child: const _LoadingPanel(
              padding: EdgeInsets.all(22),
              child: _LoadingEntriesPanel(),
            ),
          ),
        ],
      ),
    );

    if (embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: content),
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
      borderRadius: BorderRadius.circular(26),
      blur: 22,
      opacity: 0.12,
      child: child,
    );
  }
}

class _LoadingHeaderPanel extends StatelessWidget {
  const _LoadingHeaderPanel({required this.showBackButton});

  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return _LoadingPanel(
      padding: const EdgeInsets.all(24),
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
                        if (showBackButton) ...[
                          const SkeletonBox(width: 88, height: 34, radius: 999),
                          const SizedBox(width: 10),
                        ],
                        const SkeletonBox(width: 94, height: 30, radius: 999),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const SkeletonBox(width: 176, height: 28, radius: 18),
                    const SizedBox(height: 8),
                    const SkeletonBox(height: 12, radius: 12),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const SkeletonBox(width: 46, height: 46, radius: 999),
            ],
          ),
          const SizedBox(height: 22),
          const SkeletonBox(height: 1, radius: 999),
          const SizedBox(height: 18),
          const Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 124, height: 11, radius: 10),
                    SizedBox(height: 6),
                    SkeletonBox(width: 188, height: 34, radius: 18),
                  ],
                ),
              ),
              SizedBox(width: 12),
              SkeletonBox(width: 90, height: 28, radius: 10),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingHeroPanel extends StatelessWidget {
  const _LoadingHeroPanel();

  @override
  Widget build(BuildContext context) {
    return const _LoadingPanel(
      padding: EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SkeletonBox(width: 84, height: 28, radius: 999),
              SkeletonBox(width: 108, height: 28, radius: 999),
              SkeletonBox(width: 118, height: 28, radius: 999),
            ],
          ),
          SizedBox(height: 18),
          SkeletonBox(width: 168, height: 34, radius: 18),
          SizedBox(height: 8),
          SkeletonBox(width: 220, height: 12, radius: 12),
        ],
      ),
    );
  }
}

class _LoadingStatsRow extends StatelessWidget {
  const _LoadingStatsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: _LoadingStatCard()),
        SizedBox(width: 10),
        Expanded(child: _LoadingStatCard()),
        SizedBox(width: 10),
        Expanded(child: _LoadingStatCard()),
      ],
    );
  }
}

class _LoadingStatCard extends StatelessWidget {
  const _LoadingStatCard();

  @override
  Widget build(BuildContext context) {
    return const _LoadingPanel(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 64, height: 11, radius: 10),
          SizedBox(height: 8),
          SkeletonBox(width: 86, height: 18, radius: 12),
          SizedBox(height: 6),
          SkeletonBox(height: 11, radius: 10),
          SizedBox(height: 6),
          SkeletonBox(width: 72, height: 11, radius: 10),
        ],
      ),
    );
  }
}

class _LoadingFiltersPanel extends StatelessWidget {
  const _LoadingFiltersPanel();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SkeletonBox(width: 70, height: 14, radius: 12),
            Spacer(),
            SkeletonBox(width: 62, height: 12, radius: 12),
          ],
        ),
        SizedBox(height: 16),
        SkeletonBox(height: 46, radius: 16),
        SizedBox(height: 10),
        SkeletonBox(width: 244, height: 10, radius: 12),
        SizedBox(height: 16),
        SkeletonBox(width: 60, height: 12, radius: 12),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SkeletonBox(width: 56, height: 32, radius: 999),
            SkeletonBox(width: 88, height: 32, radius: 999),
            SkeletonBox(width: 96, height: 32, radius: 999),
          ],
        ),
        SizedBox(height: 16),
        SkeletonBox(width: 74, height: 12, radius: 12),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SkeletonBox(width: 56, height: 32, radius: 999),
            SkeletonBox(width: 66, height: 32, radius: 999),
            SkeletonBox(width: 78, height: 32, radius: 999),
            SkeletonBox(width: 72, height: 32, radius: 999),
          ],
        ),
        SizedBox(height: 16),
        SkeletonBox(width: 60, height: 12, radius: 12),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SkeletonBox(width: 56, height: 32, radius: 999),
            SkeletonBox(width: 62, height: 32, radius: 999),
            SkeletonBox(width: 70, height: 32, radius: 999),
          ],
        ),
        SizedBox(height: 16),
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

class _LoadingEntriesPanel extends StatelessWidget {
  const _LoadingEntriesPanel();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(
          children: [
            SkeletonBox(width: 126, height: 16, radius: 12),
            Spacer(),
            SkeletonBox(width: 76, height: 12, radius: 12),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        SkeletonBox(width: 68, height: 68, radius: 18),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 136, height: 14, radius: 12),
              SizedBox(height: 8),
              SkeletonBox(width: 88, height: 11, radius: 10),
              SizedBox(height: 10),
              SkeletonBox(width: 192, height: 10, radius: 10),
            ],
          ),
        ),
        SizedBox(width: 12),
        SkeletonBox(width: 56, height: 24, radius: 10),
      ],
    );
  }
}

class _TodoHeader extends StatefulWidget {
  const _TodoHeader({
    required this.plannedTotal,
    required this.totalCount,
    required this.onAdd,
    required this.showBackButton,
  });

  final double plannedTotal;
  final int totalCount;
  final Future<void> Function() onAdd;
  final bool showBackButton;

  @override
  State<_TodoHeader> createState() => _TodoHeaderState();
}

class _TodoHeaderState extends State<_TodoHeader>
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
                  AppColors.primary.withValues(alpha: 0.15),
                  Colors.white.withValues(alpha: 0.07),
                  AppColors.primary.withValues(alpha: 0.04),
                ],
                stops: [0.0, _shimmer.value, 1.0],
              ),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.30),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.10),
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
                              if (widget.showBackButton) ...[
                                GestureDetector(
                                  onTap: () => Navigator.of(context).pop(),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 11,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      color: Colors.white.withValues(
                                        alpha: 0.05,
                                      ),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.12,
                                        ),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        HugeIcon(
                                          icon: HugeIcons
                                              .strokeRoundedArrowLeft01,
                                          size: 14,
                                          color: AppColors.textPrimary,
                                          strokeWidth: 1.8,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Back',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                              ],
                              GlassBadge(
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    HugeIcon(
                                      icon: HugeIcons.strokeRoundedTaskDaily01,
                                      size: 15,
                                      color: AppColors.primary,
                                      strokeWidth: 1.8,
                                    ),
                                    SizedBox(width: 7),
                                    Text(
                                      'Todo',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Todo',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontSize: isCompact ? 26 : 30,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Recurring schedules, exact occurrence dates, and expense recording now match the web flow.',
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
                    _AddTodoButton(onTap: widget.onAdd),
                  ],
                ),
                const SizedBox(height: 22),
                const _GradientDivider(color: AppColors.primary),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total planned',
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
                            value: widget.plannedTotal,
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
                        color: AppColors.primary.withValues(alpha: 0.12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const HugeIcon(
                            icon: HugeIcons.strokeRoundedTaskDone02,
                            size: 12,
                            color: AppColors.primary,
                            strokeWidth: 2,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${widget.totalCount} items',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
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

class _AddTodoButton extends StatefulWidget {
  const _AddTodoButton({required this.onTap});

  final Future<void> Function() onTap;

  @override
  State<_AddTodoButton> createState() => _AddTodoButtonState();
}

class _AddTodoButtonState extends State<_AddTodoButton> {
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
            color: AppColors.primary.withValues(alpha: 0.18),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedAdd01,
              size: 20,
              color: AppColors.primary,
              strokeWidth: 2,
            ),
          ),
        ),
      ),
    );
  }
}

class _TodoHero extends StatelessWidget {
  const _TodoHero({
    required this.plannedTotal,
    required this.openCount,
    required this.recurringCount,
    required this.topPriorityCount,
    required this.totalCount,
  });

  final double plannedTotal;
  final int openCount;
  final int recurringCount;
  final int topPriorityCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(22),
      borderRadius: BorderRadius.circular(30),
      blur: 22,
      opacity: 0.12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroPill(label: 'Open', value: '$openCount'),
              _HeroPill(label: 'Recurring', value: '$recurringCount'),
              _HeroPill(label: 'Top priority', value: '$topPriorityCount'),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            _rwfCompact(plannedTotal),
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$totalCount wishlist items across your current filters.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(
        '$label · $value',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _TodoStatsRow extends StatelessWidget {
  const _TodoStatsRow({
    required this.completionShare,
    required this.doneCount,
    required this.latestEntry,
    required this.withImagesCount,
  });

  final int completionShare;
  final int doneCount;
  final TodoItem? latestEntry;
  final int withImagesCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Completion',
            value: '$completionShare%',
            detail: '$doneCount items done',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Latest',
            value: latestEntry == null
                ? 'No entries'
                : formatTodoDate(latestEntry!.createdAt),
            detail: latestEntry?.name ?? 'Add your first wishlist item',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Visuals',
            value: '$withImagesCount',
            detail: 'items with images',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(22),
      blur: 20,
      opacity: 0.1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: AppColors.textSecondary.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodoFiltersPanel extends StatelessWidget {
  const _TodoFiltersPanel({
    required this.dateFrom,
    required this.dateTo,
    required this.done,
    required this.frequency,
    required this.hasActiveFilters,
    required this.priority,
    required this.searchController,
    required this.searchInput,
    required this.onClearAll,
    required this.onClearDate,
    required this.onDatePicked,
    required this.onDoneChanged,
    required this.onFrequencyChanged,
    required this.onPriorityChanged,
    required this.onSearchChanged,
  });

  final DateTime? dateFrom;
  final DateTime? dateTo;
  final _TodoDoneFilter done;
  final TodoFrequency? frequency;
  final bool hasActiveFilters;
  final TodoPriority? priority;
  final TextEditingController searchController;
  final String searchInput;
  final Future<void> Function() onClearAll;
  final Future<void> Function({required bool isFrom}) onClearDate;
  final Future<void> Function({required bool isFrom}) onDatePicked;
  final Future<void> Function(_TodoDoneFilter value) onDoneChanged;
  final Future<void> Function(TodoFrequency? value) onFrequencyChanged;
  final Future<void> Function(TodoPriority? value) onPriorityChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(28),
      blur: 22,
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
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (hasActiveFilters)
                TextButton(
                  onPressed: () => onClearAll(),
                  child: const Text('Clear all'),
                ),
            ],
          ),
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search todo name',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              suffixIcon: searchInput.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged('');
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            searchInput.isNotEmpty && searchInput.trim().length < 3
                ? 'Type at least 3 characters to apply search.'
                : 'Server filters include frequency, priority, done state, chosen dates, and pagination.',
            style: TextStyle(
              fontSize: 11,
              height: 1.45,
              color: AppColors.textSecondary.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Priority',
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
              _FilterChip(
                label: 'All',
                selected: priority == null,
                onTap: () => onPriorityChanged(null),
              ),
              ...TodoPriority.values.map(
                (value) => _FilterChip(
                  label: value.label,
                  selected: priority == value,
                  onTap: () => onPriorityChanged(value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Frequency',
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
              _FilterChip(
                label: 'All',
                selected: frequency == null,
                onTap: () => onFrequencyChanged(null),
              ),
              ...TodoFrequency.values.map(
                (value) => _FilterChip(
                  label: value.label,
                  selected: frequency == value,
                  onTap: () => onFrequencyChanged(value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Status',
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
            children: _TodoDoneFilter.values
                .map(
                  (value) => _FilterChip(
                    label: value.label,
                    selected: done == value,
                    onTap: () => onDoneChanged(value),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DateFilterTile(
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
                child: _DateFilterTile(
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected
              ? AppColors.primary.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.24)
                : Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _DateFilterTile extends StatelessWidget {
  const _DateFilterTile({
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
                    value == null ? 'Pick date' : formatTodoDate(value!),
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
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TodoEntriesPanel extends StatelessWidget {
  const _TodoEntriesPanel({
    required this.currentPage,
    required this.entries,
    required this.totalItems,
    required this.totalPages,
    required this.loadError,
    required this.doneBusyId,
    required this.recordExpenseBusyId,
    required this.onDelete,
    required this.onEdit,
    required this.onNextPage,
    required this.onPreviousPage,
    required this.onRecordExpense,
    required this.onRetry,
    required this.onToggleDone,
  });

  final int currentPage;
  final List<TodoItem> entries;
  final int totalItems;
  final int totalPages;
  final String? loadError;
  final String? doneBusyId;
  final String? recordExpenseBusyId;
  final Future<void> Function(TodoItem entry) onDelete;
  final Future<void> Function(TodoItem entry) onEdit;
  final Future<void> Function() onNextPage;
  final Future<void> Function() onPreviousPage;
  final Future<void> Function(TodoItem entry) onRecordExpense;
  final Future<void> Function() onRetry;
  final Future<void> Function(TodoItem entry) onToggleDone;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(28),
      blur: 22,
      opacity: 0.12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Todo entries',
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
                  color: AppColors.textSecondary.withValues(alpha: 0.68),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (loadError != null)
            _ErrorPanel(message: loadError!, onRetry: onRetry)
          else if (entries.isEmpty)
            const _EmptyPanel(message: 'No todo items match these filters yet.')
          else
            Column(
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  TodoItemCard(
                    todo: entries[i],
                    busyDone: doneBusyId == entries[i].id,
                    busyRecordExpense: recordExpenseBusyId == entries[i].id,
                    onDelete: () => onDelete(entries[i]),
                    onEdit: () => onEdit(entries[i]),
                    onRecordExpense: () => onRecordExpense(entries[i]),
                    onToggleDone: () => onToggleDone(entries[i]),
                  ),
                  if (i != entries.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
          if (loadError == null && entries.isNotEmpty && totalPages > 1) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                _PagerButton(
                  label: 'Previous',
                  disabled: currentPage <= 1,
                  onTap: onPreviousPage,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Page $currentPage of $totalPages · $totalItems rows',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary.withValues(alpha: 0.68),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _PagerButton(
                  label: 'Next',
                  disabled: currentPage >= totalPages,
                  onTap: onNextPage,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

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
            'Unable to load todos',
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
              color: AppColors.textSecondary.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 14),
          TextButton(onPressed: () => onRetry(), child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Column(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedTaskDaily01,
            size: 34,
            color: AppColors.textSecondary.withValues(alpha: 0.3),
            strokeWidth: 1.6,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary.withValues(alpha: 0.58),
            ),
          ),
        ],
      ),
    );
  }
}

class _PagerButton extends StatelessWidget {
  const _PagerButton({
    required this.label,
    required this.disabled,
    required this.onTap,
  });

  final String label;
  final bool disabled;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : () => onTap(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: disabled
              ? Colors.white.withValues(alpha: 0.04)
              : AppColors.primary.withValues(alpha: 0.14),
          border: Border.all(
            color: disabled
                ? Colors.white.withValues(alpha: 0.10)
                : AppColors.primary.withValues(alpha: 0.22),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: disabled ? AppColors.textSecondary : AppColors.primary,
          ),
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

String _rwf(double amount) {
  final formatted = amount
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  return 'RWF $formatted';
}

String _rwfCompact(double amount) {
  final absolute = amount.abs();
  if (absolute >= 1000000) {
    return 'RWF ${(amount / 1000000).toStringAsFixed(1)}M';
  }
  if (absolute >= 1000) {
    return 'RWF ${(amount / 1000).toStringAsFixed(0)}k';
  }

  final formatted = amount
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  return 'RWF $formatted';
}
