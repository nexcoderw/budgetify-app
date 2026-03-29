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
import '../widgets/todo_summary_card.dart';

class TodoPage extends StatefulWidget {
  const TodoPage({super.key, required this.todoService});

  final TodoService todoService;

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  List<TodoItem> _todos = const <TodoItem>[];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 920),
    )..forward();
    _loadTodos();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  int get _topPriorityCount =>
      _todos.where((todo) => todo.priority == TodoPriority.topPriority).length;

  int get _imageCount =>
      _todos.fold<int>(0, (sum, todo) => sum + todo.images.length);

  double get _totalBudget =>
      _todos.fold<double>(0, (sum, todo) => sum + todo.price);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 760;

    return Scaffold(
      body: DecoratedBox(
        decoration: const _TodoPageBackgroundDecoration(),
        child: SafeArea(
          child: RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surfaceElevated,
            onRefresh: _loadTodos,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(
                isCompact ? 16 : 24,
                18,
                isCompact ? 16 : 24,
                32,
              ),
              children: [
                _Staggered(
                  controller: _entranceCtrl,
                  intervalStart: 0.00,
                  intervalEnd: 0.30,
                  child: _TodoPageHeader(
                    isCompact: isCompact,
                    onBack: () => Navigator.of(context).pop(),
                    onAdd: _openCreateDialog,
                  ),
                ),
                const SizedBox(height: 20),
                _Staggered(
                  controller: _entranceCtrl,
                  intervalStart: 0.12,
                  intervalEnd: 0.50,
                  child: TodoSummaryCard(
                    todoCount: _todos.length,
                    topPriorityCount: _topPriorityCount,
                    imageCount: _imageCount,
                    totalBudget: _totalBudget,
                  ),
                ),
                const SizedBox(height: 20),
                _Staggered(
                  controller: _entranceCtrl,
                  intervalStart: 0.24,
                  intervalEnd: 0.72,
                  child: _buildBody(isCompact),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(bool isCompact) {
    if (_isLoading) {
      return Column(
        children: List<Widget>.generate(
          3,
          (index) => Padding(
            padding: EdgeInsets.only(bottom: index == 2 ? 0 : 16),
            child: GlassPanel(
              borderRadius: BorderRadius.circular(28),
              padding: const EdgeInsets.all(18),
              child: Column(
                children: const [
                  SkeletonLoader(child: SkeletonBox(height: 180, radius: 22)),
                  SizedBox(height: 16),
                  SkeletonLoader(
                    child: SkeletonBox(height: 18, width: 220, radius: 999),
                  ),
                  SizedBox(height: 10),
                  SkeletonLoader(
                    child: SkeletonBox(height: 12, width: 140, radius: 999),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_loadError != null) {
      return GlassPanel(
        borderRadius: BorderRadius.circular(28),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Unable to load your todo board',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _loadError!,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _HeaderButton(
                    label: 'Try again',
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    onTap: _loadTodos,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (_todos.isEmpty) {
      return GlassPanel(
        borderRadius: BorderRadius.circular(28),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: AppColors.primary.withValues(alpha: 0.12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.24),
                ),
              ),
              child: const HugeIcon(
                icon: HugeIcons.strokeRoundedTaskDaily01,
                size: 30,
                color: AppColors.primary,
                strokeWidth: 1.8,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Your todo board is empty',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start with one important task, attach a few photo references, and keep the budget in view from the beginning.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: isCompact ? double.infinity : 260,
              child: _HeaderButton(
                label: 'Add your first todo',
                icon: HugeIcons.strokeRoundedTaskAdd01,
                onTap: _openCreateDialog,
                highlighted: true,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _todos
          .map(
            (todo) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TodoItemCard(
                todo: todo,
                onEdit: () => _openEditDialog(todo),
                onDelete: () => _confirmDelete(todo),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> _openCreateDialog() async {
    final created = await showDialog<TodoItem>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.68),
      builder: (_) => TodoFormDialog(
        onSubmit:
            ({
              required String name,
              required double price,
              required TodoPriority priority,
              String? primaryImageId,
              required List<TodoUploadImage> newImages,
            }) => widget.todoService.createTodo(
              name: name,
              price: price,
              priority: priority,
              images: newImages,
            ),
      ),
    );

    if (created == null || !mounted) {
      return;
    }

    setState(() {
      _todos = _sortedTodos(<TodoItem>[created, ..._todos]);
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
        onSubmit:
            ({
              required String name,
              required double price,
              required TodoPriority priority,
              String? primaryImageId,
              required List<TodoUploadImage> newImages,
            }) => widget.todoService.updateTodo(
              todoId: todo.id,
              name: name,
              price: price,
              priority: priority,
              primaryImageId: primaryImageId,
              images: newImages,
            ),
      ),
    );

    if (updated == null || !mounted) {
      return;
    }

    setState(() {
      _todos = _sortedTodos(
        _todos
            .map((current) => current.id == updated.id ? updated : current)
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

    if (confirmed != true) {
      return;
    }

    try {
      await widget.todoService.deleteTodo(todo.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _todos = _todos
            .where((current) => current.id != todo.id)
            .toList(growable: false);
      });

      AppToast.success(
        context,
        title: 'Todo deleted',
        description: '${todo.name} was removed from your board.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

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

      if (!mounted) {
        return;
      }

      setState(() {
        _todos = _sortedTodos(todos);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = _readableError(error);
      setState(() {
        _todos = const <TodoItem>[];
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
    sorted.sort((left, right) {
      final byPriority = _priorityRank(
        left.priority,
      ).compareTo(_priorityRank(right.priority));
      if (byPriority != 0) {
        return byPriority;
      }

      return right.updatedAt.compareTo(left.updatedAt);
    });

    return sorted;
  }

  int _priorityRank(TodoPriority priority) => switch (priority) {
    TodoPriority.topPriority => 0,
    TodoPriority.priority => 1,
    TodoPriority.notPriority => 2,
  };

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

class _TodoPageHeader extends StatelessWidget {
  const _TodoPageHeader({
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
            _HeaderButton(
              label: 'Back',
              icon: HugeIcons.strokeRoundedArrowLeft01,
              onTap: onBack,
            ),
            const Spacer(),
            _HeaderButton(
              label: isCompact ? 'Add' : 'Add todo',
              icon: HugeIcons.strokeRoundedTaskAdd01,
              onTap: onAdd,
              highlighted: true,
            ),
          ],
        ),
        const SizedBox(height: 18),
        const GlassBadge(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedTaskDaily01,
                size: 15,
                color: AppColors.primary,
                strokeWidth: 1.8,
              ),
              SizedBox(width: 8),
              Text('Todo management', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Organize every planned purchase or task in one visual workspace.',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.9,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Every item stays connected to its budget and reference photos so nothing feels scattered.',
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _HeaderButton extends StatefulWidget {
  const _HeaderButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.highlighted = false,
  });

  final String label;
  final dynamic icon;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  State<_HeaderButton> createState() => _HeaderButtonState();
}

class _HeaderButtonState extends State<_HeaderButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = widget.highlighted
        ? AppColors.primary
        : AppColors.textPrimary;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: widget.highlighted
                ? AppColors.primary.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: widget.highlighted
                  ? AppColors.primary.withValues(alpha: 0.24)
                  : Colors.white.withValues(alpha: 0.14),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: widget.icon,
                size: 14,
                color: foregroundColor,
                strokeWidth: 1.8,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: foregroundColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Staggered extends StatelessWidget {
  const _Staggered({
    required this.controller,
    required this.intervalStart,
    required this.intervalEnd,
    required this.child,
  });

  final AnimationController controller;
  final double intervalStart;
  final double intervalEnd;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(
      parent: controller,
      curve: Interval(intervalStart, intervalEnd, curve: Curves.easeOut),
    );
    final slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: controller,
            curve: Interval(
              intervalStart,
              intervalEnd,
              curve: Curves.easeOutCubic,
            ),
          ),
        );

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }
}

class _TodoPageBackgroundDecoration extends Decoration {
  const _TodoPageBackgroundDecoration();

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _TodoPageBackgroundPainter();
  }
}

class _TodoPageBackgroundPainter extends BoxPainter {
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
      Offset(offset.dx + size.width * 0.15, offset.dy + size.height * 0.12),
      size.shortestSide * 0.18,
      Paint()..color = AppColors.primary.withValues(alpha: 0.08),
    );
    canvas.drawCircle(
      Offset(offset.dx + size.width * 0.84, offset.dy + size.height * 0.82),
      size.shortestSide * 0.24,
      Paint()..color = Colors.white.withValues(alpha: 0.04),
    );
  }
}
