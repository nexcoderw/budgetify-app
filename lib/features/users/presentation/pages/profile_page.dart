import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_modal_dialog.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../auth/application/auth_service_contract.dart';
import '../../../auth/data/models/auth_user.dart';
import '../../../auth/presentation/pages/login_page.dart';

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
      // AuthService clears local credentials in its finally block even when
      // the remote logout request cannot be completed.
    }

    if (!mounted) {
      return;
    }

    _openLogin();
  }

  Future<void> _confirmDeletion() async {
    if (_isBusy) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AppModalDialog(
          maxWidth: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _DangerIcon(),
                  const Spacer(),
                  AppModalCloseButton(
                    onTap: () => Navigator.of(dialogContext).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Delete your account?',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your deletion will be scheduled for 30 days from today. '
                'Signing in again during that period will cancel the request.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: AppModalActionButton(
                      label: 'Keep account',
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppModalActionButton(
                      label: 'Delete account',
                      isPrimary: true,
                      primaryColor: AppColors.danger,
                      primaryForegroundColor: AppColors.textPrimary,
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

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
        // The local session is still cleared by AuthService.
      }

      if (!mounted) {
        return;
      }

      _openLogin();
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
    final isCompact = mediaQuery.size.width < 560;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                isCompact ? 16 : 28,
                14,
                isCompact ? 16 : 28,
                30 + mediaQuery.viewInsets.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProfileHeader(onBack: () => Navigator.of(context).pop()),
                  SizedBox(height: isCompact ? 24 : 32),
                  _IdentityPanel(user: _user),
                  const SizedBox(height: 18),
                  _ProfileForm(
                    formKey: _formKey,
                    firstNameController: _firstNameController,
                    lastNameController: _lastNameController,
                    enabled: !_isBusy,
                    canSave: _hasProfileChanges && !_isBusy,
                    isSaving: _isSaving,
                    onSave: _saveProfile,
                  ),
                  const SizedBox(height: 18),
                  _SessionPanel(
                    isLoggingOut: _isLoggingOut,
                    enabled: !_isBusy,
                    onLogout: _logout,
                  ),
                  const SizedBox(height: 18),
                  _DangerZone(
                    scheduledFor: _user.accountDeletionScheduledFor,
                    isDeleting: _isDeleting,
                    enabled: !_isBusy,
                    onDelete: _confirmDeletion,
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

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: onBack,
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            size: 20,
            color: AppColors.textPrimary,
            strokeWidth: 1.9,
          ),
          style: IconButton.styleFrom(
            minimumSize: const Size.square(46),
            backgroundColor: AppColors.surface,
            shape: const CircleBorder(),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 23,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Identity and account controls',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IdentityPanel extends StatelessWidget {
  const _IdentityPanel({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final displayName = user.fullName?.trim().isNotEmpty == true
        ? user.fullName!.trim()
        : 'Budgetify member';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          _ProfileAvatar(user: user),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 21,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (user.isEmailVerified) ...[
                  const SizedBox(height: 10),
                  const _VerifiedBadge(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user.avatarUrl?.trim();
    final initials = _initials(user);

    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: avatarUrl == null || avatarUrl.isEmpty
            ? Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              )
            : Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  static String _initials(AuthUser user) {
    final names = <String>[
      if (user.firstName?.trim().isNotEmpty == true) user.firstName!.trim(),
      if (user.lastName?.trim().isNotEmpty == true) user.lastName!.trim(),
    ];

    if (names.isNotEmpty) {
      return names
          .take(2)
          .map((name) => String.fromCharCode(name.runes.first))
          .join()
          .toUpperCase();
    }

    final emailName = user.email.split('@').first.trim();
    return emailName.isEmpty
        ? '?'
        : String.fromCharCode(emailName.runes.first).toUpperCase();
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.24)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
            size: 13,
            color: AppColors.success,
            strokeWidth: 2,
          ),
          SizedBox(width: 5),
          Text(
            'Verified email',
            style: TextStyle(
              color: AppColors.success,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileForm extends StatelessWidget {
  const _ProfileForm({
    required this.formKey,
    required this.firstNameController,
    required this.lastNameController,
    required this.enabled,
    required this.canSave,
    required this.isSaving,
    required this.onSave,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final bool enabled;
  final bool canSave;
  final bool isSaving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return _SectionPanel(
      title: 'Your name',
      description: 'This is how your identity appears across Budgetify.',
      child: Form(
        key: formKey,
        child: Column(
          children: [
            TextFormField(
              controller: firstNameController,
              enabled: enabled,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.givenName],
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: 'First name',
                counterText: '',
              ),
              validator: (value) => _validateName(value, 'First name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: lastNameController,
              enabled: enabled,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.familyName],
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: 'Last name',
                counterText: '',
              ),
              validator: (value) => _validateName(value, 'Last name'),
              onFieldSubmitted: (_) {
                if (canSave) {
                  onSave();
                }
              },
            ),
            const SizedBox(height: 18),
            AppButton(
              label: 'Save changes',
              icon: HugeIcons.strokeRoundedFloppyDisk,
              size: AppButtonSize.md,
              isLoading: isSaving,
              onPressed: canSave ? onSave : null,
            ),
          ],
        ),
      ),
    );
  }

  static String? _validateName(String? value, String label) {
    final normalized = value?.trim() ?? '';

    if (normalized.isEmpty) {
      return '$label is required.';
    }

    if (normalized.length > 60) {
      return '$label must not exceed 60 characters.';
    }

    return null;
  }
}

class _SessionPanel extends StatelessWidget {
  const _SessionPanel({
    required this.isLoggingOut,
    required this.enabled,
    required this.onLogout,
  });

  final bool isLoggingOut;
  final bool enabled;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return _SectionPanel(
      title: 'Current session',
      description: 'Sign out securely on this device.',
      child: AppButton(
        label: 'Log out',
        icon: HugeIcons.strokeRoundedLogout01,
        variant: AppButtonVariant.secondary,
        isLoading: isLoggingOut,
        onPressed: enabled ? onLogout : null,
      ),
    );
  }
}

class _DangerZone extends StatelessWidget {
  const _DangerZone({
    required this.scheduledFor,
    required this.isDeleting,
    required this.enabled,
    required this.onDelete,
  });

  final DateTime? scheduledFor;
  final bool isDeleting;
  final bool enabled;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delete account',
            style: TextStyle(
              color: AppColors.danger,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            scheduledFor == null
                ? 'Schedule permanent deletion after a 30-day grace period.'
                : 'Deletion is already scheduled. Signing in again cancels the request.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          AppButton(
            label: scheduledFor == null
                ? 'Delete my account'
                : 'Deletion scheduled',
            icon: HugeIcons.strokeRoundedDelete02,
            variant: AppButtonVariant.ghost,
            isLoading: isDeleting,
            onPressed: enabled && scheduledFor == null ? onDelete : null,
          ),
        ],
      ),
    );
  }
}

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _DangerIcon extends StatelessWidget {
  const _DangerIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.danger.withValues(alpha: 0.12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.26)),
      ),
      child: const Center(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedAlertCircle,
          size: 21,
          color: AppColors.danger,
          strokeWidth: 1.9,
        ),
      ),
    );
  }
}
