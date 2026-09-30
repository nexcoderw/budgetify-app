import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/glass_panel.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onFinished});

  final Future<void> Function() onFinished;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin {
  static const _slides = <_OnboardingSlideData>[
    _OnboardingSlideData(
      eyebrow: 'WELCOME TO BUDGETIFY',
      title: 'Your money, finally in one clear place.',
      description:
          'See what you spend, what you save, and where your money moves without digging through scattered notes and messages.',
      visual: _OnboardingVisualType.overview,
    ),
    _OnboardingSlideData(
      eyebrow: 'SMARTER PAYMENTS',
      title: 'Send money with confidence.',
      description:
          'Start MTN MoMo, eKash and MoMo Pay transfers from Budgetify, then keep each payment recorded with its status and history.',
      visual: _OnboardingVisualType.payments,
    ),
    _OnboardingSlideData(
      eyebrow: 'MORE CONTROL',
      title: 'Make every franc more intentional.',
      description:
          'Use your financial records to understand your habits, stay on top of your plans, and make better day-to-day money decisions.',
      visual: _OnboardingVisualType.control,
    ),
  ];

  late final PageController _pageController;

  late final AnimationController _ambientController;

  int _currentPage = 0;

  bool _isFinishing = false;

  @override
  void initState() {
    super.initState();

    _pageController = PageController();

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _ambientController.dispose();

    super.dispose();
  }

  Future<void> _next() async {
    if (_isFinishing) {
      return;
    }

    if (_currentPage < _slides.length - 1) {
      await _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 440),
        curve: Curves.easeOutCubic,
      );

      return;
    }

    await _finish();
  }

  Future<void> _finish() async {
    if (_isFinishing) {
      return;
    }

    setState(() {
      _isFinishing = true;
    });

    try {
      await widget.onFinished();
    } finally {
      if (mounted) {
        setState(() {
          _isFinishing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    final size = mediaQuery.size;

    final isCompact = size.width < 430;

    final disableAnimations = mediaQuery.disableAnimations;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isCompact ? 18 : 28,
                18,
                isCompact ? 18 : 28,
                18,
              ),
              child: Column(
                children: [
                  _OnboardingHeader(
                    isCompact: isCompact,
                    isFinishing: _isFinishing,
                    onSkip: () {
                      unawaited(_finish());
                    },
                  ),
                  SizedBox(height: isCompact ? 16 : 24),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _slides.length,
                      onPageChanged: (page) {
                        setState(() {
                          _currentPage = page;
                        });
                      },
                      itemBuilder: (context, index) {
                        return _AnimatedSlide(
                          index: index,
                          controller: _pageController,
                          disableAnimations: disableAnimations,
                          child: _OnboardingSlide(
                            data: _slides[index],
                            ambientController: _ambientController,
                            isCompact: isCompact,
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: isCompact ? 14 : 18),
                  _PageIndicator(
                    count: _slides.length,
                    selectedIndex: _currentPage,
                  ),
                  SizedBox(height: isCompact ? 18 : 22),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: AppButton(
                      label: _currentPage == _slides.length - 1
                          ? 'Get started'
                          : 'Continue',
                      icon: HugeIcons.strokeRoundedSent,
                      size: AppButtonSize.md,
                      isLoading: _isFinishing,
                      onPressed: _isFinishing
                          ? null
                          : () {
                              unawaited(_next());
                            },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({
    required this.isCompact,
    required this.isFinishing,
    required this.onSkip,
  });

  final bool isCompact;
  final bool isFinishing;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          'assets/branding/png/tight/logo-color-beige-512.png',
          width: isCompact ? 36 : 42,
          height: isCompact ? 30 : 34,
          fit: BoxFit.contain,
          semanticLabel: 'Budgetify logo',
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Budgetify',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: isCompact ? 22 : 25,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        TextButton(
          onPressed: isFinishing ? null : onSkip,
          style: TextButton.styleFrom(
            minimumSize: const Size(60, 44),
            foregroundColor: AppColors.textSecondary,
          ),
          child: const Text(
            'Skip',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _AnimatedSlide extends StatelessWidget {
  const _AnimatedSlide({
    required this.index,
    required this.controller,
    required this.disableAnimations,
    required this.child,
  });

  final int index;

  final PageController controller;

  final bool disableAnimations;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (disableAnimations) {
      return child;
    }

    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        var page = index.toDouble();

        if (controller.hasClients &&
            controller.positions.isNotEmpty &&
            controller.position.hasContentDimensions) {
          page = controller.page ?? index.toDouble();
        }

        final difference = page - index;

        final distance = difference.abs().clamp(0.0, 1.0);

        final opacity = 1 - (distance * 0.36);

        final scale = 1 - (distance * 0.045);

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(-difference * 28, distance * 8),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({
    required this.data,
    required this.ambientController,
    required this.isCompact,
  });

  final _OnboardingSlideData data;

  final AnimationController ambientController;

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _SlideVisual(
                      type: data.visual,
                      ambientController: ambientController,
                      compact: isCompact,
                    ),
                    SizedBox(height: isCompact ? 28 : 38),
                    Text(
                      data.eyebrow,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.65,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      data.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isCompact ? 30 : 38,
                        height: 1.06,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.2,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Text(
                        data.description,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isCompact ? 12 : 13,
                          height: 1.65,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SlideVisual extends StatelessWidget {
  const _SlideVisual({
    required this.type,
    required this.ambientController,
    required this.compact,
  });

  final _OnboardingVisualType type;

  final AnimationController ambientController;

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    final width = compact ? 310.0 : 390.0;

    return AnimatedBuilder(
      animation: ambientController,
      builder: (context, child) {
        final movement = disableAnimations
            ? 0.0
            : (ambientController.value - 0.5) * 10;

        return Transform.translate(
          offset: Offset(0, movement),
          child: SizedBox(
            width: width,
            height: compact ? 245 : 285,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: GlassPanel(
                    blur: 30,
                    opacity: 0.08,
                    borderRadius: BorderRadius.circular(34),
                    padding: const EdgeInsets.all(18),
                    child: _visualContent(),
                  ),
                ),
                Positioned(
                  right: compact ? -7 : -13,
                  top: compact ? 26 : 30,
                  child: _FloatingGlassBadge(
                    icon: HugeIcons.strokeRoundedMoneySendSquare,
                    label: type == _OnboardingVisualType.payments
                        ? 'Tracked'
                        : 'RWF',
                  ),
                ),
                Positioned(
                  left: compact ? -8 : -16,
                  bottom: compact ? 22 : 28,
                  child: _FloatingGlassBadge(
                    icon: HugeIcons.strokeRoundedTransactionHistory,
                    label: type == _OnboardingVisualType.control
                        ? 'In control'
                        : 'Clear',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _visualContent() {
    return switch (type) {
      _OnboardingVisualType.overview => const _OverviewVisual(),

      _OnboardingVisualType.payments => const _PaymentsVisual(),

      _OnboardingVisualType.control => const _ControlVisual(),
    };
  }
}

class _OverviewVisual extends StatelessWidget {
  const _OverviewVisual();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'This month',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            Spacer(),
            _MiniStatus(label: 'On track', positive: true),
          ],
        ),
        const Spacer(),
        const Text(
          'RWF 428,500',
          style: TextStyle(
            fontSize: 29,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Money recorded',
          style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              flex: 5,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              flex: 3,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.primaryMuted,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              flex: 2,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Row(
          children: [
            Expanded(
              child: _MiniMetric(label: 'Spent', value: '286K'),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _MiniMetric(label: 'Saved', value: '92K'),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _MiniMetric(label: 'Fees', value: '2.4K'),
            ),
          ],
        ),
      ],
    );
  }
}

class _PaymentsVisual extends StatelessWidget {
  const _PaymentsVisual();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'Latest payment',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            Spacer(),
            _MiniStatus(label: 'Completed', positive: true),
          ],
        ),
        const Spacer(),
        const Row(
          children: [
            _VisualIcon(icon: HugeIcons.strokeRoundedMoneySendSquare),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MTN MoMo transfer',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '25,000 RWF',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const _TimelineRow(title: 'Payment created', active: true),
        const SizedBox(height: 10),
        const _TimelineRow(title: 'MTN prompt opened', active: true),
        const SizedBox(height: 10),
        const _TimelineRow(title: 'Result recorded', active: true),
      ],
    );
  }
}

class _ControlVisual extends StatelessWidget {
  const _ControlVisual();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'Your money plan',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            Spacer(),
            _MiniStatus(label: 'Focused', positive: true),
          ],
        ),
        const Spacer(),
        const _PlanRow(
          label: 'Daily spending',
          amount: '42,000 RWF',
          progress: 0.68,
        ),
        const SizedBox(height: 16),
        const _PlanRow(label: 'Savings', amount: '120,000 RWF', progress: 0.82),
        const SizedBox(height: 16),
        const _PlanRow(
          label: 'Upcoming plans',
          amount: '75,000 RWF',
          progress: 0.46,
        ),
      ],
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.label,
    required this.amount,
    required this.progress,
  });

  final String label;
  final String amount;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              amount,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: AppColors.surfaceElevated,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.title, required this.active});

  final String title;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppColors.success : AppColors.border,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.28),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _VisualIcon extends StatelessWidget {
  const _VisualIcon({required this.icon});

  final dynamic icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: HugeIcon(
        icon: icon,
        size: 21,
        strokeWidth: 1.8,
        color: AppColors.primary,
      ),
    );
  }
}

class _FloatingGlassBadge extends StatelessWidget {
  const _FloatingGlassBadge({required this.icon, required this.label});

  final dynamic icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GlassBadge(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: icon,
            size: 14,
            strokeWidth: 1.8,
            color: AppColors.primary,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(fontSize: 8, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _MiniStatus extends StatelessWidget {
  const _MiniStatus({required this.label, required this.positive});

  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final color = positive ? AppColors.success : AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.count, required this.selectedIndex});

  final int count;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < count; index++) ...[
          if (index > 0) const SizedBox(width: 7),
          AnimatedContainer(
            duration: disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            width: index == selectedIndex ? 28 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: index == selectedIndex
                  ? AppColors.primary
                  : AppColors.border,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ],
    );
  }
}

enum _OnboardingVisualType { overview, payments, control }

class _OnboardingSlideData {
  const _OnboardingSlideData({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.visual,
  });

  final String eyebrow;
  final String title;
  final String description;

  final _OnboardingVisualType visual;
}
