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
import '../../../income/application/income_service.dart';
import '../../../income/data/models/income_entry.dart';
import '../../../income/data/models/income_list_query.dart';
import '../../../savings/application/saving_service.dart';
import '../../../savings/data/models/saving_entry.dart';
import '../../../savings/data/models/saving_list_query.dart';
import '../../../savings/data/services/savings_api_service.dart';

const Color _savingAccent = Color(0xFF7DD3FC);
const Color _savingSecondary = Color(0xFF93C5FD);

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
    return 'RWF ${(amount / 1000).toStringAsFixed(1)}k';
  }
  return _rwf(amount);
}

String _formatLongDate(DateTime value) {
  return '${_monthShort(value.month)} ${value.day}, ${value.year}';
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

String? _resolveCreatorLabel(SavingEntry entry) {
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

class SavingPage extends StatefulWidget {
  const SavingPage({
    super.key,
    required this.savingService,
    required this.incomeService,
  });

  final SavingService savingService;
  final IncomeService incomeService;

  @override
  State<SavingPage> createState() => _SavingPageState();
}

class _SavingPageState extends State<SavingPage>
    with SingleTickerProviderStateMixin {
  static const int _pageSize = 12;

  late final AnimationController _entranceCtrl;
  late final TextEditingController _searchCtrl;
  List<SavingEntry> _entries = const [];
  List<SavingEntry> _pageEntries = const [];
  bool _isLoading = true;
  String? _loadError;
  Timer? _searchDebounce;
  bool _isSaving = false;
  bool _isDepositing = false;
  bool _isWithdrawing = false;
  bool _isLoadingHistory = false;
  bool _isLoadingDepositSources = false;
  int _currentPage = 1;
  int _totalItems = 0;
  int _totalPages = 1;
  late int _selectedMonth;
  late int _selectedYear;
  DateTime? _selectedDateFrom;
  DateTime? _selectedDateTo;
  String _searchInput = '';
  String? _appliedSearch;
  int _loadSequence = 0;
  _SavingFormDialogStateData? _formDialog;
  SavingEntry? _depositDialogEntry;
  SavingEntry? _withdrawalDialogEntry;
  SavingEntry? _historyDialogEntry;
  SavingEntry? _deleteTarget;
  late _SavingFormValues _form;
  late _SavingDepositFormValues _depositForm;
  late _SavingWithdrawalFormValues _withdrawalForm;
  List<IncomeEntry> _depositIncomeOptions = const [];
  List<SavingTransactionEntry> _historyTransactions = const [];
  String? _historyError;

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
    _form = _createEmptySavingForm();
    _depositForm = _createEmptySavingDepositForm();
    _withdrawalForm = _createEmptySavingWithdrawalForm();
    _loadSavings();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  double get _totalBalance =>
      _entries.fold(0, (sum, entry) => sum + entry.currentBalanceRwf);

  double get _totalDeposited =>
      _entries.fold(0, (sum, entry) => sum + entry.totalDepositedRwf);

  double get _totalWithdrawn =>
      _entries.fold(0, (sum, entry) => sum + entry.totalWithdrawnRwf);

  int get _activeShare => _totalDeposited > 0
      ? ((_totalBalance / _totalDeposited) * 100).round()
      : 0;

  SavingEntry? get _largestSaving {
    if (_entries.isEmpty) {
      return null;
    }
    final sorted = _entries.toList(growable: false)
      ..sort(
        (left, right) =>
            right.currentBalanceRwf.compareTo(left.currentBalanceRwf),
      );
    return sorted.first;
  }

  SavingEntry? get _latestEntry => _entries.isEmpty ? null : _entries.first;

  bool get _hasExplicitDateFilter =>
      _selectedDateFrom != null || _selectedDateTo != null;

  bool get _hasActiveFilters {
    final now = DateTime.now();

    return _selectedMonth != now.month ||
        _selectedYear != now.year ||
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

  Future<void> _loadSavings() async {
    final loadId = ++_loadSequence;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final summaryQuery = _buildSavingQuery();
      final pageQuery = _buildSavingQuery(page: _currentPage, limit: _pageSize);
      final results = await Future.wait<dynamic>([
        widget.savingService.listSavings(query: summaryQuery),
        widget.savingService.listSavingsPage(query: pageQuery),
      ]);

      final entries = (results[0] as List<dynamic>).cast<SavingEntry>();
      final pageResponse = results[1] as PaginatedResponse<SavingEntry>;

      if (!mounted || loadId != _loadSequence) {
        return;
      }

      setState(() {
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
        title: 'Unable to load savings',
        description: message,
      );
    }
  }

  List<SavingEntry> _sortedEntries(List<SavingEntry> entries) {
    final sorted = List<SavingEntry>.from(entries);
    sorted.sort((left, right) {
      final byDate = right.date.compareTo(left.date);
      if (byDate != 0) {
        return byDate;
      }
      return right.createdAt.compareTo(left.createdAt);
    });
    return List<SavingEntry>.unmodifiable(sorted);
  }

  SavingListQuery _buildSavingQuery({int? page, int? limit}) {
    return SavingListQuery(
      month: _hasExplicitDateFilter ? null : _selectedMonth,
      year: _hasExplicitDateFilter ? null : _selectedYear,
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
      _loadSavings();
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
            primary: _savingAccent,
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
    await _loadSavings();
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
    await _loadSavings();
  }

  Future<void> _clearAllFilters() async {
    final now = DateTime.now();
    _searchDebounce?.cancel();
    _searchCtrl.clear();

    setState(() {
      _selectedMonth = now.month;
      _selectedYear = now.year;
      _selectedDateFrom = null;
      _selectedDateTo = null;
      _searchInput = '';
      _appliedSearch = null;
      _currentPage = 1;
    });
    await _loadSavings();
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
    await _loadSavings();
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
    await _loadSavings();
  }

  Future<void> _goToPage(int page) async {
    if (page < 1 || page > _totalPages || page == _currentPage) {
      return;
    }

    setState(() => _currentPage = page);
    await _loadSavings();
  }

  void _openAddDialog() {
    setState(() {
      _form = _createEmptySavingForm();
      _formDialog = const _SavingFormDialogStateData.create();
    });
  }

  void _openEditDialog(SavingEntry entry) {
    setState(() {
      _form = _createSavingFormFromEntry(entry);
      _formDialog = _SavingFormDialogStateData.edit(entry);
    });
  }

  void _closeFormDialog() {
    setState(() {
      _formDialog = null;
      _form = _createEmptySavingForm();
    });
  }

  Future<void> _openDepositDialog(SavingEntry entry) async {
    setState(() {
      _depositDialogEntry = entry;
      _depositForm = _createSavingDepositFormFromEntry(entry);
      _depositIncomeOptions = const [];
      _isLoadingDepositSources = true;
    });

    try {
      final incomes = await widget.incomeService.listIncome(
        query: const IncomeListQuery(received: true),
      );

      if (!mounted || _depositDialogEntry?.id != entry.id) {
        return;
      }

      setState(() {
        _depositIncomeOptions = List<IncomeEntry>.unmodifiable(incomes);
        _isLoadingDepositSources = false;
        if (incomes.isNotEmpty && _depositForm.sources.first.incomeId == null) {
          _depositForm = _depositForm.copyWith(
            sources: [
              _depositForm.sources.first.copyWith(incomeId: incomes.first.id),
            ],
          );
        }
      });
    } catch (error) {
      if (!mounted || _depositDialogEntry?.id != entry.id) {
        return;
      }

      setState(() => _isLoadingDepositSources = false);
      AppToast.error(
        context,
        title: 'Unable to load income sources',
        description: _readableError(error),
      );
    }
  }

  void _closeDepositDialog() {
    setState(() {
      _depositDialogEntry = null;
      _depositForm = _createEmptySavingDepositForm();
      _depositIncomeOptions = const [];
      _isLoadingDepositSources = false;
    });
  }

  void _openWithdrawalDialog(SavingEntry entry) {
    setState(() {
      _withdrawalDialogEntry = entry;
      _withdrawalForm = _createSavingWithdrawalFormFromEntry(entry);
    });
  }

  void _closeWithdrawalDialog() {
    setState(() {
      _withdrawalDialogEntry = null;
      _withdrawalForm = _createEmptySavingWithdrawalForm();
    });
  }

  void _updateForm(_SavingFormValues next) {
    setState(() => _form = next);
  }

  void _updateDepositForm(_SavingDepositFormValues next) {
    setState(() => _depositForm = next);
  }

  void _updateWithdrawalForm(_SavingWithdrawalFormValues next) {
    setState(() => _withdrawalForm = next);
  }

  Future<void> _submitSaving() async {
    if (_form.label.trim().isEmpty) {
      AppToast.error(
        context,
        title: 'Missing label',
        description: 'Enter a label for this saving entry.',
      );
      return;
    }

    final parsedDate = DateTime.tryParse(_form.date);
    if (parsedDate == null) {
      AppToast.error(
        context,
        title: 'Invalid date',
        description: 'Pick a valid saving date.',
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (_formDialog?.mode == _SavingFormMode.edit &&
          _formDialog?.entry != null) {
        await widget.savingService.updateSaving(
          savingId: _formDialog!.entry!.id,
          label: _form.label.trim(),
          date: parsedDate,
          note: _form.note.trim(),
        );
      } else {
        await widget.savingService.createSaving(
          label: _form.label.trim(),
          amount: 0,
          date: parsedDate,
          note: _form.note.trim(),
        );
      }

      if (!mounted) {
        return;
      }

      _closeFormDialog();
      if (_currentPage != 1 && _formDialog?.mode == _SavingFormMode.create) {
        setState(() => _currentPage = 1);
      }
      await _loadSavings();
      if (!mounted) {
        return;
      }

      AppToast.success(
        context,
        title: _formDialog?.mode == _SavingFormMode.edit
            ? 'Saving updated'
            : 'Saving bucket added',
        description: _formDialog?.mode == _SavingFormMode.edit
            ? 'Your saving bucket was updated successfully.'
            : 'You can add money to this bucket from received income.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: _formDialog?.mode == _SavingFormMode.edit
            ? 'Unable to update saving'
            : 'Unable to add saving bucket',
        description: _readableError(error),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _confirmDelete() async {
    final target = _deleteTarget;
    if (target == null) {
      return;
    }

    try {
      await widget.savingService.deleteSaving(target.id);

      if (!mounted) {
        return;
      }

      if (_pageEntries.length == 1 && _currentPage > 1) {
        setState(() => _currentPage -= 1);
      }
      setState(() => _deleteTarget = null);
      await _loadSavings();
      if (!mounted) {
        return;
      }

      AppToast.success(
        context,
        title: 'Saving deleted',
        description: '${target.label} was removed successfully.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Unable to delete saving',
        description: _readableError(error),
      );
    }
  }

  Future<void> _submitDeposit() async {
    final entry = _depositDialogEntry;
    if (entry == null) {
      return;
    }

    final amount = double.tryParse(_depositForm.amount.trim());
    if (amount == null || amount <= 0) {
      AppToast.error(
        context,
        title: 'Invalid amount',
        description: 'Enter the deposit amount in RWF.',
      );
      return;
    }

    final parsedDate = DateTime.tryParse(_depositForm.date);
    if (parsedDate == null) {
      AppToast.error(
        context,
        title: 'Invalid date',
        description: 'Pick a valid deposit date.',
      );
      return;
    }

    final selectedSources = _depositForm.sources
        .where(
          (source) =>
              source.incomeId != null &&
              source.amount.trim().isNotEmpty &&
              (double.tryParse(source.amount.trim()) ?? 0) > 0,
        )
        .toList(growable: false);

    if (selectedSources.isEmpty) {
      AppToast.error(
        context,
        title: 'Missing income sources',
        description: 'Choose at least one received income for this deposit.',
      );
      return;
    }

    final sourceTotal = selectedSources.fold<double>(
      0,
      (sum, source) => sum + (double.tryParse(source.amount.trim()) ?? 0),
    );

    if ((sourceTotal - amount).abs() > 0.01) {
      AppToast.error(
        context,
        title: 'Source totals do not match',
        description:
            'The selected income source amounts must equal the deposit amount.',
      );
      return;
    }

    setState(() => _isDepositing = true);

    try {
      await widget.savingService.createSavingDeposit(
        savingId: entry.id,
        amount: amount,
        currency: SavingCurrencyCode.rwf,
        date: parsedDate,
        note: _depositForm.note.trim(),
        incomeSources: selectedSources
            .map(
              (source) => SavingDepositIncomeSource(
                incomeId: source.incomeId!,
                amount: double.parse(source.amount.trim()),
              ),
            )
            .toList(growable: false),
      );

      if (!mounted) {
        return;
      }

      _closeDepositDialog();
      await _loadSavings();
      if (!mounted) {
        return;
      }

      AppToast.success(
        context,
        title: 'Money added to saving',
        description: 'The deposit was recorded with traced income sources.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Unable to add money',
        description: _readableError(error),
      );
    } finally {
      if (mounted) {
        setState(() => _isDepositing = false);
      }
    }
  }

  Future<void> _submitWithdrawal() async {
    final entry = _withdrawalDialogEntry;
    if (entry == null) {
      return;
    }

    final amount = double.tryParse(_withdrawalForm.amount.trim());
    if (amount == null || amount <= 0) {
      AppToast.error(
        context,
        title: 'Invalid amount',
        description: 'Enter a withdrawal amount in RWF.',
      );
      return;
    }

    if (amount > entry.currentBalanceRwf + 0.01) {
      AppToast.error(
        context,
        title: 'Amount exceeds balance',
        description: 'You cannot withdraw more than the current balance.',
      );
      return;
    }

    final parsedDate = DateTime.tryParse(_withdrawalForm.date);
    if (parsedDate == null) {
      AppToast.error(
        context,
        title: 'Invalid date',
        description: 'Pick a valid withdrawal date.',
      );
      return;
    }

    setState(() => _isWithdrawing = true);

    try {
      await widget.savingService.createSavingWithdrawal(
        savingId: entry.id,
        amount: amount,
        currency: SavingCurrencyCode.rwf,
        date: parsedDate,
        note: _withdrawalForm.note.trim(),
      );

      if (!mounted) {
        return;
      }

      _closeWithdrawalDialog();
      await _loadSavings();
      if (!mounted) {
        return;
      }

      AppToast.success(
        context,
        title: 'Money withdrawn',
        description: 'The withdrawal was recorded successfully.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Unable to withdraw money',
        description: _readableError(error),
      );
    } finally {
      if (mounted) {
        setState(() => _isWithdrawing = false);
      }
    }
  }

  Future<void> _openHistoryDialog(SavingEntry entry) async {
    setState(() {
      _historyDialogEntry = entry;
      _historyTransactions = const [];
      _historyError = null;
      _isLoadingHistory = true;
    });

    try {
      final transactions = await widget.savingService.listSavingTransactions(
        entry.id,
      );

      if (!mounted || _historyDialogEntry?.id != entry.id) {
        return;
      }

      setState(() {
        _historyTransactions = List<SavingTransactionEntry>.unmodifiable(
          transactions,
        );
        _isLoadingHistory = false;
      });
    } catch (error) {
      if (!mounted || _historyDialogEntry?.id != entry.id) {
        return;
      }

      setState(() {
        _historyError = _readableError(error);
        _isLoadingHistory = false;
      });
    }
  }

  void _closeHistoryDialog() {
    setState(() {
      _historyDialogEntry = null;
      _historyTransactions = const [];
      _historyError = null;
      _isLoadingHistory = false;
    });
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

  _SavingFormValues _createEmptySavingForm() {
    final defaultDate = _defaultCreateDate();
    return _SavingFormValues(
      label: '',
      date: _formatDateOnly(defaultDate),
      note: '',
    );
  }

  _SavingFormValues _createSavingFormFromEntry(SavingEntry entry) {
    return _SavingFormValues(
      label: entry.label,
      date: _formatDateOnly(entry.date),
      note: entry.note ?? '',
    );
  }

  _SavingDepositFormValues _createEmptySavingDepositForm() {
    return _SavingDepositFormValues(
      amount: '',
      date: _formatDateOnly(DateTime.now()),
      note: '',
      sources: const [_SavingDepositSourceFormValue()],
    );
  }

  _SavingDepositFormValues _createSavingDepositFormFromEntry(
    SavingEntry entry,
  ) {
    return _SavingDepositFormValues(
      amount: '',
      date: _formatDateOnly(entry.date),
      note: entry.note ?? '',
      sources: const [_SavingDepositSourceFormValue()],
    );
  }

  _SavingWithdrawalFormValues _createEmptySavingWithdrawalForm() {
    return _SavingWithdrawalFormValues(
      amount: '',
      date: _formatDateOnly(DateTime.now()),
      note: '',
    );
  }

  _SavingWithdrawalFormValues _createSavingWithdrawalFormFromEntry(
    SavingEntry entry,
  ) {
    return _SavingWithdrawalFormValues(
      amount: '',
      date: _formatDateOnly(entry.date),
      note: entry.note ?? '',
    );
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

  bool get _hasActiveDialog =>
      _formDialog != null ||
      _depositDialogEntry != null ||
      _withdrawalDialogEntry != null ||
      _historyDialogEntry != null ||
      _deleteTarget != null;

  void _dismissTopDialog() {
    if (_deleteTarget != null) {
      setState(() => _deleteTarget = null);
      return;
    }

    if (_historyDialogEntry != null && !_isLoadingHistory) {
      _closeHistoryDialog();
      return;
    }

    if (_withdrawalDialogEntry != null && !_isWithdrawing) {
      _closeWithdrawalDialog();
      return;
    }

    if (_depositDialogEntry != null && !_isDepositing) {
      _closeDepositDialog();
      return;
    }

    if (_formDialog != null && !_isSaving) {
      _closeFormDialog();
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _SavingPageLoading(fade: _fade, slide: _slide);
    }

    return PopScope<void>(
      canPop: !_hasActiveDialog,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _dismissTopDialog();
        }
      },
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Staggered(
                fade: _fade(0.0, 0.45),
                slide: _slide(0.0, 0.45),
                child: _SavingHeader(
                  periodLabel: _periodLabel,
                  currentBalance: _totalBalance,
                  totalDeposited: _totalDeposited,
                  entryCount: _entries.length,
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
                child: _SavingFiltersPanel(
                  dateFrom: _selectedDateFrom,
                  dateTo: _selectedDateTo,
                  hasActiveFilters: _hasActiveFilters,
                  searchController: _searchCtrl,
                  searchInput: _searchInput,
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
                child: _SavingStatsRow(
                  activeShare: _activeShare,
                  totalBalance: _totalBalance,
                  totalDeposited: _totalDeposited,
                  totalWithdrawn: _totalWithdrawn,
                  largestSaving: _largestSaving,
                  latestEntry: _latestEntry,
                ),
              ),
              const SizedBox(height: 14),
              _Staggered(
                fade: _fade(0.36, 0.90),
                slide: _slide(0.36, 0.90),
                child: _SavingEntriesPanel(
                  currentPage: _currentPage,
                  entries: _pageEntries,
                  totalItems: _totalItems,
                  totalPages: _totalPages,
                  loadError: _loadError,
                  onDelete: (entry) => setState(() => _deleteTarget = entry),
                  onEdit: _openEditDialog,
                  onNextPage: () => _goToPage(_currentPage + 1),
                  onPreviousPage: () => _goToPage(_currentPage - 1),
                  onDeposit: _openDepositDialog,
                  onRetry: _loadSavings,
                  onViewHistory: _openHistoryDialog,
                  onWithdraw: _openWithdrawalDialog,
                ),
              ),
              const SizedBox(height: 8),
              _Staggered(
                fade: _fade(0.70, 1.0),
                slide: _slide(0.70, 1.0),
                child: const _FooterNote(),
              ),
            ],
          ),
          if (_formDialog != null)
            AppModalOverlay(
              dismissible: !_isSaving,
              onDismiss: _closeFormDialog,
              child: _SavingFormDialog(
                data: _formDialog!,
                form: _form,
                isSaving: _isSaving,
                onChange: _updateForm,
                onClose: _closeFormDialog,
                onSubmit: _submitSaving,
              ),
            ),
          if (_depositDialogEntry != null)
            AppModalOverlay(
              dismissible: !_isDepositing,
              onDismiss: _closeDepositDialog,
              child: _SavingDepositDialog(
                entry: _depositDialogEntry!,
                form: _depositForm,
                isSaving: _isDepositing,
                isLoadingIncomeSources: _isLoadingDepositSources,
                incomes: _depositIncomeOptions,
                onChange: _updateDepositForm,
                onClose: _closeDepositDialog,
                onSubmit: _submitDeposit,
              ),
            ),
          if (_withdrawalDialogEntry != null)
            AppModalOverlay(
              dismissible: !_isWithdrawing,
              onDismiss: _closeWithdrawalDialog,
              child: _SavingWithdrawalDialog(
                entry: _withdrawalDialogEntry!,
                form: _withdrawalForm,
                isSaving: _isWithdrawing,
                onChange: _updateWithdrawalForm,
                onClose: _closeWithdrawalDialog,
                onSubmit: _submitWithdrawal,
              ),
            ),
          if (_historyDialogEntry != null)
            AppModalOverlay(
              dismissible: !_isLoadingHistory,
              onDismiss: _closeHistoryDialog,
              child: _SavingHistoryDialog(
                entry: _historyDialogEntry!,
                isLoading: _isLoadingHistory,
                error: _historyError,
                transactions: _historyTransactions,
                onClose: _closeHistoryDialog,
                onRetry: () => _openHistoryDialog(_historyDialogEntry!),
              ),
            ),
          if (_deleteTarget != null)
            AppModalOverlay(
              onDismiss: () => setState(() => _deleteTarget = null),
              child: _DeleteConfirmDialog(
                label: _deleteTarget!.label,
                onClose: () => setState(() => _deleteTarget = null),
                onConfirm: _confirmDelete,
              ),
            ),
        ],
      ),
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

class _SavingPageLoading extends StatelessWidget {
  const _SavingPageLoading({required this.fade, required this.slide});

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
            fade: fade(0.14, 0.58),
            slide: slide(0.14, 0.58),
            child: const _LoadingPanel(
              padding: EdgeInsets.all(22),
              child: _LoadingFiltersPanel(),
            ),
          ),
          const SizedBox(height: 14),
          _Staggered(
            fade: fade(0.26, 0.70),
            slide: slide(0.26, 0.70),
            child: const _LoadingStatsRow(),
          ),
          const SizedBox(height: 14),
          _Staggered(
            fade: fade(0.38, 0.86),
            slide: slide(0.38, 0.86),
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
                        SkeletonBox(width: 82, height: 30, radius: 999),
                        SizedBox(width: 10),
                        SkeletonBox(width: 126, height: 30, radius: 999),
                      ],
                    ),
                    SizedBox(height: 18),
                    SkeletonBox(width: 178, height: 30, radius: 18),
                    SizedBox(height: 8),
                    SkeletonBox(height: 12, radius: 12),
                    SizedBox(height: 8),
                    SkeletonBox(width: 250, height: 12, radius: 12),
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
                    SkeletonBox(width: 120, height: 11, radius: 10),
                    SizedBox(height: 6),
                    SkeletonBox(width: 186, height: 34, radius: 18),
                  ],
                ),
              ),
              SizedBox(width: 12),
              SkeletonBox(width: 112, height: 28, radius: 10),
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
            SkeletonBox(width: 72, height: 14, radius: 12),
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
            Expanded(child: SkeletonBox(height: 44, radius: 16)),
            SizedBox(width: 10),
            Expanded(child: SkeletonBox(height: 44, radius: 16)),
          ],
        ),
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
          4,
          (_) => const SizedBox(width: 220, child: _LoadingStatCard()),
        );

        if (constraints.maxWidth < 920) {
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
          SkeletonBox(width: 90, height: 11, radius: 10),
          SizedBox(height: 10),
          SkeletonBox(width: 116, height: 20, radius: 12),
          SizedBox(height: 6),
          SkeletonBox(height: 11, radius: 10),
          SizedBox(height: 6),
          SkeletonBox(width: 132, height: 11, radius: 10),
        ],
      ),
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

class _SavingHeader extends StatefulWidget {
  const _SavingHeader({
    required this.periodLabel,
    required this.currentBalance,
    required this.totalDeposited,
    required this.entryCount,
    required this.canGoNextMonth,
    required this.onAdd,
    required this.onNextMonth,
    required this.onPreviousMonth,
  });

  final String periodLabel;
  final double currentBalance;
  final double totalDeposited;
  final int entryCount;
  final bool canGoNextMonth;
  final VoidCallback onAdd;
  final Future<void> Function() onNextMonth;
  final Future<void> Function() onPreviousMonth;

  @override
  State<_SavingHeader> createState() => _SavingHeaderState();
}

class _SavingHeaderState extends State<_SavingHeader>
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
                  _savingAccent.withValues(alpha: 0.15),
                  Colors.white.withValues(alpha: 0.07),
                  _savingAccent.withValues(alpha: 0.04),
                ],
                stops: [0.0, _shimmer.value, 1.0],
              ),
              border: Border.all(color: _savingAccent.withValues(alpha: 0.30)),
              boxShadow: [
                BoxShadow(
                  color: _savingAccent.withValues(alpha: 0.10),
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
                                      icon: HugeIcons.strokeRoundedPiggyBank,
                                      size: 15,
                                      color: _savingAccent,
                                      strokeWidth: 1.8,
                                    ),
                                    SizedBox(width: 7),
                                    Text(
                                      'Saving',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _savingAccent,
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
                            'Saving',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontSize: isCompact ? 26 : 30,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Create saving buckets, move money in from received income, and track every deposit and withdrawal in one ledger.',
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
                    _AddSavingButton(onTap: widget.onAdd),
                  ],
                ),
                const SizedBox(height: 22),
                const _GradientDivider(color: _savingAccent),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current balance in ${widget.periodLabel}',
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
                            value: widget.currentBalance,
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
                        color: _savingAccent.withValues(alpha: 0.12),
                        border: Border.all(
                          color: _savingAccent.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const HugeIcon(
                            icon: HugeIcons.strokeRoundedPiggyBank,
                            size: 12,
                            color: _savingAccent,
                            strokeWidth: 2,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${widget.entryCount} buckets · ${_rwfCompact(widget.totalDeposited)} deposited',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _savingAccent,
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
              : _savingAccent.withValues(alpha: 0.12),
          border: Border.all(
            color: isDisabled
                ? Colors.white.withValues(alpha: 0.06)
                : _savingAccent.withValues(alpha: 0.16),
          ),
        ),
        child: Center(
          child: HugeIcon(
            icon: icon,
            size: 13,
            color: isDisabled
                ? AppColors.textSecondary.withValues(alpha: 0.35)
                : _savingAccent,
            strokeWidth: 1.9,
          ),
        ),
      ),
    );
  }
}

