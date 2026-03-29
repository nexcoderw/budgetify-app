import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../application/todo_service.dart';
import '../../data/models/todo_item.dart';
import '../../data/models/todo_upload_image.dart';
import '../widgets/todo_delete_dialog.dart';
import '../widgets/todo_form_dialog.dart';
import '../widgets/todo_item_card.dart';

// ── Priority filter enum ──────────────────────────────────────────────────────

enum _PriorityFilter { all, topPriority, priority, notPriority }

extension _PriorityFilterX on _PriorityFilter {
  String get label => switch (this) {
    _PriorityFilter.all => 'All',
    _PriorityFilter.topPriority => 'Top Priority',
    _PriorityFilter.priority => 'Priority',
    _PriorityFilter.notPriority => 'Not Priority',
  };

  Color get color => switch (this) {
    _PriorityFilter.all => AppColors.primary,
    _PriorityFilter.topPriority => AppColors.danger,
    _PriorityFilter.priority => AppColors.primary,
    _PriorityFilter.notPriority => AppColors.success,
  };

  dynamic get icon => switch (this) {
    _PriorityFilter.all => HugeIcons.strokeRoundedTask01,
    _PriorityFilter.topPriority => HugeIcons.strokeRoundedAlert02,
    _PriorityFilter.priority => HugeIcons.strokeRoundedCheckList,
    _PriorityFilter.notPriority => HugeIcons.strokeRoundedCheckmarkCircle02,
  };
}

// ── Page ──────────────────────────────────────────────────────────────────────

class TodoPage extends StatefulWidget {
  const TodoPage({super.key, required this.todoService});

  final TodoService todoService;

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> with TickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  late final AnimationController _bgCtrl;

