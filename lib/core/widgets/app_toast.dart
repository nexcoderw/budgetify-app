import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

import '../theme/app_colors.dart';

abstract final class AppToast {
  static const _textStyle = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 12,
    color: AppColors.textPrimary,
    height: 1.35,
  );

  static void success(
    BuildContext context, {
    required String title,
    String? description,
  }) {
    _show(
      context,
      type: ToastificationType.success,
      title: title,
      description: description,
    );
  }

  static void info(
    BuildContext context, {
    required String title,
    String? description,
  }) {
    _show(
      context,
      type: ToastificationType.info,
      title: title,
      description: description,
    );
  }

  static void error(
    BuildContext context, {
    required String title,
    String? description,
  }) {
    _show(
      context,
      type: ToastificationType.error,
      title: title,
      description: description,
    );
  }

  static void _show(
    BuildContext context, {
    required ToastificationType type,
    required String title,
    String? description,
  }) {
    toastification.show(
      context: context,
      type: type,
      style: ToastificationStyle.flatColored,
      alignment: Alignment.topCenter,
      autoCloseDuration: const Duration(seconds: 3),
      animationDuration: const Duration(milliseconds: 320),
      applyBlurEffect: true,
      closeButton: const ToastCloseButton(showType: CloseButtonShowType.none),
      closeOnClick: true,
      dragToClose: true,
      showProgressBar: false,
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      backgroundColor: AppColors.surfaceElevated.withValues(alpha: 0.9),
      foregroundColor: AppColors.textPrimary,
      primaryColor: _primaryColorFor(type),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.24),
          blurRadius: 30,
          offset: const Offset(0, 18),
        ),
      ],
      title: Text(
        title,
        style: _textStyle.copyWith(fontWeight: FontWeight.w700),
      ),
      description: description == null
          ? null
          : Text(description, style: _textStyle),
    );
  }

  static Color _primaryColorFor(ToastificationType type) {
    if (type == ToastificationType.success) {
      return AppColors.success;
    }

    if (type == ToastificationType.error) {
      return AppColors.danger;
    }

    return AppColors.primary;
  }
}
