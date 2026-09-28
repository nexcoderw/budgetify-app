import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_input.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../data/models/device_contact.dart';
import '../../data/services/device_contacts_service.dart';

class SelectRecipientPage extends StatefulWidget {
  const SelectRecipientPage({
    super.key,
    required this.amount,
    required this.category,
    this.contactsService = const DeviceContactsService(),
  });

  final String amount;
  final String category;
  final DeviceContactsService contactsService;

  @override
  State<SelectRecipientPage> createState() => _SelectRecipientPageState();
}

enum _RecipientMode {
  contacts,
  phoneNumber,
}

enum _ContactsView {
  checking,
  permissionPrompt,
  loading,
  ready,
  unavailable,
}

class _SelectRecipientPageState extends State<SelectRecipientPage> {
  final _phoneController = TextEditingController();
  final _searchController = TextEditingController();
  final _phoneFocusNode = FocusNode();

  _RecipientMode _mode = _RecipientMode.contacts;
  _ContactsView _contactsView = _ContactsView.checking;

  List<DeviceContact> _contacts = const [];
  DeviceContact? _selectedContact;

  String _searchQuery = '';

  bool get _hasManualNumber {
    return _phoneController.text.replaceAll(RegExp(r'\D'), '').length >= 7;
  }

  List<DeviceContact> get _filteredContacts {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return _contacts;
    }

