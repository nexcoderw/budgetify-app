import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_input.dart';
import '../../../home/presentation/widgets/record_received_money/received_date_sheet.dart';

enum IncomePeriod {
  thisMonth('This month'),
  lastWeek('Last week'),
  lastMonth('Last month'),
  custom('Custom');

  const IncomePeriod(this.label);
  final String label;
}

class IncomePeriodFilter extends StatelessWidget {
  const IncomePeriodFilter({
    super.key,
    required this.period,
    required this.from,
    required this.to,
    required this.enabled,
    required this.onPeriodSelected,
    required this.onDateSelected,
  });

  final IncomePeriod period;
  final DateTime from;
  final DateTime to;
  final bool enabled;
  final ValueChanged<IncomePeriod> onPeriodSelected;
  final void Function(bool isFrom, DateTime date) onDateSelected;

  Future<void> _pick(BuildContext context, bool isFrom) async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final date = await showModalBottomSheet<DateTime>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReceivedDateSheet(
        initialDate: isFrom ? from : to,
        firstYear: now.year - 10,
        lastDate: DateTime(now.year + 10, 12, 31),
      ),
    );
    if (!context.mounted || date == null) {
      return;
    }
    onDateSelected(isFrom, DateTime(date.year, date.month, date.day));
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final option in IncomePeriod.values)
            ChoiceChip(
              label: Text(option.label),
              selected: period == option,
              onSelected: enabled ? (_) => onPeriodSelected(option) : null,
              showCheckmark: false,
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.primary,
              side: BorderSide.none,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: period == option
                    ? AppColors.background
                    : AppColors.textSecondary,
              ),
              materialTapTargetSize: MaterialTapTargetSize.padded,
            ),
        ],
      ),
      if (period == IncomePeriod.custom) ...[
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final fields = [
            _DateField(label: 'From date', date: from,
              onTap: enabled ? () => _pick(context, true) : null),
            _DateField(label: 'To date', date: to,
              onTap: enabled ? () => _pick(context, false) : null),
          ];
          if (constraints.maxWidth < 420) {
            return Column(children: [
              fields[0], const SizedBox(height: 12), fields[1],
            ]);
          }
          return Row(children: [
            Expanded(child: fields[0]),
            const SizedBox(width: 12),
            Expanded(child: fields[1]),
          ]);
        }),
      ],
      const SizedBox(height: 12),
      Text(
        '${formatReceivedDate(from)} – ${formatReceivedDate(to)}',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
    ],
  );
}

class _DateField extends StatefulWidget {
  const _DateField({required this.label, required this.date, this.onTap});
  final String label;
  final DateTime date;
  final VoidCallback? onTap;

  @override
  State<_DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<_DateField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: formatReceivedDate(widget.date));
  }

  @override
  void didUpdateWidget(covariant _DateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date) {
      _controller.text = formatReceivedDate(widget.date);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppInput(
    controller: _controller,
    label: widget.label,
    readOnly: true,
    enabled: widget.onTap != null,
    borderRadius: 28,
    onTap: widget.onTap,
    suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded,
      color: AppColors.primary),
  );
}
