import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/app_dropdown.dart';

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
        AppDropdown<String>(
          tooltip: 'History actions',
          icon: Icons.more_horiz_rounded,
          onSelected: (action) {
            if (action == 'refresh') {
              onRefresh();
            } else {
              onRecordReceived?.call();
            }
          },
          items: [
            const AppDropdownItem(
              value: 'refresh',
              label: 'Refresh',
              icon: Icons.refresh_rounded,
            ),
            if (onRecordReceived != null)
              const AppDropdownItem(
                value: 'record',
                label: 'Record received money',
                icon: Icons.south_west_rounded,
              ),
          ],
        ),
      ],
    );
  }
}
