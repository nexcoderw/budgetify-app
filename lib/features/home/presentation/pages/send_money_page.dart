import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../auth/data/models/auth_user.dart';

class SendMoneyPage extends StatelessWidget {
  const SendMoneyPage({super.key, required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 700;
    final firstName = _firstName(user);

    return GlassPanel(
      padding: EdgeInsets.all(isCompact ? 22 : 32),
      borderRadius: BorderRadius.circular(34),
      blur: 28,
      opacity: 0.14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: const Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedMoneySendSquare,
                    size: 21,
                    color: AppColors.primary,
                    strokeWidth: 1.8,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Colors.white.withValues(alpha: 0.05),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.09),
                  ),
                ),
                child: const Text(
                  'RWF',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'Send money',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: isCompact ? 30 : 38,
              color: AppColors.textPrimary,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose who to pay and prepare a transfer from your Budgetify balance, $firstName.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              height: 1.55,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 30),
          const _SectionLabel(label: 'Recent people'),
          const SizedBox(height: 14),
          const SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _RecipientAvatar(initials: '+', label: 'New'),
                SizedBox(width: 18),
                _RecipientAvatar(initials: 'AM', label: 'Aline'),
                SizedBox(width: 18),
                _RecipientAvatar(initials: 'DK', label: 'David'),
                SizedBox(width: 18),
                _RecipientAvatar(initials: 'NM', label: 'Nadia'),
              ],
            ),
          ),
          const SizedBox(height: 30),
          const _SectionLabel(label: 'Transfer details'),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isCompact ? 20 : 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: const Color(0xFF111923),
              border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Amount',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '0',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            fontSize: isCompact ? 44 : 52,
                            height: 1,
                            color: AppColors.textPrimary,
                            letterSpacing: -1.8,
                          ),
                    ),
                    const SizedBox(width: 10),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 5),
                      child: Text(
                        'RWF',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const Divider(color: AppColors.border, height: 1),
                const SizedBox(height: 18),
                const _TransferRow(
                  icon: HugeIcons.strokeRoundedWallet01,
                  label: 'From',
                  value: 'Budgetify balance',
                ),
                const SizedBox(height: 14),
                const _TransferRow(
                  icon: HugeIcons.strokeRoundedUserCircle,
                  label: 'To',
                  value: 'Choose a recipient',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: null,
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 18,
                color: AppColors.background,
                strokeWidth: 2,
              ),
              label: const Text('Review transfer'),
            ),
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'Transfer actions will be connected in the next release.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  String _firstName(AuthUser user) {
    final name = user.firstName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }

    return user.email.split('@').first;
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _RecipientAvatar extends StatelessWidget {
  const _RecipientAvatar({required this.initials, required this.label});

  final String initials;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: initials == '+'
                  ? AppColors.primary.withValues(alpha: 0.17)
                  : const Color(0xFF293545),
              border: Border.all(
                color: initials == '+'
                    ? AppColors.primary.withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Center(
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: initials == '+' ? 22 : 13,
                  fontWeight: FontWeight.w700,
                  color: initials == '+'
                      ? AppColors.primary
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferRow extends StatelessWidget {
  const _TransferRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final dynamic icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.06),
          ),
          child: Center(
            child: HugeIcon(
              icon: icon,
              size: 18,
              color: AppColors.primary,
              strokeWidth: 1.8,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
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
        const HugeIcon(
          icon: HugeIcons.strokeRoundedArrowRight01,
          size: 17,
          color: AppColors.textSecondary,
          strokeWidth: 1.7,
        ),
      ],
    );
  }
}
