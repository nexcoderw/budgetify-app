import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_input.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../application/shortcut_import_credential_service.dart';
import '../../data/models/shortcut_import_credential.dart';

class IphoneShortcutSetupPage extends StatefulWidget {
  const IphoneShortcutSetupPage({
    super.key,
    this.service,
    this.currentShortcutVersion = 1,
    this.shortcutInstallUrl,
  });

  final ShortcutImportCredentialService? service;
  final int currentShortcutVersion;
  final String? shortcutInstallUrl;

  @override
  State<IphoneShortcutSetupPage> createState() =>
      _IphoneShortcutSetupPageState();
}

class _IphoneShortcutSetupPageState extends State<IphoneShortcutSetupPage> {
  final _deviceNameController = TextEditingController(text: 'My iPhone');
  late final ShortcutImportCredentialService _service;

  List<ShortcutImportCredential> _credentials = const [];
  ShortcutImportCredential? _oneTimeCredential;
  bool _loading = true;
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service =
        widget.service ?? ShortcutImportCredentialService.createDefault();
    unawaited(_load());
  }

  @override
  void dispose() {
    _deviceNameController.dispose();
    _oneTimeCredential = null;
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final credentials = await _service.list();
      if (!mounted) {
        return;
      }
      setState(() {
        _credentials = credentials;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = _readableError(error);
      });
    }
  }

  Future<void> _create() async {
    final name = _deviceNameController.text.trim();
    if (name.isEmpty || _working) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _working = true);
    try {
      final created = await _service.create(name);
      if (!mounted) {
        return;
      }
      setState(() {
        _oneTimeCredential = created;
        _credentials = [created.withoutToken(), ..._credentials];
        _working = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _working = false);
      AppToast.error(
        context,
        title: 'Could not connect iPhone',
        description: _readableError(error),
      );
    }
  }

  Future<void> _rotate(ShortcutImportCredential credential) async {
    final approved = await _confirm(
      title: 'Rotate this credential?',
      detail:
          'The current Shortcut will stop importing until you replace its token.',
      action: 'Rotate',
    );
    if (approved != true || !mounted) {
      return;
    }
    setState(() => _working = true);
    try {
      final replacement = await _service.rotate(credential.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _oneTimeCredential = replacement;
        _credentials = [
          replacement.withoutToken(),
          for (final item in _credentials)
            if (item.id != credential.id) item,
        ];
        _working = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _working = false);
      AppToast.error(
        context,
        title: 'Could not rotate credential',
        description: _readableError(error),
      );
    }
  }

  Future<void> _revoke(ShortcutImportCredential credential) async {
    final approved = await _confirm(
      title: 'Disconnect ${credential.deviceName}?',
      detail: 'Its Shortcut will immediately stop importing new messages.',
      action: 'Disconnect',
      destructive: true,
    );
    if (approved != true || !mounted) {
      return;
    }
    setState(() => _working = true);
    try {
      await _service.revoke(credential.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _credentials = _credentials
            .where((item) => item.id != credential.id)
            .toList(growable: false);
        _working = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _working = false);
      AppToast.error(
        context,
        title: 'Could not disconnect iPhone',
        description: _readableError(error),
      );
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String detail,
    required String action,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title),
        content: Text(detail),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              action,
              style: TextStyle(
                color: destructive ? AppColors.danger : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) {
      return;
    }
    AppToast.success(
      context,
      title: '$label copied',
      description: 'Paste it into the Shortcut, then clear your clipboard.',
    );
  }

  void _finishSecretStep() {
    setState(() => _oneTimeCredential = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _SetupTopBar(onBack: () => Navigator.of(context).pop()),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? _SetupError(
                      message: _error!,
                      onRetry: () => unawaited(_load()),
                    )
                  : ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        18,
                        8,
                        18,
                        28 + MediaQuery.viewInsetsOf(context).bottom,
                      ),
                      children: [
                        const _SetupIntro(),
                        const SizedBox(height: 14),
                        _ShortcutReleaseCard(
                          version: widget.currentShortcutVersion,
                          installUrl: widget.shortcutInstallUrl,
                          onCopy: _copy,
                        ),
                        const SizedBox(height: 22),
                        if (_oneTimeCredential == null)
                          _ConnectStep(
                            controller: _deviceNameController,
                            isWorking: _working,
                            onCreate: () => unawaited(_create()),
                          )
                        else
                          _CredentialStep(
                            credential: _oneTimeCredential!,
                            endpoint: _service.importEndpoint,
                            onCopy: _copy,
                            onDone: _finishSecretStep,
                          ),
                        const SizedBox(height: 26),
                        _AutomationInstructions(
                          shortcutVersion: widget.currentShortcutVersion,
                        ),
                        const SizedBox(height: 26),
                        _CredentialList(
                          credentials: _credentials,
                          disabled: _working,
                          onRotate: (item) => unawaited(_rotate(item)),
                          onRevoke: (item) => unawaited(_revoke(item)),
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

class _SetupTopBar extends StatelessWidget {
  const _SetupTopBar({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 10, 18, 14),
    child: Row(
      children: [
        IconButton.filledTonal(
          tooltip: 'Back',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'iPhone message import',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ),
        const Icon(Icons.lock_outline_rounded, size: 19),
      ],
    ),
  );
}

class _SetupIntro extends StatelessWidget {
  const _SetupIntro();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Turn payment messages into records you approve.',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
      ),
      SizedBox(height: 8),
      Text(
        'Setup takes about three minutes. Imports stay pending until you review them.',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          height: 1.5,
        ),
      ),
    ],
  );
}

