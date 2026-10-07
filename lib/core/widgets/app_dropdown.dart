import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// An option or non-interactive section heading in an [AppDropdown].
class AppDropdownItem<T extends Object> {
  const AppDropdownItem({
    required T value,
    required this.label,
    this.icon,
    this.selected = false,
    this.enabled = true,
  }) : value = value;

  const AppDropdownItem.heading(this.label)
    : value = null,
      icon = null,
      selected = false,
      enabled = false;

  final T? value;
  final String label;
  final IconData? icon;
  final bool selected;
  final bool enabled;
}

/// A flat, anchored menu with a bounded, scrollable list of options.
///
/// Supply [label] for a text trigger, or omit it for an icon-only action.
/// Mark selected options using [AppDropdownItem.selected]; section headings
/// allow multiple related filters to share one menu.
class AppDropdown<T extends Object> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.items,
    required this.onSelected,
    required this.tooltip,
    this.label,
    this.icon,
    this.isActive = false,
    this.enabled = true,
    this.maxMenuHeight = 320,
  }) : assert(maxMenuHeight >= 48);

  final List<AppDropdownItem<T>> items;
  final ValueChanged<T> onSelected;
  final String tooltip;
  final String? label;
  final IconData? icon;
  final bool isActive;
  final bool enabled;
  final double maxMenuHeight;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final availableHeight = math.max(
      0.0,
      media.size.height - media.padding.vertical - media.viewInsets.bottom,
    );
    final menuHeight = math.min(maxMenuHeight, availableHeight * 0.5);
    final menuWidth = math.min(288.0, math.max(0.0, media.size.width - 32));
    final color = isActive ? AppColors.primary : AppColors.textSecondary;

    return PopupMenuButton<T>(
      tooltip: tooltip,
      enabled: enabled && items.any((item) => item.enabled),
      onSelected: onSelected,
      position: PopupMenuPosition.under,
      padding: const EdgeInsets.all(12),
      icon: label == null
          ? Icon(icon ?? Icons.more_horiz_rounded, color: color, size: 22)
          : null,
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      constraints: BoxConstraints(
        minWidth: math.min(220.0, menuWidth),
        maxWidth: menuWidth,
        minHeight: math.min(48.0, menuHeight),
        maxHeight: menuHeight,
      ),
      itemBuilder: (_) => [
        for (final item in items)
          PopupMenuItem<T>(
            value: item.value,
            enabled: item.enabled,
            height: item.value == null ? 36 : 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: item.value == null
                ? Text(
                    item.label.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  )
                : Semantics(
                    selected: item.selected,
                    child: Row(
                      children: [
                        if (item.icon != null) ...[
                          Icon(item.icon, size: 20, color: AppColors.primary),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Text(
                            item.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: item.selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: !item.enabled
                                  ? AppColors.textSecondary
                                  : item.selected
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (item.selected) ...[
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
      ],
      child: label == null
          ? null
          : Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    icon ?? Icons.keyboard_arrow_down_rounded,
                    color: color,
                    size: 20,
                  ),
                ],
              ),
            ),
    );
  }
}
