import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../../core/theme/app_colors.dart';

class DashboardBalanceCard extends StatefulWidget {
  const DashboardBalanceCard({
    super.key,
    required this.totalBalance,
    required this.savingsRate,
    required this.month,
    required this.year,
  });

  final double totalBalance;
  final double savingsRate;
  final int month;
  final int year;

  @override
  State<DashboardBalanceCard> createState() => _DashboardBalanceCardState();
}

class _DashboardBalanceCardState extends State<DashboardBalanceCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _BalanceCardShell(
      shimmer: _shimmerCtrl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.18),
                ),
                child: const Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedWallet01,
                    size: 18,
                    color: AppColors.primary,
                    strokeWidth: 1.8,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Total Balance',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              _SavingsBadge(rate: widget.savingsRate),
            ],
          ),
          const SizedBox(height: 22),
          _AnimatedBalance(balance: widget.totalBalance),
          const SizedBox(height: 6),
          Text(
            'Available across all accounts',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary.withValues(alpha: 0.7),
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 20),
          _BalanceDivider(),
          const SizedBox(height: 16),
          Row(
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedArrowUpRight01,
                size: 14,
                color: AppColors.success,
                strokeWidth: 1.8,
              ),
              const SizedBox(width: 6),
              const Text(
                'On track — great savings this month',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.success,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Shell with glassmorphism + radial gradient accent ─────────────────────────

class _BalanceCardShell extends StatelessWidget {
  const _BalanceCardShell({required this.child, required this.shimmer});

  final Widget child;
  final Animation<double> shimmer;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: AnimatedBuilder(
          animation: shimmer,
          builder: (context, _) => Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.13),
                  Colors.white.withValues(alpha: 0.07),
                  AppColors.primary.withValues(alpha: 0.06),
                ],
                stops: [
                  0.0,
                  shimmer.value,
                  1.0,
                ],
              ),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ── Animated balance counter ──────────────────────────────────────────────────

class _AnimatedBalance extends StatefulWidget {
  const _AnimatedBalance({required this.balance});

  final double balance;

  @override
  State<_AnimatedBalance> createState() => _AnimatedBalanceState();
}

class _AnimatedBalanceState extends State<_AnimatedBalance>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  double _previous = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_AnimatedBalance old) {
    super.didUpdateWidget(old);
    if (old.balance != widget.balance) {
      _previous = old.balance;
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final value =
            _previous + (_anim.value * (widget.balance - _previous));
        final formatted =
            '\$${value.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+\.)'), (m) => '${m[1]},')}';
        return Text(
          formatted,
          style: const TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -1.2,
          ),
        );
      },
    );
  }
}

// ── Divider ───────────────────────────────────────────────────────────────────

class _BalanceDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Colors.white.withValues(alpha: 0.12),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

// ── Savings rate badge ────────────────────────────────────────────────────────

class _SavingsBadge extends StatelessWidget {
  const _SavingsBadge({required this.rate});

  final double rate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: AppColors.success.withValues(alpha: 0.12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowUpRight01,
            size: 12,
            color: AppColors.success,
            strokeWidth: 2,
          ),
          const SizedBox(width: 4),
          Text(
            '${rate.toStringAsFixed(0)}% saved',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}
