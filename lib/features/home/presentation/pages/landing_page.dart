import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../auth/application/auth_service_contract.dart';
import '../../../auth/data/models/auth_user.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../widgets/app_layout.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key, required this.authService, required this.user});

  final AuthServiceContract authService;
  final AuthUser user;

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  bool _isLoggingOut = false;
  AppLayoutSection _currentSection = AppLayoutSection.dashboard;

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      user: widget.user,
      currentSection: _currentSection,
      isLoggingOut: _isLoggingOut,
      onLogout: _isLoggingOut ? null : _logout,
      onSectionSelected: _selectSection,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: KeyedSubtree(
          key: ValueKey<AppLayoutSection>(_currentSection),
          child: _sectionContent(context),
        ),
      ),
    );
  }

  Widget _sectionContent(BuildContext context) {
    switch (_currentSection) {
      case AppLayoutSection.dashboard:
        return _DashboardSection(user: widget.user);
      case AppLayoutSection.income:
        return const _FeatureSection(
          title: 'Income',
          description:
              'Track salaries, side income, and recurring inflows in one calm workspace.',
          summaryLabel: 'Upcoming focus',
          summaryValue: 'Build recurring income streams and cashflow reports.',
          icon: HugeIcons.strokeRoundedMoneyReceiveCircle,
        );
      case AppLayoutSection.saving:
        return const _FeatureSection(
          title: 'Saving',
          description:
              'Organize savings goals and monitor progress toward short and long-term plans.',
          summaryLabel: 'Upcoming focus',
          summaryValue:
              'Add goal buckets, target dates, and progress insights.',
          icon: HugeIcons.strokeRoundedPiggyBank,
        );
      case AppLayoutSection.expense:
        return const _FeatureSection(
          title: 'Expense',
          description:
              'Understand where your money goes with clean categorization and spending visibility.',
          summaryLabel: 'Upcoming focus',
          summaryValue:
              'Add expense tracking, categories, and trend comparisons.',
          icon: HugeIcons.strokeRoundedWallet02,
        );
      case AppLayoutSection.profile:
        return _ProfileSection(
          user: widget.user,
          isLoggingOut: _isLoggingOut,
          onLogout: _isLoggingOut ? null : _logout,
        );
    }
  }

  void _selectSection(AppLayoutSection section) {
    if (_currentSection == section) {
      return;
    }

    setState(() {
      _currentSection = section;
    });

    if (section != AppLayoutSection.dashboard) {
      AppToast.info(
        context,
        title: '${_labelFor(section)} selected',
        description: 'This section is ready for the next product iteration.',
      );
    }
  }

  String _labelFor(AppLayoutSection section) {
    switch (section) {
      case AppLayoutSection.dashboard:
        return 'Dashboard';
      case AppLayoutSection.income:
        return 'Income';
      case AppLayoutSection.saving:
        return 'Saving';
      case AppLayoutSection.expense:
        return 'Expense';
      case AppLayoutSection.profile:
        return 'Profile';
    }
  }

  Future<void> _logout() async {
    setState(() {
      _isLoggingOut = true;
    });

    try {
      await widget.authService.logout();

      if (!mounted) {
        return;
      }

      AppToast.success(
        context,
        title: 'Signed out',
        description: 'Your Budgetify session has been closed safely.',
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => LoginPage(authService: widget.authService),
        ),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Unable to sign out',
        description: _readableError(error),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
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

class _DashboardSection extends StatelessWidget {
  const _DashboardSection({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 760;
    final userName = user.fullName ?? user.firstName ?? 'there';

    return GlassPanel(
      padding: EdgeInsets.all(isCompact ? 22 : 32),
      borderRadius: BorderRadius.circular(36),
      blur: 28,
      opacity: 0.14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassBadge(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedSparkles,
                  size: 16,
                  color: AppColors.primary,
                  strokeWidth: 1.8,
                ),
                SizedBox(width: 8),
                Text('Welcome back', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Hi, $userName.',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: isCompact ? 28 : 34,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Your Budgetify workspace is ready. You are signed in securely with Google and connected to the API.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 13,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _DashboardSignal(
                icon: HugeIcons.strokeRoundedCheckmarkBadge02,
                label: 'Session active',
                value: 'Authenticated',
              ),
              _DashboardSignal(
                icon: HugeIcons.strokeRoundedMail01,
                label: 'Primary email',
                value: user.email,
              ),
              _DashboardSignal(
                icon: HugeIcons.strokeRoundedShield01,
                label: 'Verification',
                value: user.isEmailVerified ? 'Verified' : 'Pending',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.14),
                  ),
                  child: const Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedWalletAdd01,
                      size: 20,
                      color: AppColors.primary,
                      strokeWidth: 1.8,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Next step',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Start shaping the dashboard, budget accounts, and transaction flows from this signed-in state.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          height: 1.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
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

class _FeatureSection extends StatelessWidget {
  const _FeatureSection({
    required this.title,
    required this.description,
    required this.summaryLabel,
    required this.summaryValue,
    required this.icon,
  });

  final String title;
  final String description;
  final String summaryLabel;
  final String summaryValue;
  final dynamic icon;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 760;

    return GlassPanel(
      padding: EdgeInsets.all(isCompact ? 22 : 30),
      borderRadius: BorderRadius.circular(34),
      blur: 28,
      opacity: 0.14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassBadge(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(
                  icon: icon,
                  size: 16,
                  color: AppColors.primary,
                  strokeWidth: 1.8,
                ),
                const SizedBox(width: 8),
                const Text('Workspace section', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: isCompact ? 26 : 32,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 13,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.14),
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: icon,
                      size: 20,
                      color: AppColors.primary,
                      strokeWidth: 1.8,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summaryLabel,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        summaryValue,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          height: 1.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
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

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.user,
    required this.isLoggingOut,
    required this.onLogout,
  });

  final AuthUser user;
  final bool isLoggingOut;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 760;

    return GlassPanel(
      padding: EdgeInsets.all(isCompact ? 22 : 30),
      borderRadius: BorderRadius.circular(34),
      blur: 28,
      opacity: 0.14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassBadge(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedUserCircle,
                  size: 16,
                  color: AppColors.primary,
                  strokeWidth: 1.8,
                ),
                SizedBox(width: 8),
                Text('Account profile', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              CircleAvatar(
                radius: isCompact ? 26 : 30,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                backgroundImage: user.avatarUrl == null
                    ? null
                    : NetworkImage(user.avatarUrl!),
                child: user.avatarUrl == null
                    ? const HugeIcon(
                        icon: HugeIcons.strokeRoundedUserCircle,
                        size: 22,
                        color: AppColors.textPrimary,
                        strokeWidth: 1.8,
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName ?? 'Budgetify user',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: isCompact ? 22 : 24,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _DashboardSignal(
                icon: HugeIcons.strokeRoundedCheckmarkBadge02,
                label: 'Account status',
                value: user.status,
              ),
              _DashboardSignal(
                icon: HugeIcons.strokeRoundedShield01,
                label: 'Email verification',
                value: user.isEmailVerified ? 'Verified' : 'Pending',
              ),
              _DashboardSignal(
                icon: HugeIcons.strokeRoundedClock01,
                label: 'Last activity',
                value: user.lastLoginAt == null ? 'Unavailable' : 'Recorded',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              height: 46,
              child: OutlinedButton(
                onPressed: onLogout,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                  backgroundColor: Colors.white.withValues(alpha: 0.04),
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  isLoggingOut ? 'Signing out...' : 'Logout',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardSignal extends StatelessWidget {
  const _DashboardSignal({
    required this.icon,
    required this.label,
    required this.value,
  });

  final dynamic icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: BorderRadius.circular(24),
      blur: 18,
      opacity: 0.1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 170),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.14),
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
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