class _ShortcutReleaseCard extends StatelessWidget {
  const _ShortcutReleaseCard({
    required this.version,
    required this.installUrl,
    required this.onCopy,
  });

  final int version;
  final String? installUrl;
  final Future<void> Function(String value, String label) onCopy;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.bolt_rounded,
            size: 19,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Budgetify Shortcut v$version',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                installUrl == null
                    ? 'Use this version in the request payload.'
                    : 'The reviewed installation link is available.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (installUrl != null)
          TextButton(
            onPressed: () => unawaited(onCopy(installUrl!, 'Shortcut link')),
            child: const Text('Copy link'),
          ),
      ],
    ),
  );
}

class _ConnectStep extends StatelessWidget {
  const _ConnectStep({
    required this.controller,
    required this.isWorking,
    required this.onCreate,
  });

  final TextEditingController controller;
  final bool isWorking;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => _StepFrame(
    number: '1',
    title: 'Connect this iPhone',
    child: Column(
      children: [
        AppInput(
          controller: controller,
          label: 'Device name',
          hintText: 'My iPhone',
          enabled: !isWorking,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onCreate(),
        ),
        const SizedBox(height: 14),
        AppButton(
          label: 'Create secure credential',
          icon: HugeIcons.strokeRoundedCircleLockCheck02,
          isLoading: isWorking,
          onPressed: isWorking ? null : onCreate,
        ),
      ],
    ),
  );
}

class _CredentialStep extends StatelessWidget {
  const _CredentialStep({
    required this.credential,
    required this.endpoint,
    required this.onCopy,
    required this.onDone,
  });

  final ShortcutImportCredential credential;
  final String endpoint;
  final Future<void> Function(String value, String label) onCopy;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => _StepFrame(
    number: '2',
    title: 'Copy the one-time values',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'This token cannot be displayed again. Budgetify does not save it on this phone.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 14),
        _CopyValue(
          label: 'Authorization token',
          value: credential.token!,
          obscure: true,
          onCopy: () => unawaited(onCopy(credential.token!, 'Token')),
        ),
        const SizedBox(height: 10),
        _CopyValue(
          label: 'Request URL',
          value: endpoint,
          onCopy: () => unawaited(onCopy(endpoint, 'Request URL')),
        ),
        const SizedBox(height: 14),
        TextButton(onPressed: onDone, child: const Text('I saved both values')),
      ],
    ),
  );
}

class _CopyValue extends StatefulWidget {
  const _CopyValue({
    required this.label,
    required this.value,
    required this.onCopy,
    this.obscure = false,
  });

  final String label;
  final String value;
  final VoidCallback onCopy;
  final bool obscure;

  @override
  State<_CopyValue> createState() => _CopyValueState();
}

class _CopyValueState extends State<_CopyValue> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final hidden = widget.obscure && !_revealed;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hidden ? '••••••••••••••••••••' : widget.value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, height: 1.35),
                ),
              ],
            ),
          ),
          if (widget.obscure)
            IconButton(
              tooltip: hidden ? 'Show token' : 'Hide token',
              onPressed: () => setState(() => _revealed = !_revealed),
              icon: Icon(
                hidden
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 19,
              ),
            ),
          IconButton(
            tooltip: 'Copy ${widget.label}',
            onPressed: widget.onCopy,
            icon: const Icon(Icons.copy_rounded, size: 19),
          ),
        ],
      ),
    );
  }
}

