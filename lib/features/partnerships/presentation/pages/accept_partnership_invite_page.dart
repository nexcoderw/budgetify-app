import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../auth/data/models/auth_user.dart';
import '../../application/partnership_service.dart';
import '../../data/models/partnership_models.dart';
import '../partnership_view_utils.dart';

class AcceptPartnershipInvitePage extends StatefulWidget {
  const AcceptPartnershipInvitePage({
    super.key,
    required this.currentUser,
    required this.partnershipService,
    this.initialInviteValue,
  });

  final AuthUser currentUser;
  final PartnershipService partnershipService;
  final String? initialInviteValue;

  @override
  State<AcceptPartnershipInvitePage> createState() =>
      _AcceptPartnershipInvitePageState();
}

class _AcceptPartnershipInvitePageState
    extends State<AcceptPartnershipInvitePage> {
  late final TextEditingController _inviteTokenCtrl;

  InviteInfo? _inviteInfo;
  bool _isLoadingPreview = false;
  bool _isAcceptingInvite = false;
  String? _inviteInfoError;

  @override
  void initState() {
    super.initState();
    _inviteTokenCtrl = TextEditingController(
      text: widget.initialInviteValue?.trim() ?? '',
    );

    if (_inviteTokenCtrl.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _previewInvite();
      });
    }
  }

  @override
  void dispose() {
    _inviteTokenCtrl.dispose();
    super.dispose();
  }

  bool get _inviteEmailMismatch {
    if (_inviteInfo == null) {
      return false;
    }

    return widget.currentUser.email.trim().toLowerCase() !=
        _inviteInfo!.inviteeEmail.trim().toLowerCase();
  }

  String get _ownerLabel {
    final info = _inviteInfo;
    if (info == null) {
      return 'Your partner';
    }

    return displayLoosePartnerName(
      firstName: info.ownerFirstName,
      lastName: info.ownerLastName,
      fullName: info.ownerFullName,
      email: info.inviteeEmail,
    );
  }

  Future<void> _previewInvite() async {
    final token = extractInviteToken(_inviteTokenCtrl.text);
    if (token == null) {
      setState(() {
        _inviteInfo = null;
        _inviteInfoError = 'Paste a full invitation link or a valid token.';
      });
      return;
    }

    setState(() {
      _isLoadingPreview = true;
      _inviteInfoError = null;
    });

    try {
      final info = await widget.partnershipService.getInviteInfo(token);
      if (!mounted) {
        return;
      }

      setState(() {
        _inviteInfo = info;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _inviteInfo = null;
        _inviteInfoError = _readableError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingPreview = false);
      }
    }
  }

  Future<void> _acceptInvite() async {
    final token = extractInviteToken(_inviteTokenCtrl.text);
    if (token == null) {
      return;
    }

    setState(() => _isAcceptingInvite = true);

    try {
      await widget.partnershipService.acceptInvite(inviteToken: token);
      if (!mounted) {
        return;
      }

      AppToast.success(
        context,
        title: 'Partnership activated',
        description:
            'You are now inside the same shared finance space together.',
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Unable to accept invitation',
        description: _readableError(error),
      );
    } finally {
      if (mounted) {
        setState(() => _isAcceptingInvite = false);
      }
    }
  }

  Future<void> _pasteInviteLink() async {
    final data = await Clipboard.getData('text/plain');
    if (!mounted) {
      return;
    }

    final value = data?.text?.trim();
    if (value == null || value.isEmpty) {
      AppToast.info(
        context,
        title: 'Nothing to paste',
        description: 'Copy the invitation link first, then try again.',
      );
      return;
    }

    _inviteTokenCtrl.text = value;
    await _previewInvite();
  }

  @override
  Widget build(BuildContext context) {
    final ownerLabel = _ownerLabel;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
          children: [
            _AcceptHeader(onBack: () => Navigator.of(context).pop()),
            const SizedBox(height: 14),
            _InviteHeroCard(
              currentUser: widget.currentUser,
              ownerLabel: ownerLabel,
              ownerAvatarUrl: _inviteInfo?.ownerAvatarUrl,
              inviteInfo: _inviteInfo,
            ),
            const SizedBox(height: 14),
            GlassPanel(
              padding: const EdgeInsets.all(24),
              borderRadius: BorderRadius.circular(28),
              blur: 24,
              opacity: 0.12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Open your invitation',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Paste the link from your email. We will verify who invited you, who the invitation belongs to, and when it expires before you join.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: AppColors.textSecondary.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _GlassTextField(
                    controller: _inviteTokenCtrl,
                    hint: 'Paste the invite link or token',
                    prefixIcon: HugeIcons.strokeRoundedLinkSquare02,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          label: _isLoadingPreview
                              ? 'Checking invite...'
                              : 'Preview invite',
                          icon: HugeIcons.strokeRoundedSearch01,
                          isBusy: _isLoadingPreview,
                          onTap: _previewInvite,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _IconActionButton(
                        icon: HugeIcons.strokeRoundedCopy01,
                        onTap: _pasteInviteLink,
                      ),
                    ],
                  ),
                  if (_inviteInfoError != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _inviteInfoError!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_inviteInfo != null) ...[
              const SizedBox(height: 14),
              _InvitePreviewCard(
                currentUser: widget.currentUser,
                inviteInfo: _inviteInfo!,
                emailMismatch: _inviteEmailMismatch,
                isAcceptingInvite: _isAcceptingInvite,
                onAcceptInvite: _acceptInvite,
              ),
            ],
          ],
        ),
      ),
    );
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
}

