import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../data/models/todo_item.dart';
import '../../data/models/todo_upload_image.dart';

const int _maxTodoImages = 6;

class TodoFormDialog extends StatefulWidget {
  const TodoFormDialog({super.key, required this.onSubmit, this.todo});

  final TodoItem? todo;
  final Future<TodoItem> Function({
    required String name,
    required double price,
    required TodoPriority priority,
    String? primaryImageId,
    required List<TodoUploadImage> newImages,
  })
  onSubmit;

  @override
  State<TodoFormDialog> createState() => _TodoFormDialogState();
}

class _TodoFormDialogState extends State<TodoFormDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  late TodoPriority _selectedPriority;
  String? _selectedPrimaryImageId;
  List<TodoUploadImage> _newImages = const <TodoUploadImage>[];
  bool _isSubmitting = false;
  bool _isLoadingImages = false;
  String? _errorText;

  bool get _isEditing => widget.todo != null;
  List<TodoImageItem> get _existingImages => widget.todo?.images ?? const [];

  @override
  void initState() {
    super.initState();
    final todo = widget.todo;
    _nameCtrl.text = todo?.name ?? '';
    _priceCtrl.text = todo == null ? '' : todo.price.toStringAsFixed(0);
    _selectedPriority = todo?.priority ?? TodoPriority.topPriority;
    _selectedPrimaryImageId = todo?.primaryImage?.id;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _scale = Tween<double>(begin: 0.92, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.30),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Header ────────────────────────────────────────────
                          Row(
                            children: [
                              Text(
                                _isEditing
                                    ? 'Update todo item'
                                    : 'Add todo item',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Close',
                                onPressed: _isSubmitting
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close, size: 18),
                                color: AppColors.textSecondary,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // ── Name field ────────────────────────────────────────
                          _FieldLabel(label: 'Todo name'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _nameCtrl,
                            textCapitalization: TextCapitalization.sentences,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: _inputDecoration(
                              hint: 'e.g. Renew annual car insurance',
                            ),
                            validator: (v) {
                              final t = v?.trim() ?? '';
                              if (t.isEmpty) return 'Enter a todo name.';
                              if (t.length > 120) {
                                return 'Must be under 120 characters.';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 12),

                          // ── Budget field ──────────────────────────────────────
                          _FieldLabel(label: 'Planned budget'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _priceCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: _inputDecoration(
                              hint: '85000',
                              prefixText: 'RWF ',
                            ),
                            validator: (v) {
                              final raw = v?.trim() ?? '';
                              if (raw.isEmpty) return 'Enter a budget amount.';
                              final amount = double.tryParse(raw);
                              if (amount == null) return 'Enter a valid amount.';
                              if (amount < 0) return 'Amount cannot be negative.';
                              return null;
                            },
                          ),

                          const SizedBox(height: 12),

                          // ── Priority ──────────────────────────────────────────
                          _FieldLabel(label: 'Priority'),
                          const SizedBox(height: 8),
                          Row(
                            children: TodoPriority.values.map((priority) {
                              final isLast =
                                  priority == TodoPriority.values.last;
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: isLast ? 0 : 8,
                                  ),
                                  child: _PriorityOption(
                                    priority: priority,
                                    selected: _selectedPriority == priority,
                                    onTap: () => setState(
                                      () => _selectedPriority = priority,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(growable: false),
                          ),

                          const SizedBox(height: 12),

                          // ── Photos ────────────────────────────────────────────
                          _PhotosSection(
                            existingImages: _existingImages,
                            newImages: _newImages,
                            selectedPrimaryImageId: _selectedPrimaryImageId,
                            isSubmitting: _isSubmitting,
                            isLoadingImages: _isLoadingImages,
                            isEditing: _isEditing,
                            onAddTap: _pickImages,
                            onSelectPrimary: (id) =>
                                setState(() => _selectedPrimaryImageId = id),
                            onRemoveNew: (index) {
                              setState(() {
                                _newImages =
                                    List<TodoUploadImage>.of(_newImages)
                                      ..removeAt(index);
                              });
                            },
                          ),

                          // ── Error banner ──────────────────────────────────────
                          if (_errorText != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: AppColors.danger.withValues(alpha: 0.08),
                                border: Border.all(
                                  color:
                                      AppColors.danger.withValues(alpha: 0.22),
                                ),
                              ),
                              child: Text(
                                _errorText!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  height: 1.45,
                                  color: AppColors.danger,
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 18),

                          // ── Buttons ───────────────────────────────────────────
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isSubmitting
                                      ? null
                                      : () => Navigator.of(context).pop(),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    side: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.18,
                                      ),
                                    ),
                                    shape: const StadiumBorder(),
                                  ),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isSubmitting ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: AppColors.background,
                                    disabledBackgroundColor:
                                        AppColors.primary.withValues(alpha: 0.4),
                                    shape: const StadiumBorder(),
                                    elevation: 0,
                                  ),
                                  child: _isSubmitting
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 1.8,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              AppColors.background,
                                            ),
                                          ),
                                        )
                                      : Text(
                                          _isEditing
                                              ? 'Save changes'
                                              : 'Create todo',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
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
            ),
          ),
        ),
      ),
    );
  }

  // ── Image picking ─────────────────────────────────────────────────────────

  Future<void> _pickImages() async {
    final remainingSlots =
        _maxTodoImages - _existingImages.length - _newImages.length;

    if (remainingSlots <= 0) {
      AppToast.info(
        context,
        title: 'Image limit reached',
        description: 'A todo item can keep up to $_maxTodoImages images.',
      );
      return;
    }

    try {
      // imageQuality compresses before readAsBytes — prevents OOM on large files
      final files = await _picker.pickMultiImage(imageQuality: 85);
      if (files.isEmpty || !mounted) return;

      setState(() => _isLoadingImages = true);

      final uploads = <TodoUploadImage>[];
      for (final file in files.take(remainingSlots)) {
        uploads.add(
          TodoUploadImage(
            filename: file.name,
            mimeType: _inferMimeType(file.name),
            bytes: await file.readAsBytes(),
          ),
        );
        // Yield between reads so the UI stays responsive
        await Future<void>.delayed(Duration.zero);
      }

      if (!mounted || uploads.isEmpty) return;

      setState(() {
        _newImages = <TodoUploadImage>[..._newImages, ...uploads];
        _isLoadingImages = false;
      });

      if (files.length > uploads.length) {
        AppToast.info(
          context,
          title: 'Some photos were skipped',
          description:
              'Only $remainingSlots more ${remainingSlots == 1 ? 'image fits' : 'images fit'} in this todo item.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoadingImages = false);
      AppToast.error(
        context,
        title: 'Unable to pick images',
        description: _readableError(error),
      );
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    if (!_isEditing && _newImages.isEmpty) {
      setState(() {
        _errorText = 'Add at least one image before creating a todo item.';
      });
      return;
    }

    final price = double.parse(_priceCtrl.text.trim());

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final todo = await widget.onSubmit(
        name: _nameCtrl.text.trim(),
        price: price,
        priority: _selectedPriority,
        primaryImageId: _isEditing ? _selectedPrimaryImageId : null,
        newImages: _newImages,
      );
      if (!mounted) return;
      Navigator.of(context).pop(todo);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = _readableError(error);
      });
    }
  }

  String _inferMimeType(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    return switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }

  String _readableError(Object error) {
    final msg = error.toString().trim();
    if (msg.startsWith('Exception: ')) return msg.replaceFirst('Exception: ', '');
    if (msg.startsWith('StateError: ')) return msg.replaceFirst('StateError: ', '');
    return msg;
  }
}

