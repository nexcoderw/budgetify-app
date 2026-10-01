import 'package:flutter/material.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../application/auth_service_contract.dart';
import '../auth_readable_error.dart';
import '../widgets/auth_layout.dart';
import '../widgets/password/password_setup_form.dart';
import 'login_page.dart';

class PasswordSetupPage extends StatefulWidget {
  const PasswordSetupPage({
    super.key,
    required this.authService,
    required this.grantToken,
    required this.isRecovery,
  });

  final AuthServiceContract authService;
  final String grantToken;
  final bool isRecovery;

  @override
  State<PasswordSetupPage> createState() => _PasswordSetupPageState();
}

class _PasswordSetupPageState extends State<PasswordSetupPage> {
  bool _isSaving = false;

  Future<void> _savePassword(String password, String confirmPassword) async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.authService.setPassword(
        grantToken: widget.grantToken,
        password: password,
        confirmPassword: confirmPassword,
      );

      if (!mounted) {
        return;
      }

      AppToast.success(
        context,
        title: widget.isRecovery ? 'Password updated' : 'Password created',
        description: 'Sign in with your email and new password.',
      );

      Navigator.of(context).pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(
          builder: (_) {
            return LoginPage(authService: widget.authService);
          },
        ),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(
        context,
        title: 'Could not save password',
        description: readableAuthError(error),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      child: PasswordSetupForm(
        isRecovery: widget.isRecovery,
        isSaving: _isSaving,
        onSubmit: _savePassword,
      ),
    );
  }
}
