import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/network/paginated_response.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../loans/application/loan_service.dart';
import '../../../loans/data/models/loan_entry.dart';
import '../../../loans/data/models/loan_list_query.dart';

const Color _loanAccent = Color(0xFFF59E0B);
const Color _loanSecondary = Color(0xFFFBBF24);

enum _LoanPaidFilter { all, paid, unpaid }

extension _LoanPaidFilterX on _LoanPaidFilter {
  String get label => switch (this) {
    _LoanPaidFilter.all => 'All',
    _LoanPaidFilter.paid => 'Paid',
    _LoanPaidFilter.unpaid => 'Unpaid',
  };
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

String? _resolveCreatorLabel(LoanEntry entry) {
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

class LoanPage extends StatefulWidget {
  const LoanPage({super.key, required this.loanService});

  final LoanService loanService;

  @override
  State<LoanPage> createState() => _LoanPageState();
}

class _LoanPageState extends State<LoanPage>
    with SingleTickerProviderStateMixin {
  static const int _pageSize = 12;

  late final AnimationController _entranceCtrl;
  late final TextEditingController _searchCtrl;
  List<LoanEntry> _entries = const [];
  List<LoanEntry> _pageEntries = const [];
  bool _isLoading = true;
  String? _loadError;
  Timer? _searchDebounce;
  bool _isSaving = false;
  bool _isSettling = false;
  String? _paidBusyId;
  int _currentPage = 1;
  int _totalItems = 0;
  int _totalPages = 1;
  late int _selectedMonth;
  late int _selectedYear;
  _LoanPaidFilter _selectedPaid = _LoanPaidFilter.all;
  DateTime? _selectedDateFrom;
  DateTime? _selectedDateTo;
  String _searchInput = '';
  String? _appliedSearch;
  int _loadSequence = 0;
  _LoanFormDialogStateData? _formDialog;
  LoanEntry? _settlementDialogEntry;
  LoanEntry? _deleteTarget;
  late _LoanFormValues _form;
  late _LoanSettlementFormValues _settlementForm;

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
    _form = _createEmptyLoanForm();
    _settlementForm = _createEmptySettlementForm();
    _loadLoans();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  double get _totalLoans =>
      _entries.fold(0, (sum, entry) => sum + entry.amount);

  double get _paidAmount => _entries
      .where((entry) => entry.paid)
      .fold(0, (sum, entry) => sum + entry.amount);

  double get _outstandingAmount =>
      (_totalLoans - _paidAmount).clamp(0, double.infinity).toDouble();

  int get _paidCount => _entries.where((entry) => entry.paid).length;

  int get _paidShare =>
      _totalLoans > 0 ? ((_paidAmount / _totalLoans) * 100).round() : 0;

  LoanEntry? get _largestLoan {
    if (_entries.isEmpty) {
      return null;
    }

    final sorted = _entries.toList(growable: false)
      ..sort((left, right) => right.amount.compareTo(left.amount));
    return sorted.first;
  }

  LoanEntry? get _latestLoan => _entries.isEmpty ? null : _entries.first;

  bool get _hasExplicitDateFilter =>
      _selectedDateFrom != null || _selectedDateTo != null;

  bool get _hasActiveFilters {
    final now = DateTime.now();
    return _selectedMonth != now.month ||
        _selectedYear != now.year ||
        _selectedPaid != _LoanPaidFilter.all ||
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

  Future<void> _loadLoans() async {
    final loadId = ++_loadSequence;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final summaryQuery = _buildLoanQuery();
      final pageQuery = _buildLoanQuery(page: _currentPage, limit: _pageSize);
      final results = await Future.wait<dynamic>([
        widget.loanService.listLoans(query: summaryQuery),
        widget.loanService.listLoansPage(query: pageQuery),
      ]);

      final entries = (results[0] as List<dynamic>).cast<LoanEntry>();
      final pageResponse = results[1] as PaginatedResponse<LoanEntry>;

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
        title: 'Unable to load loans',
        description: message,
      );
    }
  }

  List<LoanEntry> _sortedEntries(List<LoanEntry> entries) {
    final sorted = List<LoanEntry>.from(entries);
    sorted.sort((left, right) {
      final byDate = right.date.compareTo(left.date);
      if (byDate != 0) {
        return byDate;
      }
      return right.createdAt.compareTo(left.createdAt);
    });
    return List<LoanEntry>.unmodifiable(sorted);
  }

  LoanListQuery _buildLoanQuery({int? page, int? limit}) {
    return LoanListQuery(
      month: _hasExplicitDateFilter ? null : _selectedMonth,
      year: _hasExplicitDateFilter ? null : _selectedYear,
      paid: switch (_selectedPaid) {
        _LoanPaidFilter.all => null,
        _LoanPaidFilter.paid => true,
        _LoanPaidFilter.unpaid => false,
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
      _loadLoans();
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
            primary: _loanAccent,
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
    await _loadLoans();
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
    await _loadLoans();
  }

  Future<void> _clearAllFilters() async {
    final now = DateTime.now();
    _searchDebounce?.cancel();
    _searchCtrl.clear();

    setState(() {
      _selectedMonth = now.month;
      _selectedYear = now.year;
      _selectedPaid = _LoanPaidFilter.all;
      _selectedDateFrom = null;
      _selectedDateTo = null;
      _searchInput = '';
      _appliedSearch = null;
      _currentPage = 1;
    });
    await _loadLoans();
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
    await _loadLoans();
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
    await _loadLoans();
  }

  Future<void> _goToPage(int page) async {
    if (page < 1 || page > _totalPages || page == _currentPage) {
      return;
    }

    setState(() => _currentPage = page);
    await _loadLoans();
  }

  void _openAddDialog() {
    setState(() {
      _form = _createEmptyLoanForm();
      _formDialog = const _LoanFormDialogStateData.create();
    });
  }

  void _openEditDialog(LoanEntry entry) {
    setState(() {
      _form = _createLoanFormFromEntry(entry);
      _formDialog = _LoanFormDialogStateData.edit(entry);
    });
  }

  void _closeFormDialog() {
    setState(() {
      _formDialog = null;
      _form = _createEmptyLoanForm();
    });
  }

  void _openSettlementDialog(LoanEntry entry) {
    if (entry.paid) {
      AppToast.info(
        context,
        title: 'Already settled',
        description: 'This loan is already marked as paid.',
      );
      return;
    }

    setState(() {
      _settlementDialogEntry = entry;
      _settlementForm = _createSettlementFormFromEntry(entry);
    });
  }

  void _closeSettlementDialog() {
    setState(() {
      _settlementDialogEntry = null;
      _settlementForm = _createEmptySettlementForm();
    });
  }

  void _updateForm(_LoanFormValues next) {
    setState(() => _form = next);
  }

  void _updateSettlementForm(_LoanSettlementFormValues next) {
    setState(() => _settlementForm = next);
  }

  Future<void> _submitLoan() async {
    if (_form.label.trim().isEmpty) {
      AppToast.error(
        context,
        title: 'Missing label',
        description: 'Enter a label for this loan.',
      );
      return;
    }

    final amount = double.tryParse(_form.amount.trim());
    if (amount == null || amount <= 0) {
      AppToast.error(
        context,
        title: 'Invalid amount',
        description: 'Enter an amount greater than zero.',
      );
      return;
    }

    final parsedDate = DateTime.tryParse(_form.date);
    if (parsedDate == null) {
      AppToast.error(
        context,
        title: 'Invalid date',
        description: 'Pick a valid loan date.',
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final isEditing = _formDialog?.mode == _LoanFormMode.edit;
      if (isEditing && _formDialog?.entry != null) {
        await widget.loanService.updateLoan(
          loanId: _formDialog!.entry!.id,
          label: _form.label.trim(),
          amount: amount,
          date: parsedDate,
          paid: _form.paid,
          note: _form.note.trim(),
        );
      } else {
        await widget.loanService.createLoan(
          label: _form.label.trim(),
          amount: amount,
          date: parsedDate,
          paid: _form.paid,
          note: _form.note.trim(),
        );
      }

      if (!mounted) {
        return;
      }

      final created = _formDialog?.mode == _LoanFormMode.create;
      _closeFormDialog();
      if (created && _currentPage != 1) {
        setState(() => _currentPage = 1);
      }
      await _loadLoans();
      if (!mounted) {
        return;
      }

      AppToast.success(
        context,
        title: isEditing ? 'Loan updated' : 'Loan added',
        description: isEditing
            ? 'Your loan entry was updated successfully.'
            : 'Your loan entry was added successfully.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: _formDialog?.mode == _LoanFormMode.edit
            ? 'Unable to update loan'
            : 'Unable to add loan',
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
      await widget.loanService.deleteLoan(target.id);
      if (!mounted) {
        return;
      }

      if (_pageEntries.length == 1 && _currentPage > 1) {
        setState(() => _currentPage -= 1);
      }
      setState(() => _deleteTarget = null);
      await _loadLoans();
      if (!mounted) {
        return;
      }

      AppToast.success(
        context,
        title: 'Loan deleted',
        description: '${target.label} was removed successfully.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Unable to delete loan',
        description: _readableError(error),
      );
    }
  }

  Future<void> _togglePaid(LoanEntry entry) async {
    setState(() => _paidBusyId = entry.id);

    try {
      await widget.loanService.updateLoan(loanId: entry.id, paid: !entry.paid);

      if (!mounted) {
        return;
      }

      await _loadLoans();
      if (!mounted) {
        return;
      }

      AppToast.success(
        context,
        title: !entry.paid ? 'Loan marked paid' : 'Loan marked unpaid',
        description: '${entry.label} was updated successfully.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Unable to update loan state',
        description: _readableError(error),
      );
    } finally {
      if (mounted) {
        setState(() => _paidBusyId = null);
      }
    }
  }

  Future<void> _settleLoan() async {
    final entry = _settlementDialogEntry;
    if (entry == null) {
      return;
    }

    final parsedDate = DateTime.tryParse(_settlementForm.date);
    if (parsedDate == null) {
      AppToast.error(
        context,
        title: 'Invalid date',
        description: 'Pick a valid expense date.',
      );
      return;
    }

    setState(() => _isSettling = true);

    try {
      final result = await widget.loanService.sendLoanToExpense(
        loanId: entry.id,
        date: parsedDate,
        note: _settlementForm.note.trim(),
      );

      if (!mounted) {
        return;
      }

      _closeSettlementDialog();
      await _loadLoans();
      if (!mounted) {
        return;
      }

      AppToast.success(
        context,
        title: 'Loan settled',
        description:
            '${result.loan.label} was sent to expenses as ${_rwf(result.expense.amount)}.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Unable to settle loan',
        description: _readableError(error),
      );
    } finally {
      if (mounted) {
        setState(() => _isSettling = false);
      }
    }
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

  _LoanFormValues _createEmptyLoanForm() {
    final defaultDate = _defaultCreateDate();
    return _LoanFormValues(
      label: '',
      amount: '',
      date: _formatDateOnly(defaultDate),
      paid: false,
      note: '',
    );
  }

  _LoanFormValues _createLoanFormFromEntry(LoanEntry entry) {
    return _LoanFormValues(
      label: entry.label,
      amount: entry.amount.toStringAsFixed(0),
      date: _formatDateOnly(entry.date),
      paid: entry.paid,
      note: entry.note ?? '',
    );
  }

  _LoanSettlementFormValues _createEmptySettlementForm() {
    return _LoanSettlementFormValues(
      date: _formatDateOnly(DateTime.now()),
      note: '',
    );
  }

  _LoanSettlementFormValues _createSettlementFormFromEntry(LoanEntry entry) {
    return _LoanSettlementFormValues(
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _LoanPageLoading(fade: _fade, slide: _slide);
    }

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Staggered(
              fade: _fade(0.0, 0.45),
              slide: _slide(0.0, 0.45),
              child: _LoanHeader(
                periodLabel: _periodLabel,
                totalLoans: _totalLoans,
                outstandingAmount: _outstandingAmount,
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
              child: _LoanFiltersPanel(
                dateFrom: _selectedDateFrom,
                dateTo: _selectedDateTo,
                hasActiveFilters: _hasActiveFilters,
                paid: _selectedPaid,
                searchController: _searchCtrl,
                searchInput: _searchInput,
                onClearAll: _clearAllFilters,
                onClearDate: _clearDateFilter,
                onDatePicked: _pickFilterDate,
                onPaidChanged: (value) async {
                  setState(() {
                    _selectedPaid = value;
                    _currentPage = 1;
                  });
                  await _loadLoans();
                },
                onSearchChanged: _onSearchChanged,
              ),
            ),
            const SizedBox(height: 14),
            _Staggered(
              fade: _fade(0.24, 0.68),
              slide: _slide(0.24, 0.68),
              child: _LoanStatsRow(
                largestLoan: _largestLoan,
                latestLoan: _latestLoan,
                outstandingAmount: _outstandingAmount,
                paidAmount: _paidAmount,
                paidCount: _paidCount,
                paidShare: _paidShare,
              ),
            ),
            const SizedBox(height: 14),
            _Staggered(
              fade: _fade(0.38, 0.92),
              slide: _slide(0.38, 0.92),
              child: _LoanEntriesPanel(
                currentPage: _currentPage,
                entries: _pageEntries,
                totalItems: _totalItems,
                totalPages: _totalPages,
                loadError: _loadError,
                paidBusyId: _paidBusyId,
                onDelete: (entry) => setState(() => _deleteTarget = entry),
                onEdit: _openEditDialog,
                onNextPage: () => _goToPage(_currentPage + 1),
                onPreviousPage: () => _goToPage(_currentPage - 1),
                onRetry: _loadLoans,
                onSendToExpense: _openSettlementDialog,
                onTogglePaid: _togglePaid,
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
          _LoanFormDialog(
            data: _formDialog!,
            form: _form,
            isSaving: _isSaving,
            onChange: _updateForm,
            onClose: _closeFormDialog,
            onSubmit: _submitLoan,
          ),
        if (_settlementDialogEntry != null)
          _LoanSettlementDialog(
            entry: _settlementDialogEntry!,
            form: _settlementForm,
            isSaving: _isSettling,
            onChange: _updateSettlementForm,
            onClose: _closeSettlementDialog,
            onSubmit: _settleLoan,
          ),
        if (_deleteTarget != null)
          _DeleteConfirmDialog(
            label: _deleteTarget!.label,
            onClose: () => setState(() => _deleteTarget = null),
            onConfirm: _confirmDelete,
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

class _LoanPageLoading extends StatelessWidget {
  const _LoanPageLoading({required this.fade, required this.slide});

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
                        SkeletonBox(width: 72, height: 30, radius: 999),
                        SizedBox(width: 10),
                        SkeletonBox(width: 126, height: 30, radius: 999),
                      ],
                    ),
                    SizedBox(height: 18),
                    SkeletonBox(width: 170, height: 30, radius: 18),
                    SizedBox(height: 8),
                    SkeletonBox(height: 12, radius: 12),
                    SizedBox(height: 8),
                    SkeletonBox(width: 240, height: 12, radius: 12),
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
                    SkeletonBox(width: 124, height: 11, radius: 10),
                    SizedBox(height: 6),
                    SkeletonBox(width: 190, height: 34, radius: 18),
                  ],
                ),
              ),
              SizedBox(width: 12),
              SkeletonBox(width: 104, height: 28, radius: 10),
            ],
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
        SizedBox(height: 16),
        SkeletonBox(width: 92, height: 12, radius: 12),
        SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SkeletonBox(width: 56, height: 32, radius: 999),
            SkeletonBox(width: 62, height: 32, radius: 999),
            SkeletonBox(width: 74, height: 32, radius: 999),
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
          SkeletonBox(width: 118, height: 20, radius: 12),
          SizedBox(height: 6),
          Expanded(child: SkeletonBox(height: 11, radius: 10)),
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

class _LoanHeader extends StatefulWidget {
  const _LoanHeader({
    required this.periodLabel,
    required this.totalLoans,
    required this.outstandingAmount,
    required this.entryCount,
    required this.canGoNextMonth,
    required this.onAdd,
    required this.onNextMonth,
    required this.onPreviousMonth,
  });

  final String periodLabel;
  final double totalLoans;
  final double outstandingAmount;
  final int entryCount;
  final bool canGoNextMonth;
  final VoidCallback onAdd;
  final Future<void> Function() onNextMonth;
  final Future<void> Function() onPreviousMonth;

  @override
  State<_LoanHeader> createState() => _LoanHeaderState();
}

class _LoanHeaderState extends State<_LoanHeader>
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
                  _loanAccent.withValues(alpha: 0.15),
                  Colors.white.withValues(alpha: 0.07),
                  _loanAccent.withValues(alpha: 0.04),
                ],
                stops: [0.0, _shimmer.value, 1.0],
              ),
              border: Border.all(color: _loanAccent.withValues(alpha: 0.30)),
              boxShadow: [
                BoxShadow(
                  color: _loanAccent.withValues(alpha: 0.10),
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
                                      icon: HugeIcons.strokeRoundedWallet03,
                                      size: 15,
                                      color: _loanAccent,
                                      strokeWidth: 1.8,
                                    ),
                                    SizedBox(width: 7),
                                    Text(
                                      'Loan',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _loanAccent,
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
                            'Loans',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontSize: isCompact ? 26 : 30,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Track borrowed money, follow settlement status, and convert unpaid loans into expenses when they are repaid.',
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
                    _AddLoanButton(onTap: widget.onAdd),
                  ],
                ),
                const SizedBox(height: 22),
                const _GradientDivider(color: _loanAccent),
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
                            value: widget.totalLoans,
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
                        color: _loanAccent.withValues(alpha: 0.12),
                        border: Border.all(
                          color: _loanAccent.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const HugeIcon(
                            icon: HugeIcons.strokeRoundedWallet03,
                            size: 12,
                            color: _loanAccent,
                            strokeWidth: 2,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${widget.entryCount} records',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _loanAccent,
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
              : _loanAccent.withValues(alpha: 0.12),
          border: Border.all(
            color: isDisabled
                ? Colors.white.withValues(alpha: 0.06)
                : _loanAccent.withValues(alpha: 0.16),
          ),
        ),
        child: Center(
          child: HugeIcon(
            icon: icon,
            size: 13,
            color: isDisabled
                ? AppColors.textSecondary.withValues(alpha: 0.35)
                : _loanAccent,
            strokeWidth: 1.9,
          ),
        ),
      ),
    );
  }
}

class _AddLoanButton extends StatefulWidget {
  const _AddLoanButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_AddLoanButton> createState() => _AddLoanButtonState();
}

class _AddLoanButtonState extends State<_AddLoanButton> {
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
            color: _loanAccent.withValues(alpha: 0.18),
            border: Border.all(color: _loanAccent.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: _loanAccent.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedAdd01,
              size: 20,
              color: _loanAccent,
              strokeWidth: 2,
            ),
          ),
        ),
      ),
    );
  }
}

