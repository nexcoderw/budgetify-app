import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../features/auth/data/models/auth_user.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.user,
    required this.month,
    required this.year,
    required this.canGoNextMonth,
    required this.onPrevMonth,
    required this.onNextMonth,
  });

  final AuthUser user;
  final int month;
  final int year;
  final bool canGoNextMonth;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _firstName {
    final name = user.firstName ?? user.fullName ?? '';
    return name.split(' ').first;
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return month == now.month && year == now.year;
  }

  @override
  Widget build(BuildContext context) {
    final greetingContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$_greeting, $_firstName.',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _isCurrentMonth
              ? 'Here\'s your overview for this month.'
              : 'Reviewing ${_months[month - 1]} $year.',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );

    final monthNavigator = _MonthNavigator(
      label: '${_months[month - 1].substring(0, 3)} $year',
      onPrev: onPrevMonth,
      onNext: canGoNextMonth ? onNextMonth : null,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isStacked = constraints.maxWidth < 560;

        if (isStacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              greetingContent,
              const SizedBox(height: 12),
              monthNavigator,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: greetingContent),
            const SizedBox(width: 12),
            monthNavigator,
          ],
        );
      },
    );
  }
}

class _MonthNavigator extends StatelessWidget {
  const _MonthNavigator({
    required this.label,
    required this.onPrev,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _NavArrow(icon: HugeIcons.strokeRoundedArrowLeft01, onTap: onPrev),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                letterSpacing: 0.2,
              ),
            ),
          ),
          _NavArrow(icon: HugeIcons.strokeRoundedArrowRight01, onTap: onNext),
        ],
      ),
    );
  }
}

class _NavArrow extends StatefulWidget {
  const _NavArrow({required this.icon, required this.onTap});

  final dynamic icon;
  final VoidCallback? onTap;

  @override
  State<_NavArrow> createState() => _NavArrowState();
}

class _NavArrowState extends State<_NavArrow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.80 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: _pressed
                ? AppColors.primary.withValues(alpha: 0.20)
                : Colors.transparent,
          ),
          child: Center(
            child: HugeIcon(
              icon: widget.icon,
              size: 16,
              color: enabled
                  ? AppColors.textPrimary
                  : AppColors.textSecondary.withValues(alpha: 0.35),
              strokeWidth: 1.8,
            ),
          ),
        ),
      ),
    );
  }
}