class _AddSavingButton extends StatefulWidget {
  const _AddSavingButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_AddSavingButton> createState() => _AddSavingButtonState();
}

class _AddSavingButtonState extends State<_AddSavingButton> {
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
            color: _savingAccent.withValues(alpha: 0.18),
            border: Border.all(color: _savingAccent.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: _savingAccent.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedAdd01,
              size: 20,
              color: _savingAccent,
              strokeWidth: 2,
            ),
          ),
        ),
      ),
    );
  }
}

class _SavingFiltersPanel extends StatelessWidget {
  const _SavingFiltersPanel({
    required this.dateFrom,
    required this.dateTo,
    required this.hasActiveFilters,
    required this.searchController,
    required this.searchInput,
    required this.onClearAll,
    required this.onClearDate,
    required this.onDatePicked,
    required this.onSearchChanged,
  });

  final DateTime? dateFrom;
  final DateTime? dateTo;
  final bool hasActiveFilters;
  final TextEditingController searchController;
  final String searchInput;
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
                      color: _savingAccent.withValues(alpha: 0.9),
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
              hintText: 'Search saving label or note',
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
                  color: _savingAccent.withValues(alpha: 0.45),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            searchInput.isNotEmpty && searchInput.trim().length < 3
                ? 'Type at least 3 characters to apply search.'
                : 'Month, chosen date range, search, and pagination match the web filters.',
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: AppColors.textSecondary.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 16),
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

