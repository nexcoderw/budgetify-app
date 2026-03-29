import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/glass_panel.dart';
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
      duration: const Duration(milliseconds: 320),
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
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: GlassPanel(
              borderRadius: BorderRadius.circular(32),
              padding: const EdgeInsets.all(24),
              blur: 28,
              opacity: 0.15,
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header ──────────────────────────────────────────────
                      Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: AppColors.primary.withValues(alpha: 0.14),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.24),
                              ),
                            ),
                            child: Center(
                              child: HugeIcon(
                                icon: _isEditing
                                    ? HugeIcons.strokeRoundedTaskEdit01
                                    : HugeIcons.strokeRoundedTaskAdd01,
                                size: 22,
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
                                  _isEditing
                                      ? 'Update todo item'
                                      : 'Create todo item',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isEditing
                                      ? 'Refine the task, budget, priority, and photo references.'
                                      : 'Capture the task, planned cost, and visual references in one clean card.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.45,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),

                      // ── Name field ───────────────────────────────────────────
                      _LabeledField(
                        label: 'Todo name',
                        child: TextFormField(
                          controller: _nameCtrl,
                          textCapitalization: TextCapitalization.sentences,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: _inputDecoration(
                            hint: 'e.g. Renew annual car insurance',
                          ),
                          validator: (value) {
                            final trimmed = value?.trim() ?? '';
                            if (trimmed.isEmpty) return 'Enter a todo name.';
                            if (trimmed.length > 120) {
                              return 'Todo name must stay under 120 characters.';
                            }
                            return null;
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Price field ──────────────────────────────────────────
                      _LabeledField(
                        label: 'Planned budget',
                        child: TextFormField(
                          controller: _priceCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: _inputDecoration(
                            hint: '85000',
                            prefixText: 'RWF ',
                          ),
                          validator: (value) {
                            final raw = value?.trim() ?? '';
                            if (raw.isEmpty) return 'Enter a budget amount.';
                            final amount = double.tryParse(raw);
                            if (amount == null) return 'Enter a valid amount.';
                            if (amount < 0) {
                              return 'Amount cannot be negative.';
                            }
                            return null;
                          },
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ── Priority picker ──────────────────────────────────────
                      const Text(
                        'Priority',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: TodoPriority.values
                            .map(
                              (priority) => _PriorityOption(
                                priority: priority,
                                selected: _selectedPriority == priority,
                                onTap: () {
                                  setState(() => _selectedPriority = priority);
                                },
                              ),
                            )
                            .toList(growable: false),
                      ),

                      const SizedBox(height: 22),

                      // ── Photos section ───────────────────────────────────────
                      _PhotosSection(
                        existingImages: _existingImages,
                        newImages: _newImages,
                        selectedPrimaryImageId: _selectedPrimaryImageId,
                        isSubmitting: _isSubmitting,
                        isLoadingImages: _isLoadingImages,
                        isEditing: _isEditing,
                        onAddTap: _pickImages,
                        onSelectPrimary: (id) {
                          setState(() => _selectedPrimaryImageId = id);
                        },
                        onRemoveNew: (index) {
                          setState(() {
                            _newImages = List<TodoUploadImage>.of(_newImages)
                              ..removeAt(index);
                          });
                        },
                      ),

                      // ── Error banner ─────────────────────────────────────────
                      if (_errorText != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: AppColors.danger.withValues(alpha: 0.08),
                            border: Border.all(
                              color: AppColors.danger.withValues(alpha: 0.20),
                            ),
                          ),
                          child: Text(
                            _errorText!,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.45,
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // ── Action buttons ───────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: _DialogButton(
                              label: 'Cancel',
                              onTap: _isSubmitting
                                  ? null
                                  : () => Navigator.of(context).pop(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DialogButton(
                              label: _isEditing ? 'Save changes' : 'Create todo',
                              onTap: _isSubmitting ? null : _submit,
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.14),
                              borderColor:
                                  AppColors.primary.withValues(alpha: 0.26),
                              foregroundColor: AppColors.primary,
                              isLoading: _isSubmitting,
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
    );
  }

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
      final selectedFiles = files.take(remainingSlots);

      for (final file in selectedFiles) {
        uploads.add(
          TodoUploadImage(
            filename: file.name,
            mimeType: _inferMimeType(file.name),
            bytes: await file.readAsBytes(),
          ),
        );
        // Yield between reads so the UI remains responsive
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
    final parts = filename.toLowerCase().split('.');
    final extension = parts.isEmpty ? '' : parts.last;
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
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

// ── Photos section ───────────────────────────────────────────────────────────

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
        // ── Label row ──────────────────────────────────────────────────────
        Row(
          children: [
            const Text(
              'Photos',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              '$_totalCount/$_maxTodoImages selected',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Container ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row: hint + add button ───────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isEditing
                          ? 'Keep your cover image sharp and append more references when needed.'
                          : 'Pick up to $_maxTodoImages images. The first one becomes the cover.',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _AddPhotosButton(
                    disabled: isSubmitting || _atLimit,
                    isLoading: isLoadingImages,
                    onTap: onAddTap,
                  ),
                ],
              ),

              // ── Existing images ──────────────────────────────────────────
              if (existingImages.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Current gallery',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 84,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: existingImages.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final image = existingImages[index];
                      return _ExistingImageTile(
                        image: image,
                        selected: selectedPrimaryImageId == image.id,
                        onTap: () => onSelectPrimary(image.id),
                      );
                    },
                  ),
                ),
              ],

              // ── New images ───────────────────────────────────────────────
              if (newImages.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'New uploads',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 84,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: newImages.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final image = newImages[index];
                      return _PendingImageTile(
                        bytes: image.bytes,
                        filename: image.filename,
                        onRemove: () => onRemoveNew(index),
                      );
                    },
                  ),
                ),
              ],

              // ── Loading shimmer tiles ────────────────────────────────────
              if (isLoadingImages) ...[
                const SizedBox(height: 16),
                const Text(
                  'Loading…',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 84,
                  child: Row(
                    children: List.generate(
                      3,
                      (i) => Padding(
                        padding: EdgeInsets.only(right: i < 2 ? 10 : 0),
                        child: const SkeletonLoader(
                          child: SkeletonBox(
                            width: 84,
                            height: 84,
                            radius: 18,
                          ),
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

// ── Add photos button ────────────────────────────────────────────────────────

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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
                    width: 14,
                    height: 14,
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
                    size: 14,
                    color: AppColors.primary,
                    strokeWidth: 1.8,
                  ),
                const SizedBox(width: 8),
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

// ── Existing image tile ──────────────────────────────────────────────────────

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
        width: 84,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.50)
                : Colors.white.withValues(alpha: 0.10),
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
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
                      Colors.black.withValues(alpha: 0.04),
                      Colors.black.withValues(alpha: 0.28),
                    ],
                  ),
                ),
              ),
              if (selected)
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    margin: const EdgeInsets.all(6),
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      size: 12,
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

// ── Pending image tile ───────────────────────────────────────────────────────

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
      width: 84,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
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
                    Colors.black.withValues(alpha: 0.04),
                    Colors.black.withValues(alpha: 0.34),
                  ],
                ),
              ),
            ),
            // Remove button — large tap area for easy removal
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: widget.onRemove,
                onTapDown: (_) => setState(() => _removePressed = true),
                onTapUp: (_) => setState(() => _removePressed = false),
                onTapCancel: () => setState(() => _removePressed = false),
                child: AnimatedScale(
                  scale: _removePressed ? 0.85 : 1.0,
                  duration: const Duration(milliseconds: 110),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.danger.withValues(alpha: 0.82),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 6,
              right: 6,
              bottom: 6,
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

// ── Shared helpers ───────────────────────────────────────────────────────────

InputDecoration _inputDecoration({String? hint, String? prefixText}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.textSecondary),
    prefixText: prefixText,
    prefixStyle: const TextStyle(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w600,
    ),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.05),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: const BorderSide(color: AppColors.primary),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide(color: AppColors.danger.withValues(alpha: 0.55)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: const BorderSide(color: AppColors.danger),
    ),
  );
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

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

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected
              ? color.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Text(
              priority.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? color : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.foregroundColor = AppColors.textPrimary,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color foregroundColor;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: backgroundColor ?? Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: borderColor ?? Colors.white.withValues(alpha: 0.14),
          ),
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(foregroundColor),
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: foregroundColor,
                  ),
                ),
        ),
      ),
    );
  }
}

Color _priorityColor(TodoPriority priority) => switch (priority) {
  TodoPriority.topPriority => AppColors.danger,
  TodoPriority.priority => AppColors.primary,
  TodoPriority.notPriority => AppColors.success,
};