class _AcceptHeader extends StatelessWidget {
  const _AcceptHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(22),
      borderRadius: BorderRadius.circular(30),
      blur: 22,
      opacity: 0.12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: Colors.white.withValues(alpha: 0.05),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowLeft01,
                    size: 14,
                    color: AppColors.textPrimary,
                    strokeWidth: 1.8,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Back',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          GlassBadge(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedUserMultiple,
                  size: 16,
                  color: AppColors.primary,
                  strokeWidth: 1.8,
                ),
                SizedBox(width: 8),
                Text(
                  'Accept partnership',
                  style: TextStyle(fontSize: 12, color: AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Join one shared finance space.',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Budgetify keeps the partnership warm and simple: one shared money space, clear visibility for both of you, and creator tracking on every record.',
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: AppColors.textSecondary.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteHeroCard extends StatelessWidget {
  const _InviteHeroCard({
    required this.currentUser,
    required this.ownerLabel,
    required this.ownerAvatarUrl,
    required this.inviteInfo,
  });

  final AuthUser currentUser;
  final String ownerLabel;
  final String? ownerAvatarUrl;
  final InviteInfo? inviteInfo;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(30),
      blur: 24,
      opacity: 0.12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PartnerAvatar(
                avatarUrl: ownerAvatarUrl,
                fallbackLabel: ownerLabel,
              ),
              const SizedBox(width: 12),
              Container(
                width: 34,
                height: 1,
                color: AppColors.primary.withValues(alpha: 0.36),
              ),
              const SizedBox(width: 12),
              _PartnerAvatar(
                avatarUrl: currentUser.avatarUrl,
                fallbackLabel: displayAuthUserName(currentUser),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            inviteInfo == null
                ? 'Your partner invitation is waiting for one last step.'
                : '$ownerLabel is inviting you to manage your finances together.',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            inviteInfo == null
                ? 'Paste the link from your email and we will prepare the partnership preview for you.'
                : 'You will both see the same income, expenses, todos, savings, and loans while Budgetify still remembers who added each movement.',
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: AppColors.textSecondary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _HeroPill(label: 'You must be signed in to accept'),
              _HeroPill(label: 'Every record keeps its creator'),
              _HeroPill(label: 'Both partners use the same tools'),
            ],
          ),
        ],
      ),
    );
  }
}

class _InvitePreviewCard extends StatelessWidget {
  const _InvitePreviewCard({
    required this.currentUser,
    required this.inviteInfo,
    required this.emailMismatch,
    required this.isAcceptingInvite,
    required this.onAcceptInvite,
  });

