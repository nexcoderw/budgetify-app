import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import 'app_layout_section.dart';

class AppBottomNavBar extends StatefulWidget {
  const AppBottomNavBar({
    super.key,
    required this.currentSection,
    required this.destinations,
    required this.onSectionSelected,
  });

  final AppLayoutSection currentSection;
  final List<AppNavDestination> destinations;
  final ValueChanged<AppLayoutSection> onSectionSelected;

  @override
  State<AppBottomNavBar> createState() => _AppBottomNavBarState();
}

class _AppBottomNavBarState extends State<AppBottomNavBar>
    with TickerProviderStateMixin {
  final Map<AppLayoutSection, AnimationController> _pressControllers = {};

  @override
  void initState() {
    super.initState();
    _createControllers(widget.destinations);
  }

  @override
  void didUpdateWidget(covariant AppBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentSections = widget.destinations
        .map((destination) => destination.section)
        .toSet();

    for (final destination in widget.destinations) {
      _pressControllers.putIfAbsent(
        destination.section,
        () => _newController(),
      );
    }

    final removedSections = _pressControllers.keys
        .where((section) => !currentSections.contains(section))
        .toList(growable: false);
    for (final section in removedSections) {
      _pressControllers.remove(section)?.dispose();
    }
  }

  @override
  void dispose() {
    for (final controller in _pressControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _createControllers(List<AppNavDestination> destinations) {
    for (final destination in destinations) {
      _pressControllers[destination.section] = _newController();
    }
  }

  AnimationController _newController() {
    return AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 360),
    );
  }

  void _handleTap(AppLayoutSection section) {
    if (section == widget.currentSection) {
      return;
    }

    final controller = _pressControllers[section];
    if (controller != null) {
      controller
          .forward()
          .then((_) => controller.animateBack(0, curve: Curves.easeOutBack));
    }

    widget.onSectionSelected(section);
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 760;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: widget.destinations
          .map(
            (destination) => _buildAnimatedItem(
              destination,
              compact: isCompact,
            ),
          )
          .toList(growable: false),
    );

    return Semantics(
      label: 'Primary navigation',
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 620),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: const Color(0xFF101925).withValues(alpha: 0.97),
            border: Border.all(
              color: const Color(0xFF31506E).withValues(alpha: 0.58),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.36),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: const Color(0xFF2A74B8).withValues(alpha: 0.09),
                blurRadius: 22,
                spreadRadius: -4,
              ),
            ],
          ),
          child: isCompact
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: content,
                  ),
                )
              : content,
        ),
      ),
    );
  }

  Widget _buildAnimatedItem(
    AppNavDestination destination, {
    required bool compact,
  }) {
    final controller = _pressControllers[destination.section]!;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.scale(
          scale: 1 - (controller.value * 0.08),
          child: child,
        );
      },
      child: _NavigationItem(
        destination: destination,
        selected: destination.section == widget.currentSection,
        compact: compact,
        onTap: () => _handleTap(destination.section),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.destination,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final AppNavDestination destination;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? AppColors.textPrimary
        : AppColors.textSecondary.withValues(alpha: 0.76);

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: Tooltip(
        message: destination.label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(25),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            width: compact ? (selected ? 70 : 58) : (selected ? 88 : 72),
            height: compact ? 56 : 60,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: selected
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF3B4A5D), Color(0xFF273444)],
                    )
                  : null,
              border: Border.all(
                color: selected
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.transparent,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: selected ? 1.08 : 1,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  child: HugeIcon(
                    icon: destination.icon,
                    size: selected ? 19 : 18,
                    color: foreground,
                    strokeWidth: selected ? 2 : 1.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: compact ? 9 : 10,
                    height: 1,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
