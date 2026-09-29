import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_input.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../application/transaction_service.dart';
import '../../application/ussd_transfer_service.dart';
import '../../data/models/device_contact.dart';
import '../../data/models/transaction_models.dart';
import '../../data/services/device_contacts_service.dart';

class SelectRecipientPage extends StatefulWidget {
  const SelectRecipientPage({
    super.key,
    required this.amount,
    required this.category,
    this.contactsService = const DeviceContactsService(),
    this.transactionService,
    this.ussdTransferService,
  });

  final String amount;
  final String category;
  final DeviceContactsService contactsService;
  final TransactionService? transactionService;
  final UssdTransferService? ussdTransferService;

  @override
  State<SelectRecipientPage> createState() => _SelectRecipientPageState();
}

enum _ContactsView {
  checking,
  permissionPrompt,
  loading,
  ready,
  unavailable,
}

class _RecipientSelection {
  const _RecipientSelection({
    required this.identifier,
    required this.recipientType,
    required this.title,
    required this.subtitle,
    this.contactId,
  });

  final String identifier;
  final TransactionRecipientType recipientType;
  final String title;
  final String subtitle;
  final String? contactId;

  String get key => '${recipientType.apiValue}:$identifier';
}

class _SelectRecipientPageState extends State<SelectRecipientPage> {
  final _searchController = TextEditingController();

  late final TransactionService _transactionService;
  late final UssdTransferService _ussdTransferService;

  _ContactsView _contactsView = _ContactsView.checking;

  List<DeviceContact> _contacts = const [];
  _RecipientSelection? _selectedRecipient;
  PaymentTransaction? _pendingTransaction;

  String _searchQuery = '';
  String? _activeTransferSignature;
  String? _idempotencyKey;
  bool _isStartingTransfer = false;

  List<DeviceContact> get _filteredContacts {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return _contacts;
    }