class _SavingStatsRow extends StatelessWidget {
  const _SavingStatsRow({
    required this.activeShare,
    required this.totalBalance,
    required this.totalDeposited,
    required this.totalWithdrawn,
    required this.largestSaving,
    required this.latestEntry,
  });

  final int activeShare;
  final double totalBalance;
  final double totalDeposited;
  final double totalWithdrawn;
  final SavingEntry? largestSaving;
  final SavingEntry? latestEntry;

  @override
  Widget build(BuildContext context) {
    final items = [
      _MetricCard(
        label: 'Current balance',
        value: _rwfCompact(totalBalance),
        detail: '$activeShare% of deposited money is still inside savings',
        accent: _savingAccent,
      ),
      _MetricCard(
        label: 'Total deposited',
        value: _rwfCompact(totalDeposited),
        detail: 'All money moved into savings buckets',
        accent: const Color(0xFFFFB86C),
      ),
      _MetricCard(
        label: 'Total withdrawn',
        value: _rwfCompact(totalWithdrawn),
        detail: 'Money already moved out of savings',
        accent: AppColors.success,
      ),
      _MetricCard(
        label: 'Largest balance',
        value: largestSaving == null
            ? 'No entries'
            : _rwfCompact(largestSaving!.currentBalanceRwf),
        detail: largestSaving?.label ?? 'Record your first saving',
        accent: _savingSecondary,
      ),
      _MetricCard(
        label: 'Latest activity',
        value: latestEntry == null
            ? 'No entries'
            : _formatLongDate(latestEntry!.date),
        detail:
            latestEntry?.label ??
            (_rwfCompact(totalBalance) == 'RWF 0'
                ? 'Create a saving bucket to start tracking your reserve.'
                : 'Latest saving activity'),
        accent: _savingSecondary,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 920) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    SizedBox(width: 220, child: items[i]),
                    if (i != items.length - 1) const SizedBox(width: 10),
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
              for (var i = 0; i < items.length; i++) ...[
                Expanded(child: items[i]),
                if (i != items.length - 1) const SizedBox(width: 10),
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
              fontSize: 18,
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

class _SavingEntriesPanel extends StatelessWidget {
  const _SavingEntriesPanel({
    required this.currentPage,
    required this.entries,
    required this.totalItems,
    required this.totalPages,
    required this.loadError,
    required this.onDelete,
    required this.onDeposit,
    required this.onEdit,
    required this.onNextPage,
    required this.onPreviousPage,
    required this.onRetry,
    required this.onViewHistory,
    required this.onWithdraw,
  });

  final int currentPage;
  final List<SavingEntry> entries;
  final int totalItems;
  final int totalPages;
  final String? loadError;
  final void Function(SavingEntry entry) onDelete;
  final Future<void> Function(SavingEntry entry) onDeposit;
  final void Function(SavingEntry entry) onEdit;
  final Future<void> Function() onNextPage;
  final Future<void> Function() onPreviousPage;
  final Future<void> Function() onRetry;
  final Future<void> Function(SavingEntry entry) onViewHistory;
  final void Function(SavingEntry entry) onWithdraw;

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
                  'Saving buckets',
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
            const _EmptyHint(message: 'No savings match these filters yet.')
          else
            Column(
              children: [
                for (var i = 0; i < entries.length; i++)
                  _SavingEntryTile(
                    entry: entries[i],
                    isLast: i == entries.length - 1,
                    onDelete: onDelete,
                    onDeposit: onDeposit,
                    onEdit: onEdit,
                    onViewHistory: onViewHistory,
                    onWithdraw: onWithdraw,
                  ),
              ],
            ),
          if (loadError == null && entries.isNotEmpty && totalPages > 1) ...[
            const SizedBox(height: 16),
            const _GradientDivider(color: _savingAccent),
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
        color: _savingAccent.withValues(alpha: 0.08),
        border: Border.all(color: _savingAccent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Unable to load savings',
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
                color: _savingAccent.withValues(alpha: 0.12),
                border: Border.all(
                  color: _savingAccent.withValues(alpha: 0.22),
                ),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _savingAccent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavingEntryTile extends StatefulWidget {
  const _SavingEntryTile({
    required this.entry,
    required this.isLast,
    required this.onDelete,
    required this.onDeposit,
    required this.onEdit,
    required this.onViewHistory,
    required this.onWithdraw,
  });

  final SavingEntry entry;
  final bool isLast;
  final void Function(SavingEntry entry) onDelete;
  final Future<void> Function(SavingEntry entry) onDeposit;
  final void Function(SavingEntry entry) onEdit;
  final Future<void> Function(SavingEntry entry) onViewHistory;
  final void Function(SavingEntry entry) onWithdraw;

  @override
  State<_SavingEntryTile> createState() => _SavingEntryTileState();
}

class _SavingEntryTileState extends State<_SavingEntryTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final creatorLabel = _resolveCreatorLabel(widget.entry);
    final amountColor = widget.entry.currentBalanceRwf > 0
        ? _savingAccent
        : AppColors.textSecondary;

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
                    color: _savingAccent.withValues(alpha: 0.12),
                    border: Border.all(
                      color: _savingAccent.withValues(alpha: 0.18),
                    ),
                  ),
                  child: const Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedPiggyBank,
                      size: 18,
                      color: _savingAccent,
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
                        _formatLongDate(widget.entry.date),
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
                      _rwfCompact(widget.entry.currentBalanceRwf),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: amountColor,
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
                              label: 'Balance',
                              value: _rwf(widget.entry.currentBalanceRwf),
                            ),
                            _DetailItem(
                              label: 'Deposited',
                              value: _rwf(widget.entry.totalDepositedRwf),
                            ),
                            _DetailItem(
                              label: 'Withdrawn',
                              value: _rwf(widget.entry.totalWithdrawnRwf),
                            ),
                            _DetailItem(
                              label: 'Created',
                              value: _formatLongDate(widget.entry.createdAt),
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
                              icon: HugeIcons.strokeRoundedArrowDown01,
                              color: _savingAccent,
                              onTap: () => widget.onDeposit(widget.entry),
                            ),
                            _ActionIcon(
                              icon: HugeIcons.strokeRoundedArrowUp01,
                              color: _savingSecondary,
                              onTap: () => widget.onWithdraw(widget.entry),
                            ),
                            _ActionIcon(
                              icon: HugeIcons.strokeRoundedTransactionHistory,
                              color: const Color(0xFFFFB86C),
                              onTap: () => widget.onViewHistory(widget.entry),
                            ),
                            _ActionIcon(
                              icon: HugeIcons.strokeRoundedPencil,
                              color: const Color(0xFF7EB8FF),
                              onTap: () => widget.onEdit(widget.entry),
                            ),
                            _ActionIcon(
                              icon: HugeIcons.strokeRoundedDelete01,
                              color: AppColors.danger,
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
    required this.onTap,
  });

  final dynamic icon;
  final Color color;
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
              : _savingAccent.withValues(alpha: 0.12),
          border: Border.all(
            color: isDisabled
                ? Colors.white.withValues(alpha: 0.08)
                : _savingAccent.withValues(alpha: 0.20),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isDisabled
                ? AppColors.textSecondary.withValues(alpha: 0.36)
                : _savingAccent,
          ),
        ),
      ),
    );
  }
}

