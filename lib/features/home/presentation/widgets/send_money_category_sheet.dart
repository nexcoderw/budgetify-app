import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';

Future<String?> showSendMoneyCategorySheet(
  BuildContext context, {
  required String amount,
}) {
  final screenHeight = MediaQuery.sizeOf(context).height;
  final heightFactor = screenHeight < 600
      ? 0.88
      : screenHeight < 760
      ? 0.68
      : 0.56;

  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (context) {
      return FractionallySizedBox(
        heightFactor: heightFactor,
        child: _SendMoneyCategorySheet(amount: amount),
      );
    },
  );
}

class _SendMoneyCategorySheet extends StatefulWidget {
  const _SendMoneyCategorySheet({required this.amount});

  final String amount;

  @override
  State<_SendMoneyCategorySheet> createState() =>
      _SendMoneyCategorySheetState();
}

class _SendMoneyCategorySheetState
    extends State<_SendMoneyCategorySheet> {
  static const _categories = [
    _MoneyCategory(
      label: 'Transport',
      icon: Icons.directions_bus_rounded,
    ),
    _MoneyCategory(
      label: 'Groceries',
      icon: Icons.shopping_basket_rounded,
    ),
    _MoneyCategory(
      label: 'Bills',
      icon: Icons.receipt_long_rounded,
    ),
    _MoneyCategory(
      label: 'Rent',
      icon: Icons.home_rounded,
    ),
    _MoneyCategory(
      label: 'Health',
      icon: Icons.local_hospital_rounded,
    ),
    _MoneyCategory(
      label: 'Education',
      icon: Icons.school_rounded,
    ),
    _MoneyCategory(
      label: 'Dining',
      icon: Icons.restaurant_rounded,
    ),
    _MoneyCategory(
      label: 'Shopping',
      icon: Icons.shopping_bag_rounded,
    ),
    _MoneyCategory(
      label: 'Family',
      icon: Icons.family_restroom_rounded,
    ),
    _MoneyCategory(
      label: 'Entertainment',
      icon: Icons.movie_rounded,
    ),
    _MoneyCategory(
      label: 'Other',
      icon: Icons.more_horiz_rounded,
    ),
  ];

  String? _selectedCategory;

  void _selectCategory(String category) {
    if (_selectedCategory == category) {
      return;
    }

    setState(() => _selectedCategory = category);
  }

  void _continue() {
    final selectedCategory = _selectedCategory;
    if (selectedCategory == null) {
      return;
    }

    Navigator.of(context).pop(selectedCategory);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.surfaceElevated, AppColors.backgroundSecondary],
          ),
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'What is this payment for?',
                            style: TextStyle(
                              fontSize: 21,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 7),
                          Text(
                            'Choose one category',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    _AmountBadge(amount: widget.amount),
                  ],
                ),
              ),
              SizedBox(
                height: 116,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final category = _categories[index];

                    return _CategoryCard(
                      category: category,
                      isSelected: _selectedCategory == category.label,
                      onTap: () => _selectCategory(category.label),
                    );
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.swipe_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 7),
                    Text(
                      'Swipe to see more',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: 240,
                  child: AppButton(
                    label: 'Continue',
                    iconWidget: const Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.background,
                    ),
                    size: AppButtonSize.md,
                    onPressed:
                        _selectedCategory == null ? null : _continue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.textSecondary.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _AmountBadge extends StatelessWidget {
  const _AmountBadge({required this.amount});

  final String amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.20),
        ),
      ),
      child: Text(
        'RWF $amount',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final _MoneyCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      button: true,
      selected: isSelected,
      label: category.label,
      child: AnimatedScale(
        scale: isSelected ? 1 : 0.96,
        duration: disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            splashColor: AppColors.primary.withValues(alpha: 0.10),
            highlightColor: AppColors.primary.withValues(alpha: 0.05),
            child: AnimatedContainer(
              duration: disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: 104,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.52)
                      : AppColors.border,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: disableAnimations
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.surfaceElevated,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      category.icon,
                      size: 21,
                      color: isSelected
                          ? AppColors.background
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    category.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoneyCategory {
  const _MoneyCategory({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
