import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_panel.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 700;

    return GlassPanel(
      padding: EdgeInsets.all(isCompact ? 22 : 32),
      borderRadius: BorderRadius.circular(34),
      blur: 28,
      opacity: 0.14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'History',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: isCompact ? 30 : 38,
              color: AppColors.textPrimary,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your completed and pending transfers will appear here.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              height: 1.55,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: const Color(0xFF111923),
              border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
            ),
            child: const Column(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedTransactionHistory,
                  size: 34,
                  color: AppColors.textPrimary,
                  strokeWidth: 1.7,
                ),
                SizedBox(height: 18),
                Text(
                  'No transfers yet',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Send money to someone and the transaction will show here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.textSecondary,
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
