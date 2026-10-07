import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';

enum HistoryTab { transactions, insights }

class HistoryHeader extends StatelessWidget {
  const HistoryHeader({
    super.key,
    required this.selectedTab,
    required this.onTabSelected,
    required this.onRefresh,
    this.onRecordReceived,
  });

  final HistoryTab selectedTab;
  final ValueChanged<HistoryTab> onTabSelected;
  final VoidCallback onRefresh;
  final VoidCallback? onRecordReceived;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                for (final tab in HistoryTab.values)
                  Expanded(
                    child: Semantics(
                      selected: selectedTab == tab,
                      child: TextButton(
                        onPressed: () => onTabSelected(tab),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          backgroundColor: selectedTab == tab
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : Colors.transparent,
                          foregroundColor: selectedTab == tab
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        child: Text(
                          tab == HistoryTab.transactions
                              ? 'Transactions'
                              : 'Insights',
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          tooltip: 'History actions',
          icon: const Icon(Icons.more_horiz_rounded, color: AppColors.textPrimary),
          onSelected: (action) {
            if (action == 'refresh') {
              onRefresh();
            } else {
              onRecordReceived?.call();
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'refresh', child: Text('Refresh')),
            if (onRecordReceived != null)
              const PopupMenuItem(
                value: 'record',
                child: Text('Record received money'),
              ),
          ],
        ),
      ],
    );
  }
}
