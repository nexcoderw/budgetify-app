import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../auth/data/models/auth_user.dart';
import '../../../expenses/application/expense_service.dart';
import '../../../todos/application/todo_service.dart';
import '../../../todos/presentation/pages/todo_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.user,
    required this.todoService,
    required this.expenseService,
    required this.isLoggingOut,
    required this.onLogout,
  });

  final AuthUser user;
  final TodoService todoService;
  final ExpenseService expenseService;
  final bool isLoggingOut;
  final VoidCallback? onLogout;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  late final AnimationController _pulseCtrl;

  late final Animation<double> _badgeFade;
  late final Animation<Offset> _badgeSlide;

  late final Animation<double> _avatarScale;
  late final Animation<double> _avatarFade;
  late final Animation<Offset> _avatarSlide;

  late final Animation<double> _statsFade;
  late final Animation<Offset> _statsSlide;

  late final Animation<double> _detailsFade;
  late final Animation<Offset> _detailsSlide;

  late final Animation<double> _logoutFade;
  late final Animation<Offset> _logoutSlide;

  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    Animation<double> fade(double s, double e) =>
        Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(
            parent: _entranceCtrl,
            curve: Interval(s, e, curve: Curves.easeOut),
          ),
        );

    Animation<Offset> slide(double s, double e) =>
        Tween<Offset>(begin: const Offset(0, 0.28), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceCtrl,
            curve: Interval(s, e, curve: Curves.easeOutCubic),
          ),
        );

    _badgeFade = fade(0.0, 0.28);
    _badgeSlide = slide(0.0, 0.28);

    _avatarFade = fade(0.08, 0.42);
    _avatarSlide = slide(0.08, 0.42);
    _avatarScale = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.08, 0.52, curve: Curves.easeOutBack),
      ),
    );

    _statsFade = fade(0.32, 0.62);
    _statsSlide = slide(0.32, 0.62);

    _detailsFade = fade(0.50, 0.80);
    _detailsSlide = slide(0.50, 0.80);

    _logoutFade = fade(0.70, 1.00);
    _logoutSlide = slide(0.70, 1.00);

    _pulse = Tween<double>(
      begin: 0.55,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 760;
    final pad = isCompact ? 22.0 : 30.0;

    return GlassPanel(
      padding: EdgeInsets.all(pad),
      borderRadius: BorderRadius.circular(34),
      blur: 28,
      opacity: 0.14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Badge ──────────────────────────────────────────────────────────
          FadeTransition(
            opacity: _badgeFade,
            child: SlideTransition(
              position: _badgeSlide,
              child: GlassBadge(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedUserCircle,
                      size: 15,
                      color: AppColors.primary,
                      strokeWidth: 1.8,
                    ),
                    SizedBox(width: 8),
                    Text('Account profile', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── Avatar hero ────────────────────────────────────────────────────
          FadeTransition(
            opacity: _avatarFade,
            child: SlideTransition(
              position: _avatarSlide,
              child: ScaleTransition(
                scale: _avatarScale,
                child: Center(
                  child: _AvatarHero(
                    user: widget.user,
                    pulse: _pulse,
                    isCompact: isCompact,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Name + email ───────────────────────────────────────────────────
          FadeTransition(
            opacity: _avatarFade,
            child: SlideTransition(
              position: _avatarSlide,
              child: Center(
                child: Column(
                  children: [
                    Text(
                      widget.user.fullName ?? 'Budgetify user',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isCompact ? 22 : 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.user.email,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.1,
                      ),
                    ),
                    if (widget.user.isEmailVerified) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: AppColors.success.withValues(alpha: 0.12),
                          border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.verified_rounded,
                              size: 13,
                              color: AppColors.success,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Verified account',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── Divider ────────────────────────────────────────────────────────
          FadeTransition(
            opacity: _statsFade,
            child: Divider(
              color: Colors.white.withValues(alpha: 0.08),
              height: 1,
            ),
          ),

          const SizedBox(height: 24),

          // ── Stat cards ─────────────────────────────────────────────────────
          FadeTransition(
            opacity: _statsFade,
            child: SlideTransition(
              position: _statsSlide,
              child: Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: HugeIcons.strokeRoundedCheckmarkBadge02,
                      label: 'Status',
                      value: _capitalize(widget.user.status),
                      valueColor: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      icon: HugeIcons.strokeRoundedShield01,
                      label: 'Verification',
                      value: widget.user.isEmailVerified
                          ? 'Verified'
                          : 'Pending',
                      valueColor: widget.user.isEmailVerified
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      icon: HugeIcons.strokeRoundedCalendar01,
                      label: 'Joined',
                      value: _shortDate(widget.user.createdAt),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Account details ────────────────────────────────────────────────
          FadeTransition(
            opacity: _detailsFade,
            child: SlideTransition(
              position: _detailsSlide,
              child: Column(
                children: [
                  _AccountDetails(user: widget.user),
                  const SizedBox(height: 18),
                  _TodoShortcutCard(onTap: _openTodoBoard),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Divider ────────────────────────────────────────────────────────
          FadeTransition(
            opacity: _logoutFade,
            child: Divider(
              color: Colors.white.withValues(alpha: 0.08),
              height: 1,
            ),
          ),

          const SizedBox(height: 20),

          // ── Logout button ──────────────────────────────────────────────────
          FadeTransition(
            opacity: _logoutFade,
            child: SlideTransition(
              position: _logoutSlide,
              child: _LogoutButton(
                isLoggingOut: widget.isLoggingOut,
                onLogout: widget.onLogout,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  static const _months = [
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

  String _shortDate(DateTime dt) => '${_months[dt.month - 1]} ${dt.year}';

  Future<void> _openTodoBoard() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TodoPage(
          todoService: widget.todoService,
          expenseService: widget.expenseService,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatar hero with pulsing glow ring
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarHero extends StatelessWidget {
  const _AvatarHero({
    required this.user,
    required this.pulse,
    required this.isCompact,
  });

  final AuthUser user;
  final Animation<double> pulse;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final avatarRadius = isCompact ? 44.0 : 52.0;
    final ringGap = 5.0;
    final ringWidth = 2.0;
    final outerRadius = avatarRadius + ringGap + ringWidth;

    return SizedBox(
      width: outerRadius * 2 + 24,
      height: outerRadius * 2 + 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing outer glow
          AnimatedBuilder(
            animation: pulse,
            builder: (context, _) => Container(
              width: outerRadius * 2 + pulse.value * 16,
              height: outerRadius * 2 + pulse.value * 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(
                      alpha: 0.18 * pulse.value,
                    ),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),

          // Gradient ring
          AnimatedBuilder(
            animation: pulse,
            builder: (context, _) => Container(
              width: outerRadius * 2,
              height: outerRadius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  startAngle: 0,
                  endAngle: 6.28,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.7 * pulse.value),
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.primary.withValues(alpha: 0.7 * pulse.value),
                  ],
                ),
              ),
            ),
          ),

          // Inner background ring
          Container(
            width: (avatarRadius + ringGap) * 2,
            height: (avatarRadius + ringGap) * 2,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.background,
            ),
          ),

          // Avatar
          CircleAvatar(
            radius: avatarRadius,
            backgroundColor: AppColors.surfaceElevated,
            backgroundImage: user.avatarUrl != null
                ? NetworkImage(user.avatarUrl!)
                : null,
            child: user.avatarUrl == null
                ? Text(
                    _initials(),
                    style: TextStyle(
                      fontSize: avatarRadius * 0.46,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 1,
                    ),
                  )
                : null,
          ),

          // Verified badge
          if (user.isEmailVerified)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success,
                  border: Border.all(color: AppColors.background, width: 2.5),
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_rounded,
                    size: 12,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _initials() {
    if (user.firstName != null && user.lastName != null) {
      return '${user.firstName![0]}${user.lastName![0]}'.toUpperCase();
    }
    if (user.firstName != null && user.firstName!.isNotEmpty) {
      return user.firstName![0].toUpperCase();
    }
    return user.email[0].toUpperCase();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat card
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatefulWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor = AppColors.textPrimary,
  });

  final dynamic icon;
  final String label;
  final String value;
  final Color valueColor;

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      reverseDuration: const Duration(milliseconds: 380),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) => _pressCtrl.animateBack(0, curve: Curves.easeOutBack),
      onTapCancel: () => _pressCtrl.animateBack(0, curve: Curves.easeOutBack),
      child: AnimatedBuilder(
        animation: _pressCtrl,
        builder: (context, child) =>
            Transform.scale(scale: 1.0 - _pressCtrl.value * 0.04, child: child),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: widget.icon,
                    size: 16,
                    color: AppColors.primary,
                    strokeWidth: 1.8,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                widget.value,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: widget.valueColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Account details rows
// ─────────────────────────────────────────────────────────────────────────────

class _AccountDetails extends StatelessWidget {
  const _AccountDetails({required this.user});

  final AuthUser user;

  static const _months = [
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

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Unavailable';
    return '${_months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final rows = [
      _InfoRowData(
        icon: HugeIcons.strokeRoundedMail01,
        label: 'Email address',
        value: user.email,
        copyable: true,
      ),
      _InfoRowData(
        icon: HugeIcons.strokeRoundedShield01,
        label: 'Email verification',
        value: user.isEmailVerified ? 'Verified' : 'Pending',
        valueColor: user.isEmailVerified
            ? AppColors.success
            : AppColors.textSecondary,
      ),
      _InfoRowData(
        icon: HugeIcons.strokeRoundedClock01,
        label: 'Last login',
        value: _formatDate(user.lastLoginAt),
      ),
      _InfoRowData(
        icon: HugeIcons.strokeRoundedCalendar01,
        label: 'Member since',
        value: _formatDate(user.createdAt),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            _InfoRow(data: rows[i]),
            if (i < rows.length - 1)
              Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.06),
                indent: 56,
              ),
          ],
        ],
      ),
    );
  }
}

class _InfoRowData {
  const _InfoRowData({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor = AppColors.textPrimary,
    this.copyable = false,
  });

  final dynamic icon;
  final String label;
  final String value;
  final Color valueColor;
  final bool copyable;
}

class _InfoRow extends StatefulWidget {
  const _InfoRow({required this.data});

  final _InfoRowData data;

  @override
  State<_InfoRow> createState() => _InfoRowState();
}

class _TodoShortcutCard extends StatefulWidget {
  const _TodoShortcutCard({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_TodoShortcutCard> createState() => _TodoShortcutCardState();
}

class _TodoShortcutCardState extends State<_TodoShortcutCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withValues(alpha: 0.14),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: AppColors.primary.withValues(alpha: 0.16),
                ),
                child: const HugeIcon(
                  icon: HugeIcons.strokeRoundedTaskDaily01,
                  size: 18,
                  color: AppColors.primary,
                  strokeWidth: 1.8,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Todo board',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Open your visual todo list to add, edit, and manage planned tasks with photos and budgets.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                child: const Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    size: 16,
                    color: AppColors.textPrimary,
                    strokeWidth: 1.8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRowState extends State<_InfoRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 360),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    _pressCtrl.forward().then(
      (_) => _pressCtrl.animateBack(0, curve: Curves.easeOutBack),
    );

    if (widget.data.copyable) {
      await Clipboard.setData(ClipboardData(text: widget.data.value));
      if (!mounted) return;
      setState(() => _copied = true);
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      if (mounted) setState(() => _copied = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _pressCtrl,
        builder: (context, child) => Container(
          color: Colors.white.withValues(alpha: _pressCtrl.value * 0.04),
          child: child,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.10),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: widget.data.icon,
                    size: 15,
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
                      widget.data.label,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.data.value,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: widget.data.valueColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.data.copyable)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _copied
                      ? const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: AppColors.success,
                          key: ValueKey('check'),
                        )
                      : Icon(
                          Icons.copy_rounded,
                          size: 14,
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                          key: const ValueKey('copy'),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Logout button
// ─────────────────────────────────────────────────────────────────────────────

class _LogoutButton extends StatefulWidget {
  const _LogoutButton({required this.isLoggingOut, required this.onLogout});

  final bool isLoggingOut;
  final VoidCallback? onLogout;

  @override
  State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      reverseDuration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canTap = widget.onLogout != null && !widget.isLoggingOut;

    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Danger zone',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'End your current session',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
        const Spacer(),
        GestureDetector(
          onTapDown: canTap ? (_) => _pressCtrl.forward() : null,
          onTapUp: canTap
              ? (_) {
                  _pressCtrl.animateBack(0, curve: Curves.easeOutBack);
                  widget.onLogout?.call();
                }
              : null,
          onTapCancel: canTap
              ? () => _pressCtrl.animateBack(0, curve: Curves.easeOutBack)
              : null,
          child: AnimatedBuilder(
            animation: _pressCtrl,
            builder: (context, child) => Transform.scale(
              scale: 1.0 - _pressCtrl.value * 0.06,
              child: child,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: widget.isLoggingOut
                    ? AppColors.danger.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.05),
                border: Border.all(
                  color: widget.isLoggingOut
                      ? AppColors.danger.withValues(alpha: 0.35)
                      : Colors.white.withValues(alpha: 0.14),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: widget.isLoggingOut
                        ? const SizedBox(
                            width: 13,
                            height: 13,
                            key: ValueKey('spinner'),
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.danger,
                              ),
                            ),
                          )
                        : HugeIcon(
                            key: const ValueKey('icon'),
                            icon: HugeIcons.strokeRoundedLogout01,
                            size: 14,
                            color: AppColors.danger,
                            strokeWidth: 1.8,
                          ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: widget.isLoggingOut
                          ? AppColors.danger.withValues(alpha: 0.7)
                          : AppColors.danger,
                    ),
                    child: Text(
                      widget.isLoggingOut ? 'Signing out…' : 'Sign out',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
