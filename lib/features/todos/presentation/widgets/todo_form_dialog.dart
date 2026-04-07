import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../data/models/todo_item.dart';
import '../../data/models/todo_upload_image.dart';
import '../todo_utils.dart';

const int _maxTodoImages = 6;

class TodoFormDialog extends StatefulWidget {
  const TodoFormDialog({super.key, required this.onSubmit, this.todo});

  final TodoItem? todo;
  final Future<TodoItem> Function({
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
  })
  onSubmit;

  @override
  State<TodoFormDialog> createState() => _TodoFormDialogState();
}

class _TodoFormDialogState extends State<TodoFormDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;

  late TodoPriority _priority;
  late bool _done;
  late TodoFrequency _frequency;
  late String _startDate;
  late String _endDate;
  late List<int> _frequencyDays;
  late List<String> _occurrenceDates;
  String? _selectedPrimaryImageId;
  List<TodoUploadImage> _newImages = const <TodoUploadImage>[];
  bool _isSubmitting = false;
  bool _isLoadingImages = false;
  String? _errorText;

  bool get _isEditing => widget.todo != null;
  List<TodoImageItem> get _existingImages => widget.todo?.images ?? const [];

  @override
  void initState() {
    super.initState();
    final todo = widget.todo;
    final defaultStartDate = todo?.startDate != null
        ? formatDateOnly(todo!.startDate!)
        : getTodayDateValue();
    final initialFrequency = todo?.frequency ?? TodoFrequency.once;
    final initialOccurrenceDates = todo == null
        ? <String>[defaultStartDate]
        : (todo.occurrenceDates.isEmpty
              ? <String>[defaultStartDate]
              : todo.occurrenceDates);

    _nameCtrl = TextEditingController(text: todo?.name ?? '');
    _priceCtrl = TextEditingController(
      text: todo == null ? '' : todo.price.toStringAsFixed(0),
    );
    _priority = todo?.priority ?? TodoPriority.topPriority;
    _done = todo?.done ?? false;
    _frequency = initialFrequency;
    _startDate = defaultStartDate;
    _endDate = computeTodoEndDate(_startDate, _frequency);
    _frequencyDays = todo?.frequencyDays.toList(growable: true) ?? <int>[];
    _occurrenceDates = buildTodoOccurrenceDates(
      frequency: _frequency,
      startDate: _startDate,
      endDate: _endDate,
      frequencyDays: _frequencyDays,
      occurrenceDates: initialOccurrenceDates,
    ).toList(growable: true);
    _selectedPrimaryImageId = todo?.primaryImage?.id;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _scale = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 620),
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
                    color: AppColors.primary.withValues(alpha: 0.28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 48,
                      offset: const Offset(0, 20),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
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
                                color: AppColors.primary.withValues(
                                  alpha: 0.16,
                                ),
                              ),
                              child: Center(
                                child: HugeIcon(
                                  icon: _isEditing
                                      ? HugeIcons.strokeRoundedPencil
                                      : HugeIcons.strokeRoundedTaskAdd01,
                                  size: 18,
                                  color: AppColors.primary,
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
                                    _isEditing
                                        ? 'Edit todo item'
                                        : 'Add todo item',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Plan the budget, choose the schedule, and keep the item visually grounded with images.',
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
                              onTap: _isSubmitting
                                  ? null
                                  : () => Navigator.of(context).pop(),
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
                        const _GradientDivider(color: AppColors.primary),
                        const SizedBox(height: 24),
                        _FieldLabel(label: 'Todo name'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameCtrl,
                          textCapitalization: TextCapitalization.sentences,
                          validator: (value) {
                            final normalized = value?.trim() ?? '';
                            if (normalized.isEmpty) {
                              return 'Enter a todo name.';
                            }
                            if (normalized.length > 120) {
                              return 'Keep the name under 120 characters.';
                            }
                            return null;
                          },
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                          decoration: _inputDecoration(
                            hint: 'Renew annual car insurance',
                          ),
                        ),
                        const SizedBox(height: 16),
                        _FieldLabel(label: 'Planned budget (RWF)'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}$'),
                            ),
                          ],
                          validator: (value) {
                            final amount = double.tryParse(value?.trim() ?? '');
                            if (amount == null || amount <= 0) {
                              return 'Enter an amount greater than zero.';
                            }
                            return null;
                          },
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                          decoration: _inputDecoration(hint: '85000'),
                        ),
                        const SizedBox(height: 16),
                        _FieldLabel(label: 'Priority'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: TodoPriority.values
                              .map(
                                (priority) => _ChoiceChipButton(
                                  label: priority.label,
                                  selected: _priority == priority,
                                  color: _priorityColor(priority),
                                  onTap: () =>
                                      setState(() => _priority = priority),
                                ),
                              )
                              .toList(growable: false),
                        ),
                        const SizedBox(height: 16),
                        _FieldLabel(label: 'Status'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _ChoiceChipButton(
                              label: 'Open',
                              selected: !_done,
                              color: const Color(0xFFFFB86C),
                              onTap: () => setState(() => _done = false),
                            ),
                            _ChoiceChipButton(
                              label: 'Done',
                              selected: _done,
                              color: AppColors.success,
                              onTap: () => setState(() => _done = true),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _FieldLabel(label: 'How often will this happen?'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: TodoFrequency.values
                              .map(
                                (frequency) => _ChoiceChipButton(
                                  label: frequency.label,
                                  selected: _frequency == frequency,
                                  color: AppColors.primary,
                                  onTap: () =>
                                      _applySchedulePatch(frequency: frequency),
                                ),
                              )
                              .toList(growable: false),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _DateTile(
                                label: 'Start date',
                                value: formatTodoDate(
                                  parseDateOnly(_startDate),
                                ),
                                onTap: _pickStartDate,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _DateTile(
                                label: 'End date',
                                value: formatTodoDate(parseDateOnly(_endDate)),
                              ),
                            ),
                          ],
                        ),
                        if (_frequency == TodoFrequency.weekly) ...[
                          const SizedBox(height: 16),
                          _FieldLabel(label: 'Select the weekdays'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: todoWeekdayValues
                                .map(
                                  (day) => _ChoiceChipButton(
                                    label: todoWeekdayLabels[day],
                                    selected: _frequencyDays.contains(day),
                                    color: AppColors.primary,
                                    onTap: () {
                                      final next = <int>[..._frequencyDays];
                                      if (next.contains(day)) {
                                        next.remove(day);
                                      } else {
                                        next.add(day);
                                      }
                                      _applySchedulePatch(frequencyDays: next);
                                    },
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ],
                        if (_frequency == TodoFrequency.monthly ||
                            _frequency == TodoFrequency.yearly) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Expanded(
                                child: _FieldLabel(
                                  label: 'Select occurrence dates',
                                ),
                              ),
                              TextButton(
                                onPressed: _pickOccurrenceDate,
                                child: const Text('Add date'),
                              ),
                            ],
                          ),
                          if (_occurrenceDates.isEmpty)
                            Text(
                              'Pick at least one occurrence date inside the schedule window.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.72,
                                ),
                              ),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _occurrenceDates
                                  .map(
                                    (date) => _OccurrenceChip(
                                      label: formatTodoDate(
                                        parseDateOnly(date),
                                      ),
                                      onRemove: () {
                                        final next = <String>[
                                          ..._occurrenceDates,
                                        ]..remove(date);
                                        _applySchedulePatch(
                                          occurrenceDates: next,
                                        );
                                      },
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                        ],
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: Colors.white.withValues(alpha: 0.04),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Text(
                            _frequency == TodoFrequency.once
                                ? 'One occurrence planned.'
                                : '${_occurrenceDates.length} occurrence${_occurrenceDates.length == 1 ? '' : 's'} planned between ${formatTodoDate(parseDateOnly(_startDate))} and ${formatTodoDate(parseDateOnly(_endDate))}.',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.45,
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.74,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _PhotosSection(
                          existingImages: _existingImages,
                          newImages: _newImages,
                          selectedPrimaryImageId: _selectedPrimaryImageId,
                          isSubmitting: _isSubmitting,
                          isLoadingImages: _isLoadingImages,
                          onAddTap: _pickImages,
                          onRemoveNew: (index) {
                            setState(() {
                              _newImages = <TodoUploadImage>[..._newImages]
                                ..removeAt(index);
                            });
                          },
                          onSelectPrimary: (imageId) =>
                              setState(() => _selectedPrimaryImageId = imageId),
                        ),
                        if (_errorText != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _errorText!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.danger,
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
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
                                label: _isEditing
                                    ? 'Save changes'
                                    : 'Create todo',
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
          ),
        ),
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final initialDate = parseDateOnly(_startDate);
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

    _applySchedulePatch(startDate: formatDateOnly(picked));
  }

  Future<void> _pickOccurrenceDate() async {
    final firstDate = parseDateOnly(_startDate);
    final lastDate = parseDateOnly(_endDate).subtract(const Duration(days: 1));
    final initialDate = _occurrenceDates.isEmpty
        ? firstDate
        : parseDateOnly(_occurrenceDates.last);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate) ? firstDate : initialDate,
      firstDate: firstDate,
      lastDate: lastDate.isBefore(firstDate) ? firstDate : lastDate,
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

    _applySchedulePatch(
      occurrenceDates: <String>[..._occurrenceDates, formatDateOnly(picked)],
    );
  }

  void _applySchedulePatch({
    TodoFrequency? frequency,
    String? startDate,
    List<int>? frequencyDays,
    List<String>? occurrenceDates,
  }) {
    final nextFrequency = frequency ?? _frequency;
    final nextStartDate = startDate ?? _startDate;
    final nextEndDate = computeTodoEndDate(nextStartDate, nextFrequency);
    final nextFrequencyDays = sortNumberValues(
      frequencyDays ?? _frequencyDays,
    ).toList(growable: true);
    final nextOccurrenceDates = buildTodoOccurrenceDates(
      frequency: nextFrequency,
      startDate: nextStartDate,
      endDate: nextEndDate,
      frequencyDays: nextFrequencyDays,
      occurrenceDates: occurrenceDates ?? _occurrenceDates,
    ).toList(growable: true);

    setState(() {
      _frequency = nextFrequency;
      _startDate = nextStartDate;
      _endDate = nextEndDate;
      _frequencyDays = nextFrequency == TodoFrequency.weekly
          ? nextFrequencyDays
          : <int>[];
      _occurrenceDates = nextOccurrenceDates;
    });
  }

  Future<void> _pickImages() async {
    final remainingSlots =
        _maxTodoImages - _existingImages.length - _newImages.length;
    if (remainingSlots <= 0) {
      AppToast.info(
        context,
        title: 'Image limit reached',
        description: 'A todo item can keep up to $_maxTodoImages images.',
      );
      return;
    }

    try {
      final files = await _picker.pickMultiImage(imageQuality: 85);
      if (files.isEmpty || !mounted) {
        return;
      }

      setState(() => _isLoadingImages = true);

      final uploads = <TodoUploadImage>[];
      for (final file in files.take(remainingSlots)) {
        uploads.add(
          TodoUploadImage(
            filename: file.name,
            mimeType: _inferMimeType(file.name),
            bytes: await file.readAsBytes(),
          ),
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _newImages = <TodoUploadImage>[..._newImages, ...uploads];
        _isLoadingImages = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _isLoadingImages = false);
      AppToast.error(
        context,
        title: 'Unable to pick images',
        description: _readableError(error),
      );
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_frequency == TodoFrequency.weekly && _frequencyDays.isEmpty) {
      setState(() {
        _errorText = 'Select at least one weekday for a weekly todo.';
      });
      return;
    }

    if (_frequency != TodoFrequency.once && _occurrenceDates.isEmpty) {
      setState(() {
        _errorText = 'Select at least one occurrence date for this schedule.';
      });
      return;
    }

    final price = double.parse(_priceCtrl.text.trim());

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final todo = await widget.onSubmit(
        name: _nameCtrl.text.trim(),
        price: price,
        priority: _priority,
        done: _done,
        frequency: _frequency,
        startDate: _startDate,
        endDate: _endDate,
        frequencyDays: _frequencyDays,
        occurrenceDates: _occurrenceDates,
        primaryImageId: _selectedPrimaryImageId,
        newImages: _newImages,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(todo);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
        _errorText = _readableError(error);
      });
    }
  }

  String _inferMimeType(String filename) {
    final extension = filename.toLowerCase().split('.').last;
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
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

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 13,
        color: AppColors.textSecondary.withValues(alpha: 0.45),
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
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
          color: AppColors.primary.withValues(alpha: 0.42),
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
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _ChoiceChipButton extends StatelessWidget {
  const _ChoiceChipButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected
              ? color.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.28)
                : Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? color : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
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
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OccurrenceChip extends StatelessWidget {
  const _OccurrenceChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close_rounded,
              size: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotosSection extends StatelessWidget {
  const _PhotosSection({
    required this.existingImages,
    required this.newImages,
    required this.selectedPrimaryImageId,
    required this.isSubmitting,
    required this.isLoadingImages,
    required this.onAddTap,
    required this.onRemoveNew,
    required this.onSelectPrimary,
  });

  final List<TodoImageItem> existingImages;
  final List<TodoUploadImage> newImages;
  final String? selectedPrimaryImageId;
  final bool isSubmitting;
  final bool isLoadingImages;
  final VoidCallback onAddTap;
  final ValueChanged<int> onRemoveNew;
  final ValueChanged<String> onSelectPrimary;

  @override
  Widget build(BuildContext context) {
    final totalCount = existingImages.length + newImages.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _FieldLabel(label: 'Photos'),
            const Spacer(),
            Text(
              '$totalCount / $_maxTodoImages selected',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withValues(alpha: 0.04),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add reference images. Tap an existing image to make it the cover.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.45,
                        color: AppColors.textSecondary.withValues(alpha: 0.74),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: isSubmitting || totalCount >= _maxTodoImages
                        ? null
                        : onAddTap,
                    child: Text(isLoadingImages ? 'Loading…' : 'Add photos'),
                  ),
                ],
              ),
              if (existingImages.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 84,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: existingImages.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final image = existingImages[index];
                      return GestureDetector(
                        onTap: () => onSelectPrimary(image.id),
                        child: Container(
                          width: 84,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selectedPrimaryImageId == image.id
                                  ? AppColors.primary
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: Image.network(
                              image.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(color: AppColors.surfaceElevated),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (newImages.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 84,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: newImages.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) => _PendingImageTile(
                      bytes: newImages[index].bytes,
                      onRemove: () => onRemoveNew(index),
                    ),
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

class _PendingImageTile extends StatelessWidget {
  const _PendingImageTile({required this.bytes, required this.onRemove});

  final Uint8List bytes;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.memory(bytes, width: 84, height: 84, fit: BoxFit.cover),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.danger,
              ),
              child: const Icon(Icons.close_rounded, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}

Color _priorityColor(TodoPriority priority) => switch (priority) {
  TodoPriority.topPriority => AppColors.danger,
  TodoPriority.priority => AppColors.primary,
  TodoPriority.notPriority => AppColors.success,
};

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
            color.withValues(alpha: 0.45),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.onTap,
    required this.isPrimary,
    this.isLoading = false,
    this.isDisabled = false,
  });

  final String label;
  final Future<void> Function() onTap;
  final bool isPrimary;
  final bool isLoading;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isPrimary
        ? AppColors.primary.withValues(alpha: isDisabled ? 0.12 : 0.16)
        : Colors.white.withValues(alpha: 0.05);
    final borderColor = isPrimary
        ? AppColors.primary.withValues(alpha: isDisabled ? 0.16 : 0.24)
        : Colors.white.withValues(alpha: 0.12);
    final foregroundColor = isPrimary
        ? (isDisabled
              ? AppColors.primary.withValues(alpha: 0.55)
              : AppColors.primary)
        : (isDisabled
              ? AppColors.textSecondary.withValues(alpha: 0.45)
              : AppColors.textPrimary);

    return GestureDetector(
      onTap: isDisabled || isLoading ? null : () => onTap(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: backgroundColor,
          border: Border.all(color: borderColor),
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: foregroundColor,
                  ),
                ),
        ),
      ),
    );
  }
}
