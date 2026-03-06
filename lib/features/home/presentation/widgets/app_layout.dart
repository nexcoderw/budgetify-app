import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../auth/data/models/auth_user.dart';

enum AppLayoutSection { dashboard, income, saving, expense, profile }

class AppLayout extends StatelessWidget {
  const AppLayout({
    super.key,
    required this.user,
    required this.currentSection,
    required this.child,
    required this.onSectionSelected,
    required this.onLogout,
    this.isLoggingOut = false,
  });

  final AuthUser user;
  final AppLayoutSection currentSection;
  final Widget child;
  final ValueChanged<AppLayoutSection> onSectionSelected;
  final VoidCallback? onLogout;
  final bool isLoggingOut;

  static const List<_AppNavDestination> _destinations = [
    _AppNavDestination(
      section: AppLayoutSection.dashboard,
      label: 'Dashboard',
      icon: HugeIcons.strokeRoundedDashboardSquare02,
    ),
    _AppNavDestination(
      section: AppLayoutSection.income,
      label: 'Income',
      icon: HugeIcons.strokeRoundedMoneyReceiveCircle,
    ),
    _AppNavDestination(
      section: AppLayoutSection.saving,
      label: 'Saving',
      icon: HugeIcons.strokeRoundedPiggyBank,
    ),
    _AppNavDestination(
      section: AppLayoutSection.expense,
      label: 'Expense',
      icon: HugeIcons.strokeRoundedWallet02,
    ),
    _AppNavDestination(
      section: AppLayoutSection.profile,
      label: 'Profile',
      icon: HugeIcons.strokeRoundedUserCircle,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 760;

    return Scaffold(
      body: DecoratedBox(
        decoration: const _AppBackgroundDecoration(),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isCompact ? 16 : 24,
                  18,
                  isCompact ? 16 : 24,
                  isCompact ? 16 : 22,
                ),
                child: Column(
                  children: [
                    _AppNavbar(
                      user: user,
                      isLoggingOut: isLoggingOut,
                      onLogout: onLogout,
                    ),
                    SizedBox(height: isCompact ? 18 : 24),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1040),
                            child: child,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: isCompact ? 14 : 18),
                    _BottomNavBar(
                      currentSection: currentSection,
                      destinations: _destinations,
                      onSectionSelected: onSectionSelected,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppNavbar extends StatelessWidget {
  const _AppNavbar({
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
      borderRadius: BorderRadius.circular(28),
      blur: 24,
      opacity: 0.12,
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 14 : 18,
        vertical: isCompact ? 14 : 16,
      ),
      child: Row(
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GlassPanel(
                  padding: const EdgeInsets.all(8),
                  blur: 18,
                  opacity: 0.1,
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset(
                    'assets/branding/logo_color.png',
                    width: 26,
                    height: 26,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Budgetify',
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: isCompact ? 22 : 24,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Clear financial tracking for everyday decisions.',
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _UserMenu(user: user, isLoggingOut: isLoggingOut, onLogout: onLogout),
        ],
      ),
    );
  }
}

class _UserMenu extends StatelessWidget {
  const _UserMenu({
    required this.user,
    required this.isLoggingOut,
    required this.onLogout,
  });

  final AuthUser user;
  final bool isLoggingOut;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final displayName = user.fullName ?? user.email;
    final isCompact = MediaQuery.sizeOf(context).width < 560;

    return PopupMenuButton<_UserMenuAction>(
      tooltip: 'Account menu',
      offset: const Offset(0, 12),
      color: AppColors.surfaceElevated.withValues(alpha: 0.96),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      onSelected: (value) {
        if (value == _UserMenuAction.logout) {
          onLogout?.call();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<_UserMenuAction>(
          value: _UserMenuAction.logout,
          enabled: !isLoggingOut,
          child: Row(
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedLogout03,
                size: 18,
                color: AppColors.textPrimary,
                strokeWidth: 1.8,
              ),
              const SizedBox(width: 10),
              Text(
                isLoggingOut ? 'Signing out...' : 'Logout',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
      child: GlassBadge(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 10 : 12,
          vertical: 8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              backgroundImage: user.avatarUrl == null
                  ? null
                  : NetworkImage(user.avatarUrl!),
              child: user.avatarUrl == null
                  ? const HugeIcon(
                      icon: HugeIcons.strokeRoundedUserCircle,
                      size: 16,
                      color: AppColors.textPrimary,
                      strokeWidth: 1.7,
                    )
                  : null,
            ),
            if (!isCompact) ...[
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 190),
                child: Text(
                  displayName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ] else
              const SizedBox(width: 6),
            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowDown01,
              size: 16,
              color: Colors.white.withValues(alpha: 0.72),
              strokeWidth: 1.9,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.currentSection,
    required this.destinations,
    required this.onSectionSelected,
  });

  final AppLayoutSection currentSection;
  final List<_AppNavDestination> destinations;
  final ValueChanged<AppLayoutSection> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 900;

    return GlassPanel(
      borderRadius: BorderRadius.circular(30),
      blur: 24,
      opacity: 0.12,
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 10 : 12,
        vertical: isCompact ? 8 : 10,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: destinations
              .map(
                (destination) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _BottomNavItem(
                    destination: destination,
                    isSelected: destination.section == currentSection,
                    onTap: () => onSectionSelected(destination.section),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  final _AppNavDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlight = AppColors.primary.withValues(alpha: 0.16);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: isSelected ? highlight : Colors.transparent,
            border: Border.all(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.28)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: destination.icon,
                size: 18,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textSecondary.withValues(alpha: 0.9),
                strokeWidth: 1.8,
              ),
              const SizedBox(width: 8),
              Text(
                destination.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppNavDestination {
  const _AppNavDestination({
    required this.section,
    required this.label,
    required this.icon,
  });

  final AppLayoutSection section;
  final String label;
  final dynamic icon;
}

enum _UserMenuAction { logout }

class _AppBackgroundDecoration extends Decoration {
  const _AppBackgroundDecoration();

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _AppBackgroundPainter();
  }
}

class _AppBackgroundPainter extends BoxPainter {
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) {
      return;
    }

    final rect = offset & size;
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.background, Color(0xFF0E131A), Color(0xFF161E28)],
      ).createShader(rect);
    canvas.drawRect(rect, paint);

    canvas.drawCircle(
      Offset(offset.dx + size.width * 0.16, offset.dy + size.height * 0.18),
      size.shortestSide * 0.18,
      Paint()..color = AppColors.primary.withValues(alpha: 0.08),
    );
    canvas.drawCircle(
      Offset(offset.dx + size.width * 0.86, offset.dy + size.height * 0.76),
      size.shortestSide * 0.24,
      Paint()..color = Colors.white.withValues(alpha: 0.04),
    );
  }
}