class _LoanFiltersPanel extends StatelessWidget {
  const _LoanFiltersPanel({
    required this.dateFrom,
    required this.dateTo,
    required this.hasActiveFilters,
    required this.paid,
    required this.searchController,
    required this.searchInput,
    required this.onClearAll,
    required this.onClearDate,
    required this.onDatePicked,
    required this.onPaidChanged,
    required this.onSearchChanged,
  });

  final DateTime? dateFrom;
  final DateTime? dateTo;
  final bool hasActiveFilters;
  final _LoanPaidFilter paid;
  final TextEditingController searchController;
  final String searchInput;
  final Future<void> Function() onClearAll;
  final Future<void> Function({required bool isFrom}) onClearDate;
  final Future<void> Function({required bool isFrom}) onDatePicked;
  final Future<void> Function(_LoanPaidFilter value) onPaidChanged;
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
                      color: _loanAccent.withValues(alpha: 0.9),
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
              hintText: 'Search loan label or note',
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
                  color: _loanAccent.withValues(alpha: 0.45),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            searchInput.isNotEmpty && searchInput.trim().length < 3
                ? 'Type at least 3 characters to apply search.'
                : 'Month, paid state, chosen date range, search, and pagination match the web filters.',
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: AppColors.textSecondary.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Settlement state',
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
            children: _LoanPaidFilter.values
                .map(
                  (item) => _FilterChoiceChip(
                    label: item.label,
                    isSelected: paid == item,
                    accent: item == _LoanPaidFilter.unpaid
                        ? const Color(0xFFFFB86C)
                        : _loanAccent,
                    onTap: () => onPaidChanged(item),
                  ),
                )
                .toList(growable: false),
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

class _FilterChoiceChip extends StatelessWidget {
  const _FilterChoiceChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.accent = _loanAccent,
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

class _LoanStatsRow extends StatelessWidget {
  const _LoanStatsRow({
    required this.largestLoan,
    required this.latestLoan,
    required this.outstandingAmount,
    required this.paidAmount,
    required this.paidCount,
    required this.paidShare,
  });