  final AuthUser currentUser;
  final InviteInfo inviteInfo;
  final bool emailMismatch;
  final bool isAcceptingInvite;
  final Future<void> Function() onAcceptInvite;

  @override
  Widget build(BuildContext context) {
    final ownerLabel = displayLoosePartnerName(
      firstName: inviteInfo.ownerFirstName,
      lastName: inviteInfo.ownerLastName,
      fullName: inviteInfo.ownerFullName,
      email: inviteInfo.inviteeEmail,
    );

    return GlassPanel(
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(28),
      blur: 24,
      opacity: 0.12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invitation preview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$ownerLabel is ready to welcome you as a Budgetify partner. Take one more look before joining the shared finance space.',
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: AppColors.textSecondary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _PartnerAvatar(
                      avatarUrl: inviteInfo.ownerAvatarUrl,
                      fallbackLabel: ownerLabel,
                      radius: 22,
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 28,
                      height: 1,
                      color: AppColors.primary.withValues(alpha: 0.36),
                    ),
                    const SizedBox(width: 10),
                    _PartnerAvatar(
                      avatarUrl: currentUser.avatarUrl,
                      fallbackLabel: displayAuthUserName(currentUser),
                      radius: 22,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _MetaRow(
                  label: 'Invitation prepared for',
                  value: inviteInfo.inviteeEmail,
                ),
                const SizedBox(height: 6),
                _MetaRow(
                  label: 'Expires',
                  value: formatPartnershipDate(inviteInfo.expiresAt),
                ),
              ],
            ),
          ),
          if (emailMismatch) ...[
            const SizedBox(height: 14),
            Text(
              'You are signed in as ${currentUser.email}, but this invitation was created for ${inviteInfo.inviteeEmail}.',
              style: const TextStyle(fontSize: 11, color: AppColors.danger),
            ),
          ] else ...[
            const SizedBox(height: 16),
            _ActionButton(
              label: isAcceptingInvite
                  ? 'Joining partnership...'
                  : 'Accept and start sharing',
              icon: HugeIcons.strokeRoundedUserMultiple,
              isBusy: isAcceptingInvite,
              onTap: onAcceptInvite,
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: AppColors.textSecondary.withValues(alpha: 0.78),
        ),
      ),
    );
  }
}

class _PartnerAvatar extends StatelessWidget {
  const _PartnerAvatar({
    required this.avatarUrl,
    required this.fallbackLabel,
    this.radius = 24,
  });

  final String? avatarUrl;
  final String fallbackLabel;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initials = _resolveInitials(fallbackLabel);

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white.withValues(alpha: 0.08),
      backgroundImage: avatarUrl == null ? null : NetworkImage(avatarUrl!),
      child: avatarUrl == null
          ? Text(
              initials,
              style: TextStyle(
                fontSize: radius * 0.56,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            )
          : null,
    );
  }

  String _resolveInitials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);

    if (parts.isEmpty) {
      return 'B';
    }

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary.withValues(alpha: 0.62),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassTextField extends StatelessWidget {
  const _GlassTextField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
  });

  final TextEditingController controller;
  final String hint;
  final dynamic prefixIcon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(
        fontSize: 13,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary.withValues(alpha: 0.44),
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12),
          child: HugeIcon(
            icon: prefixIcon,
            size: 16,
            color: AppColors.textSecondary.withValues(alpha: 0.66),
            strokeWidth: 1.8,
          ),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.42),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isBusy = false,
  });

  final String label;
  final dynamic icon;
  final Future<void> Function() onTap;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isBusy ? null : () => onTap(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.primary.withValues(alpha: 0.15),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.24)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isBusy)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            else
              HugeIcon(
                icon: icon,
                size: 16,
                color: AppColors.primary,
                strokeWidth: 1.8,
              ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  const _IconActionButton({required this.icon, required this.onTap});

  final dynamic icon;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Center(
          child: HugeIcon(
            icon: icon,
            size: 16,
            color: AppColors.textPrimary,
            strokeWidth: 1.8,
          ),
        ),
      ),
    );
  }
}