enum _SavingFormMode { create, edit }

class _SavingFormDialogStateData {
  const _SavingFormDialogStateData._({required this.mode, this.entry});

  const _SavingFormDialogStateData.create()
    : this._(mode: _SavingFormMode.create);

  const _SavingFormDialogStateData.edit(SavingEntry entry)
    : this._(mode: _SavingFormMode.edit, entry: entry);

  final _SavingFormMode mode;
  final SavingEntry? entry;
}

class _SavingFormValues {
  const _SavingFormValues({
    required this.label,
    required this.date,
    required this.note,
  });

  final String label;
  final String date;
  final String note;

  _SavingFormValues copyWith({String? label, String? date, String? note}) {
    return _SavingFormValues(
      label: label ?? this.label,
      date: date ?? this.date,
      note: note ?? this.note,
    );
  }
}

class _SavingDepositSourceFormValue {
  const _SavingDepositSourceFormValue({this.incomeId, this.amount = ''});

  final String? incomeId;
  final String amount;

  _SavingDepositSourceFormValue copyWith({
    Object? incomeId = _sentinel,
    String? amount,
  }) {
    return _SavingDepositSourceFormValue(
      incomeId: identical(incomeId, _sentinel)
          ? this.incomeId
          : incomeId as String?,
      amount: amount ?? this.amount,
    );
  }
}

