import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
import '../widgets/recipient/recipient_contacts_states.dart';
import '../widgets/recipient/recipient_results_list.dart';
import '../widgets/recipient/recipient_selection.dart';
import '../widgets/recipient/recipient_top_bar.dart';
import '../widgets/transaction_manual_confirmation_sheet.dart';

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

enum _ContactsView { checking, permissionPrompt, loading, ready, unavailable }

class _SelectRecipientPageState extends State<SelectRecipientPage>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();

  late final TransactionService _transactionService;
  late final UssdTransferService _ussdTransferService;

  _ContactsView _contactsView = _ContactsView.checking;

  List<DeviceContact> _contacts = const [];
  RecipientSelection? _selectedRecipient;
  PaymentTransaction? _pendingTransaction;

  String _searchQuery = '';
  String? _activeTransferSignature;
  String? _idempotencyKey;

  bool _isStartingTransfer = false;
  bool _awaitingIosManualConfirmation = false;
  bool _iosTransferLeftForeground = false;
  bool _isShowingIosManualConfirmation = false;

  AppLifecycleState? _lifecycleState;

  List<DeviceContact> get _filteredContacts {
    return filterRecipientContacts(contacts: _contacts, query: _searchQuery);
  }

  RecipientSelection? get _typedRecipient {
    return resolveTypedRecipient(query: _searchQuery, contacts: _contacts);
  }

  @override
  void initState() {
    super.initState();

    _transactionService =
        widget.transactionService ?? TransactionService.createDefault();

    _ussdTransferService =
        widget.ussdTransferService ?? const UssdTransferService();

    _lifecycleState = WidgetsBinding.instance.lifecycleState;

    WidgetsBinding.instance.addObserver(this);

    _searchController.addListener(_filterContacts);

    unawaited(_initializePermissionState());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;

    if (!supportsIosManualTransactionConfirmation) {
      return;
    }

    if (_awaitingIosManualConfirmation &&
        (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden)) {
      _iosTransferLeftForeground = true;

      return;
    }

    if (state == AppLifecycleState.resumed) {
      unawaited(_presentIosManualConfirmationIfReady());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

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
      _selectedRecipient = RecipientSelection.fromContact(contact);
    });
  }

  void _selectTypedRecipient(RecipientSelection recipient) {
    if (_isStartingTransfer) {
      return;
    }

    HapticFeedback.selectionClick();

    setState(() {
      _selectedRecipient = recipient;
    });
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
            category: TransactionCategory.fromLabel(widget.category),
            receiverIdentifier: receiverIdentifier,
            idempotencyKey: _idempotencyKey!,
          );

      _pendingTransaction = transaction;

      final ussdEventId = _createUssdEventId();

      if (supportsIosManualTransactionConfirmation) {
        _awaitingIosManualConfirmation = true;
        _iosTransferLeftForeground = false;
      }

      try {
        await _ussdTransferService.launch(
          transferType: transferType,
          recipientType: recipientType,
          receiverIdentifier: receiverIdentifier,
          amount: amount,
        );
      } catch (_) {
        if (supportsIosManualTransactionConfirmation) {
          _resetIosManualConfirmation();
        }

        rethrow;
      }

      try {
        _pendingTransaction = await _transactionService.recordUssdOpened(
          transactionId: transaction.id,
          clientEventId: ussdEventId,
        );
      } on ApiException catch (error) {
        if (!mounted) {
          return;
        }

        AppToast.info(
          context,
          title: '${transferType.label} opened',
          description:
              'The MTN prompt opened, but Budgetify could not sync the transaction status: ${error.message}',
        );

        return;
      } catch (_) {
        if (!mounted) {
          return;
        }

        AppToast.info(
          context,
          title: '${transferType.label} opened',
          description:
              'The MTN prompt opened, but Budgetify could not update the transaction status.',
        );

        return;
      }

      if (!mounted) {
        return;
      }

      AppToast.info(
        context,
        title: '${transferType.label} opened',
        description: supportsIosManualTransactionConfirmation
            ? 'Complete the transfer in MTN MoMo. Budgetify will ask you to confirm the result when you return.'
            : 'Complete the transfer in MTN MoMo. Budgetify is waiting for confirmation.',
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

        if (supportsIosManualTransactionConfirmation &&
            _awaitingIosManualConfirmation) {
          unawaited(_presentIosManualConfirmationIfReady());
        }
      }
    }
  }

  Future<void> _presentIosManualConfirmationIfReady() async {
    if (!supportsIosManualTransactionConfirmation ||
        !_awaitingIosManualConfirmation ||
        !_iosTransferLeftForeground ||
        _isShowingIosManualConfirmation ||
        _isStartingTransfer ||
        !mounted ||
        _lifecycleState != AppLifecycleState.resumed) {
      return;
    }

    final transaction = _pendingTransaction;

    if (transaction == null) {
      return;
    }

    if (transaction.status != TransactionStatus.pending &&
        transaction.status != TransactionStatus.processing) {
      _resetIosManualConfirmation();
      return;
    }

    _isShowingIosManualConfirmation = true;

    try {
      await Future<void>.delayed(const Duration(milliseconds: 350));

      if (!mounted ||
          !_awaitingIosManualConfirmation ||
          !_iosTransferLeftForeground ||
          _lifecycleState != AppLifecycleState.resumed) {
        return;
      }

      final choice = await showManualTransactionConfirmationSheet(
        context,
        transaction: transaction,
      );

      if (!mounted) {
        return;
      }

      if (choice == null) {
        _resetIosManualConfirmation();
        return;
      }

      if (choice == ManualTransactionConfirmationChoice.notSure) {
        _resetIosManualConfirmation();

        AppToast.info(
          context,
          title: 'Transaction left open',
          description:
              'You can confirm the payment later from its transaction details.',
        );

        return;
      }

      final status = choice.status;

      if (status == null) {
        _resetIosManualConfirmation();
        return;
      }

      _resetIosManualConfirmation();

      setState(() {
        _isStartingTransfer = true;
      });

      try {
        final updated = await _transactionService.recordManualResult(
          transactionId: transaction.id,
          status: status,
        );

        if (!mounted) {
          return;
        }

        _pendingTransaction = null;
        _activeTransferSignature = null;
        _idempotencyKey = null;

        if (updated.status == TransactionStatus.completed) {
          AppToast.success(
            context,
            title: 'Payment recorded',
            description:
                'The transaction was manually confirmed as successful.',
          );
        } else {
          AppToast.info(
            context,
            title: 'Payment recorded',
            description: 'The transaction was manually confirmed as failed.',
          );
        }
      } on ApiException catch (error) {
        if (!mounted) {
          return;
        }

        AppToast.error(
          context,
          title: 'Could not record result',
          description: error.message,
        );
      } catch (_) {
        if (!mounted) {
          return;
        }

        AppToast.error(
          context,
          title: 'Could not record result',
          description:
              'Budgetify could not save your manual confirmation. You can try again from transaction details.',
        );
      } finally {
        if (mounted) {
          setState(() {
            _isStartingTransfer = false;
          });
        }
      }
    } finally {
      _isShowingIosManualConfirmation = false;
    }
  }

  void _resetIosManualConfirmation() {
    _awaitingIosManualConfirmation = false;
    _iosTransferLeftForeground = false;
  }

  String _createIdempotencyKey() {
    final random = Random.secure();

    final randomPart = List<int>.generate(
      16,
      (_) => random.nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();

    return 'ussd-${DateTime.now().microsecondsSinceEpoch}-$randomPart';
  }

  String _createUssdEventId() {
    final random = Random.secure();

    final randomPart = List<int>.generate(
      16,
      (_) => random.nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();

    return 'ussd-opened-${DateTime.now().microsecondsSinceEpoch}-$randomPart';
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
            constraints: const BoxConstraints(maxWidth: 560),
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
                  RecipientTopBar(onBack: () => Navigator.of(context).pop()),
                  SizedBox(height: isCompact ? 18 : 22),
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
                  Expanded(child: _buildRecipientContent()),
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
      return RecipientResultsList(
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
      _ContactsView.loading => const LoadingContacts(),
      _ContactsView.permissionPrompt => ContactsPermissionPrompt(
        onAllow: _requestContacts,
      ),
      _ContactsView.unavailable => ContactsUnavailable(
        onRetry: _requestContacts,
      ),
      _ContactsView.ready => RecipientResultsList(
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
