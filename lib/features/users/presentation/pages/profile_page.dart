import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../auth/application/auth_service_contract.dart';
import '../../../auth/data/models/auth_user.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../widgets/account_deletion_dialog.dart';
import '../widgets/delete_account_tab.dart';
import '../widgets/personal_details_tab.dart';
import '../widgets/profile_tab_selector.dart';
import '../widgets/profile_top_bar.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.authService,
    required this.user,
    required this.onUserChanged,
  });

  final AuthServiceContract authService;
  final AuthUser user;
  final ValueChanged<AuthUser> onUserChanged;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late AuthUser _user;

  ProfileTab _selectedTab = ProfileTab.profile;
  bool _isSaving = false;
  bool _isLoggingOut = false;
  bool _isDeleting = false;

  bool get _isBusy => _isSaving || _isLoggingOut || _isDeleting;

  bool get _hasProfileChanges {
    return _firstNameController.text.trim() != (_user.firstName ?? '') ||
        _lastNameController.text.trim() != (_user.lastName ?? '');
  }

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _firstNameController = TextEditingController(text: _user.firstName ?? '');
    _lastNameController = TextEditingController(text: _user.lastName ?? '');
    _firstNameController.addListener(_refreshFormState);
    _lastNameController.addListener(_refreshFormState);
  }

  @override
  void dispose() {
    _firstNameController
      ..removeListener(_refreshFormState)
      ..dispose();
    _lastNameController
      ..removeListener(_refreshFormState)
      ..dispose();
    super.dispose();
  }

  void _refreshFormState() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false) ||
        !_hasProfileChanges ||
        _isBusy) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updatedUser = await widget.authService.updateCurrentUserNames(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _user = updatedUser;
        _isSaving = false;
      });
      widget.onUserChanged(updatedUser);

      AppToast.success(
        context,
        title: 'Profile updated',
        description: 'Your name has been saved.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _isSaving = false);
      AppToast.error(
        context,
        title: 'Could not update profile',
        description: _readableError(error),
      );
    }
  }

  Future<void> _logout() async {
    if (_isBusy) {
      return;
    }

    setState(() => _isLoggingOut = true);

    try {
      await widget.authService.logout();
    } catch (_) {
      // AuthService clears local credentials even when remote logout fails.
    }

    if (mounted) {
      _openLogin();
    }
  }

  Future<void> _confirmDeletion() async {
    if (_isBusy) {
      return;
    }

    final shouldDelete = await showAccountDeletionDialog(context);
    if (shouldDelete == true) {
      await _deleteAccount();
    }
  }

  Future<void> _deleteAccount() async {
    setState(() => _isDeleting = true);

    try {
      final updatedUser = await widget.authService
          .requestCurrentUserDeletion();

      if (!mounted) {
        return;
      }

      widget.onUserChanged(updatedUser);

      try {
        await widget.authService.logout();
      } catch (_) {
        // AuthService still clears the local session before this completes.
      }

      if (mounted) {
        _openLogin();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _isDeleting = false);
      AppToast.error(
        context,
        title: 'Could not schedule deletion',
        description: _readableError(error),
      );
    }
  }

  void _openLogin() {
    Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(
        builder: (_) => LoginPage(authService: widget.authService),
      ),
      (route) => false,
    );
  }

  String _readableError(Object error) {
    if (error is ApiException) {
      return error.message;
    }

    return 'Please check your connection and try again.';
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isCompact = mediaQuery.size.width < 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isCompact ? 16 : 28,
                isCompact ? 14 : 22,
                isCompact ? 16 : 28,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProfileTopBar(
                    isLoggingOut: _isLoggingOut,
                    onBack: () => Navigator.of(context).pop(),
                    onLogout: _isBusy ? null : _logout,
                  ),
                  SizedBox(height: isCompact ? 32 : 48),
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.only(
                        bottom: 32 + mediaQuery.viewInsets.bottom,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FractionallySizedBox(
                            widthFactor: isCompact ? 0.88 : 0.66,
                            child: ProfileTabSelector(
                              selectedTab: _selectedTab,
                              onSelected: (tab) {
                                FocusScope.of(context).unfocus();
                                setState(() => _selectedTab = tab);
                              },
                            ),
                          ),
                          SizedBox(height: isCompact ? 24 : 32),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: _selectedTab == ProfileTab.profile
                                ? PersonalDetailsTab(
                                    key: const ValueKey(ProfileTab.profile),
                                    formKey: _formKey,
                                    firstNameController: _firstNameController,
                                    lastNameController: _lastNameController,
                                    enabled: !_isBusy,
                                    canSave: _hasProfileChanges && !_isBusy,
                                    isSaving: _isSaving,
                                    onSave: _saveProfile,
                                  )
                                : DeleteAccountTab(
                                    key: const ValueKey(
                                      ProfileTab.deleteAccount,
                                    ),
                                    scheduledFor:
                                        _user.accountDeletionScheduledFor,
                                    enabled: !_isBusy,
                                    isDeleting: _isDeleting,
                                    onDelete: _confirmDeletion,
                                  ),
                          ),
                        ],
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
}