  List<TodoItem> _todos = const [];
  bool _isLoading = true;
  String? _loadError;
  _PriorityFilter _filter = _PriorityFilter.all;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..forward();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat(reverse: true);
    _loadTodos();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _bgCtrl.dispose();
    super.dispose();
  }

  // ── Computed ──────────────────────────────────────────────────────────────

  int get _topPriorityCount =>
      _todos.where((t) => t.priority == TodoPriority.topPriority).length;
  int get _priorityCount =>
      _todos.where((t) => t.priority == TodoPriority.priority).length;
  int get _notPriorityCount =>
      _todos.where((t) => t.priority == TodoPriority.notPriority).length;
  int get _imageCount => _todos.fold(0, (sum, t) => sum + t.images.length);
  double get _totalBudget => _todos.fold(0.0, (sum, t) => sum + t.price);

  List<TodoItem> get _filteredTodos => switch (_filter) {
    _PriorityFilter.all => _todos,
    _PriorityFilter.topPriority =>
      _todos.where((t) => t.priority == TodoPriority.topPriority).toList(),
    _PriorityFilter.priority =>
      _todos.where((t) => t.priority == TodoPriority.priority).toList(),
    _PriorityFilter.notPriority =>
      _todos.where((t) => t.priority == TodoPriority.notPriority).toList(),
  };

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 760;
    final hPad = isCompact ? 16.0 : 24.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Animated gradient background ────────────────────────────────
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (context, child) {
              final t = _bgCtrl.value;
              return CustomPaint(
                size: Size.infinite,
                painter: _BackgroundPainter(t: t, size: size),
              );
            },
          ),

          // ── Main scrollable content ────────────────────────────────────
          SafeArea(
            child: RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surfaceElevated,
              onRefresh: _loadTodos,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // ── Page header ─────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: _Staggered(
                      ctrl: _entranceCtrl,
                      start: 0.00,
                      end: 0.38,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 0),
                        child: _PageHeader(
                          isCompact: isCompact,
                          onBack: () => Navigator.of(context).pop(),
                          onAdd: _openCreateDialog,
                        ),
                      ),
                    ),
                  ),

                  // ── Hero budget card ────────────────────────────────────
                  SliverToBoxAdapter(
                    child: _Staggered(
                      ctrl: _entranceCtrl,
                      start: 0.14,
                      end: 0.56,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(hPad, 22, hPad, 0),
                        child: _HeroBudgetCard(
                          totalBudget: _totalBudget,
                          todoCount: _todos.length,
                          topPriorityCount: _topPriorityCount,
                          imageCount: _imageCount,
                          isLoading: _isLoading,
                        ),
                      ),
                    ),
                  ),

                  // ── Priority breakdown bar ──────────────────────────────
                  if (!_isLoading && _loadError == null && _todos.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _Staggered(
                        ctrl: _entranceCtrl,
                        start: 0.26,
                        end: 0.66,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 0),
                          child: _PriorityBreakdown(
                            topPriorityCount: _topPriorityCount,
                            priorityCount: _priorityCount,
                            notPriorityCount: _notPriorityCount,
                          ),
                        ),
                      ),
                    ),

                  // ── Filter chips ────────────────────────────────────────
                  if (!_isLoading && _loadError == null && _todos.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _Staggered(
                        ctrl: _entranceCtrl,
                        start: 0.32,
                        end: 0.72,
                        child: Padding(
                          padding: EdgeInsets.only(top: 18),
                          child: _FilterChipsRow(
                            selected: _filter,
                            counts: {
                              _PriorityFilter.all: _todos.length,
                              _PriorityFilter.topPriority: _topPriorityCount,
                              _PriorityFilter.priority: _priorityCount,
                              _PriorityFilter.notPriority: _notPriorityCount,
                            },
                            hPad: hPad,
                            onChanged: (f) => setState(() => _filter = f),
                          ),
                        ),
                      ),
                    ),

                  // ── Body sliver ─────────────────────────────────────────
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(hPad, 18, hPad, 48),
                    sliver: _buildBodySliver(isCompact),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodySliver(bool isCompact) {
    if (_isLoading) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) => Padding(
            padding: EdgeInsets.only(bottom: i < 2 ? 14 : 0),
            child: const _SkeletonCard(),
          ),
          childCount: 3,
        ),
      );
    }

    if (_loadError != null) {
      return SliverToBoxAdapter(
        child: _ErrorPanel(message: _loadError!, onRetry: _loadTodos),
      );
    }

    final filtered = _filteredTodos;

    if (filtered.isEmpty && _todos.isEmpty) {
      return SliverToBoxAdapter(
        child: _AnimatedEmptyState(
          isCompact: isCompact,
          onAdd: _openCreateDialog,
        ),
      );
    }

    if (filtered.isEmpty) {
      return SliverToBoxAdapter(
        child: _FilterEmptyState(
          filter: _filter,
          onClear: () => setState(() => _filter = _PriorityFilter.all),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final todo = filtered[index];
          return Padding(
            padding: EdgeInsets.only(
              bottom: index < filtered.length - 1 ? 12 : 0,
            ),
            child: TodoItemCard(
              key: ValueKey(todo.id),
              todo: todo,
              staggerIndex: index,
              onEdit: () => _openEditDialog(todo),
              onDelete: () => _confirmDelete(todo),
            ),
          );
        },
        childCount: filtered.length,
      ),
    );
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<void> _openCreateDialog() async {
    final created = await showDialog<TodoItem>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.68),
      builder: (_) => TodoFormDialog(
        onSubmit: ({
          required String name,
          required double price,
          required TodoPriority priority,
          String? primaryImageId,
          required List<TodoUploadImage> newImages,
        }) =>
            widget.todoService.createTodo(
          name: name,
          price: price,
          priority: priority,
          images: newImages,
        ),
      ),
    );

    if (created == null || !mounted) return;

    setState(() {
      _todos = _sortedTodos([created, ..._todos]);
      _loadError = null;
    });

    AppToast.success(
      context,
      title: 'Todo created',
      description: '${created.name} is now on your board.',
    );
  }

  Future<void> _openEditDialog(TodoItem todo) async {
    final updated = await showDialog<TodoItem>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.68),
      builder: (_) => TodoFormDialog(
        todo: todo,
        onSubmit: ({
          required String name,
          required double price,
          required TodoPriority priority,
          String? primaryImageId,
          required List<TodoUploadImage> newImages,
        }) =>
            widget.todoService.updateTodo(
          todoId: todo.id,
          name: name,
          price: price,
          priority: priority,
          primaryImageId: primaryImageId,
          images: newImages,
        ),
      ),
    );

    if (updated == null || !mounted) return;

    setState(() {
      _todos = _sortedTodos(
        _todos
            .map((c) => c.id == updated.id ? updated : c)
            .toList(growable: false),
      );
      _loadError = null;
    });

    AppToast.success(
      context,
      title: 'Todo updated',
      description: '${updated.name} was refreshed successfully.',
    );
  }

  Future<void> _confirmDelete(TodoItem todo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.68),
      builder: (_) =>
          TodoDeleteDialog(todoName: todo.name, imageCount: todo.images.length),
    );

    if (confirmed != true) return;

    try {
      await widget.todoService.deleteTodo(todo.id);
      if (!mounted) return;

      setState(() {
        _todos = _todos.where((c) => c.id != todo.id).toList(growable: false);
      });

      AppToast.success(
        context,
        title: 'Todo deleted',
        description: '${todo.name} was removed from your board.',
      );
    } catch (error) {
      if (!mounted) return;
      AppToast.error(
        context,
        title: 'Unable to delete todo',
        description: _readableError(error),
      );
    }
  }

  Future<void> _loadTodos() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final todos = await widget.todoService.listTodos();
      if (!mounted) return;
      setState(() {
        _todos = _sortedTodos(todos);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      final message = _readableError(error);
      setState(() {
        _todos = const [];
        _isLoading = false;
        _loadError = message;
      });
      AppToast.error(
        context,
        title: 'Unable to load todo board',
        description: message,
      );
    }
  }

  List<TodoItem> _sortedTodos(List<TodoItem> todos) {
    final sorted = List<TodoItem>.of(todos);
    sorted.sort((a, b) {
      final byPriority = _rank(a.priority).compareTo(_rank(b.priority));
      if (byPriority != 0) return byPriority;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return sorted;
  }

  int _rank(TodoPriority p) => switch (p) {
    TodoPriority.topPriority => 0,
    TodoPriority.priority => 1,
    TodoPriority.notPriority => 2,
  };

  String _readableError(Object error) {
    final msg = error.toString().trim();
    if (msg.startsWith('Exception: ')) return msg.replaceFirst('Exception: ', '');
    if (msg.startsWith('StateError: ')) return msg.replaceFirst('StateError: ', '');
    return msg;
  }
}

// ── Animated background ───────────────────────────────────────────────────────

class _BackgroundPainter extends CustomPainter {
  const _BackgroundPainter({required this.t, required this.size});

  final double t;
  final Size size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final w = canvasSize.width;
    final h = canvasSize.height;

    canvas.drawRect(
      Offset.zero & canvasSize,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.background, Color(0xFF0D1117), Color(0xFF131A22)],
        ).createShader(Offset.zero & canvasSize),
    );

    final eased = Curves.easeInOut.transform(t);

    // Top-left orb (primary color)
    final orb1x = w * (0.10 + 0.08 * eased);
    final orb1y = h * (0.08 + 0.06 * eased);
    canvas.drawCircle(
      Offset(orb1x, orb1y),
      w * 0.22,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.13),
            AppColors.primary.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(
          center: Offset(orb1x, orb1y),
          radius: w * 0.22,
        )),
    );

    // Bottom-right orb (danger tint)
    final orb2x = w * (0.88 - 0.06 * eased);
    final orb2y = h * (0.78 + 0.05 * eased);
    canvas.drawCircle(
      Offset(orb2x, orb2y),
      w * 0.28,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.04),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(
          center: Offset(orb2x, orb2y),
          radius: w * 0.28,
        )),
    );
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) => old.t != t;
}

