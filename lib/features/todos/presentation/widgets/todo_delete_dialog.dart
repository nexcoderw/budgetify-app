import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_modal_dialog.dart';

class TodoDeleteDialog extends StatefulWidget {
  const TodoDeleteDialog({
    super.key,
    required this.todoName,
    required this.imageCount,
  });

  final String todoName;
  final int imageCount;

  @override
  State<TodoDeleteDialog> createState() => _TodoDeleteDialogState();
}

class _TodoDeleteDialogState extends State<TodoDeleteDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _scale = Tween<double>(
      begin: 0.92,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppModalDialog(
      maxWidth: 420,
      padding: const EdgeInsets.all(24),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: AppColors.danger.withValues(alpha: 0.14),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.24),
                  ),
                ),
                child: const HugeIcon(
                  icon: HugeIcons.strokeRoundedDelete02,
                  size: 22,
                  color: AppColors.danger,
                  strokeWidth: 1.8,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Delete todo item?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '`${widget.todoName}` and its ${widget.imageCount} ${widget.imageCount == 1 ? 'photo' : 'photos'} will be removed from your board. This action cannot be undone.',
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _DialogButton(
                      label: 'Keep item',
                      onTap: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DialogButton(
                      label: 'Delete',
                      onTap: () => Navigator.of(context).pop(true),
                      backgroundColor: AppColors.danger.withValues(alpha: 0.12),
                      borderColor: AppColors.danger.withValues(alpha: 0.28),
                      foregroundColor: AppColors.danger,
                    ),
                  ),
                ],
              ),
            ],
          ),
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
  });

  final String label;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return AppModalActionButton(
      label: label,
      isPrimary: backgroundColor != null,
      onPressed: onTap,
      primaryColor: foregroundColor == AppColors.danger
          ? AppColors.danger
          : AppColors.primary,
      primaryForegroundColor: Colors.white,
      outlineForegroundColor: foregroundColor,
    );
  }
}
