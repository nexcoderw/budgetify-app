import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/app_colors.dart';

/// Visual treatments supported by [AppInput].
enum AppInputVariant { standard, bare }

/// Budgetify's shared text input.
///
/// Use [AppInputVariant.standard] for visible form fields and
/// [AppInputVariant.bare] when another widget owns the field presentation.
class AppInput extends StatefulWidget {
  const AppInput({
    super.key,
    required this.controller,
    this.focusNode,
    this.label,
    this.hintText,
    this.leadingIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.inputFormatters,
    this.enabled = true,
    this.enableSuggestions = true,
    this.autocorrect = true,
    this.obscureText = false,
    this.readOnly = false,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.variant = AppInputVariant.standard,
    this.borderRadius = 22,
    this.textStyle,
  });

  final TextEditingController controller;

  final FocusNode? focusNode;

  final String? label;

  final String? hintText;

  final List<List<dynamic>>? leadingIcon;

  final Widget? suffixIcon;

  final FormFieldValidator<String>? validator;

  final ValueChanged<String>? onChanged;

  final ValueChanged<String>? onSubmitted;

  final VoidCallback? onTap;

  final TextInputType? keyboardType;

  final TextInputAction? textInputAction;

  final TextCapitalization textCapitalization;

  final Iterable<String>? autofillHints;

  final List<TextInputFormatter>? inputFormatters;

  final bool enabled;

  final bool enableSuggestions;

  final bool autocorrect;

  final bool obscureText;

  final bool readOnly;

  final int? maxLength;

  final int maxLines;

  final int? minLines;

  final AppInputVariant variant;

  final double borderRadius;

  final TextStyle? textStyle;

  @override
  State<AppInput> createState() => _AppInputState();
}

class _AppInputState extends State<AppInput> {
  FocusNode? _internalFocusNode;

  FocusNode get _focusNode {
    return widget.focusNode ?? (_internalFocusNode ??= FocusNode());
  }

  bool get _isFocused => _focusNode.hasFocus;

  @override
  void initState() {
    super.initState();

    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant AppInput oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.focusNode == widget.focusNode) {
      return;
    }

    (oldWidget.focusNode ?? _internalFocusNode)?.removeListener(
      _handleFocusChange,
    );

    if (widget.focusNode != null) {
      _internalFocusNode?.dispose();

      _internalFocusNode = null;
    }

    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);

    _internalFocusNode?.dispose();

    super.dispose();
  }

  void _handleFocusChange() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.variant == AppInputVariant.bare) {
      return _buildField(
        const InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          counterText: '',
        ),
      );
    }

    final radius = BorderRadius.circular(widget.borderRadius);

    final border = OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: AppColors.border),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 190),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.17),
                  blurRadius: 17,
                ),
              ]
            : null,
      ),
      child: _buildField(
        InputDecoration(
          labelText: widget.label,
          hintText: widget.hintText,
          labelStyle: TextStyle(
            color: _isFocused ? AppColors.primary : AppColors.textSecondary,
            fontSize: 13,
          ),
          hintStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
          prefixIcon: widget.leadingIcon == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(left: 18, right: 12),
                  child: HugeIcon(
                    icon: widget.leadingIcon!,
                    size: 18,
                    color: _isFocused
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    strokeWidth: 1.8,
                  ),
                ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          suffixIcon: widget.suffixIcon,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          filled: true,
          fillColor: AppColors.surfaceElevated,
          border: border,
          enabledBorder: border,
          disabledBorder: border.copyWith(
            borderSide: BorderSide(
              color: AppColors.border.withValues(alpha: 0.6),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
          ),
          errorStyle: const TextStyle(color: AppColors.danger, fontSize: 11),
          counterText: '',
        ),
      ),
    );
  }

  Widget _buildField(InputDecoration decoration) {
    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      onTap: widget.onTap,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      autofillHints: widget.autofillHints,
      inputFormatters: widget.inputFormatters,
      enabled: widget.enabled,
      enableSuggestions: widget.enableSuggestions,
      autocorrect: widget.autocorrect,
      obscureText: widget.obscureText,
      readOnly: widget.readOnly,
      maxLength: widget.maxLength,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      style:
          widget.textStyle ??
          const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
      decoration: decoration,
    );
  }
}
