import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../data/models/todo_item.dart';

class TodoItemCard extends StatefulWidget {
  const TodoItemCard({
    super.key,
    required this.todo,
    required this.staggerIndex,
    required this.onEdit,
    required this.onDelete,
  });

  final TodoItem todo;
  final int staggerIndex;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<TodoItemCard> createState() => _TodoItemCardState();
}

class _TodoItemCardState extends State<TodoItemCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 540),
    );
    _fade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Curves.easeOutCubic,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.07),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic),
    );

    final delay = Duration(milliseconds: widget.staggerIndex * 80);
    Future.delayed(delay, () {
      if (mounted) _entranceCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coverUrl = widget.todo.primaryImage?.imageUrl ??
        widget.todo.coverImageUrl;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.985 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: GlassPanel(
              borderRadius: BorderRadius.circular(30),
              padding: const EdgeInsets.all(18),
              blur: 26,
              opacity: 0.13,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Cover image ───────────────────────────────────────────
                  _CoverImage(
                    coverUrl: coverUrl,
                    priority: widget.todo.priority,
                    imageCount: widget.todo.imageCount,
                  ),

                  const SizedBox(height: 18),

                  // ── Title + price ─────────────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.todo.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Updated ${_formatDate(widget.todo.updatedAt)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _rwf(widget.todo.price),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'budget',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // ── Thumbnail strip ───────────────────────────────────────
                  if (widget.todo.images.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _ThumbnailStrip(images: widget.todo.images),
                  ],

                  const SizedBox(height: 18),

                  // ── Action row ────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _ActionPill(
                          icon: HugeIcons.strokeRoundedTaskEdit01,
                          label: 'Edit',
                          onTap: widget.onEdit,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionPill(
                          icon: HugeIcons.strokeRoundedDelete02,
                          label: 'Delete',
                          onTap: widget.onDelete,
                          foregroundColor: AppColors.danger,
                          backgroundColor:
                              AppColors.danger.withValues(alpha: 0.08),
                          borderColor: AppColors.danger.withValues(alpha: 0.24),
                        ),
                      ),
                    ],
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

// ── Cover image with shimmer loader ─────────────────────────────────────────

class _CoverImage extends StatelessWidget {
  const _CoverImage({
    required this.coverUrl,
    required this.priority,
    required this.imageCount,
  });

  final String? coverUrl;
  final TodoPriority priority;
  final int imageCount;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background gradient
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _priorityColor(priority).withValues(alpha: 0.28),
                    AppColors.surfaceElevated,
                    Colors.black.withValues(alpha: 0.54),
                  ],
                ),
              ),
            ),

            // Cover image with shimmer while loading
            if (coverUrl != null)
              Image.network(
                coverUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const SkeletonLoader(child: SizedBox.expand());
                },
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),

            // Bottom gradient overlay
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.06),
                    Colors.black.withValues(alpha: 0.48),
                  ],
                ),
              ),
            ),

            // Priority badge
            Positioned(
              top: 14,
              left: 14,
              child: _PriorityPill(priority: priority),
            ),

            // Photo count badge
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Colors.black.withValues(alpha: 0.34),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedCamera01,
                      size: 14,
                      color: AppColors.textPrimary,
                      strokeWidth: 1.8,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$imageCount ${imageCount == 1 ? 'photo' : 'photos'}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // No-image placeholder
            if (coverUrl == null)
              Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedTaskDaily01,
                  size: 42,
                  color: _priorityColor(priority).withValues(alpha: 0.6),
                  strokeWidth: 1.6,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Thumbnail strip ──────────────────────────────────────────────────────────

class _ThumbnailStrip extends StatelessWidget {
  const _ThumbnailStrip({required this.images});

  final List<TodoImageItem> images;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final image = images[index];
          return _ThumbnailTile(image: image);
        },
      ),
    );
  }
}

class _ThumbnailTile extends StatelessWidget {
  const _ThumbnailTile({required this.image});

  final TodoImageItem image;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: image.isPrimary
              ? AppColors.primary.withValues(alpha: 0.60)
              : Colors.white.withValues(alpha: 0.10),
          width: image.isPrimary ? 1.5 : 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              image.imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const SkeletonLoader(child: SizedBox.expand());
              },
              errorBuilder: (context, error, stackTrace) => Container(
                color: AppColors.surfaceElevated,
                child: const Icon(
                  Icons.image_not_supported_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            if (image.isPrimary)
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  margin: const EdgeInsets.all(4),
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    size: 10,
                    color: Colors.black,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Priority pill ────────────────────────────────────────────────────────────

class _PriorityPill extends StatelessWidget {
  const _PriorityPill({required this.priority});

  final TodoPriority priority;

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(priority);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        priority.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ── Action pill ──────────────────────────────────────────────────────────────

class _ActionPill extends StatefulWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.foregroundColor = AppColors.textPrimary,
    this.backgroundColor,
    this.borderColor,
  });

  final dynamic icon;
  final String label;
  final VoidCallback onTap;
  final Color foregroundColor;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  State<_ActionPill> createState() => _ActionPillState();
}

class _ActionPillState extends State<_ActionPill> {
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
        duration: const Duration(milliseconds: 140),
        scale: _pressed ? 0.96 : 1.0,
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color:
                widget.backgroundColor ?? Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: widget.borderColor ?? Colors.white.withValues(alpha: 0.14),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                icon: widget.icon,
                size: 14,
                color: widget.foregroundColor,
                strokeWidth: 1.8,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: widget.foregroundColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

Color _priorityColor(TodoPriority priority) => switch (priority) {
  TodoPriority.topPriority => AppColors.danger,
  TodoPriority.priority => AppColors.primary,
  TodoPriority.notPriority => AppColors.success,
};

String _rwf(double amount) {
  final formatted = amount
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  return 'RWF $formatted';
}

const List<String> _months = <String>[
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

String _formatDate(DateTime date) {
  return '${_months[date.month - 1]} ${date.day}, ${date.year}';
}
