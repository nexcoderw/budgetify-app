import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../auth/data/models/auth_user.dart';
import '../../application/partnership_service.dart';
import '../../data/models/partnership_models.dart';
import '../partnership_view_utils.dart';
import 'accept_partnership_invite_page.dart';

class PartnersPage extends StatefulWidget {
  const PartnersPage({
    super.key,
    required this.partnershipService,
    required this.user,
  });

  final PartnershipService partnershipService;
  final AuthUser user;

  @override
  State<PartnersPage> createState() => _PartnersPageState();
}

class _PartnersPageState extends State<PartnersPage> {
  late final TextEditingController _inviteEmailCtrl;

  Partnership? _partnership;
  bool _isLoading = true;
  bool _isSubmittingInvite = false;
  bool _isCancellingInvite = false;
  bool _isRemovingPartner = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _inviteEmailCtrl = TextEditingController();
    _loadPartnership();
  }

  @override
  void dispose() {
    _inviteEmailCtrl.dispose();
    super.dispose();
  }

  bool get _canRemoveAcceptedPartner =>
      _partnership?.status == PartnershipStatus.accepted &&
      (_partnership?.isOwner ?? false);

  bool get _canCancelPendingInvite =>
      _partnership?.status == PartnershipStatus.pending &&
      (_partnership?.isOwner ?? false);

  PartnerUser? get _counterpart {
    final partnership = _partnership;
    if (partnership == null) {
      return null;
    }

    if (partnership.isOwner) {
      return partnership.partner;
    }

    if (partnership.owner.id == widget.user.id) {
      return partnership.partner;
    }

    return partnership.owner;
  }

  Future<void> _loadPartnership() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final partnership = await widget.partnershipService.getMyPartnership();
      if (!mounted) {
        return;
      }

      setState(() {
        _partnership = partnership;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadError = _readableError(error);
        _isLoading = false;
      });
    }
  }

  Future<void> _submitInvite() async {
    final email = _inviteEmailCtrl.text.trim().toLowerCase();
    if (email.isEmpty) {
      AppToast.info(
        context,
        title: 'Email required',
        description: 'Enter your partner’s email before sending the invite.',
      );
      return;
    }

    setState(() => _isSubmittingInvite = true);

    try {
      final partnership = await widget.partnershipService.invitePartner(
        email: email,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _partnership = partnership;
        _inviteEmailCtrl.clear();
      });

      AppToast.success(
        context,
        title: 'Invitation sent',
        description:
            'Your partner can continue from the email and join your shared workspace.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Unable to send invitation',
        description: _readableError(error),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingInvite = false);
      }
    }
  }

  Future<void> _cancelPendingInvite() async {
    setState(() => _isCancellingInvite = true);

    try {
      await widget.partnershipService.cancelPendingInvite();
      if (!mounted) {
        return;
      }

      setState(() => _partnership = null);
      AppToast.success(
        context,
        title: 'Invitation cancelled',
        description: 'Your pending partner invitation has been withdrawn.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Unable to cancel invitation',
        description: _readableError(error),
      );
    } finally {
      if (mounted) {
        setState(() => _isCancellingInvite = false);
      }
    }
  }

  Future<void> _removePartner() async {
    setState(() => _isRemovingPartner = true);

    try {
      await widget.partnershipService.removePartnership();
      if (!mounted) {
        return;
      }

      setState(() => _partnership = null);
      AppToast.success(
        context,
        title: 'Partner removed',
        description: 'The shared workspace is back to a solo space.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Unable to remove partner',
        description: _readableError(error),
      );
    } finally {
      if (mounted) {
        setState(() => _isRemovingPartner = false);
      }
    }
  }

  Future<void> _openAcceptInvitePage() async {
    final accepted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AcceptPartnershipInvitePage(
          currentUser: widget.user,
          partnershipService: widget.partnershipService,
        ),
      ),
    );

    if (accepted == true && mounted) {
      await _loadPartnership();
    }
  }

  @override
  Widget build(BuildContext context) {
    final counterpart = _counterpart;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surfaceElevated,
          onRefresh: _loadPartnership,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
            children: [
              _Header(onBack: () => Navigator.of(context).pop()),
              const SizedBox(height: 14),
              _HeroCard(
                currentUser: widget.user,
                counterpart: counterpart,
                inviteeEmail: _partnership?.inviteeEmail,
                hasPartnership: _partnership != null,
              ),
              const SizedBox(height: 14),
              if (_isLoading)
                const _LoadingState()
              else if (_loadError != null)
                _ErrorState(message: _loadError!, onRetry: _loadPartnership)
              else ...[
                if (_partnership != null)
                  _PartnershipStatusPanel(
                    partnership: _partnership!,
                    currentUser: widget.user,
                    counterpart: counterpart,
                    onCancelPendingInvite: _canCancelPendingInvite
                        ? _cancelPendingInvite
                        : null,
                    onRemovePartner: _canRemoveAcceptedPartner
                        ? _removePartner
                        : null,
                    cancellingInvite: _isCancellingInvite,
                    removingPartner: _isRemovingPartner,
                  )
                else ...[
                  _InvitePartnerPanel(
                    controller: _inviteEmailCtrl,
                    isSubmitting: _isSubmittingInvite,
                    onSubmit: _submitInvite,
                  ),
                  const SizedBox(height: 14),
                  _AcceptInviteEntryPanel(
                    currentUser: widget.user,
                    onOpenAcceptInvite: _openAcceptInvitePage,
                  ),
                ],
              ],
            ],
          ),
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

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

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
          Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Colors.white.withValues(alpha: 0.05),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
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
            ],
          ),
          const SizedBox(height: 20),
          GlassBadge(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedUserAccount,
                  size: 16,
                  color: AppColors.primary,
                  strokeWidth: 1.8,
                ),
                SizedBox(width: 8),
                Text(
                  'Shared finances',
                  style: TextStyle(fontSize: 12, color: AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Build one calm money space together.',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Invite one trusted partner to see the same ledgers, use the same tools, and still keep every entry traceable by creator.',
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.currentUser,
    required this.counterpart,
    required this.inviteeEmail,
    required this.hasPartnership,
  });

  final AuthUser currentUser;
  final PartnerUser? counterpart;
  final String? inviteeEmail;
  final bool hasPartnership;

  @override
  Widget build(BuildContext context) {
    final counterpartLabel = counterpart == null
        ? (inviteeEmail ?? 'Your future partner')
        : displayPartnerName(counterpart!);

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
                avatarUrl: currentUser.avatarUrl,
                fallbackLabel: displayAuthUserName(currentUser),
              ),
              const SizedBox(width: 12),
              Container(
                width: 34,
                height: 1,
                color: AppColors.primary.withValues(alpha: 0.36),
              ),
              const SizedBox(width: 12),
              _PartnerAvatar(
                avatarUrl: counterpart?.avatarUrl,
                fallbackLabel: counterpartLabel,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            hasPartnership
                ? 'You and $counterpartLabel are building better habits together.'
                : 'Invite your partner and let Budgetify keep both of you aligned.',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasPartnership
                ? 'Two partners, one shared financial story. Budgetify keeps it warm, clear, and accountable.'
                : 'When your partner joins, both of you will see the same finances, the same dashboard, and the same plans without losing who added what.',
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
              _HeroPill(
                label: 'Shared income, expense, todo, saving, and loan views',
              ),
              _HeroPill(label: 'Every record keeps its creator'),
              _HeroPill(
                label: 'Only signed-in partners can accept invitations',
              ),
            ],
          ),
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

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: Column(
        children: const [
          _LoadingPanel(height: 220),
          SizedBox(height: 14),
          _LoadingPanel(height: 260),
        ],
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(28),
      blur: 22,
      opacity: 0.12,
      child: SizedBox(height: height),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(28),
      blur: 24,
      opacity: 0.12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Could not load your partnership',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: AppColors.textSecondary.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 16),
          _ActionButton(
            label: 'Try again',
            icon: HugeIcons.strokeRoundedRefresh,
            onTap: onRetry,
          ),
        ],
      ),
    );
  }
}

