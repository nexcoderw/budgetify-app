import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/models/created_by_summary.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_modal_dialog.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../data/models/todo_item.dart';
import '../todo_utils.dart';

class TodoItemCard extends StatefulWidget {
  const TodoItemCard({
    super.key,
    required this.todo,
    required this.busyStatus,
    required this.busyRecordExpense,
    required this.onDelete,
    required this.onEdit,
    required this.onRecordExpense,
    required this.onToggleStatus,
  });

  final TodoItem todo;
  final bool busyStatus;
  final bool busyRecordExpense;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onRecordExpense;
  final VoidCallback onToggleStatus;

  @override
  State<TodoItemCard> createState() => _TodoItemCardState();
}

class _TodoItemCardState extends State<TodoItemCard> {
  bool _expanded = false;

  Future<void> _openRecordingDetails(TodoRecordingItem recording) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.68),
      builder: (dialogContext) => _TodoRecordingDetailsDialog(
        recording: recording,
        onClose: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final priorityColor = _priorityColor(widget.todo.priority);
    final recurring = isRecurringTodo(widget.todo);
    final canRecord = canRecordTodoExpense(widget.todo);
    final creator = _resolveCreatorLabel(widget.todo);
    final statusColor = _todoStatusColor(widget.todo.status);
    final latestRecording = widget.todo.recordings.isEmpty
        ? null
        : widget.todo.recordings.first;
    final remainingShare =
        recurring &&
            widget.todo.remainingAmount != null &&
            widget.todo.price > 0
        ? ((widget.todo.remainingAmount! / widget.todo.price) * 100)
              .clamp(0, 100)
              .round()
        : 0;

    return GlassPanel(
      padding: const EdgeInsets.all(18),
      borderRadius: BorderRadius.circular(24),
      blur: 22,
      opacity: 0.11,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PriorityDot(color: priorityColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MetaChip(
                          label: widget.todo.priority.label,
                          color: priorityColor,
                        ),
                        _MetaChip(
                          label: formatTodoFrequencyLabel(
                            widget.todo.frequency,
                          ),
                          color: AppColors.primary,
                        ),
                        _MetaChip(
                          label: resolveTodoStatusLabel(widget.todo.status),
                          color: statusColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.todo.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatTodoScheduleSummary(widget.todo),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary.withValues(alpha: 0.78),
                      ),
                    ),
                    if (creator != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Added by $creator',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary.withValues(
                            alpha: 0.56,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _rwf(widget.todo.price),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Updated ${formatTodoDate(widget.todo.updatedAt)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary.withValues(alpha: 0.56),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (widget.todo.primaryImage?.imageUrl != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  widget.todo.primaryImage!.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppColors.surfaceElevated,
                    child: const Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedImageNotFound01,
                        size: 24,
                        color: AppColors.textSecondary,
                        strokeWidth: 1.8,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (recurring) ...[
            const SizedBox(height: 14),
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
                      Text(
                        'Remaining budget',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary.withValues(
                            alpha: 0.64,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _rwf(widget.todo.remainingAmount ?? 0),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: remainingShare / 100,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (latestRecording != null) ...[
            const SizedBox(height: 14),
            _LatestRecordingPanel(
              recording: latestRecording,
              onTap: () => _openRecordingDetails(latestRecording),
            ),
          ],
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Text(
                  _expanded ? 'Hide details' : 'Show details',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary.withValues(alpha: 0.84),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowDown01,
                    size: 14,
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                    strokeWidth: 1.8,
                  ),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.todo.startDate != null ||
                      widget.todo.endDate != null)
                    Text(
                      recurring
                          ? 'Window: ${widget.todo.startDate == null ? 'Now' : formatTodoDate(widget.todo.startDate!)} - ${widget.todo.endDate == null ? 'Open' : formatTodoDate(widget.todo.endDate!)}'
                          : 'Planned for ${widget.todo.startDate == null ? 'today' : formatTodoDate(widget.todo.startDate!)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary.withValues(alpha: 0.72),
                      ),
                    ),
                  if (widget.todo.frequency == TodoFrequency.weekly &&
                      widget.todo.frequencyDays.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: widget.todo.frequencyDays
                          .map(
                            (day) => _SubtlePill(label: todoWeekdayLabels[day]),
                          )
                          .toList(growable: false),
                    ),
                  ],
                  if (widget.todo.frequency != TodoFrequency.once &&
                      widget.todo.occurrenceDates.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: getRemainingOccurrenceDates(widget.todo)
                          .take(4)
                          .map(
                            (date) => _SubtlePill(
                              label: formatTodoDate(parseDateOnly(date)),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                  if (widget.todo.recordings.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _RecordingHistoryList(
                      recordings: widget.todo.recordings
                          .take(5)
                          .toList(growable: false),
                      onOpenRecording: _openRecordingDetails,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionButton(
                label: widget.busyRecordExpense
                    ? 'Recording...'
                    : canRecord
                    ? 'Record expense'
                    : recurring
                    ? 'No budget left'
                    : 'Recorded',
                icon: HugeIcons.strokeRoundedMoneySendSquare,
                color: AppColors.primary,
                disabled: widget.busyRecordExpense || !canRecord,
                onTap: widget.onRecordExpense,
              ),
              _ActionButton(
                label: widget.busyStatus
                    ? 'Updating...'
                    : isClosedTodoStatus(widget.todo.status)
                    ? 'Reopen'
                    : 'Mark completed',
                icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                color: isClosedTodoStatus(widget.todo.status)
                    ? const Color(0xFFFFB86C)
                    : AppColors.success,
                disabled: widget.busyStatus,
                onTap: widget.onToggleStatus,
              ),
              _ActionButton(
                label: 'Edit',
                icon: HugeIcons.strokeRoundedTaskEdit01,
                color: const Color(0xFF7EB8FF),
                onTap: widget.onEdit,
              ),
              _ActionButton(
                label: 'Delete',
                icon: HugeIcons.strokeRoundedDelete02,
                color: AppColors.danger,
                onTap: widget.onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String? _resolveCreatorLabel(TodoItem entry) {
    final creator = entry.createdBy;
    if (creator == null) {
      return null;
    }

    final firstName = creator.firstName?.trim();
    final lastName = creator.lastName?.trim();
    final fullName = <String>[
      if (firstName != null && firstName.isNotEmpty) firstName,
      if (lastName != null && lastName.isNotEmpty) lastName,
    ].join(' ');

    return fullName.isEmpty ? 'partner' : fullName;
  }
}

class _LatestRecordingPanel extends StatelessWidget {
  const _LatestRecordingPanel({required this.recording, required this.onTap});

  final TodoRecordingItem recording;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final varianceColor = _varianceColor(recording.varianceAmount);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: AppColors.primary.withValues(alpha: 0.08),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const HugeIcon(
                  icon: HugeIcons.strokeRoundedInvoice03,
                  size: 16,
                  color: AppColors.primary,
                  strokeWidth: 1.8,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Latest recording',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  formatTodoDate(parseDateOnly(recording.occurrenceDate)),
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 8),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  size: 14,
                  color: AppColors.primary.withValues(alpha: 0.8),
                  strokeWidth: 1.8,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _AuditAmountTile(
                  label: 'Plan',
                  value: _rwf(recording.plannedAmount),
                ),
                _AuditAmountTile(
                  label: 'Charged',
                  value: _rwf(recording.totalChargedAmount),
                  valueColor: AppColors.primary,
                ),
                _AuditAmountTile(
                  label: 'Fee',
                  value: _rwf(recording.feeAmount),
                ),
                _AuditAmountTile(
                  label: 'Variance',
                  value: _rwf(recording.varianceAmount),
                  valueColor: varianceColor,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _recordingPaymentSummary(recording),
              style: TextStyle(
                fontSize: 11,
                height: 1.45,
                color: AppColors.textSecondary.withValues(alpha: 0.74),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingHistoryList extends StatelessWidget {
  const _RecordingHistoryList({
    required this.recordings,
    required this.onOpenRecording,
  });

  final List<TodoRecordingItem> recordings;
  final void Function(TodoRecordingItem recording) onOpenRecording;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text(
            'Recording history',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary.withValues(alpha: 0.84),
            ),
          ),
          const SizedBox(height: 10),
          ...recordings.map(
            (recording) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RecordingHistoryRow(
                recording: recording,
                onTap: () => onOpenRecording(recording),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordingHistoryRow extends StatelessWidget {
  const _RecordingHistoryRow({required this.recording, required this.onTap});

  final TodoRecordingItem recording;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.black.withValues(alpha: 0.12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatTodoDate(parseDateOnly(recording.occurrenceDate)),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  _rwf(recording.totalChargedAmount),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  size: 13,
                  color: AppColors.textSecondary.withValues(alpha: 0.62),
                  strokeWidth: 1.8,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _SubtlePill(label: 'Plan ${_rwf(recording.plannedAmount)}'),
                _SubtlePill(label: 'Base ${_rwf(recording.baseAmount)}'),
                _SubtlePill(label: 'Fee ${_rwf(recording.feeAmount)}'),
                _SubtlePill(
                  label: 'Variance ${_rwf(recording.varianceAmount)}',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _recordingPaymentSummary(recording),
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary.withValues(alpha: 0.68),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodoRecordingDetailsDialog extends StatelessWidget {
  const _TodoRecordingDetailsDialog({
    required this.recording,
    required this.onClose,
  });

  final TodoRecordingItem recording;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final expense = recording.expense;
    final recorder = _createdByLabel(recording.recordedBy) ?? 'Unknown';

    return AppModalDialog(
      maxWidth: 560,
      padding: const EdgeInsets.all(24),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: SingleChildScrollView(
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
                    color: AppColors.primary.withValues(alpha: 0.16),
                  ),
                  child: const Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedInvoice03,
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
                      const Text(
                        'Recording details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatTodoDate(parseDateOnly(recording.occurrenceDate)),
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
                AppModalCloseButton(onTap: onClose),
              ],
            ),
            const SizedBox(height: 18),
            const _GradientDivider(color: AppColors.primary),
            const SizedBox(height: 18),
            _RecordingDetailsSection(
              title: 'Linked expense',
              children: [
                _DetailsRow(label: 'Label', value: expense?.label ?? 'Missing'),
                _DetailsRow(
                  label: 'Category',
                  value: expense?.category.displayName ?? 'Not available',
                ),
                _DetailsRow(
                  label: 'Expense date',
                  value: expense == null
                      ? 'Not available'
                      : formatTodoDate(expense.date),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _RecordingDetailsSection(
              title: 'Amount audit',
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _AuditAmountTile(
                      label: 'Plan',
                      value: _rwf(recording.plannedAmount),
                    ),
                    _AuditAmountTile(
                      label: 'Base',
                      value: _rwf(recording.baseAmount),
                    ),
                    _AuditAmountTile(
                      label: 'Fee',
                      value: _rwf(recording.feeAmount),
                    ),
                    _AuditAmountTile(
                      label: 'Charged',
                      value: _rwf(recording.totalChargedAmount),
                      valueColor: AppColors.primary,
                    ),
                    _AuditAmountTile(
                      label: 'Variance',
                      value: _rwf(recording.varianceAmount),
                      valueColor: _varianceColor(recording.varianceAmount),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            _RecordingDetailsSection(
              title: 'Payment',
              children: [
                _DetailsRow(
                  label: 'Method',
                  value: recording.paymentMethod.displayName,
                ),
                _DetailsRow(
                  label: 'Channel',
                  value:
                      recording.mobileMoneyChannel?.displayName ??
                      'Not applicable',
                ),
                _DetailsRow(
                  label: 'Network',
                  value:
                      recording.mobileMoneyNetwork?.displayName ??
                      'Not applicable',
                ),
              ],
            ),
            const SizedBox(height: 14),
            _RecordingDetailsSection(
              title: 'Recorded by',
              children: [
                _DetailsRow(label: 'Person', value: recorder),
                _DetailsRow(
                  label: 'Timestamp',
                  value: _formatDateTime(recording.recordedAt),
                ),
                _DetailsRow(
                  label: 'Recording ID',
                  value: recording.id,
                  compact: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingDetailsSection extends StatelessWidget {
  const _RecordingDetailsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.primary.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _DetailsRow extends StatelessWidget {
  const _DetailsRow({
    required this.label,
    required this.value,
    this.compact = false,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary.withValues(alpha: 0.68),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: compact ? 10 : 12,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
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
            color.withValues(alpha: 0.45),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _AuditAmountTile extends StatelessWidget {
  const _AuditAmountTile({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 112),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.black.withValues(alpha: 0.13),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: AppColors.textSecondary.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityDot extends StatelessWidget {
  const _PriorityDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _SubtlePill extends StatelessWidget {
  const _SubtlePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: AppColors.textSecondary.withValues(alpha: 0.78),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.disabled = false,
  });

  final String label;
  final dynamic icon;
  final Color color;
  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: disabled
              ? Colors.white.withValues(alpha: 0.04)
              : color.withValues(alpha: 0.14),
          border: Border.all(
            color: disabled
                ? Colors.white.withValues(alpha: 0.10)
                : color.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: icon,
              size: 13,
              color: disabled ? AppColors.textSecondary : color,
              strokeWidth: 1.8,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: disabled ? AppColors.textSecondary : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _priorityColor(TodoPriority priority) => switch (priority) {
  TodoPriority.topPriority => AppColors.danger,
  TodoPriority.priority => AppColors.primary,
  TodoPriority.notPriority => AppColors.success,
};

Color _todoStatusColor(TodoStatus status) => switch (status) {
  TodoStatus.active => const Color(0xFFFFB86C),
  TodoStatus.recorded => AppColors.primary,
  TodoStatus.completed => AppColors.success,
  TodoStatus.skipped => AppColors.danger,
  TodoStatus.archived => AppColors.textSecondary,
};

Color _varianceColor(double amount) {
  if (amount > 0) {
    return AppColors.danger;
  }

  if (amount < 0) {
    return AppColors.success;
  }

  return AppColors.textPrimary;
}

String _recordingPaymentSummary(TodoRecordingItem recording) {
  final details = <String>[recording.paymentMethod.displayName];

  if (recording.mobileMoneyChannel != null) {
    details.add(recording.mobileMoneyChannel!.displayName);
  }

  if (recording.mobileMoneyNetwork != null) {
    details.add(recording.mobileMoneyNetwork!.displayName);
  }

  final expenseLabel = recording.expense?.label.trim();
  if (expenseLabel != null && expenseLabel.isNotEmpty) {
    details.add(expenseLabel);
  }

  return details.join(' · ');
}

String? _createdByLabel(CreatedBySummary? creator) {
  if (creator == null) {
    return null;
  }

  final firstName = creator.firstName?.trim();
  final lastName = creator.lastName?.trim();
  final fullName = <String>[
    if (firstName != null && firstName.isNotEmpty) firstName,
    if (lastName != null && lastName.isNotEmpty) lastName,
  ].join(' ');

  return fullName.isEmpty ? null : fullName;
}

String _formatDateTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');

  return '${formatTodoDate(value)} at $hour:$minute';
}

String _rwf(double amount) {
  final formatted = amount
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  return 'RWF $formatted';
}
