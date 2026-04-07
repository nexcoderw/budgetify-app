import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_modal_dialog.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../application/auth_service_contract.dart';
import '../../data/models/auth_user.dart';

class ProfileCompletionDialog extends StatefulWidget {
  const ProfileCompletionDialog({
    super.key,
    required this.authService,
    required this.user,
  });

  final AuthServiceContract authService;
  final AuthUser user;

  static bool needsCompletion(AuthUser user) {
    return !_hasText(user.firstName) && !_hasText(user.lastName);
  }

  static Future<AuthUser> showIfRequired(
    BuildContext context, {
    required AuthServiceContract authService,
    required AuthUser user,
  }) async {
    if (!needsCompletion(user)) {
      return user;
    }

    final updatedUser = await showDialog<AuthUser>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (dialogContext) =>
          ProfileCompletionDialog(authService: authService, user: user),
    );

    return updatedUser ?? user;
  }

  static bool _hasText(String? value) {
    return value?.trim().isNotEmpty ?? false;
  }

  @override
  State<ProfileCompletionDialog> createState() =>
      _ProfileCompletionDialogState();
}

class _ProfileCompletionDialogState extends State<ProfileCompletionDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final FocusNode _firstNameFocusNode;
  late final FocusNode _lastNameFocusNode;
  late final AnimationController _dialogController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _firstNameFocusNode = FocusNode();
    _lastNameFocusNode = FocusNode();
    _dialogController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _firstNameFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _firstNameFocusNode.dispose();
    _lastNameFocusNode.dispose();
    _dialogController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      final updatedUser = await widget.authService.updateCurrentUserNames(
        firstName: _normalizeName(_firstNameController.text),
        lastName: _normalizeName(_lastNameController.text),
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(updatedUser);
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Unable to save your profile',
        description: _readableError(error),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _normalizeName(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _readableError(Object error) {
    final message = error.toString().trim();

    if (message.startsWith('Exception: ')) {
      return message.replaceFirst('Exception: ', '');
    }

    if (message.startsWith('StateError: ')) {
      return message.replaceFirst('StateError: ', '');
    }

    return message;
  }

  String? _validateName(String? value, String label) {
    final normalized = _normalizeName(value ?? '');

    if (normalized.isEmpty) {
      return 'Enter your $label.';
    }

    if (normalized.length > 60) {
      return '$label must stay under 60 characters.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(
      parent: _dialogController,
      curve: Curves.easeOutCubic,
    );
    final scale = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(parent: _dialogController, curve: Curves.easeOutBack),
    );

    return PopScope(
      canPop: false,
      child: FadeTransition(
        opacity: fade,
        child: ScaleTransition(
          scale: scale,
          child: AppModalDialog(
            maxWidth: 520,
            padding: const EdgeInsets.all(24),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 32,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileHeader(email: widget.user.email),
                  const SizedBox(height: 22),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 360;

                      if (isCompact) {
                        return Column(
                          children: [
                            _NameField(
                              controller: _firstNameController,
                              focusNode: _firstNameFocusNode,
                              label: 'First name',
                              hintText: 'Alice',
                              icon: HugeIcons.strokeRoundedUser02,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) {
                                _lastNameFocusNode.requestFocus();
                              },
                              validator: (value) =>
                                  _validateName(value, 'first name'),
                            ),
                            const SizedBox(height: 12),
                            _NameField(
                              controller: _lastNameController,
                              focusNode: _lastNameFocusNode,
                              label: 'Last name',
                              hintText: 'Mutoni',
                              icon: HugeIcons.strokeRoundedUserSquare,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                              validator: (value) =>
                                  _validateName(value, 'last name'),
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(
                            child: _NameField(
                              controller: _firstNameController,
                              focusNode: _firstNameFocusNode,
                              label: 'First name',
                              hintText: 'Alice',
                              icon: HugeIcons.strokeRoundedUser02,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) {
                                _lastNameFocusNode.requestFocus();
                              },
                              validator: (value) =>
                                  _validateName(value, 'first name'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _NameField(
                              controller: _lastNameController,
                              focusNode: _lastNameFocusNode,
                              label: 'Last name',
                              hintText: 'Mutoni',
                              icon: HugeIcons.strokeRoundedUserSquare,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                              validator: (value) =>
                                  _validateName(value, 'last name'),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary.withValues(alpha: 0.10),
                          Colors.white.withValues(alpha: 0.04),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Center(
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedSparkles,
                              size: 16,
                              color: AppColors.primary,
                              strokeWidth: 1.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'These names will appear across your dashboard, activity history, and account profile.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontFamily: 'DMSans',
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: AppModalActionButton(
                      label: 'Save and continue',
                      isPrimary: true,
                      isLoading: _isSaving,
                      onPressed: _submit,
                      primaryColor: AppColors.primary,
                      primaryForegroundColor: AppColors.background,
                      leading: HugeIcon(
                        icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                        size: 18,
                        color: AppColors.background,
                        strokeWidth: 1.8,
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

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.20),
                    Colors.white.withValues(alpha: 0.08),
                  ],
                ),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.28),
                ),
              ),
              child: const Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedUserCircle,
                  size: 26,
                  color: AppColors.primary,
                  strokeWidth: 1.8,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Complete your profile',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.textPrimary,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.55,
              fontFamily: 'DMSans',
            ),
            children: [
              const TextSpan(
                text:
                    'Before we open your workspace, add the name that should appear on your account for ',
              ),
              TextSpan(
                text: email,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(text: '.'),
            ],
          ),
        ),
      ],
    );
  }
}

class _NameField extends StatefulWidget {
  const _NameField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hintText,
    required this.icon,
    required this.textInputAction,
    required this.onSubmitted,
    required this.validator,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String hintText;
  final List<List<dynamic>> icon;
  final TextInputAction textInputAction;
  final ValueChanged<String> onSubmitted;
  final String? Function(String?) validator;

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChange);
    super.dispose();
  }

  void _handleFocusChange() {
    if (_isFocused == widget.focusNode.hasFocus) {
      return;
    }

    setState(() => _isFocused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.16),
                  blurRadius: 18,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        textCapitalization: TextCapitalization.words,
        keyboardType: TextInputType.name,
        textInputAction: widget.textInputAction,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        validator: widget.validator,
        onFieldSubmitted: widget.onSubmitted,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hintText,
          labelStyle: TextStyle(
            color: _isFocused ? AppColors.primary : AppColors.textSecondary,
            fontSize: 13,
          ),
          hintStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 18, right: 12),
            child: HugeIcon(
              icon: widget.icon,
              size: 18,
              color: _isFocused ? AppColors.primary : AppColors.textSecondary,
              strokeWidth: 1.8,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          filled: true,
          fillColor: AppColors.surfaceElevated,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
          ),
          errorStyle: const TextStyle(fontSize: 11, color: AppColors.danger),
        ),
      ),
    );
  }
}
