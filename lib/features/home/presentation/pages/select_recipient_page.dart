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

enum _RecipientView { checking, permissionPrompt, loading, contacts, manual }

class _SelectRecipientPageState extends State<SelectRecipientPage> {
  final _phoneController = TextEditingController();
  final _searchController = TextEditingController();
  final _phoneFocusNode = FocusNode();

  _RecipientView _view = _RecipientView.checking;
  List<DeviceContact> _contacts = const [];
  DeviceContact? _selectedContact;
  String _searchQuery = '';

  bool get _hasManualNumber => _phoneController.text.trim().length >= 7;

  List<DeviceContact> get _filteredContacts {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return _contacts;
    }

    return _contacts.where((contact) {
      return contact.name.toLowerCase().contains(query) ||
          contact.phoneNumber.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_refreshManualAction);
    _searchController.addListener(_filterContacts);
    _initializePermissionState();
  }

  @override
  void dispose() {
    _phoneController
      ..removeListener(_refreshManualAction)
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

      setState(() {
        _view = permission == DeviceContactsPermission.notDetermined
            ? _RecipientView.permissionPrompt
            : _RecipientView.manual;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _view = _RecipientView.manual);
      }
    }
  }

  Future<void> _requestContacts() async {
    setState(() => _view = _RecipientView.loading);

    try {
      final permission = await widget.contactsService.requestPermission();

      if (!mounted) {
        return;
      }

      if (permission == DeviceContactsPermission.granted) {
        await _loadContacts();
        return;
      }

      _showManualEntry();
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showManualEntry();
      AppToast.error(
        context,
        title: 'Contacts unavailable',
        description: 'Enter the recipient phone number instead.',
      );
    }
  }

  Future<void> _loadContacts() async {
    if (mounted) {
      setState(() => _view = _RecipientView.loading);
    }

    try {
      final contacts = await widget.contactsService.getContacts();

      if (!mounted) {
        return;
      }

      if (contacts.isEmpty) {
        _showManualEntry();
        return;
      }

      setState(() {
        _contacts = contacts;
        _view = _RecipientView.contacts;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showManualEntry();
      AppToast.error(
        context,
        title: 'Could not load contacts',
        description: 'Enter the recipient phone number instead.',
      );
    }
  }

  void _showManualEntry() {
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedContact = null;
      _view = _RecipientView.manual;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _phoneFocusNode.requestFocus();
      }
    });
  }

  void _refreshManualAction() {
    if (mounted && _view == _RecipientView.manual) {
      setState(() {});
    }
  }

  void _filterContacts() {
    if (mounted && _view == _RecipientView.contacts) {
      setState(() => _searchQuery = _searchController.text);
    }
  }

  void _selectContact(DeviceContact contact) {
    setState(() => _selectedContact = contact);
  }

  void _continueWithRecipient() {
    final selectedContact = _selectedContact;
    final phoneNumber = selectedContact?.phoneNumber ??
        _phoneController.text.trim();

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
      title: selectedContact?.name ?? phoneNumber,
      description: 'Transfer review will be connected next.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _RecipientTopBar(onBack: () => Navigator.of(context).pop()),
                  const SizedBox(height: 24),
                  const Text(
                    'Choose recipient',
                    style: TextStyle(
                      fontSize: 26,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.7,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Who should receive this money?',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _TransferSummary(
                    amount: widget.amount,
                    category: widget.category,
                  ),
                  const SizedBox(height: 22),
                  Expanded(child: _buildContent()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return switch (_view) {
      _RecipientView.checking || _RecipientView.loading =>
        const _LoadingContacts(),
      _RecipientView.permissionPrompt => _ContactsPermissionPrompt(
        onAllow: _requestContacts,
        onUseNumber: _showManualEntry,
      ),
      _RecipientView.contacts => _ContactsList(
        searchController: _searchController,
        contacts: _filteredContacts,
        selectedContact: _selectedContact,
        onSelected: _selectContact,
        onContinue: _selectedContact == null
            ? null
            : _continueWithRecipient,
      ),
      _RecipientView.manual => _ManualRecipientEntry(
        phoneController: _phoneController,
        phoneFocusNode: _phoneFocusNode,
        canContinue: _hasManualNumber,
        onContinue: _continueWithRecipient,
      ),
    };
  }
}

class _RecipientTopBar extends StatelessWidget {
  const _RecipientTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
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
    );
  }
}

class _TransferSummary extends StatelessWidget {
  const _TransferSummary({required this.amount, required this.category});

  final String amount;
  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'RWF $amount',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
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
      child: Column(
        children: [
          const SizedBox(height: 22),
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.24),
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.contacts_rounded,
              size: 32,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Find people faster',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 9),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: const Text(
              'Allow access to show names and phone numbers from your device. Nothing is uploaded.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 26),
          SizedBox(
            width: 230,
            child: AppButton(
              label: 'Allow contacts',
              iconWidget: const Icon(
                Icons.contacts_rounded,
                color: AppColors.background,
              ),
              size: AppButtonSize.md,
              onPressed: onAllow,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 230,
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
    );
  }
}

class _ContactsList extends StatelessWidget {
  const _ContactsList({
    required this.searchController,
    required this.contacts,
    required this.selectedContact,
    required this.onSelected,
    required this.onContinue,
  });

  final TextEditingController searchController;
  final List<DeviceContact> contacts;
  final DeviceContact? selectedContact;
  final ValueChanged<DeviceContact> onSelected;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppInput(
          controller: searchController,
          hintText: 'Search contacts',
          textInputAction: TextInputAction.search,
          suffixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: contacts.isEmpty
              ? const _NoContactResults()
              : ListView.separated(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: contacts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final contact = contacts[index];

                    return _ContactTile(
                      contact: contact,
                      isSelected: selectedContact?.id == contact.id,
                      onTap: () => onSelected(contact),
                    );
                  },
                ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: 190,
            child: AppButton(
              label: 'Continue',
              iconWidget: const Icon(
                Icons.check_rounded,
                color: AppColors.background,
              ),
              size: AppButtonSize.sm,
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
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.48)
                    : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Container(
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
                      fontSize: 13,
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
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        contact.phoneNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
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
                      : Icons.circle_outlined,
                  size: 21,
                  color: isSelected
                      ? AppColors.primary
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
        AppInput(
          controller: phoneController,
          focusNode: phoneFocusNode,
          label: 'Phone number',
          hintText: 'Enter recipient number',
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          maxLength: 15,
          enableSuggestions: false,
          autocorrect: false,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
        const Spacer(),
        Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: 190,
            child: AppButton(
              label: 'Continue',
              iconWidget: const Icon(
                Icons.check_rounded,
                color: AppColors.background,
              ),
              size: AppButtonSize.sm,
              onPressed: canContinue ? onContinue : null,
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
      child: SizedBox.square(
        dimension: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _NoContactResults extends StatelessWidget {
  const _NoContactResults();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No matching contacts',
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
    );
  }
}