    return _contacts.where((contact) {
      final name = contact.name.toLowerCase();
      final phone = contact.phoneNumber.replaceAll(RegExp(r'\D'), '');
      final queryDigits = query.replaceAll(RegExp(r'\D'), '');
      final comparablePhone = _comparablePhone(contact.phoneNumber);
      final comparableQuery = _comparablePhone(query);

      return name.contains(query) ||
          (queryDigits.isNotEmpty &&
              (phone.contains(queryDigits) ||
                  comparablePhone.contains(comparableQuery)));
    }).toList(growable: false);
  }

  _RecipientSelection? get _typedRecipient {
    final value = _searchQuery.trim();

    if (value.isEmpty || !RegExp(r'^[+\d\s()-]+$').hasMatch(value)) {
      return null;
    }

    final type = inferTransactionRecipientType(value);

    if (!isValidTransactionRecipient(value, type)) {
      return null;
    }

    if (type == TransactionRecipientType.phone &&
        _contacts.any(
          (contact) =>
              _comparablePhone(contact.phoneNumber) ==
              _comparablePhone(value),
        )) {
      return null;
    }

    final digits = value.replaceAll(RegExp(r'\D'), '');
    final transferType = inferTransactionTransferType(
      recipientIdentifier: digits,
      recipientType: type,
    );

    final subtitle = switch (type) {
      TransactionRecipientType.phone => '${transferType.label} phone number',
      TransactionRecipientType.bankAccount => 'eKash bank account',
      TransactionRecipientType.momoCode => 'MoMo Pay merchant code',
    };

    return _RecipientSelection(
      identifier: digits,
      recipientType: type,
      title: digits,
      subtitle: subtitle,
    );
  }

  String _comparablePhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('250')) {
      return digits.substring(3);
    }

    if (digits.startsWith('0')) {
      return digits.substring(1);
    }

    return digits;
  }

  @override
  void initState() {
    super.initState();

    _transactionService = widget.transactionService ??
        TransactionService.createDefault();
    _ussdTransferService =
        widget.ussdTransferService ?? const UssdTransferService();

    _searchController.addListener(_filterContacts);

    _initializePermissionState();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_filterContacts)
      ..dispose();

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
          _contactsView = _ContactsView.permissionPrompt;
        });

        return;
      }

      setState(() {
        _contactsView = _ContactsView.unavailable;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _contactsView = _ContactsView.unavailable;
      });
    }
  }

  Future<void> _requestContacts() async {
    setState(() {
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
        _contactsView = _ContactsView.unavailable;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _contactsView = _ContactsView.unavailable;
      });

      AppToast.error(
        context,
        title: 'Contacts unavailable',
        description: 'You can still enter a number or MoMo code above.',
      );
    }
  }

  Future<void> _loadContacts() async {
    if (mounted) {
      setState(() {
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
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _contactsView = _ContactsView.unavailable;
      });

      AppToast.error(
        context,
        title: 'Could not load contacts',
        description: 'You can still enter a number or MoMo code above.',
      );
    }
  }

  Future<void> _refreshContacts() async {
    try {
      final contacts = await widget.contactsService.getContacts();

      if (!mounted) {
        return;
      }

      setState(() {
        _contacts = contacts;
        final contactId = _selectedRecipient?.contactId;

        if (contactId != null &&
            !contacts.any((contact) => contact.id == contactId)) {
          _selectedRecipient = null;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Could not refresh contacts',
        description: 'Pull down to try again.',
      );
    }
  }

  void _filterContacts() {
    if (!mounted) {
      return;
    }

    setState(() {
      _searchQuery = _searchController.text;
      _selectedRecipient = null;
    });
  }

  void _clearSearch() {
    _searchController.clear();
  }

  void _selectContact(DeviceContact contact) {
    if (_isStartingTransfer) {
      return;
    }

    HapticFeedback.selectionClick();

    setState(() {
      _selectedRecipient = _RecipientSelection(
        identifier: contact.phoneNumber,
        recipientType: TransactionRecipientType.phone,
        title: contact.name,
        subtitle: contact.phoneNumber,
        contactId: contact.id,
      );
    });
  }

  void _selectTypedRecipient(_RecipientSelection recipient) {
    if (_isStartingTransfer) {
      return;
    }

    HapticFeedback.selectionClick();
    setState(() => _selectedRecipient = recipient);
  }

  Future<void> _continueWithRecipient() async {
    final recipient = _selectedRecipient;

    if (recipient == null) {
      return;
    }

    await _startTransfer(
      receiverIdentifier: recipient.identifier,
      recipientType: recipient.recipientType,
    );
  }

  Future<void> _startTransfer({
    required String receiverIdentifier,
    required TransactionRecipientType recipientType,
  }) async {
    if (_isStartingTransfer) {
      return;
    }

    if (!isValidTransactionRecipient(receiverIdentifier, recipientType)) {
      AppToast.error(
        context,
        title: 'Invalid recipient',
        description: switch (recipientType) {
          TransactionRecipientType.phone =>
            'Enter a valid Rwanda phone number.',
          TransactionRecipientType.bankAccount =>
            'Enter a valid bank account number.',
          TransactionRecipientType.momoCode =>
            'Enter a valid MoMo merchant code.',
        },
      );

      return;
    }

    final amount = int.parse(widget.amount.replaceAll(',', ''));
    final transferType = inferTransactionTransferType(
      recipientIdentifier: receiverIdentifier,
      recipientType: recipientType,
    );

    if (!_ussdTransferService.isSupported) {
      AppToast.error(
        context,
        title: 'USSD unavailable on this device',
        description:
            'Use Budgetify on an Android phone or iPhone to open the MTN transfer prompt.',
      );
      return;
    }

    final transferSignature = [
      amount,
      transferType.apiValue,
      recipientType.apiValue,
      receiverIdentifier.replaceAll(RegExp(r'\D'), ''),
      widget.category,
    ].join(':');

    if (_activeTransferSignature != transferSignature) {
      _activeTransferSignature = transferSignature;
      _idempotencyKey = _createIdempotencyKey();
      _pendingTransaction = null;
    }

    setState(() {
      _isStartingTransfer = true;
    });

    try {
      final allowed = await _ussdTransferService.prepare();

      if (!allowed) {
        if (!mounted) {
          return;
        }

        AppToast.error(
          context,
          title: 'Phone access required',
          description:
              'Allow phone access so Budgetify can open the MTN transfer prompt.',
        );
        return;
      }

      final transaction =
          _pendingTransaction ??
          await _transactionService.create(
            amount: amount,
            transferType: transferType,
            recipientType: recipientType,
            category: TransactionCategory.fromLabel(
              widget.category,
            ),
            receiverIdentifier: receiverIdentifier,
            idempotencyKey: _idempotencyKey!,
          );

      _pendingTransaction = transaction;

      await _ussdTransferService.launch(
        transferType: transferType,
        recipientType: recipientType,
        receiverIdentifier: receiverIdentifier,
        amount: amount,
      );

      if (!mounted) {
        return;
      }

      AppToast.info(
        context,
        title: '${transferType.label} opened',
        description:
            'Complete the transfer in the MTN prompt. It remains pending until confirmed.',
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Could not prepare transfer',
        description: error.message,
      );
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Could not open MTN MoMo',
        description: error.message ?? 'Please try again.',
      );
    } on ArgumentError catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Invalid transfer details',
        description: error.message?.toString() ?? 'Check the recipient.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Transfer unavailable',
        description: 'The transfer could not be started. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isStartingTransfer = false;
        });
      }
    }
  }

  String _createIdempotencyKey() {
    final random = Random.secure();
    final randomPart = List<int>.generate(
      16,
      (_) => random.nextInt(256),
    ).map(
      (value) => value.toRadixString(16).padLeft(2, '0'),
    ).join();

    return 'ussd-${DateTime.now().microsecondsSinceEpoch}-$randomPart';
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
                    height: isCompact ? 18 : 22,
                  ),
                  AppInput(
                    controller: _searchController,
                    hintText: 'Name, phone, account, or MoMo code',
                    borderRadius: 999,
                    textInputAction: TextInputAction.search,
                    enableSuggestions: false,
                    autocorrect: false,
                    suffixIcon: _searchController.text.isEmpty
                        ? const Icon(
                            Icons.search_rounded,
                            color: AppColors.textSecondary,
                          )
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: _clearSearch,
                            icon: const Icon(
                              Icons.close_rounded,
                              color: AppColors.textSecondary,
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _buildRecipientContent(),
                  ),
                  AnimatedSwitcher(
                    duration: mediaQuery.disableAnimations
                        ? Duration.zero
                        : const Duration(milliseconds: 160),
                    child: _selectedRecipient == null
                        ? const SizedBox.shrink()
                        : Padding(
                            key: ValueKey(_selectedRecipient!.key),
                            padding: const EdgeInsets.only(top: 12),
                            child: Center(
                              child: SizedBox(
                                width: 220,
                                child: AppButton(
                                  label: 'Continue',
                                  iconWidget: const Icon(
                                    Icons.phone_in_talk_rounded,
                                    color: AppColors.background,
                                  ),
                                  size: AppButtonSize.md,
                                  isLoading: _isStartingTransfer,
                                  onPressed: _isStartingTransfer
                                      ? null
                                      : _continueWithRecipient,
                                ),
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

  Widget _buildRecipientContent() {
    final typedRecipient = _typedRecipient;

    if (typedRecipient != null) {
      return _RecipientResultsList(
        contacts: _filteredContacts,
        typedRecipient: typedRecipient,
        isSearching: _searchQuery.trim().isNotEmpty,
        selectedRecipient: _selectedRecipient,
        isLoading: _isStartingTransfer,
        onContactSelected: _selectContact,
        onTypedRecipientSelected: _selectTypedRecipient,
        onRefresh: _contactsView == _ContactsView.ready
            ? _refreshContacts
            : null,
      );
    }

    return switch (_contactsView) {
      _ContactsView.checking ||
      _ContactsView.loading =>
        const _LoadingContacts(),
      _ContactsView.permissionPrompt => _ContactsPermissionPrompt(
          onAllow: _requestContacts,
        ),
      _ContactsView.unavailable => _ContactsUnavailable(
          onRetry: _requestContacts,
        ),
      _ContactsView.ready => _RecipientResultsList(
          contacts: _filteredContacts,
          typedRecipient: null,
          isSearching: _searchQuery.trim().isNotEmpty,
          selectedRecipient: _selectedRecipient,
          isLoading: _isStartingTransfer,
          onContactSelected: _selectContact,
          onTypedRecipientSelected: _selectTypedRecipient,
          onRefresh: _refreshContacts,
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

class _ContactsPermissionPrompt extends StatelessWidget {
  const _ContactsPermissionPrompt({
    required this.onAllow,
  });

  final VoidCallback onAllow;

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
                'Allow Budgetify to show names and phone numbers from your device. Choose full contact access when your phone asks.',
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
          ],
        ),
      ),
    );
  }
}

class _ContactsUnavailable extends StatelessWidget {
  const _ContactsUnavailable({
    required this.onRetry,
  });

  final VoidCallback onRetry;

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
                'Try contact access again, or enter a phone number, bank account, or MoMo code above.',
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
          ],
        ),
      ),
    );
  }
}