  final LoanEntry? largestLoan;
  final LoanEntry? latestLoan;
  final double outstandingAmount;
  final double paidAmount;
  final int paidCount;
  final int paidShare;

  @override
  Widget build(BuildContext context) {
    final items = [
      _MetricCard(
        label: 'Outstanding',
        value: _rwfCompact(outstandingAmount),
        detail: 'Unpaid amount still to be settled',
        accent: const Color(0xFFFFB86C),
      ),
      _MetricCard(
        label: 'Paid total',
        value: _rwfCompact(paidAmount),
        detail: '$paidCount loans settled · $paidShare% of total amount',
        accent: AppColors.success,
      ),
      _MetricCard(
        label: 'Largest loan',
        value: largestLoan == null
            ? 'No entries'
            : _rwfCompact(largestLoan!.amount),
        detail: largestLoan?.label ?? 'Record your first loan',
        accent: _loanAccent,
      ),
      _MetricCard(
        label: 'Latest signal',
        value: latestLoan == null
            ? 'No entries'
            : _formatLongDate(latestLoan!.date),
        detail: latestLoan?.label ?? 'Latest borrowing activity',
        accent: _loanSecondary,
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

class _LoanEntriesPanel extends StatelessWidget {
  const _LoanEntriesPanel({
    required this.currentPage,
    required this.entries,
    required this.totalItems,
    required this.totalPages,
    required this.loadError,
    required this.paidBusyId,
    required this.onDelete,
    required this.onEdit,
    required this.onNextPage,
    required this.onPreviousPage,
    required this.onRetry,
    required this.onSendToExpense,
    required this.onTogglePaid,
  });

  final int currentPage;
  final List<LoanEntry> entries;
  final int totalItems;
  final int totalPages;
  final String? loadError;
  final String? paidBusyId;
  final void Function(LoanEntry entry) onDelete;
  final void Function(LoanEntry entry) onEdit;
  final Future<void> Function() onNextPage;
  final Future<void> Function() onPreviousPage;
  final Future<void> Function() onRetry;
  final void Function(LoanEntry entry) onSendToExpense;
  final Future<void> Function(LoanEntry entry) onTogglePaid;

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
                  'Loan entries',
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
            const _EmptyHint(message: 'No loans match these filters yet.')
          else
            Column(
              children: [
                for (var i = 0; i < entries.length; i++)
                  _LoanEntryTile(
                    entry: entries[i],
                    isBusy: paidBusyId == entries[i].id,
                    isLast: i == entries.length - 1,
                    onDelete: onDelete,
                    onEdit: onEdit,
                    onSendToExpense: onSendToExpense,
                    onTogglePaid: onTogglePaid,
                  ),
              ],
            ),
          if (loadError == null && entries.isNotEmpty && totalPages > 1) ...[
            const SizedBox(height: 16),
            const _GradientDivider(color: _loanAccent),
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
        color: _loanAccent.withValues(alpha: 0.08),
        border: Border.all(color: _loanAccent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Unable to load loans',
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
                color: _loanAccent.withValues(alpha: 0.12),
                border: Border.all(color: _loanAccent.withValues(alpha: 0.22)),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _loanAccent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoanEntryTile extends StatefulWidget {
  const _LoanEntryTile({
    required this.entry,
    required this.isBusy,
    required this.isLast,
    required this.onDelete,
    required this.onEdit,
    required this.onSendToExpense,
    required this.onTogglePaid,
  });

  final LoanEntry entry;
  final bool isBusy;
  final bool isLast;
  final void Function(LoanEntry entry) onDelete;
  final void Function(LoanEntry entry) onEdit;
  final void Function(LoanEntry entry) onSendToExpense;
  final Future<void> Function(LoanEntry entry) onTogglePaid;

  @override
  State<_LoanEntryTile> createState() => _LoanEntryTileState();
}

class _LoanEntryTileState extends State<_LoanEntryTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final creatorLabel = _resolveCreatorLabel(widget.entry);
    final amountColor = widget.entry.paid
        ? AppColors.success
        : const Color(0xFFFFB86C);

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
                    color: _loanAccent.withValues(alpha: 0.12),
                    border: Border.all(
                      color: _loanAccent.withValues(alpha: 0.18),
                    ),
                  ),
                  child: const Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedWallet03,
                      size: 18,
                      color: _loanAccent,
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
                      _rwfCompact(widget.entry.amount),
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
                              label: 'Amount',
                              value: _rwf(widget.entry.amount),
                            ),
                            _DetailItem(
                              label: 'Status',
                              value: widget.entry.paid ? 'Paid' : 'Unpaid',
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
                            _PaidChip(
                              isBusy: widget.isBusy,
                              paid: widget.entry.paid,
                              onTap: () => widget.onTogglePaid(widget.entry),
                            ),
                            _ActionIcon(
                              icon: HugeIcons.strokeRoundedMoneySendSquare,
                              color: _loanSecondary,
                              isDisabled: widget.entry.paid,
                              onTap: () => widget.onSendToExpense(widget.entry),
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

class _PaidChip extends StatelessWidget {
  const _PaidChip({
    required this.isBusy,
    required this.paid,
    required this.onTap,
  });

  final bool isBusy;
  final bool paid;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final accent = paid ? AppColors.success : const Color(0xFFFFB86C);

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
                paid ? 'Paid' : 'Unpaid',
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
    this.isDisabled = false,
  });

  final dynamic icon;
  final Color color;
  final VoidCallback onTap;
  final bool isDisabled;

  @override
  State<_ActionIcon> createState() => _ActionIconState();
}

class _ActionIconState extends State<_ActionIcon> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isDisabled
          ? null
          : (_) => setState(() => _pressed = true),
      onTapUp: widget.isDisabled
          ? null
          : (_) {
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
            color: widget.color.withValues(
              alpha: widget.isDisabled ? 0.05 : 0.12,
            ),
            border: Border.all(
              color: widget.color.withValues(
                alpha: widget.isDisabled ? 0.10 : 0.20,
              ),
            ),
          ),
          child: Center(
            child: HugeIcon(
              icon: widget.icon,
              size: 15,
              color: widget.isDisabled
                  ? widget.color.withValues(alpha: 0.45)
                  : widget.color,
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
              : _loanAccent.withValues(alpha: 0.12),
          border: Border.all(
            color: isDisabled
                ? Colors.white.withValues(alpha: 0.08)
                : _loanAccent.withValues(alpha: 0.20),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isDisabled
                ? AppColors.textSecondary.withValues(alpha: 0.36)
                : _loanAccent,
          ),
        ),
      ),
    );
  }
}

enum _LoanFormMode { create, edit }

class _LoanFormDialogStateData {
  const _LoanFormDialogStateData._({required this.mode, this.entry});

  const _LoanFormDialogStateData.create() : this._(mode: _LoanFormMode.create);

  const _LoanFormDialogStateData.edit(LoanEntry entry)
    : this._(mode: _LoanFormMode.edit, entry: entry);

  final _LoanFormMode mode;
  final LoanEntry? entry;
}

class _LoanFormValues {
  const _LoanFormValues({
    required this.label,
    required this.amount,
    required this.date,
    required this.paid,
    required this.note,
  });

  final String label;
  final String amount;
  final String date;
  final bool paid;
  final String note;

  _LoanFormValues copyWith({
    String? label,
    String? amount,
    String? date,
    bool? paid,
    String? note,
  }) {
    return _LoanFormValues(
      label: label ?? this.label,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      paid: paid ?? this.paid,
      note: note ?? this.note,
    );
  }
}

class _LoanSettlementFormValues {
  const _LoanSettlementFormValues({required this.date, required this.note});

  final String date;
  final String note;

  _LoanSettlementFormValues copyWith({String? date, String? note}) {
    return _LoanSettlementFormValues(
      date: date ?? this.date,
      note: note ?? this.note,
    );
  }
}

class _LoanFormDialog extends StatefulWidget {
  const _LoanFormDialog({
    required this.data,
    required this.form,
    required this.isSaving,
    required this.onChange,
    required this.onClose,
    required this.onSubmit,
  });

  final _LoanFormDialogStateData data;
  final _LoanFormValues form;
  final bool isSaving;
  final ValueChanged<_LoanFormValues> onChange;
  final VoidCallback onClose;
  final Future<void> Function() onSubmit;

  @override
  State<_LoanFormDialog> createState() => _LoanFormDialogState();
}

class _LoanFormDialogState extends State<_LoanFormDialog>
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
            primary: _loanAccent,
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
    final isEditing = widget.data.mode == _LoanFormMode.edit;
    final dateLabel = _formatLongDate(
      DateTime.tryParse(widget.form.date) ?? DateTime.now(),
    );

    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 470),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.15),
                      Colors.white.withValues(alpha: 0.08),
                    ],
                  ),
                  border: Border.all(
                    color: _loanAccent.withValues(alpha: 0.28),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
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
                              color: _loanAccent.withValues(alpha: 0.16),
                            ),
                            child: const Center(
                              child: HugeIcon(
                                icon: HugeIcons.strokeRoundedWallet03,
                                size: 18,
                                color: _loanAccent,
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
                                  isEditing ? 'Edit loan' : 'Add loan',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  isEditing
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
                          GestureDetector(
                            onTap: widget.isSaving ? null : widget.onClose,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.07),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                              ),
                              child: Center(
                                child: HugeIcon(
                                  icon: HugeIcons.strokeRoundedCancel01,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const _GradientDivider(color: _loanAccent),
                      const SizedBox(height: 24),
                      const _FieldLabel(label: 'Label'),
                      const SizedBox(height: 8),
                      _GlassField(
                        initialValue: widget.form.label,
                        hint: 'Car repair advance',
                        accent: _loanAccent,
                        onChanged: (value) =>
                            widget.onChange(widget.form.copyWith(label: value)),
                      ),
                      const SizedBox(height: 18),
                      const _FieldLabel(label: 'Amount (RWF)'),
                      const SizedBox(height: 8),
                      _GlassField(
                        initialValue: widget.form.amount,
                        hint: '250000',
                        accent: _loanAccent,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}$'),
                          ),
                        ],
                        onChanged: (value) => widget.onChange(
                          widget.form.copyWith(amount: value),
                        ),
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
                      const _FieldLabel(label: 'Settlement state'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _BooleanChoiceChip(
                            label: 'Unpaid',
                            isSelected: !widget.form.paid,
                            color: const Color(0xFFFFB86C),
                            onTap: () => widget.onChange(
                              widget.form.copyWith(paid: false),
                            ),
                          ),
                          _BooleanChoiceChip(
                            label: 'Paid',
                            isSelected: widget.form.paid,
                            color: AppColors.success,
                            onTap: () => widget.onChange(
                              widget.form.copyWith(paid: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const _FieldLabel(label: 'Note'),
                      const SizedBox(height: 8),
                      _GlassField(
                        initialValue: widget.form.note,
                        hint: 'Optional context for this loan',
                        accent: _loanAccent,
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
                              label: isEditing ? 'Save changes' : 'Add loan',
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
          ),
        ),
      ),
    );
  }
}