// ── Field label ───────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

// ── Priority option ───────────────────────────────────────────────────────────

class _PriorityOption extends StatelessWidget {
  const _PriorityOption({
    required this.priority,
    required this.selected,
    required this.onTap,
  });

  final TodoPriority priority;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(priority);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? color.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.32)
                : Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                priority.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? color : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Photos section ────────────────────────────────────────────────────────────

class _PhotosSection extends StatelessWidget {
  const _PhotosSection({
    required this.existingImages,
    required this.newImages,
    required this.selectedPrimaryImageId,
    required this.isSubmitting,
    required this.isLoadingImages,
    required this.isEditing,
    required this.onAddTap,
    required this.onSelectPrimary,
    required this.onRemoveNew,
  });

  final List<TodoImageItem> existingImages;
  final List<TodoUploadImage> newImages;
  final String? selectedPrimaryImageId;
  final bool isSubmitting;
  final bool isLoadingImages;
  final bool isEditing;
  final VoidCallback onAddTap;
  final ValueChanged<String> onSelectPrimary;
  final ValueChanged<int> onRemoveNew;

  int get _totalCount => existingImages.length + newImages.length;
  bool get _atLimit => _totalCount >= _maxTodoImages;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Label row ────────────────────────────────────────────────────────
        Row(
          children: [
            const _FieldLabel(label: 'Photos'),
            const Spacer(),
            Text(
              '$_totalCount / $_maxTodoImages selected',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // ── Container ────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white.withValues(alpha: 0.04),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Hint + add button ──────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isEditing
                          ? 'Tap an image to set it as the cover.'
                          : 'Up to $_maxTodoImages photos. First one becomes the cover.',
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _AddPhotosButton(
                    disabled: isSubmitting || _atLimit,
                    isLoading: isLoadingImages,
                    onTap: onAddTap,
                  ),
                ],
              ),

              // ── Existing images ────────────────────────────────────────────
              if (existingImages.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Current gallery',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: existingImages.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => _ExistingImageTile(
                      image: existingImages[i],
                      selected: selectedPrimaryImageId == existingImages[i].id,
                      onTap: () => onSelectPrimary(existingImages[i].id),
                    ),
                  ),
                ),
              ],

              // ── New images ─────────────────────────────────────────────────
              if (newImages.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'New uploads',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: newImages.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => _PendingImageTile(
                      bytes: newImages[i].bytes,
                      filename: newImages[i].filename,
                      onRemove: () => onRemoveNew(i),
                    ),
                  ),
                ),
              ],

              // ── Loading shimmer ────────────────────────────────────────────
              if (isLoadingImages) ...[
                const SizedBox(height: 12),
                const Text(
                  'Loading…',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 80,
                  child: Row(
                    children: List.generate(
                      3,
                      (i) => Padding(
                        padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
                        child: const SkeletonLoader(
                          child: SkeletonBox(width: 80, height: 80, radius: 12),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Add photos button ─────────────────────────────────────────────────────────

class _AddPhotosButton extends StatefulWidget {
  const _AddPhotosButton({
    required this.disabled,
    required this.isLoading,
    required this.onTap,
  });

  final bool disabled;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  State<_AddPhotosButton> createState() => _AddPhotosButtonState();
}

class _AddPhotosButtonState extends State<_AddPhotosButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final canTap = !widget.disabled && !widget.isLoading;

    return GestureDetector(
      onTapDown: canTap ? (_) => setState(() => _pressed = true) : null,
      onTapUp: canTap
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedOpacity(
          opacity: widget.disabled ? 0.45 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: AppColors.primary.withValues(alpha: 0.12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isLoading)
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.6,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary.withValues(alpha: 0.8),
                      ),
                    ),
                  )
                else
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedAdd01,
                    size: 13,
                    color: AppColors.primary,
                    strokeWidth: 1.8,
                  ),
                const SizedBox(width: 6),
                Text(
                  widget.isLoading ? 'Loading…' : 'Add photos',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Existing image tile ───────────────────────────────────────────────────────

class _ExistingImageTile extends StatelessWidget {
  const _ExistingImageTile({
    required this.image,
    required this.selected,
    required this.onTap,
  });

  final TodoImageItem image;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.10),
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
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
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.24),
                    ],
                  ),
                ),
              ),
              if (selected)
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    margin: const EdgeInsets.all(5),
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      size: 11,
                      color: Colors.black,
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

