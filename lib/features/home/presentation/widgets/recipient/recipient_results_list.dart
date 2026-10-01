import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../data/models/device_contact.dart';
import '../../../data/models/transaction_models.dart';
import 'recipient_contacts_states.dart';
import 'recipient_selection.dart';

class RecipientResultsList extends StatelessWidget {
  const RecipientResultsList({
    super.key,
    required this.contacts,
    required this.typedRecipient,
    required this.isSearching,
    required this.selectedRecipient,
    required this.isLoading,
    required this.onContactSelected,
    required this.onTypedRecipientSelected,
    required this.onRefresh,
  });

  final List<DeviceContact> contacts;
  final RecipientSelection? typedRecipient;
  final bool isSearching;
  final RecipientSelection? selectedRecipient;
  final bool isLoading;
  final ValueChanged<DeviceContact> onContactSelected;
  final ValueChanged<RecipientSelection> onTypedRecipientSelected;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final itemCount = contacts.length + (typedRecipient == null ? 0 : 1);

    if (itemCount == 0) {
      return NoContactResults(
        isSearching: isSearching,
        onRefresh: onRefresh,
      );
    }

    final list = ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: itemCount,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        indent: 60,
        color: AppColors.border.withValues(alpha: 0.65),
      ),
      itemBuilder: (context, index) {
        final typed = typedRecipient;

        if (typed != null && index == 0) {
          return _TypedRecipientTile(
            recipient: typed,
            isSelected: selectedRecipient?.key == typed.key,
            onTap: isLoading
                ? null
                : () => onTypedRecipientSelected(typed),
          );
        }

        final contactIndex = index - (typed == null ? 0 : 1);
        final contact = contacts[contactIndex];

        return _ContactTile(
          contact: contact,
          isSelected: selectedRecipient?.contactId == contact.id,
          onTap: isLoading ? null : () => onContactSelected(contact),
        );
      },
    );

    final refresh = onRefresh;

    if (refresh == null) {
      return list;
    }

    return RefreshIndicator(
      color: AppColors.background,
      backgroundColor: AppColors.primary,
      onRefresh: refresh,
      child: list,
    );
  }
}

class _TypedRecipientTile extends StatelessWidget {
  const _TypedRecipientTile({
    required this.recipient,
    required this.isSelected,
    required this.onTap,
  });

  final RecipientSelection recipient;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (recipient.recipientType) {
      TransactionRecipientType.phone => Icons.phone_iphone_rounded,
      TransactionRecipientType.bankAccount => Icons.account_balance_outlined,
      TransactionRecipientType.momoCode => Icons.storefront_outlined,
    };

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${recipient.title}, ${recipient.subtitle}',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.13)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.surfaceElevated,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    size: 19,
                    color: isSelected
                        ? AppColors.background
                        : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        recipient.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        recipient.subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.arrow_forward_ios_rounded,
                  size: isSelected ? 20 : 14,
                  color: isSelected
                      ? AppColors.success
                      : AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.contact,
    required this.isSelected,
    required this.onTap,
  });

  final DeviceContact contact;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${contact.name}, ${contact.phoneNumber}',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.13)
                  : Colors.white.withValues(alpha: 0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: disableAnimations
                      ? Duration.zero
                      : const Duration(milliseconds: 160),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.surfaceElevated,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    contact.initials,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? AppColors.background
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        contact.phoneNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedContainer(
                  duration: disableAnimations
                      ? Duration.zero
                      : const Duration(milliseconds: 160),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.surfaceElevated,
                  ),
                  alignment: Alignment.center,
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: AppColors.background,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}