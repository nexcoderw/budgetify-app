import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../auth/application/auth_service_contract.dart';
import '../../../auth/data/models/auth_user.dart';
import '../../../auth/presentation/pages/login_page.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key, required this.authService, required this.user});

  final AuthServiceContract authService;
  final AuthUser user;

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  bool _isLoggingOut = false;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 680;
    final userName = widget.user.fullName ?? widget.user.firstName ?? 'there';

    return Scaffold(
      body: DecoratedBox(
        decoration: const _LandingBackgroundDecoration(),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  children: [
                    _LandingHeader(
                      user: widget.user,
                      isLoggingOut: _isLoggingOut,
                      onLogout: _isLoggingOut ? null : _logout,
                    ),
                    const SizedBox(height: 28),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 900),
                            child: GlassPanel(
                              padding: EdgeInsets.all(isCompact ? 24 : 32),
                              borderRadius: BorderRadius.circular(36),
                              blur: 28,
                              opacity: 0.14,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
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
                                        Text(
                                          'Welcome back',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 22),
                                  Text(
                                    'Hi, $userName.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          fontSize: isCompact ? 28 : 34,
                                          color: AppColors.textPrimary,
                                        ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Your Budgetify workspace is ready. You are signed in securely with Google and connected to the API.',
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
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
                                      _LandingSignal(
                                        icon: HugeIcons
                                            .strokeRoundedCheckmarkBadge02,
                                        label: 'Session active',
                                        value: 'Authenticated',
                                      ),
                                      _LandingSignal(
                                        icon: HugeIcons.strokeRoundedMail01,
                                        label: 'Primary email',
                                        value: widget.user.email,
                                      ),
                                      _LandingSignal(
                                        icon: HugeIcons.strokeRoundedShield01,
                                        label: 'Verification',
                                        value: widget.user.isEmailVerified
                                            ? 'Verified'
                                            : 'Pending',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(24),
                                      color: Colors.white.withValues(
                                        alpha: 0.04,
                                      ),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.1,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: AppColors.primary.withValues(
                                              alpha: 0.14,
                                            ),
                                          ),
                                          child: const Center(
                                            child: HugeIcon(
                                              icon: HugeIcons
                                                  .strokeRoundedWalletAdd01,
                                              size: 20,
                                              color: AppColors.primary,
                                              strokeWidth: 1.8,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Next step',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelLarge
                                                    ?.copyWith(
                                                      fontSize: 12,
                                                      color:
                                                          AppColors.textPrimary,
                                                    ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Start shaping the dashboard, budget accounts, and transaction flows from this signed-in state.',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      fontSize: 12,
                                                      height: 1.5,
                                                      color: AppColors
                                                          .textSecondary,
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
                            ),
                          ),
                        ),
                      ),
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
        description: error.toString(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }
}

class _LandingHeader extends StatelessWidget {
  const _LandingHeader({
    required this.user,
    required this.isLoggingOut,
    required this.onLogout,
  });

  final AuthUser user;
  final bool isLoggingOut;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 720;

        final brand = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlassPanel(
              padding: const EdgeInsets.all(8),
              blur: 20,
              opacity: 0.12,
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/branding/logo_color.png',
                width: 26,
                height: 26,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 14),
            Text(
              'Budgetify',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 26,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        );

        final actions = Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            GlassBadge(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    backgroundImage: user.avatarUrl == null
                        ? null
                        : NetworkImage(user.avatarUrl!),
                    child: user.avatarUrl == null
                        ? const HugeIcon(
                            icon: HugeIcons.strokeRoundedUserCircle,
                            size: 14,
                            color: AppColors.textPrimary,
                            strokeWidth: 1.7,
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isCompact ? 180 : 260,
                    ),
                    child: Text(
                      user.fullName ?? user.email,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onLogout,
              child: Text(
                isLoggingOut ? 'Signing out...' : 'Logout',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [brand, const SizedBox(height: 14), actions],
          );
        }

        return Row(children: [brand, const Spacer(), actions]);
      },
    );
  }
}

class _LandingSignal extends StatelessWidget {
  const _LandingSignal({
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

class _LandingBackgroundDecoration extends Decoration {
  const _LandingBackgroundDecoration();

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _LandingBackgroundPainter();
  }
}

class _LandingBackgroundPainter extends BoxPainter {
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
        colors: [AppColors.background, Color(0xFF10151C), Color(0xFF171E28)],
      ).createShader(rect);
    canvas.drawRect(rect, paint);

    canvas.drawCircle(
      Offset(offset.dx + size.width * 0.18, offset.dy + size.height * 0.2),
      size.shortestSide * 0.18,
      Paint()..color = AppColors.primary.withValues(alpha: 0.08),
    );
    canvas.drawCircle(
      Offset(offset.dx + size.width * 0.82, offset.dy + size.height * 0.78),
      size.shortestSide * 0.22,
      Paint()..color = Colors.white.withValues(alpha: 0.05),
    );
  }
}