class _PartnershipStatusPanel extends StatelessWidget {
  const _PartnershipStatusPanel({
    required this.partnership,
    required this.currentUser,
    required this.counterpart,
    required this.onCancelPendingInvite,
    required this.onRemovePartner,
    required this.cancellingInvite,
    required this.removingPartner,
  });

  final Partnership partnership;
  final AuthUser currentUser;
  final PartnerUser? counterpart;
  final Future<void> Function()? onCancelPendingInvite;
  final Future<void> Function()? onRemovePartner;
  final bool cancellingInvite;
  final bool removingPartner;

  @override
  Widget build(BuildContext context) {
    final counterpartLabel = counterpart == null
        ? partnership.inviteeEmail
        : displayPartnerName(counterpart!);

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partnership.status == PartnershipStatus.pending
                          ? 'Invitation is on its way'
                          : 'Your shared workspace is active',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      partnership.status == PartnershipStatus.pending
                          ? 'We are waiting for $counterpartLabel to accept the invitation.'
                          : '${displayAuthUserName(currentUser)} and $counterpartLabel are now partners inside the same finance workspace.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _StatusPill(status: partnership.status),
            ],
          ),
          const SizedBox(height: 18),
          _PartnerLine(
            title: 'Invited by',
            name: displayPartnerName(partnership.owner),
            subtitle: partnership.owner.email,
            avatarUrl: partnership.owner.avatarUrl,
          ),
          const SizedBox(height: 12),
          _PartnerLine(
            title: 'Partner',
            name: counterpartLabel,
            subtitle: partnership.partner?.email ?? partnership.inviteeEmail,
            avatarUrl: counterpart?.avatarUrl,
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MetaRow(
                  label: 'Created',
                  value: formatPartnershipDate(partnership.createdAt),
                ),
                const SizedBox(height: 6),
                _MetaRow(
                  label: 'Invite expires',
                  value: formatPartnershipDate(partnership.expiresAt),
                ),
              ],
            ),
          ),
          if (onCancelPendingInvite != null || onRemovePartner != null) ...[
            const SizedBox(height: 18),
            _ActionButton(
              label: onCancelPendingInvite != null
                  ? (cancellingInvite
                        ? 'Cancelling invitation...'
                        : 'Cancel invitation')
                  : (removingPartner
                        ? 'Removing partner...'
                        : 'Remove partner'),
              icon: onCancelPendingInvite != null
                  ? HugeIcons.strokeRoundedSent
                  : HugeIcons.strokeRoundedDelete01,
              destructive: onRemovePartner != null,
              isBusy: cancellingInvite || removingPartner,
              onTap: onCancelPendingInvite ?? onRemovePartner!,
            ),
          ],
        ],
      ),
    );
  }
}

