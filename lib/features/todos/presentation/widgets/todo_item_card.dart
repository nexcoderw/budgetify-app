import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../data/models/todo_item.dart';
import '../todo_utils.dart';

class TodoItemCard extends StatefulWidget {
  const TodoItemCard({
    super.key,
    required this.todo,
    required this.busyDone,
    required this.busyRecordExpense,
    required this.onDelete,
    required this.onEdit,
    required this.onRecordExpense,
    required this.onToggleDone,
  });

  final TodoItem todo;
  final bool busyDone;
  final bool busyRecordExpense;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onRecordExpense;
  final VoidCallback onToggleDone;

  @override
  State<TodoItemCard> createState() => _TodoItemCardState();
}

class _TodoItemCardState extends State<TodoItemCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final priorityColor = _priorityColor(widget.todo.priority);
    final recurring = isRecurringTodo(widget.todo);
    final canRecord = canRecordTodoExpense(widget.todo);
    final creator = _resolveCreatorLabel(widget.todo);
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
                          label: widget.todo.done ? 'Done' : 'Open',
                          color: widget.todo.done
                              ? AppColors.success
                              : const Color(0xFFFFB86C),
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
                label: widget.busyDone
                    ? 'Updating...'
                    : widget.todo.done
                    ? 'Mark open'
                    : 'Mark done',
                icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                color: widget.todo.done
                    ? const Color(0xFFFFB86C)
                    : AppColors.success,
                disabled: widget.busyDone,
                onTap: widget.onToggleDone,
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

String _rwf(double amount) {
  final formatted = amount
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  return 'RWF $formatted';
}