// ── Page header ───────────────────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.isCompact,
    required this.onBack,
    required this.onAdd,
  });

  final bool isCompact;
  final VoidCallback onBack;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _NavButton(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              label: 'Back',
              onTap: onBack,
            ),
            const Spacer(),
            _NavButton(
              icon: HugeIcons.strokeRoundedTaskAdd01,
              label: isCompact ? 'Add' : 'Add todo',
              onTap: onAdd,
              highlighted: true,
            ),
          ],
        ),
        const SizedBox(height: 22),
        const GlassBadge(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedTaskDaily01,
                size: 14,
                color: AppColors.primary,
                strokeWidth: 1.8,
              ),
              SizedBox(width: 7),
              Text(
                'Todo board',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Plan ahead.\nStay grounded.',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -1.1,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Every purchase, every task — tracked with a budget and visual references so nothing slips.',
          style: TextStyle(
            fontSize: 13,
            height: 1.55,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _NavButton extends StatefulWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  final dynamic icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color =
        widget.highlighted ? AppColors.primary : AppColors.textPrimary;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: widget.highlighted
                ? AppColors.primary.withValues(alpha: 0.11)
                : Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: widget.highlighted
                  ? AppColors.primary.withValues(alpha: 0.26)
                  : Colors.white.withValues(alpha: 0.13),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: widget.icon,
                size: 14,
                color: color,
                strokeWidth: 1.8,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Hero budget card ──────────────────────────────────────────────────────────

class _HeroBudgetCard extends StatefulWidget {
  const _HeroBudgetCard({
    required this.totalBudget,
    required this.todoCount,
    required this.topPriorityCount,
    required this.imageCount,
    required this.isLoading,
  });

  final double totalBudget;
  final int todoCount;
  final int topPriorityCount;
  final int imageCount;
  final bool isLoading;

  @override
  State<_HeroBudgetCard> createState() => _HeroBudgetCardState();
}

class _HeroBudgetCardState extends State<_HeroBudgetCard>
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
    return GlassPanel(
      borderRadius: BorderRadius.circular(32),
      padding: EdgeInsets.zero,
      blur: 32,
      opacity: 0.14,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            // Gradient overlay inside card
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.12),
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.02),
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: AppColors.primary.withValues(alpha: 0.14),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const HugeIcon(
                              icon: HugeIcons.strokeRoundedMoney01,
                              size: 13,
                              color: AppColors.primary,
                              strokeWidth: 1.8,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Planned budget',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Budget number with shimmer
                  if (widget.isLoading)
                    const SkeletonLoader(
                      child: SkeletonBox(height: 44, width: 200, radius: 10),
                    )
                  else
                    TweenAnimationBuilder<double>(
                      key: ValueKey(widget.totalBudget),
                      tween: Tween<double>(begin: 0, end: widget.totalBudget),
                      duration: const Duration(milliseconds: 1200),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return AnimatedBuilder(
                          animation: _shimmerCtrl,
                          builder: (context, _) {
                            final t = _shimmerCtrl.value;
                            return ShaderMask(
                              shaderCallback: (bounds) =>
                                  LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    stops: [
                                      (t - 0.28).clamp(0.0, 1.0),
                                      t.clamp(0.0, 1.0),
                                      (t + 0.28).clamp(0.0, 1.0),
                                    ],
                                    colors: const [
                                      AppColors.textPrimary,
                                      Colors.white,
                                      AppColors.textPrimary,
                                    ],
                                  ).createShader(bounds),
                              blendMode: BlendMode.srcIn,
                              child: Text(
                                _rwfCompact(value),
                                style: const TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -1.4,
                                  height: 1.0,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),

                  const SizedBox(height: 5),
                  const Text(
                    'across all planned items',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Stats row
                  if (widget.isLoading)
                    Row(
                      children: List.generate(
                        3,
                        (i) => Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: i < 2 ? 10 : 0),
                            child: const SkeletonLoader(
                              child: SkeletonBox(height: 64, radius: 16),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: _StatPill(
                            icon: HugeIcons.strokeRoundedTask01,
                            value: '${widget.todoCount}',
                            label: 'Items',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatPill(
                            icon: HugeIcons.strokeRoundedAlert02,
                            value: '${widget.topPriorityCount}',
                            label: 'Top priority',
                            valueColor: widget.topPriorityCount > 0
                                ? AppColors.danger
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatPill(
                            icon: HugeIcons.strokeRoundedCamera01,
                            value: '${widget.imageCount}',
                            label: 'Photos',
                          ),
                        ),
                      ],
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

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.value,
    required this.label,
    this.valueColor,
  });

  final dynamic icon;
  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(
            icon: icon,
            size: 15,
            color: AppColors.primary,
            strokeWidth: 1.8,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Priority breakdown bar ────────────────────────────────────────────────────

class _PriorityBreakdown extends StatelessWidget {
  const _PriorityBreakdown({
    required this.topPriorityCount,
    required this.priorityCount,
    required this.notPriorityCount,
  });

  final int topPriorityCount;
  final int priorityCount;
  final int notPriorityCount;

  int get _total => topPriorityCount + priorityCount + notPriorityCount;

  @override
  Widget build(BuildContext context) {
    final total = _total;
    if (total == 0) return const SizedBox.shrink();

    return GlassPanel(
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      blur: 20,
      opacity: 0.10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Priority breakdown',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 12),

          // Segmented bar
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  if (topPriorityCount > 0)
                    Flexible(
                      flex: topPriorityCount,
                      child: Container(color: AppColors.danger),
                    ),
                  if (topPriorityCount > 0 && priorityCount > 0)
                    const SizedBox(width: 2),
                  if (priorityCount > 0)
                    Flexible(
                      flex: priorityCount,
                      child: Container(color: AppColors.primary),
                    ),
                  if (priorityCount > 0 && notPriorityCount > 0)
                    const SizedBox(width: 2),
                  if (notPriorityCount > 0)
                    Flexible(
                      flex: notPriorityCount,
                      child: Container(color: AppColors.success),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              if (topPriorityCount > 0) ...[
                _BreakdownLegend(
                  color: AppColors.danger,
                  label: 'Top',
                  count: topPriorityCount,
                ),
                const SizedBox(width: 16),
              ],
              if (priorityCount > 0) ...[
                _BreakdownLegend(
                  color: AppColors.primary,
                  label: 'Priority',
                  count: priorityCount,
                ),
                const SizedBox(width: 16),
              ],
              if (notPriorityCount > 0)
                _BreakdownLegend(
                  color: AppColors.success,
                  label: 'Normal',
                  count: notPriorityCount,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BreakdownLegend extends StatelessWidget {
  const _BreakdownLegend({
    required this.color,
    required this.label,
    required this.count,
  });

  final Color color;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label · $count',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ── Filter chips row ──────────────────────────────────────────────────────────

class _FilterChipsRow extends StatelessWidget {
  const _FilterChipsRow({
    required this.selected,
    required this.counts,
    required this.hPad,
    required this.onChanged,
  });

  final _PriorityFilter selected;
  final Map<_PriorityFilter, int> counts;
  final double hPad;
  final ValueChanged<_PriorityFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: hPad),
        children: _PriorityFilter.values.map((filter) {
          final isSelected = selected == filter;
          final count = counts[filter] ?? 0;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _FilterChip(
              filter: filter,
              count: count,
              isSelected: isSelected,
              onTap: () => onChanged(filter),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _FilterChip extends StatefulWidget {
  const _FilterChip({
    required this.filter,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final _PriorityFilter filter;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.filter.color;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: widget.isSelected
                ? color.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: widget.isSelected
                  ? color.withValues(alpha: 0.38)
                  : Colors.white.withValues(alpha: 0.11),
              width: widget.isSelected ? 1.2 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: widget.filter.icon,
                size: 13,
                color: widget.isSelected ? color : AppColors.textSecondary,
                strokeWidth: 1.8,
              ),
              const SizedBox(width: 7),
              Text(
                widget.filter.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.isSelected ? color : AppColors.textSecondary,
                ),
              ),
              if (widget.count > 0) ...[
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: widget.isSelected
                        ? color.withValues(alpha: 0.22)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                  child: Text(
                    '${widget.count}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: widget.isSelected
                          ? color
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Skeleton card ─────────────────────────────────────────────────────────────

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.all(18),
      blur: 22,
      opacity: 0.11,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Priority accent + badge row
          Row(
            children: [
              const SkeletonLoader(
                child: SkeletonBox(height: 24, width: 80, radius: 999),
              ),
              const Spacer(),
              const SkeletonLoader(
                child: SkeletonBox(height: 24, width: 60, radius: 999),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Image area
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: const AspectRatio(
              aspectRatio: 16 / 9,
              child: SkeletonLoader(child: SizedBox.expand()),
            ),
          ),
          const SizedBox(height: 16),
          // Title + price
          Row(
            children: [
              const Expanded(
                child: SkeletonLoader(
                  child: SkeletonBox(height: 20, radius: 8),
                ),
              ),
              const SizedBox(width: 16),
              const SkeletonLoader(
                child: SkeletonBox(height: 20, width: 80, radius: 8),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const SkeletonLoader(
            child: SkeletonBox(height: 12, width: 120, radius: 999),
          ),
          const SizedBox(height: 18),
          // Actions
          const Row(
            children: [
              Expanded(
                child: SkeletonLoader(
                  child: SkeletonBox(height: 44, radius: 999),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: SkeletonLoader(
                  child: SkeletonBox(height: 44, radius: 999),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Error panel ───────────────────────────────────────────────────────────────

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.all(28),
      blur: 26,
      opacity: 0.12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: AppColors.danger.withValues(alpha: 0.12),
              border: Border.all(
                color: AppColors.danger.withValues(alpha: 0.26),
              ),
            ),
            child: const Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedAlert02,
                size: 24,
                color: AppColors.danger,
                strokeWidth: 1.8,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Could not load your board',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 22),
          _NavButton(
            icon: HugeIcons.strokeRoundedRefresh,
            label: 'Try again',
            onTap: onRetry,
            highlighted: true,
          ),
        ],
      ),
    );
  }
}

// ── Animated empty state ──────────────────────────────────────────────────────

class _AnimatedEmptyState extends StatefulWidget {
  const _AnimatedEmptyState({required this.isCompact, required this.onAdd});

  final bool isCompact;
  final VoidCallback onAdd;

  @override
  State<_AnimatedEmptyState> createState() => _AnimatedEmptyStateState();
}

class _AnimatedEmptyStateState extends State<_AnimatedEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathCtrl;

  @override
  void initState() {
    super.initState();
    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      borderRadius: BorderRadius.circular(32),
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 36),
      blur: 26,
      opacity: 0.14,
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _breathCtrl,
            builder: (context, child) {
              final t = Curves.easeInOut.transform(_breathCtrl.value);
              return Transform.scale(
                scale: 1.0 + 0.055 * t,
                child: child,
              );
            },
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.22),
                    AppColors.primary.withValues(alpha: 0.06),
                  ],
                ),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.16),
                    blurRadius: 30,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: const Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedTaskDaily01,
                  size: 38,
                  color: AppColors.primary,
                  strokeWidth: 1.6,
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),

          const Text(
            'Your board is ready',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.8,
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            'Add your first item — set a budget, choose a priority, and attach photos to keep everything clear.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 28),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _EmptyChip(
                icon: HugeIcons.strokeRoundedTask01,
                label: '0 items',
              ),
              const SizedBox(width: 10),
              _EmptyChip(
                icon: HugeIcons.strokeRoundedCamera01,
                label: '0 photos',
              ),
              const SizedBox(width: 10),
              _EmptyChip(
                icon: HugeIcons.strokeRoundedMoney01,
                label: 'RWF 0',
              ),
            ],
          ),

          const SizedBox(height: 28),

          SizedBox(
            width: widget.isCompact ? double.infinity : 260,
            child: _NavButton(
              icon: HugeIcons.strokeRoundedTaskAdd01,
              label: 'Add your first todo',
              onTap: widget.onAdd,
              highlighted: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChip extends StatelessWidget {
  const _EmptyChip({required this.icon, required this.label});

  final dynamic icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: icon,
            size: 13,
            color: AppColors.textSecondary,
            strokeWidth: 1.8,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter empty state ────────────────────────────────────────────────────────

class _FilterEmptyState extends StatelessWidget {
  const _FilterEmptyState({required this.filter, required this.onClear});

  final _PriorityFilter filter;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(24),
      blur: 20,
      opacity: 0.10,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: filter.color.withValues(alpha: 0.10),
              border: Border.all(
                color: filter.color.withValues(alpha: 0.22),
              ),
            ),
            child: Center(
              child: HugeIcon(
                icon: filter.icon,
                size: 22,
                color: filter.color,
                strokeWidth: 1.8,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No ${filter.label} items',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You have no items in the "${filter.label}" category yet.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          _NavButton(
            icon: HugeIcons.strokeRoundedTask01,
            label: 'Show all',
            onTap: onClear,
          ),
        ],
      ),
    );
  }
}

// ── Staggered entrance ────────────────────────────────────────────────────────

class _Staggered extends StatelessWidget {
  const _Staggered({
    required this.ctrl,
    required this.start,
    required this.end,
    required this.child,
  });

  final AnimationController ctrl;
  final double start;
  final double end;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(
      parent: ctrl,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: ctrl,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      ),
    );

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }
}

// ── Formatters ────────────────────────────────────────────────────────────────

String _rwfCompact(double v) {
  if (v >= 1000000) return 'RWF ${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return 'RWF ${(v / 1000).toStringAsFixed(0)}k';
  final s = v
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  return 'RWF $s';
}