    return _contacts.where((contact) {
      final name = contact.name.toLowerCase();
      final phone = contact.phoneNumber.toLowerCase();

      return name.contains(query) || phone.contains(query);
    }).toList(growable: false);
  }

  @override
  void initState() {
    super.initState();

    _phoneController.addListener(_refreshManualEntry);
    _searchController.addListener(_filterContacts);

    _initializePermissionState();
  }

  @override
  void dispose() {
    _phoneController
      ..removeListener(_refreshManualEntry)
      ..dispose();

    _searchController
      ..removeListener(_filterContacts)
      ..dispose();

    _phoneFocusNode.dispose();

    super.dispose();
  }

  Future<void> _initializePermissionState() async {
    try {
      final permission = await widget.contactsService.checkPermission();

      if (!mounted) {
        return;
      }

      if (permission == DeviceContactsPermission.granted) {
        await _loadContacts();
        return;
      }

      if (permission == DeviceContactsPermission.notDetermined) {
        setState(() {
          _mode = _RecipientMode.contacts;
          _contactsView = _ContactsView.permissionPrompt;
        });

        return;
      }

      setState(() {
        _mode = _RecipientMode.phoneNumber;
        _contactsView = _ContactsView.unavailable;
      });

      _focusPhoneNumber();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _mode = _RecipientMode.phoneNumber;
        _contactsView = _ContactsView.unavailable;
      });

      _focusPhoneNumber();
    }
  }

  Future<void> _requestContacts() async {
    setState(() {
      _mode = _RecipientMode.contacts;
      _contactsView = _ContactsView.loading;
    });

    try {
      final permission = await widget.contactsService.requestPermission();

      if (!mounted) {
        return;
      }

      if (permission == DeviceContactsPermission.granted) {
        await _loadContacts();
        return;
      }

      setState(() {
        _mode = _RecipientMode.phoneNumber;
        _contactsView = _ContactsView.unavailable;
      });

      _focusPhoneNumber();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _mode = _RecipientMode.phoneNumber;
        _contactsView = _ContactsView.unavailable;
      });

      _focusPhoneNumber();

      AppToast.error(
        context,
        title: 'Contacts unavailable',
        description: 'Enter the recipient phone number instead.',
      );
    }
  }

  Future<void> _loadContacts() async {
    if (mounted) {
      setState(() {
        _mode = _RecipientMode.contacts;
        _contactsView = _ContactsView.loading;
      });
    }

    try {
      final contacts = await widget.contactsService.getContacts();

      if (!mounted) {
        return;
      }

      setState(() {
        _contacts = contacts;
        _contactsView = _ContactsView.ready;

        if (contacts.isEmpty) {
          _mode = _RecipientMode.phoneNumber;
        }
      });

      if (contacts.isEmpty) {
        _focusPhoneNumber();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _mode = _RecipientMode.phoneNumber;
        _contactsView = _ContactsView.unavailable;
      });

      _focusPhoneNumber();

      AppToast.error(
        context,
        title: 'Could not load contacts',
        description: 'Enter the recipient phone number instead.',
      );
    }
  }

  void _showContacts() {
    FocusScope.of(context).unfocus();

    HapticFeedback.selectionClick();

    setState(() {
      _mode = _RecipientMode.contacts;
    });
  }

  void _showManualEntry() {
    HapticFeedback.selectionClick();

    setState(() {
      _mode = _RecipientMode.phoneNumber;
    });

    _focusPhoneNumber();
  }

  void _focusPhoneNumber() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _phoneFocusNode.requestFocus();
    });
  }

  void _refreshManualEntry() {
    if (!mounted || _mode != _RecipientMode.phoneNumber) {
      return;
    }

    setState(() {});
  }

  void _filterContacts() {
    if (!mounted) {
      return;
    }

    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  void _clearSearch() {
    _searchController.clear();
  }

  void _selectContact(DeviceContact contact) {
    HapticFeedback.selectionClick();

    setState(() {
      _selectedContact = contact;
    });
  }

  void _continueWithRecipient() {
    final selectedContact = _selectedContact;

    final phoneNumber = _mode == _RecipientMode.contacts
        ? selectedContact?.phoneNumber ?? ''
        : _phoneController.text.trim();

    if (phoneNumber.replaceAll(RegExp(r'\D'), '').length < 7) {
      AppToast.error(
        context,
        title: 'Invalid phone number',
        description: 'Enter at least 7 digits.',
      );

      return;
    }

    AppToast.info(
      context,
      title: _mode == _RecipientMode.contacts
          ? selectedContact?.name ?? phoneNumber
          : phoneNumber,
      description: 'Transfer review will be connected next.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isCompact = mediaQuery.size.width < 420;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 560,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isCompact ? 16 : 20,
                14,
                isCompact ? 16 : 20,
                18,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _RecipientTopBar(
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  SizedBox(
                    height: isCompact ? 22 : 28,
                  ),
                  _RecipientHeader(
                    compact: isCompact,
                  ),
                  const SizedBox(
                    height: 18,
                  ),
                  _TransferSummary(
                    amount: widget.amount,
                    category: widget.category,
                  ),
                  const SizedBox(
                    height: 18,
                  ),
                  _RecipientModeSelector(
                    mode: _mode,
                    onContactsPressed: _showContacts,
                    onPhonePressed: _showManualEntry,
                  ),
                  const SizedBox(
                    height: 18,
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: mediaQuery.disableAnimations
                          ? Duration.zero
                          : const Duration(
                              milliseconds: 180,
                            ),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: _mode == _RecipientMode.contacts
                          ? KeyedSubtree(
                              key: const ValueKey('contacts'),
                              child: _buildContactsContent(),
                            )
                          : KeyedSubtree(
                              key: const ValueKey('phone-number'),
                              child: _ManualRecipientEntry(
                                phoneController: _phoneController,
                                phoneFocusNode: _phoneFocusNode,
                                canContinue: _hasManualNumber,
                                onContinue: _continueWithRecipient,
                              ),
                            ),
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

  Widget _buildContactsContent() {
    return switch (_contactsView) {
      _ContactsView.checking ||
      _ContactsView.loading =>
        const _LoadingContacts(),
      _ContactsView.permissionPrompt => _ContactsPermissionPrompt(
          onAllow: _requestContacts,
          onUseNumber: _showManualEntry,
        ),
      _ContactsView.unavailable => _ContactsUnavailable(
          onRetry: _requestContacts,
          onUseNumber: _showManualEntry,
        ),
      _ContactsView.ready => _ContactsList(
          searchController: _searchController,
          contacts: _filteredContacts,
          allContactsCount: _contacts.length,
          selectedContact: _selectedContact,
          onClearSearch: _clearSearch,
          onSelected: _selectContact,
          onContinue:
              _selectedContact == null ? null : _continueWithRecipient,
          onUseNumber: _showManualEntry,
        ),
    };
  }
}

class _RecipientTopBar extends StatelessWidget {
  const _RecipientTopBar({
    required this.onBack,
  });

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Semantics(
          button: true,
          label: 'Go back',
          child: Tooltip(
            message: 'Back',
            child: Material(
              color: AppColors.surfaceElevated,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onBack,
                customBorder: const CircleBorder(),
                child: const SizedBox.square(
                  dimension: 44,
                  child: Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowLeft01,
                      size: 19,
                      color: AppColors.textPrimary,
                      strokeWidth: 1.9,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(
              alpha: 0.05,
            ),
            borderRadius: BorderRadius.circular(
              999,
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 14,
                color: AppColors.textSecondary,
              ),
              SizedBox(
                width: 6,
              ),
              Text(
                'Secure transfer',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecipientHeader extends StatelessWidget {
  const _RecipientHeader({
    required this.compact,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SEND MONEY',
          style: TextStyle(
            fontSize: 10,
            height: 1,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: AppColors.primary.withValues(
              alpha: 0.92,
            ),
          ),
        ),
        const SizedBox(
          height: 10,
        ),
        Text(
          'Choose recipient',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: compact ? 25 : 28,
                height: 1.05,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
                color: AppColors.textPrimary,
              ),
        ),
        const SizedBox(
          height: 7,
        ),
        const Text(
          'Who should receive this money?',
          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _TransferSummary extends StatelessWidget {
  const _TransferSummary({
    required this.amount,
    required this.category,
  });

  final String amount;
  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(
        14,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: 0.045,
        ),
        borderRadius: BorderRadius.circular(
          22,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(
                alpha: 0.14,
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.payments_outlined,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOU ARE SENDING',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  'RWF $amount',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(
                  alpha: 0.11,
                ),
                borderRadius: BorderRadius.circular(
                  999,
                ),
              ),
              child: Text(
                category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipientModeSelector extends StatelessWidget {
  const _RecipientModeSelector({
    required this.mode,
    required this.onContactsPressed,
    required this.onPhonePressed,
  });

  final _RecipientMode mode;
  final VoidCallback onContactsPressed;
  final VoidCallback onPhonePressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(
        4,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(
          18,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _RecipientModeButton(
              label: 'Contacts',
              icon: Icons.contacts_outlined,
              isSelected: mode == _RecipientMode.contacts,
              onPressed: onContactsPressed,
            ),
          ),
          const SizedBox(
            width: 4,
          ),
          Expanded(
            child: _RecipientModeButton(
              label: 'Phone number',
              icon: Icons.dialpad_rounded,
              isSelected: mode == _RecipientMode.phoneNumber,
              onPressed: onPhonePressed,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipientModeButton extends StatelessWidget {
  const _RecipientModeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(
        14,
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(
          14,
        ),
        child: AnimatedContainer(
          duration: disableAnimations
              ? Duration.zero
              : const Duration(
                  milliseconds: 170,
                ),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(
              14,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: isSelected
                    ? AppColors.background
                    : AppColors.textSecondary,
              ),
              const SizedBox(
                width: 8,
              ),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isSelected
                        ? AppColors.background
                        : AppColors.textSecondary,
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

class _ContactsPermissionPrompt extends StatelessWidget {
  const _ContactsPermissionPrompt({
    required this.onAllow,
    required this.onUseNumber,
  });

  final VoidCallback onAllow;
  final VoidCallback onUseNumber;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(
          top: 14,
        ),
        child: Column(
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(
                  alpha: 0.12,
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.contacts_outlined,
                size: 34,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(
              height: 22,
            ),
            const Text(
              'Find people faster',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                height: 1.15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 340,
              ),
              child: const Text(
                'Allow Budgetify to show names and phone numbers from your device so you can choose a recipient quickly.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.55,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(
              height: 18,
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(
                  alpha: 0.035,
                ),
                borderRadius: BorderRadius.circular(
                  16,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 16,
                    color: AppColors.success,
                  ),
                  SizedBox(
                    width: 8,
                  ),
                  Flexible(
                    child: Text(
                      'Contacts stay on your device',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(
              height: 28,
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 260,
              ),
              child: AppButton(
                label: 'Allow contacts',
                iconWidget: const Icon(
                  Icons.contacts_outlined,
                  color: AppColors.background,
                ),
                size: AppButtonSize.md,
                onPressed: onAllow,
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 260,
              ),
              child: AppButton(
                label: 'Enter number instead',
                iconWidget: const Icon(
                  Icons.dialpad_rounded,
                  color: AppColors.textPrimary,
                ),
                size: AppButtonSize.sm,
                variant: AppButtonVariant.secondary,
                onPressed: onUseNumber,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactsUnavailable extends StatelessWidget {
  const _ContactsUnavailable({
    required this.onRetry,
    required this.onUseNumber,
  });

  final VoidCallback onRetry;
  final VoidCallback onUseNumber;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceElevated,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.contact_page_outlined,
                size: 29,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(
              height: 18,
            ),
            const Text(
              'Contacts are unavailable',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 320,
              ),
              child: const Text(
                'You can try contact access again or continue by entering the phone number manually.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(
              height: 24,
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 240,
              ),
              child: AppButton(
                label: 'Try again',
                iconWidget: const Icon(
                  Icons.refresh_rounded,
                  color: AppColors.background,
                ),
                size: AppButtonSize.sm,
                onPressed: onRetry,
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 240,
              ),
              child: AppButton(
                label: 'Enter number',
                iconWidget: const Icon(
                  Icons.dialpad_rounded,
                  color: AppColors.textPrimary,
                ),
                size: AppButtonSize.sm,
                variant: AppButtonVariant.secondary,
                onPressed: onUseNumber,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactsList extends StatelessWidget {
  const _ContactsList({
    required this.searchController,
    required this.contacts,
    required this.allContactsCount,
    required this.selectedContact,
    required this.onClearSearch,
    required this.onSelected,
    required this.onContinue,
    required this.onUseNumber,
  });

  final TextEditingController searchController;
  final List<DeviceContact> contacts;
  final int allContactsCount;
  final DeviceContact? selectedContact;
  final VoidCallback onClearSearch;
  final ValueChanged<DeviceContact> onSelected;
  final VoidCallback? onContinue;
  final VoidCallback onUseNumber;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppInput(
          controller: searchController,
          hintText: 'Search name or phone number',
          textInputAction: TextInputAction.search,
          suffixIcon: searchController.text.isEmpty
              ? const Icon(
                  Icons.search_rounded,
                  color: AppColors.textSecondary,
                )
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: onClearSearch,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary,
                  ),
                ),
        ),
        const SizedBox(
          height: 16,
        ),
        Row(
          children: [
            const Text(
              'CONTACTS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.3,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(
              width: 8,
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(
                  999,
                ),
              ),
              child: Text(
                '$allContactsCount',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: onUseNumber,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                ),
                minimumSize: const Size(
                  44,
                  44,
                ),
              ),
              child: const Text(
                'Enter number',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(
          height: 6,
        ),
        Expanded(
          child: contacts.isEmpty
              ? const _NoContactResults()
              : ListView.separated(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.only(
                    bottom: 10,
                  ),
                  itemCount: contacts.length,
                  separatorBuilder: (_, _) {
                    return const SizedBox(
                      height: 7,
                    );
                  },
                  itemBuilder: (context, index) {
                    final contact = contacts[index];

                    return _ContactTile(
                      contact: contact,
                      isSelected:
                          selectedContact?.id == contact.id,
                      onTap: () => onSelected(contact),
                    );
                  },
                ),
        ),
        const SizedBox(
          height: 10,
        ),
        AnimatedSwitcher(
          duration: const Duration(
            milliseconds: 160,
          ),
          child: selectedContact == null
              ? const SizedBox(
                  height: 0,
                )
              : Padding(
                  key: ValueKey(
                    selectedContact!.id,
                  ),
                  padding: const EdgeInsets.only(
                    bottom: 10,
                  ),
                  child: _SelectedContactSummary(
                    contact: selectedContact!,
                  ),
                ),
        ),
        Center(
          child: SizedBox(
            width: 220,
            child: AppButton(
              label: 'Continue',
              iconWidget: const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.background,
              ),
              size: AppButtonSize.md,
              onPressed: onContinue,
            ),
          ),
        ),
      ],
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${contact.name}, ${contact.phoneNumber}',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(
          18,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(
            18,
          ),
          child: AnimatedContainer(
            duration: disableAnimations
                ? Duration.zero
                : const Duration(
                    milliseconds: 160,
                  ),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(
                      alpha: 0.13,
                    )
                  : Colors.white.withValues(
                      alpha: 0.035,
                    ),
              borderRadius: BorderRadius.circular(
                18,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: disableAnimations
                      ? Duration.zero
                      : const Duration(
                          milliseconds: 160,
                        ),
                  width: 44,
                  height: 44,
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
                const SizedBox(
                  width: 13,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
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
                      const SizedBox(
                        height: 5,
                      ),
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
                const SizedBox(
                  width: 10,
                ),
                AnimatedContainer(
                  duration: disableAnimations
                      ? Duration.zero
                      : const Duration(
                          milliseconds: 160,
                        ),
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

class _SelectedContactSummary extends StatelessWidget {
  const _SelectedContactSummary({
    required this.contact,
  });

  final DeviceContact contact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(
          18,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
            alignment: Alignment.center,
            child: Text(
              contact.initials,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.background,
              ),
            ),
          ),
          const SizedBox(
            width: 11,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'SELECTED RECIPIENT',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  contact.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.check_circle_rounded,
            size: 19,
            color: AppColors.success,
          ),
        ],
      ),
    );
  }
}

class _ManualRecipientEntry extends StatelessWidget {
  const _ManualRecipientEntry({
    required this.phoneController,
    required this.phoneFocusNode,
    required this.canContinue,
    required this.onContinue,
  });

  final TextEditingController phoneController;
  final FocusNode phoneFocusNode;
  final bool canContinue;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'PHONE NUMBER',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.3,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(
          height: 10,
        ),
        AppInput(
          controller: phoneController,
          focusNode: phoneFocusNode,
          label: 'Recipient phone number',
          hintText: '0788 123 456',
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          maxLength: 15,
          enableSuggestions: false,
          autocorrect: false,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          suffixIcon: const Icon(
            Icons.dialpad_rounded,
            color: AppColors.textSecondary,
          ),
          onSubmitted: (_) {
            if (canContinue) {
              onContinue();
            }
          },
        ),
        const SizedBox(
          height: 14,
        ),
        Container(
          padding: const EdgeInsets.all(
            14,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(
              alpha: 0.035,
            ),
            borderRadius: BorderRadius.circular(
              18,
            ),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              SizedBox(
                width: 10,
              ),
              Expanded(
                child: Text(
                  'Enter the recipient number carefully. You will be able to review the transfer before it is completed.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Center(
          child: SizedBox(
            width: 220,
            child: AppButton(
              label: 'Continue',
              iconWidget: const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.background,
              ),
              size: AppButtonSize.md,
              onPressed:
                  canContinue ? onContinue : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadingContacts extends StatelessWidget {
  const _LoadingContacts();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: AppColors.primary,
            ),
          ),
          SizedBox(
            height: 14,
          ),
          Text(
            'Loading contacts...',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoContactResults extends StatelessWidget {
  const _NoContactResults();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_search_outlined,
            size: 30,
            color: AppColors.textSecondary,
          ),
          SizedBox(
            height: 10,
          ),
          Text(
            'No matching contacts',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(
            height: 5,
          ),
          Text(
            'Try another name or phone number.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