class _AutomationInstructions extends StatelessWidget {
  const _AutomationInstructions({required this.shortcutVersion});

  final int shortcutVersion;

  @override
  Widget build(BuildContext context) => _StepFrame(
    number: '3',
    title: 'Create the Messages automation',
    child: Column(
      children: [
        const _Instruction(
          title: 'Open Shortcuts → Automation',
          detail:
              'Create a personal automation for Message and choose Run Immediately.',
        ),
        const _Instruction(
          title: 'Choose your payment senders',
          detail:
              'Add MoMo or bank senders. Create another automation when a sender needs different matching rules.',
        ),
        const _Instruction(
          title: 'Send JSON to the copied URL',
          detail:
              'Use Get Contents of URL with POST, the token as a Bearer Authorization header, and the message fields shown below.',
        ),
        const _Instruction(
          title: 'Run one real notification',
          detail:
              'Return to Message review. The import should appear as pending and will not affect totals until confirmed.',
          isLast: true,
        ),
        const SizedBox(height: 16),
        _PayloadGuide(shortcutVersion: shortcutVersion),
      ],
    ),
  );
}

class _PayloadGuide extends StatelessWidget {
  const _PayloadGuide({required this.shortcutVersion});

  final int shortcutVersion;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.backgroundSecondary,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Request configuration',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 9),
        const _PayloadLine(label: 'Method', value: 'POST'),
        const _PayloadLine(label: 'Request body', value: 'JSON'),
        const _PayloadLine(
          label: 'Header',
          value: 'Authorization: Bearer [token]',
        ),
        const _PayloadLine(label: 'clientEventId', value: 'Generate UUID'),
        _PayloadLine(label: 'shortcutVersion', value: '$shortcutVersion'),
        const _PayloadLine(
          label: 'sourceHint',
          value: 'OTHER_PAYMENT_NOTIFICATION',
        ),
        const _PayloadLine(
          label: 'messageSender',
          value: 'Shortcut Input sender',
        ),
        const _PayloadLine(label: 'message', value: 'Shortcut Input content'),
        const _PayloadLine(
          label: 'messageReceivedAt',
          value: 'Current Date formatted as ISO 8601',
          isLast: true,
        ),
      ],
    ),
  );
}

class _PayloadLine extends StatelessWidget {
  const _PayloadLine({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: isLast ? 0 : 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 10, height: 1.35),
          ),
        ),
      ],
    ),
  );
}

class _Instruction extends StatelessWidget {
  const _Instruction({
    required this.title,
    required this.detail,
    this.isLast = false,
  });

  final String title;
  final String detail;
  final bool isLast;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 5),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CredentialList extends StatelessWidget {
  const _CredentialList({
    required this.credentials,
    required this.disabled,
    required this.onRotate,
    required this.onRevoke,
  });

  final List<ShortcutImportCredential> credentials;
  final bool disabled;
  final ValueChanged<ShortcutImportCredential> onRotate;
  final ValueChanged<ShortcutImportCredential> onRevoke;

  @override
  Widget build(BuildContext context) {
    if (credentials.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Connected iPhones',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        for (final credential in credentials)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone_iphone_rounded, size: 21),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          credential.deviceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          credential.lastUsedAt == null
                              ? '${credential.status.label} · Not used yet'
                              : '${credential.status.label} · Used ${_shortDate(credential.lastUsedAt!)}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    enabled: !disabled && credential.isActive,
                    color: AppColors.surfaceElevated,
                    onSelected: (value) {
                      if (value == 'rotate') {
                        onRotate(credential);
                      } else {
                        onRevoke(credential);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'rotate',
                        child: Text('Rotate token'),
                      ),
                      PopupMenuItem(value: 'revoke', child: Text('Disconnect')),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StepFrame extends StatelessWidget {
  const _StepFrame({
    required this.number,
    required this.title,
    required this.child,
  });

  final String number;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                number,
                style: const TextStyle(
                  color: AppColors.background,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}

class _SetupError extends StatelessWidget {
  const _SetupError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 32),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

String _shortDate(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

String _readableError(Object error) {
  if (error is ApiException) {
    return error.message;
  }
  return 'Please check your connection and try again.';
}