const Object _sentinel = Object();

class _SavingDepositFormValues {
  const _SavingDepositFormValues({
    required this.amount,
    required this.date,
    required this.note,
    required this.sources,
  });

  final String amount;
  final String date;
  final String note;
  final List<_SavingDepositSourceFormValue> sources;

  _SavingDepositFormValues copyWith({
    String? amount,
    String? date,
    String? note,
    List<_SavingDepositSourceFormValue>? sources,
  }) {
    return _SavingDepositFormValues(
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: note ?? this.note,
      sources: sources ?? this.sources,
    );
  }
}

class _SavingWithdrawalFormValues {
  const _SavingWithdrawalFormValues({
    required this.amount,
    required this.date,
    required this.note,
  });

  final String amount;
  final String date;
  final String note;

  _SavingWithdrawalFormValues copyWith({
    String? amount,
    String? date,
    String? note,
  }) {
    return _SavingWithdrawalFormValues(
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: note ?? this.note,
    );
  }
}

class _SavingFormDialog extends StatefulWidget {
  const _SavingFormDialog({
    required this.data,
    required this.form,
    required this.isSaving,
    required this.onChange,
    required this.onClose,
    required this.onSubmit,
  });

  final _SavingFormDialogStateData data;
  final _SavingFormValues form;
  final bool isSaving;
  final ValueChanged<_SavingFormValues> onChange;
  final VoidCallback onClose;
  final Future<void> Function() onSubmit;