class _BooleanChoiceChip extends StatelessWidget {
  const _BooleanChoiceChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
            color: isSelected ? color : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _LoanSettlementDialog extends StatefulWidget {
  const _LoanSettlementDialog({
    required this.entry,
    required this.form,
    required this.isSaving,
    required this.onChange,
    required this.onClose,
    required this.onSubmit,
  });

  final LoanEntry entry;
  final _LoanSettlementFormValues form;
  final bool isSaving;
  final ValueChanged<_LoanSettlementFormValues> onChange;
  final VoidCallback onClose;
  final Future<void> Function() onSubmit;

  @override
  State<_LoanSettlementDialog> createState() => _LoanSettlementDialogState();
}

class _LoanSettlementDialogState extends State<_LoanSettlementDialog>
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
            primary: _loanAccent,
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
    final dateLabel = _formatLongDate(
      DateTime.tryParse(widget.form.date) ?? widget.entry.date,
    );

    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 470),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.15),
                      Colors.white.withValues(alpha: 0.08),
                    ],
                  ),
                  border: Border.all(
                    color: _loanSecondary.withValues(alpha: 0.28),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
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
                              color: _loanSecondary.withValues(alpha: 0.16),
                            ),
                            child: const Center(
                              child: HugeIcon(
                                icon: HugeIcons.strokeRoundedMoneySendSquare,
                                size: 18,
                                color: _loanSecondary,
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
                                  'Send to expense',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Settle this loan by creating a linked expense entry in the loan category.',
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
                          GestureDetector(
                            onTap: widget.isSaving ? null : widget.onClose,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.07),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                              ),
                              child: Center(
                                child: HugeIcon(
                                  icon: HugeIcons.strokeRoundedCancel01,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const _GradientDivider(color: _loanSecondary),
                      const SizedBox(height: 20),
                      _SummaryBlock(label: 'Loan', value: widget.entry.label),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _SummaryBlock(
                              label: 'Amount',
                              value: _rwf(widget.entry.amount),
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
                      const _FieldLabel(label: 'Expense date'),
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
                      const _FieldLabel(label: 'Expense note'),
                      const SizedBox(height: 8),
                      _GlassField(
                        initialValue: widget.form.note,
                        hint:
                            'Optional settlement note. Leave blank to reuse the loan note.',
                        accent: _loanSecondary,
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
                              label: 'Send to expense',
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
          ),
        ),
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
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 40,
            vertical: 24,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 380),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.14),
                      Colors.white.withValues(alpha: 0.08),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.3),
                  ),
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
                      'Remove loan entry?',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '"${widget.label}" will be permanently removed from your loan records.',
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
    final primaryColor = widget.isDanger ? AppColors.danger : _loanAccent;

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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: widget.isPrimary
                ? primaryColor.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: widget.isPrimary
                  ? primaryColor.withValues(alpha: 0.42)
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: widget.isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                )
              : Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: widget.isPrimary
                        ? primaryColor
                        : AppColors.textPrimary,
                  ),
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
            icon: HugeIcons.strokeRoundedWallet03,
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
          'Live loan sync · secured to your account session',
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