class _InvitePartnerPanel extends StatelessWidget {
  const _InvitePartnerPanel({
    required this.controller,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool isSubmitting;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(28),
      blur: 24,
      opacity: 0.12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invite a partner',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send one email invitation. Your partner will receive clear instructions to continue and accept after sign-in.',
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: AppColors.textSecondary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 16),
          _GlassTextField(
            controller: controller,
            hint: 'partner@example.com',
            prefixIcon: HugeIcons.strokeRoundedMail01,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          _ActionButton(
            label: isSubmitting ? 'Sending invitation...' : 'Send invitation',
            icon: HugeIcons.strokeRoundedSent,
            isBusy: isSubmitting,
            onTap: onSubmit,
          ),
        ],
      ),
    );
  }
}

class _AcceptInviteEntryPanel extends StatelessWidget {
  const _AcceptInviteEntryPanel({
    required this.currentUser,
    required this.onOpenAcceptInvite,
  });

  final AuthUser currentUser;
  final Future<void> Function() onOpenAcceptInvite;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(28),
      blur: 24,
      opacity: 0.12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Already have an invitation?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Open the dedicated invite page to paste the link from your email, preview the partnership, and accept it while signed in as ${displayAuthUserName(currentUser)}.',
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: AppColors.textSecondary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 16),
          _ActionButton(
            label: 'Open invite acceptance',
            icon: HugeIcons.strokeRoundedLinkSquare02,
            onTap: onOpenAcceptInvite,
          ),
        ],
      ),
    );
  }
}

class _PartnerLine extends StatelessWidget {
  const _PartnerLine({
    required this.title,
    required this.name,
    required this.subtitle,
    required this.avatarUrl,
  });

  final String title;
  final String name;
  final String subtitle;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          _PartnerAvatar(avatarUrl: avatarUrl, fallbackLabel: name, radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary.withValues(alpha: 0.58),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary.withValues(alpha: 0.76),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final PartnershipStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status == PartnershipStatus.pending
        ? const Color(0xFFFFB86C)
        : AppColors.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
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
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final dynamic prefixIcon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
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
    this.destructive = false,
  });

  final String label;
  final dynamic icon;
  final Future<void> Function() onTap;
  final bool isBusy;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final accent = destructive ? AppColors.danger : AppColors.primary;

    return GestureDetector(
      onTap: isBusy ? null : () => onTap(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: accent.withValues(alpha: 0.15),
          border: Border.all(color: accent.withValues(alpha: 0.24)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isBusy)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              )
            else
              HugeIcon(icon: icon, size: 16, color: accent, strokeWidth: 1.8),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
