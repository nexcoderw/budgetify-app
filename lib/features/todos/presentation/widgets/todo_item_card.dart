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
      duration: const Duration(milliseconds: 520),
    );
    _fade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Curves.easeOutCubic,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic),
    );

    final delay = Duration(milliseconds: widget.staggerIndex * 75);
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
    final priorityColor = _priorityColor(widget.todo.priority);
    final coverUrl =
        widget.todo.primaryImage?.imageUrl ?? widget.todo.coverImageUrl;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.984 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: GlassPanel(
              borderRadius: BorderRadius.circular(28),
              padding: EdgeInsets.zero,
              blur: 26,
              opacity: 0.12,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Priority accent band ────────────────────────────────
                    Container(
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            priorityColor,
                            priorityColor.withValues(alpha: 0.3),
                          ],
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Top row: priority badge + photo count ─────────
                          Row(
                            children: [
                              _PriorityBadge(
                                priority: widget.todo.priority,
                                color: priorityColor,
                              ),
                              const Spacer(),
                              if (widget.todo.imageCount > 0)
                                _PhotoCountBadge(
                                  count: widget.todo.imageCount,
                                ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // ── Cover image ─────────────────────────────────
                          if (coverUrl != null) ...[
                            _CoverImage(coverUrl: coverUrl),
                            const SizedBox(height: 14),
                          ],

                          // ── Title + price ──────────────────────────────
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  widget.todo.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.4,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _rwf(widget.todo.price),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: priorityColor,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const Text(
                                    'budget',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // ── Subtitle row ───────────────────────────────
                          Text(
                            'Updated ${_formatDate(widget.todo.updatedAt)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),

                          // ── Thumbnail strip ────────────────────────────
                          if (widget.todo.images.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            _ThumbnailStrip(images: widget.todo.images),
                          ],

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),

                    // ── Divider ──────────────────────────────────────────────
                    Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.07),
                    ),

                    // ── Action row ──────────────────────────────────────────
                    IntrinsicHeight(
                      child: Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              icon: HugeIcons.strokeRoundedTaskEdit01,
                              label: 'Edit',
                              onTap: widget.onEdit,
                            ),
                          ),
                          Container(
                            width: 1,
                            color: Colors.white.withValues(alpha: 0.07),
                          ),
                          Expanded(
                            child: _ActionButton(
                              icon: HugeIcons.strokeRoundedDelete02,
                              label: 'Delete',
                              onTap: widget.onDelete,
                              color: AppColors.danger,
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
    );
  }
}

// ── Cover image ───────────────────────────────────────────────────────────────

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.coverUrl});

  final String coverUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          coverUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const SkeletonLoader(child: SizedBox.expand());
          },
          errorBuilder: (context, error, stackTrace) => Container(
            color: AppColors.surfaceElevated,
            child: const Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedImageNotFound01,
                size: 28,
                color: AppColors.textSecondary,
                strokeWidth: 1.6,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Thumbnail strip ───────────────────────────────────────────────────────────

class _ThumbnailStrip extends StatelessWidget {
  const _ThumbnailStrip({required this.images});

  final List<TodoImageItem> images;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) =>
            _ThumbnailTile(image: images[index]),
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
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: image.isPrimary
              ? AppColors.primary.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.09),
          width: image.isPrimary ? 1.5 : 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
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
                  size: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            if (image.isPrimary)
              Positioned(
                top: 3,
                right: 3,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    size: 9,
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

// ── Priority badge ────────────────────────────────────────────────────────────

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority, required this.color});

  final TodoPriority priority;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            priority.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Photo count badge ─────────────────────────────────────────────────────────

class _PhotoCountBadge extends StatelessWidget {
  const _PhotoCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.black.withValues(alpha: 0.28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedCamera01,
            size: 13,
            color: AppColors.textSecondary,
            strokeWidth: 1.8,
          ),
          const SizedBox(width: 5),
          Text(
            '$count ${count == 1 ? 'photo' : 'photos'}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.textSecondary,
  });

  final dynamic icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(vertical: 14),
        color: _pressed
            ? widget.color.withValues(alpha: 0.06)
            : Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: widget.icon,
              size: 14,
              color: widget.color,
              strokeWidth: 1.8,
            ),
            const SizedBox(width: 8),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: widget.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Color _priorityColor(TodoPriority priority) => switch (priority) {
  TodoPriority.topPriority => AppColors.danger,
  TodoPriority.priority => AppColors.primary,
  TodoPriority.notPriority => AppColors.success,
};

String _rwf(double amount) {
  final s = amount
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  return 'RWF $s';
}

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime date) =>
    '${_months[date.month - 1]} ${date.day}, ${date.year}';
