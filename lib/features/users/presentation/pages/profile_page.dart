import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_input.dart';
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

  bool get _isBusy {
    return _isSaving || _isLoggingOut || _isDeleting;
  }

  bool get _hasProfileChanges {
    return _firstNameController.text.trim() != (_user.firstName ?? '') ||
        _lastNameController.text.trim() != (_user.lastName ?? '');
  }

  @override
  void initState() {
    super.initState();

    _user = widget.user;

    _firstNameController = TextEditingController(
      text: _user.firstName ?? '',
    );

    _lastNameController = TextEditingController(
      text: _user.lastName ?? '',
    );

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
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false) ||
        !_hasProfileChanges ||
        _isBusy) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

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

      setState(() {
        _isSaving = false;
      });

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

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await widget.authService.logout();
    } catch (_) {
      // AuthService clears local credentials even when the
      // remote logout request cannot be completed.
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
                    onTap: () {
                      Navigator.of(dialogContext).pop(false);
                    },
                  ),
                ],
              ),
              const SizedBox(
                height: 22,
              ),
              const Text(
                'Delete your account?',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              const Text(
                'Your account will be scheduled for deletion in 30 days. '
                'Signing in again during that period will cancel the request.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.55,
                ),
              ),
              const SizedBox(
                height: 24,
              ),
              Row(
                children: [
                  Expanded(
                    child: AppModalActionButton(
                      label: 'Keep account',
                      onPressed: () {
                        Navigator.of(dialogContext).pop(false);
                      },
                    ),
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  Expanded(
                    child: AppModalActionButton(
                      label: 'Delete account',
                      isPrimary: true,
                      primaryColor: AppColors.danger,
                      primaryForegroundColor: AppColors.textPrimary,
                      onPressed: () {
                        Navigator.of(dialogContext).pop(true);
                      },
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
    setState(() {
      _isDeleting = true;
    });

    try {
      final updatedUser =
          await widget.authService.requestCurrentUserDeletion();

      if (!mounted) {
        return;
      }

      widget.onUserChanged(updatedUser);

      try {
        await widget.authService.logout();
      } catch (_) {
        // Local authentication state is still cleared by AuthService.
      }

      if (!mounted) {
        return;
      }

      _openLogin();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isDeleting = false;
      });

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
        builder: (_) {
          return LoginPage(
            authService: widget.authService,
          );
        },
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
    final width = mediaQuery.size.width;

    final isCompact = width < 600;
    final isWide = width >= 820;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 900,
            ),
            child: SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                isCompact ? 16 : 28,
                isCompact ? 14 : 22,
                isCompact ? 16 : 28,
                32 + mediaQuery.viewInsets.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProfileHeader(
                    compact: isCompact,
                    onBack: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  SizedBox(
                    height: isCompact ? 24 : 32,
                  ),
                  _IdentityHero(
                    user: _user,
                    compact: isCompact,
                  ),
                  SizedBox(
                    height: isCompact ? 14 : 18,
                  ),
                  _AccountOverview(
                    user: _user,
                    compact: isCompact,
                  ),
                  SizedBox(
                    height: isCompact ? 26 : 32,
                  ),
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 6,
                          child: _ProfileForm(
                            formKey: _formKey,
                            firstNameController:
                                _firstNameController,
                            lastNameController:
                                _lastNameController,
                            enabled: !_isBusy,
                            canSave:
                                _hasProfileChanges && !_isBusy,
                            isSaving: _isSaving,
                            onSave: _saveProfile,
                          ),
                        ),
                        const SizedBox(
                          width: 18,
                        ),
                        Expanded(
                          flex: 4,
                          child: Column(
                            children: [
                              _SessionPanel(
                                isLoggingOut: _isLoggingOut,
                                enabled: !_isBusy,
                                onLogout: _logout,
                              ),
                              const SizedBox(
                                height: 18,
                              ),
                              _DangerZone(
                                scheduledFor:
                                    _user.accountDeletionScheduledFor,
                                isDeleting: _isDeleting,
                                enabled: !_isBusy,
                                onDelete: _confirmDeletion,
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _ProfileForm(
                      formKey: _formKey,
                      firstNameController: _firstNameController,
                      lastNameController: _lastNameController,
                      enabled: !_isBusy,
                      canSave: _hasProfileChanges && !_isBusy,
                      isSaving: _isSaving,
                      onSave: _saveProfile,
                    ),
                    const SizedBox(
                      height: 18,
                    ),
                    _SessionPanel(
                      isLoggingOut: _isLoggingOut,
                      enabled: !_isBusy,
                      onLogout: _logout,
                    ),
                    const SizedBox(
                      height: 18,
                    ),
                    _DangerZone(
                      scheduledFor:
                          _user.accountDeletionScheduledFor,
                      isDeleting: _isDeleting,
                      enabled: !_isBusy,
                      onDelete: _confirmDeletion,
                    ),
                  ],
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
  const _ProfileHeader({
    required this.compact,
    required this.onBack,
  });

  final bool compact;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BackButton(
          onPressed: onBack,
        ),
        const SizedBox(
          width: 16,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PROFILE',
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
                height: 9,
              ),
              Text(
                'Your account',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(
                      fontSize: compact ? 25 : 30,
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
                'Manage your identity, account details and security.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
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

class _BackButton extends StatelessWidget {
  const _BackButton({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(
            16,
          ),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(
                16,
              ),
            ),
            alignment: Alignment.center,
            child: const HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              size: 19,
              color: AppColors.textPrimary,
              strokeWidth: 1.9,
            ),
          ),
        ),
      ),
    );
  }
}

class _IdentityHero extends StatelessWidget {
  const _IdentityHero({
    required this.user,
    required this.compact,
  });

  final AuthUser user;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final displayName =
        user.fullName?.trim().isNotEmpty == true
            ? user.fullName!.trim()
            : 'Budgetify member';

    return Container(
      padding: EdgeInsets.all(
        compact ? 18 : 24,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(
          compact ? 26 : 30,
        ),
      ),
      child: compact
          ? Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    _ProfileAvatar(
                      user: user,
                      size: 74,
                    ),
                    const SizedBox(
                      width: 16,
                    ),
                    Expanded(
                      child: _IdentityDetails(
                        displayName: displayName,
                        user: user,
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 18,
                ),
                _AccountStateStrip(
                  user: user,
                ),
              ],
            )
          : Row(
              children: [
                _ProfileAvatar(
                  user: user,
                  size: 86,
                ),
                const SizedBox(
                  width: 20,
                ),
                Expanded(
                  child: _IdentityDetails(
                    displayName: displayName,
                    user: user,
                  ),
                ),
                const SizedBox(
                  width: 20,
                ),
                _AccountStateStrip(
                  user: user,
                ),
              ],
            ),
    );
  }
}

class _IdentityDetails extends StatelessWidget {
  const _IdentityDetails({
    required this.displayName,
    required this.user,
  });

  final String displayName;
  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          displayName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            height: 1.12,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(
          height: 7,
        ),
        Text(
          user.email,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        if (user.isEmailVerified) ...[
          const SizedBox(
            height: 12,
          ),
          const _VerifiedBadge(),
        ],
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.user,
    required this.size,
  });

  final AuthUser user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final avatarUrl =
        user.avatarUrl?.trim();

    final initials =
        _initials(user);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(
          alpha: 0.12,
        ),
      ),
      child: ClipOval(
        child: avatarUrl == null ||
                avatarUrl.isEmpty
            ? Center(
                child: Text(
                  initials,
                  style: TextStyle(
                    color:
                        AppColors.textPrimary,
                    fontSize:
                        size * 0.27,
                    fontWeight:
                        FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              )
            : Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, _, _) {
                  return Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: AppColors
                            .textPrimary,
                        fontSize:
                            size * 0.27,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  static String _initials(
    AuthUser user,
  ) {
    final names = <String>[
      if (user.firstName
              ?.trim()
              .isNotEmpty ==
          true)
        user.firstName!.trim(),
      if (user.lastName
              ?.trim()
              .isNotEmpty ==
          true)
        user.lastName!.trim(),
    ];

    if (names.isNotEmpty) {
      return names
          .take(2)
          .map(
            (name) =>
                String.fromCharCode(
                  name.runes.first,
                ),
          )
          .join()
          .toUpperCase();
    }

    final emailName =
        user.email.split('@').first.trim();

    if (emailName.isEmpty) {
      return '?';
    }

    return String.fromCharCode(
      emailName.runes.first,
    ).toUpperCase();
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(
          alpha: 0.10,
        ),
        borderRadius: BorderRadius.circular(
          999,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon:
                HugeIcons.strokeRoundedCheckmarkCircle02,
            size: 13,
            color: AppColors.success,
            strokeWidth: 2,
          ),
          SizedBox(
            width: 6,
          ),
          Text(
            'Verified email',
            style: TextStyle(
              color: AppColors.success,
              fontSize: 10,
              height: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountStateStrip extends StatelessWidget {
  const _AccountStateStrip({
    required this.user,
  });

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final isActive =
        user.status.toUpperCase() == 'ACTIVE';

    final color = isActive
        ? AppColors.success
        : AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.10,
        ),
        borderRadius: BorderRadius.circular(
          999,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(
            width: 7,
          ),
          Text(
            _capitalize(
              user.status,
            ),
            style: TextStyle(
              color: color,
              fontSize: 10,
              height: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountOverview extends StatelessWidget {
  const _AccountOverview({
    required this.user,
    required this.compact,
  });

  final AuthUser user;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final items = [
      _OverviewItem(
        label: 'EMAIL',
        value: user.isEmailVerified
            ? 'Verified'
            : 'Not verified',
        icon:
            HugeIcons.strokeRoundedCheckmarkCircle02,
        accent: user.isEmailVerified
            ? AppColors.success
            : AppColors.primary,
      ),
      _OverviewItem(
        label: 'MEMBER SINCE',
        value: _formatMonthYear(
          user.createdAt,
        ),
        icon:
            HugeIcons.strokeRoundedUser02,
        accent: AppColors.primary,
      ),
      _OverviewItem(
        label: 'LAST LOGIN',
        value: user.lastLoginAt == null
            ? 'Not available'
            : _formatDate(
                user.lastLoginAt!,
              ),
        icon:
            HugeIcons.strokeRoundedUserSquare,
        accent:
            AppColors.textSecondary,
      ),
    ];

    if (compact) {
      return Column(
        children: [
          for (
            var index = 0;
            index < items.length;
            index++
          ) ...[
            _OverviewCard(
              item: items[index],
            ),
            if (index <
                items.length - 1)
              const SizedBox(
                height: 10,
              ),
          ],
        ],
      );
    }

    return Row(
      children: [
        for (
          var index = 0;
          index < items.length;
          index++
        ) ...[
          if (index > 0)
            const SizedBox(
              width: 12,
            ),
          Expanded(
            child: _OverviewCard(
              item: items[index],
            ),
          ),
        ],
      ],
    );
  }
}

class _OverviewItem {
  const _OverviewItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final dynamic icon;
  final Color accent;
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.item,
  });

  final _OverviewItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(
        16,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(
          20,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: item.accent.withValues(
                alpha: 0.10,
              ),
              borderRadius:
                  BorderRadius.circular(
                13,
              ),
            ),
            alignment: Alignment.center,
            child: HugeIcon(
              icon: item.icon,
              size: 17,
              strokeWidth: 1.8,
              color: item.accent,
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                    color:
                        AppColors.textSecondary,
                    fontSize: 9,
                    height: 1,
                    fontWeight:
                        FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(
                  height: 7,
                ),
                Text(
                  item.value,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color:
                        AppColors.textPrimary,
                    fontSize: 12,
                    height: 1.2,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ],
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

  final TextEditingController
      firstNameController;

  final TextEditingController
      lastNameController;

  final bool enabled;
  final bool canSave;
  final bool isSaving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return _SectionSurface(
      eyebrow: 'PERSONAL DETAILS',
      title: 'Your name',
      description:
          'Keep the name associated with your Budgetify account up to date.',
      icon: HugeIcons.strokeRoundedUser02,
      child: Form(
        key: formKey,
        child: Column(
          children: [
            AppInput(
              controller:
                  firstNameController,
              enabled: enabled,
              label: 'First name',
              leadingIcon:
                  HugeIcons.strokeRoundedUser02,
              textCapitalization:
                  TextCapitalization.words,
              keyboardType:
                  TextInputType.name,
              textInputAction:
                  TextInputAction.next,
              autofillHints: const [
                AutofillHints.givenName,
              ],
              maxLength: 60,
              validator: (value) {
                return _validateName(
                  value,
                  'First name',
                );
              },
            ),
            const SizedBox(
              height: 12,
            ),
            AppInput(
              controller:
                  lastNameController,
              enabled: enabled,
              label: 'Last name',
              leadingIcon:
                  HugeIcons.strokeRoundedUserSquare,
              textCapitalization:
                  TextCapitalization.words,
              keyboardType:
                  TextInputType.name,
              textInputAction:
                  TextInputAction.done,
              autofillHints: const [
                AutofillHints.familyName,
              ],
              maxLength: 60,
              validator: (value) {
                return _validateName(
                  value,
                  'Last name',
                );
              },
              onSubmitted: (_) {
                if (canSave) {
                  onSave();
                }
              },
            ),
            const SizedBox(
              height: 18,
            ),
            AppButton(
              label: 'Save changes',
              icon:
                  HugeIcons.strokeRoundedFloppyDisk,
              size: AppButtonSize.md,
              isLoading: isSaving,
              onPressed:
                  canSave ? onSave : null,
            ),
          ],
        ),
      ),
    );
  }

  static String? _validateName(
    String? value,
    String label,
  ) {
    final normalized =
        value?.trim() ?? '';

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
    return _SectionSurface(
      eyebrow: 'SESSION',
      title: 'Signed in',
      description:
          'Sign out of Budgetify on this device.',
      icon: HugeIcons.strokeRoundedLogout01,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Container(
            padding:
                const EdgeInsets.all(
              14,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: 0.035,
              ),
              borderRadius:
                  BorderRadius.circular(
                18,
              ),
            ),
            child: const Row(
              children: [
                _SessionIndicator(),
                SizedBox(
                  width: 11,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current device',
                        style: TextStyle(
                          color: AppColors
                              .textPrimary,
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                      SizedBox(
                        height: 4,
                      ),
                      Text(
                        'This session is active',
                        style: TextStyle(
                          color: AppColors
                              .textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            height: 14,
          ),
          AppButton(
            label: 'Log out',
            icon:
                HugeIcons.strokeRoundedLogout01,
            variant:
                AppButtonVariant.secondary,
            isLoading: isLoggingOut,
            onPressed:
                enabled ? onLogout : null,
          ),
        ],
      ),
    );
  }
}

class _SessionIndicator extends StatelessWidget {
  const _SessionIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.success.withValues(
          alpha: 0.10,
        ),
        borderRadius: BorderRadius.circular(
          12,
        ),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.success,
        ),
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
    final isScheduled =
        scheduledFor != null;

    return Container(
      padding: const EdgeInsets.all(
        20,
      ),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(
          alpha: 0.045,
        ),
        borderRadius: BorderRadius.circular(
          24,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _DangerIcon(),
              const SizedBox(
                width: 12,
              ),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account deletion',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontSize: 15,
                        height: 1.2,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                    SizedBox(
                      height: 4,
                    ),
                    Text(
                      'Permanent account action',
                      style: TextStyle(
                        color: AppColors
                            .textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 16,
          ),
          Text(
            isScheduled
                ? 'Your account is scheduled for deletion on '
                    '${_formatDate(scheduledFor!)}. Signing in again '
                    'during the grace period will cancel the request.'
                : 'Request account deletion with a 30-day grace period '
                    'before your account is permanently removed.',
            style: const TextStyle(
              color:
                  AppColors.textSecondary,
              fontSize: 11,
              height: 1.55,
            ),
          ),
          const SizedBox(
            height: 18,
          ),
          AppButton(
            label: isScheduled
                ? 'Deletion scheduled'
                : 'Delete my account',
            icon:
                HugeIcons.strokeRoundedDelete02,
            variant:
                AppButtonVariant.ghost,
            isLoading: isDeleting,
            onPressed:
                enabled && !isScheduled
                    ? onDelete
                    : null,
          ),
        ],
      ),
    );
  }
}

class _SectionSurface extends StatelessWidget {
  const _SectionSurface({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.icon,
    required this.child,
  });

  final String eyebrow;
  final String title;
  final String description;
  final dynamic icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(
        20,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(
          24,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow,
                      style: TextStyle(
                        color: AppColors
                            .primary
                            .withValues(
                          alpha: 0.86,
                        ),
                        fontSize: 9,
                        height: 1,
                        fontWeight:
                            FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors
                            .textPrimary,
                        fontSize: 17,
                        height: 1.2,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                    const SizedBox(
                      height: 6,
                    ),
                    Text(
                      description,
                      style: const TextStyle(
                        color: AppColors
                            .textSecondary,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                width: 14,
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: 0.045,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                alignment: Alignment.center,
                child: HugeIcon(
                  icon: icon,
                  size: 18,
                  strokeWidth: 1.8,
                  color:
                      AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 20,
          ),
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
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(
          alpha: 0.11,
        ),
        borderRadius: BorderRadius.circular(
          14,
        ),
      ),
      alignment: Alignment.center,
      child: const HugeIcon(
        icon:
            HugeIcons.strokeRoundedAlertCircle,
        size: 19,
        color: AppColors.danger,
        strokeWidth: 1.9,
      ),
    );
  }
}

String _capitalize(
  String value,
) {
  if (value.isEmpty) {
    return value;
  }

  final lower =
      value.toLowerCase();

  return '${lower[0].toUpperCase()}${lower.substring(1)}';
}

String _formatMonthYear(
  DateTime date,
) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final localDate =
      date.toLocal();

  return '${months[localDate.month - 1]} ${localDate.year}';
}

String _formatDate(
  DateTime date,
) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final localDate =
      date.toLocal();

  return '${localDate.day} ${months[localDate.month - 1]} ${localDate.year}';
}