class _RecipientResultsList extends StatelessWidget {
  const _RecipientResultsList({
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
  final _RecipientSelection? typedRecipient;
  final bool isSearching;
  final _RecipientSelection? selectedRecipient;
  final bool isLoading;
  final ValueChanged<DeviceContact> onContactSelected;
  final ValueChanged<_RecipientSelection> onTypedRecipientSelected;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final itemCount = contacts.length + (typedRecipient == null ? 0 : 1);

    if (itemCount == 0) {
      return _NoContactResults(
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

  final _RecipientSelection recipient;
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
            minHeight: 58,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
        borderRadius: BorderRadius.circular(
          14,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(
            14,
          ),
          child: AnimatedContainer(
            duration: disableAnimations
                ? Duration.zero
                : const Duration(
                    milliseconds: 160,
                  ),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(
                      alpha: 0.13,
                    )
                  : Colors.white.withValues(
                      alpha: 0,
                    ),
              borderRadius: BorderRadius.circular(
                14,
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
  const _NoContactResults({
    required this.isSearching,
    required this.onRefresh,
  });

  final bool isSearching;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.person_search_outlined,
            size: 30,
            color: AppColors.textSecondary,
          ),
          const SizedBox(
            height: 10,
          ),
          Text(
            isSearching ? 'No recipient found' : 'No contacts available',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(
            height: 5,
          ),
          Text(
            isSearching
                ? 'Try another name, phone, account, or MoMo code.'
                : 'Allow full contact access, then refresh this list.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          if (!isSearching && onRefresh != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                onRefresh?.call();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh contacts'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: const Size(44, 44),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