  @override
  State<_SavingFormDialog> createState() => _SavingFormDialogState();
}

class _SavingFormDialogState extends State<_SavingFormDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
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
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    if (widget.isSaving) {
      return;
    }

    final initialDate = DateTime.tryParse(widget.form.date) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _savingAccent,
            onPrimary: AppColors.background,
            surface: AppColors.surfaceElevated,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      widget.onChange(
        widget.form.copyWith(
          date:
              '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.data.mode == _SavingFormMode.edit;
    final dateLabel = _formatLongDate(
      DateTime.tryParse(widget.form.date) ?? DateTime.now(),
    );

    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AppModalDialog(
          maxWidth: 470,
          padding: const EdgeInsets.all(28),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _savingAccent.withValues(alpha: 0.16),
                      ),
                      child: const Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedPiggyBank,
                          size: 18,
                          color: _savingAccent,
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
                            isEditing
                                ? 'Edit saving bucket'
                                : 'Add saving bucket',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            isEditing
                                ? 'Update the bucket details below'
                                : 'Create a bucket first, then add money later',
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
                      onTap: widget.isSaving ? null : widget.onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const _GradientDivider(color: _savingAccent),
                const SizedBox(height: 24),
                const _FieldLabel(label: 'Label'),
                const SizedBox(height: 8),
                _GlassField(
                  initialValue: widget.form.label,
                  hint: 'Emergency fund',
                  accent: _savingAccent,
                  onChanged: (value) =>
                      widget.onChange(widget.form.copyWith(label: value)),
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
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
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
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
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
                  initialValue: widget.form.note,
                  hint: 'Optional context for this saving bucket',
                  accent: _savingAccent,
                  maxLines: 4,
                  minLines: 3,
                  onChanged: (value) =>
                      widget.onChange(widget.form.copyWith(note: value)),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: _DialogButton(
                        label: 'Cancel',
                        isPrimary: false,
                        isDisabled: widget.isSaving,
                        onTap: () async => widget.onClose(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DialogButton(
                        label: isEditing ? 'Save changes' : 'Create bucket',
                        isPrimary: true,
                        isLoading: widget.isSaving,
                        onTap: widget.onSubmit,
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

class _SavingDepositDialog extends StatefulWidget {
  const _SavingDepositDialog({
    required this.entry,
    required this.form,
    required this.isSaving,
    required this.isLoadingIncomeSources,
    required this.incomes,
    required this.onChange,
    required this.onClose,
    required this.onSubmit,
  });

  final SavingEntry entry;
  final _SavingDepositFormValues form;
  final bool isSaving;
  final bool isLoadingIncomeSources;
  final List<IncomeEntry> incomes;
  final ValueChanged<_SavingDepositFormValues> onChange;
  final VoidCallback onClose;
  final Future<void> Function() onSubmit;

  @override
  State<_SavingDepositDialog> createState() => _SavingDepositDialogState();
}

class _SavingDepositDialogState extends State<_SavingDepositDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
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
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    if (widget.isSaving) {
      return;
    }

    final initialDate =
        DateTime.tryParse(widget.form.date) ?? widget.entry.date;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _savingAccent,
            onPrimary: AppColors.background,
            surface: AppColors.surfaceElevated,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      widget.onChange(
        widget.form.copyWith(
          date:
              '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final parsedAmount = double.tryParse(widget.form.amount);
    final amountPreview = parsedAmount != null && parsedAmount > 0
        ? _rwf(parsedAmount)
        : 'Enter RWF amount';
    final dateLabel = _formatLongDate(
      DateTime.tryParse(widget.form.date) ?? widget.entry.date,
    );

    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AppModalDialog(
          maxWidth: 470,
          padding: const EdgeInsets.all(28),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _savingSecondary.withValues(alpha: 0.16),
                      ),
                      child: const Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedMoneySendSquare,
                          size: 18,
                          color: _savingSecondary,
                          strokeWidth: 1.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add money',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Move money into this bucket and trace the deposit back to one or more received incomes.',
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
                      onTap: widget.isSaving ? null : widget.onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const _GradientDivider(color: _savingSecondary),
                const SizedBox(height: 20),
                _SummaryBlock(
                  label: 'Saving bucket',
                  value: widget.entry.label,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryBlock(
                        label: 'Current balance',
                        value: _rwf(widget.entry.currentBalanceRwf),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryBlock(
                        label: 'Recorded date',
                        value: _formatLongDate(widget.entry.date),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const _FieldLabel(label: 'Deposit date'),
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
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
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
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                          strokeWidth: 1.8,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const _FieldLabel(label: 'Amount in RWF'),
                const SizedBox(height: 8),
                _GlassField(
                  initialValue: widget.form.amount,
                  hint: '125000',
                  accent: _savingSecondary,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}$'),
                    ),
                  ],
                  onChanged: (value) =>
                      widget.onChange(widget.form.copyWith(amount: value)),
                ),
                const SizedBox(height: 8),
                Text(
                  amountPreview,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 18),
                const _FieldLabel(label: 'Income sources'),
                const SizedBox(height: 8),
                if (widget.isLoadingIncomeSources)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (widget.incomes.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.white.withValues(alpha: 0.05),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Text(
                      'No received income is available yet. Mark income as received before tracing a deposit.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: AppColors.textSecondary.withValues(alpha: 0.75),
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
                      for (var i = 0; i < widget.form.sources.length; i++) ...[
                        _SavingDepositSourceRow(
                          index: i,
                          source: widget.form.sources[i],
                          incomes: widget.incomes,
                          onIncomeChanged: (incomeId) {
                            final nextSources = widget.form.sources.toList(
                              growable: true,
                            );
                            nextSources[i] = nextSources[i].copyWith(
                              incomeId: incomeId,
                            );
                            widget.onChange(
                              widget.form.copyWith(sources: nextSources),
                            );
                          },
                          onAmountChanged: (amount) {
                            final nextSources = widget.form.sources.toList(
                              growable: true,
                            );
                            nextSources[i] = nextSources[i].copyWith(
                              amount: amount,
                            );
                            widget.onChange(
                              widget.form.copyWith(sources: nextSources),
                            );
                          },
                          onRemove: widget.form.sources.length == 1
                              ? null
                              : () {
                                  final nextSources =
                                      widget.form.sources.toList(growable: true)
                                        ..removeAt(i);
                                  widget.onChange(
                                    widget.form.copyWith(sources: nextSources),
                                  );
                                },
                        ),
                        if (i != widget.form.sources.length - 1)
                          const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () {
                            final fallbackIncome = widget.incomes.first.id;
                            widget.onChange(
                              widget.form.copyWith(
                                sources: [
                                  ...widget.form.sources,
                                  _SavingDepositSourceFormValue(
                                    incomeId: fallbackIncome,
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: _savingAccent.withValues(alpha: 0.12),
                              border: Border.all(
                                color: _savingAccent.withValues(alpha: 0.24),
                              ),
                            ),
                            child: const Text(
                              'Add another income source',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _savingAccent,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 18),
                const _FieldLabel(label: 'Deposit note'),
                const SizedBox(height: 8),
                _GlassField(
                  initialValue: widget.form.note,
                  hint: 'Optional context for this deposit',
                  accent: _savingSecondary,
                  maxLines: 4,
                  minLines: 3,
                  onChanged: (value) =>
                      widget.onChange(widget.form.copyWith(note: value)),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: _DialogButton(
                        label: 'Cancel',
                        isPrimary: false,
                        isDisabled: widget.isSaving,
                        onTap: () async => widget.onClose(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DialogButton(
                        label: 'Add money',
                        isPrimary: true,
                        isLoading: widget.isSaving,
                        onTap: widget.onSubmit,
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

class _SavingWithdrawalDialog extends StatefulWidget {
  const _SavingWithdrawalDialog({
    required this.entry,
    required this.form,
    required this.isSaving,
    required this.onChange,
    required this.onClose,
    required this.onSubmit,
  });

  final SavingEntry entry;
  final _SavingWithdrawalFormValues form;
  final bool isSaving;
  final ValueChanged<_SavingWithdrawalFormValues> onChange;
  final VoidCallback onClose;
  final Future<void> Function() onSubmit;

  @override
  State<_SavingWithdrawalDialog> createState() =>
      _SavingWithdrawalDialogState();
}

class _SavingWithdrawalDialogState extends State<_SavingWithdrawalDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
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
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    if (widget.isSaving) {
      return;
    }

    final initialDate =
        DateTime.tryParse(widget.form.date) ?? widget.entry.date;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _savingAccent,
            onPrimary: AppColors.background,
            surface: AppColors.surfaceElevated,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      widget.onChange(
        widget.form.copyWith(
          date:
              '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final parsedAmount = double.tryParse(widget.form.amount);
    final amountPreview = parsedAmount != null && parsedAmount > 0
        ? _rwf(parsedAmount)
        : 'Enter RWF amount';
    final dateLabel = _formatLongDate(
      DateTime.tryParse(widget.form.date) ?? widget.entry.date,
    );

    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AppModalDialog(
          maxWidth: 470,
          padding: const EdgeInsets.all(28),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFFB86C).withValues(alpha: 0.16),
                      ),
                      child: const Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowUp01,
                          size: 18,
                          color: Color(0xFFFFB86C),
                          strokeWidth: 1.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Withdraw money',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Move money out of this saving bucket and record the withdrawal in the ledger.',
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
                      onTap: widget.isSaving ? null : widget.onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const _GradientDivider(color: Color(0xFFFFB86C)),
                const SizedBox(height: 20),
                _SummaryBlock(
                  label: 'Saving bucket',
                  value: widget.entry.label,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryBlock(
                        label: 'Current balance',
                        value: _rwf(widget.entry.currentBalanceRwf),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryBlock(
                        label: 'Total withdrawn',
                        value: _rwf(widget.entry.totalWithdrawnRwf),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const _FieldLabel(label: 'Withdrawal date'),
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
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
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
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                          strokeWidth: 1.8,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const _FieldLabel(label: 'Amount in RWF'),
                const SizedBox(height: 8),
                _GlassField(
                  initialValue: widget.form.amount,
                  hint: '50000',
                  accent: const Color(0xFFFFB86C),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}$'),
                    ),
                  ],
                  onChanged: (value) =>
                      widget.onChange(widget.form.copyWith(amount: value)),
                ),
                const SizedBox(height: 8),
                Text(
                  amountPreview,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 18),
                const _FieldLabel(label: 'Withdrawal note'),
                const SizedBox(height: 8),
                _GlassField(
                  initialValue: widget.form.note,
                  hint: 'Optional context for this withdrawal',
                  accent: const Color(0xFFFFB86C),
                  maxLines: 4,
                  minLines: 3,
                  onChanged: (value) =>
                      widget.onChange(widget.form.copyWith(note: value)),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: _DialogButton(
                        label: 'Cancel',
                        isPrimary: false,
                        isDisabled: widget.isSaving,
                        onTap: () async => widget.onClose(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DialogButton(
                        label: 'Withdraw',
                        isPrimary: true,
                        isLoading: widget.isSaving,
                        onTap: widget.onSubmit,
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

class _SavingHistoryDialog extends StatefulWidget {
  const _SavingHistoryDialog({
    required this.entry,
    required this.isLoading,
    required this.error,
    required this.transactions,
    required this.onClose,
    required this.onRetry,
  });

  final SavingEntry entry;
  final bool isLoading;
  final String? error;
  final List<SavingTransactionEntry> transactions;
  final VoidCallback onClose;
  final Future<void> Function() onRetry;

  @override
  State<_SavingHistoryDialog> createState() => _SavingHistoryDialogState();
}

class _SavingHistoryDialogState extends State<_SavingHistoryDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
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
          maxWidth: 560,
          padding: const EdgeInsets.all(24),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Saving history',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.entry.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.72,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppModalCloseButton(onTap: widget.onClose),
                ],
              ),
              const SizedBox(height: 16),
              const _GradientDivider(color: _savingAccent),
              const SizedBox(height: 16),
              if (widget.isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (widget.error != null)
                Expanded(
                  child: _ErrorState(
                    message: widget.error!,
                    onRetry: widget.onRetry,
                  ),
                )
              else if (widget.transactions.isEmpty)
                const Expanded(
                  child: _EmptyHint(
                    message: 'No saving transactions recorded yet.',
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: widget.transactions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final transaction = widget.transactions[index];
                      final accent = switch (transaction.type) {
                        SavingTransactionTypeCode.deposit => _savingAccent,
                        SavingTransactionTypeCode.withdrawal => const Color(
                          0xFFFFB86C,
                        ),
                        SavingTransactionTypeCode.adjustment =>
                          _savingSecondary,
                      };
                      final label = switch (transaction.type) {
                        SavingTransactionTypeCode.deposit => 'Deposit',
                        SavingTransactionTypeCode.withdrawal => 'Withdrawal',
                        SavingTransactionTypeCode.adjustment => 'Adjustment',
                      };

                      return Container(
                        padding: const EdgeInsets.all(14),
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
                            Row(
                              children: [
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: accent,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _rwf(transaction.amountRwf),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatLongDate(transaction.date),
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                            if (transaction.note != null &&
                                transaction.note!.trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                transaction.note!.trim(),
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.45,
                                  color: AppColors.textSecondary.withValues(
                                    alpha: 0.82,
                                  ),
                                ),
                              ),
                            ],
                            if (transaction.incomeSources.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              const Text(
                                'Income sources',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              for (final source in transaction.incomeSources)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    '${source.incomeLabel} · ${source.incomeCategory} · ${_rwf(source.amountRwf)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary.withValues(
                                        alpha: 0.72,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavingDepositSourceRow extends StatelessWidget {
  const _SavingDepositSourceRow({
    required this.index,
    required this.source,
    required this.incomes,
    required this.onIncomeChanged,
    required this.onAmountChanged,
    this.onRemove,
  });

  final int index;
  final _SavingDepositSourceFormValue source;
  final List<IncomeEntry> incomes;
  final ValueChanged<String?> onIncomeChanged;
  final ValueChanged<String> onAmountChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Source ${index + 1}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (onRemove != null)
                GestureDetector(
                  onTap: onRemove,
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedCancel01,
                    size: 14,
                    color: AppColors.textSecondary.withValues(alpha: 0.65),
                    strokeWidth: 1.8,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: incomes.any((income) => income.id == source.incomeId)
                ? source.incomeId
                : incomes.first.id,
            dropdownColor: AppColors.surfaceElevated,
            iconEnabledColor: _savingAccent,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),
            items: incomes
                .map(
                  (income) => DropdownMenuItem<String>(
                    value: income.id,
                    child: Text(
                      '${income.label} · ${_rwf(income.amountRwf)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: onIncomeChanged,
          ),
          const SizedBox(height: 10),
          _GlassField(
            initialValue: source.amount,
            hint: '50000',
            accent: _savingAccent,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
            ],
            onChanged: onAmountChanged,
          ),
        ],
      ),
    );
  }
}

class _SummaryBlock extends StatelessWidget {
  const _SummaryBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
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
              color: AppColors.textSecondary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteConfirmDialog extends StatefulWidget {
  const _DeleteConfirmDialog({
    required this.label,
    required this.onClose,
    required this.onConfirm,
  });

  final String label;
  final VoidCallback onClose;
  final Future<void> Function() onConfirm;

  @override
  State<_DeleteConfirmDialog> createState() => _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends State<_DeleteConfirmDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;
  bool _deleting = false;

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

  Future<void> _confirm() async {
    setState(() => _deleting = true);
    try {
      await widget.onConfirm();
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
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
                'Remove saving entry?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '"${widget.label}" will be permanently removed from your saving records.',
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
                      isDisabled: _deleting,
                      onTap: () async => widget.onClose(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DialogButton(
                      label: 'Delete',
                      isPrimary: true,
                      isDanger: true,
                      isLoading: _deleting,
                      onTap: _confirm,
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
    required this.initialValue,
    required this.hint,
    required this.accent,
    required this.onChanged,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.minLines,
  });

  final String initialValue;
  final String hint;
  final Color accent;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines;
  final int? minLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      onChanged: onChanged,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      minLines: minLines,
      maxLines: maxLines,
      style: const TextStyle(
        fontSize: 13,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
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
    final primaryColor = widget.isDanger ? AppColors.danger : _savingAccent;

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
            icon: HugeIcons.strokeRoundedPiggyBank,
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
          'Every saving movement stays linked to your ledger and account session',
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