// ── Pending image tile ────────────────────────────────────────────────────────

class _PendingImageTile extends StatefulWidget {
  const _PendingImageTile({
    required this.bytes,
    required this.filename,
    required this.onRemove,
  });

  final Uint8List bytes;
  final String filename;
  final VoidCallback onRemove;

  @override
  State<_PendingImageTile> createState() => _PendingImageTileState();
}

class _PendingImageTileState extends State<_PendingImageTile> {
  bool _removePressed = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(widget.bytes, fit: BoxFit.cover),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.30),
                  ],
                ),
              ),
            ),
            // Remove button
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: widget.onRemove,
                onTapDown: (_) => setState(() => _removePressed = true),
                onTapUp: (_) => setState(() => _removePressed = false),
                onTapCancel: () => setState(() => _removePressed = false),
                child: AnimatedScale(
                  scale: _removePressed ? 0.84 : 1.0,
                  duration: const Duration(milliseconds: 110),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.danger.withValues(alpha: 0.85),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.30),
                      ),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 5,
              right: 5,
              bottom: 5,
              child: Text(
                widget.filename,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

InputDecoration _inputDecoration({String? hint, String? prefixText}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
      fontSize: 12,
      color: AppColors.textSecondary,
    ),
    prefixText: prefixText,
    prefixStyle: const TextStyle(
      fontSize: 12,
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w600,
    ),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.04),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: AppColors.primary.withValues(alpha: 0.55),
        width: 1.4,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.danger.withValues(alpha: 0.50)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
    ),
  );
}

Color _priorityColor(TodoPriority priority) => switch (priority) {
  TodoPriority.topPriority => AppColors.danger,
  TodoPriority.priority => AppColors.primary,
  TodoPriority.notPriority => AppColors.success,
};
