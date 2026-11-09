import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dropdown.dart';
import '../../../../core/widgets/app_input.dart';
import '../../../../core/widgets/app_modal_dialog.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../application/shortcut_import_credential_service.dart';
import '../../data/models/shortcut_import_credential.dart';
import '../widgets/shortcut_setup_illustration.dart';

enum _ShortcutPilotProvider {
  mtnMomo(
    label: 'MTN MoMo',
    sourceHint: 'MTN_MOMO',
    shortcutName: 'Budgetify MTN Import v1',
  ),
  airtelMoney(
    label: 'Airtel Money',
    sourceHint: 'AIRTEL_MONEY',
    shortcutName: 'Budgetify Airtel Import v1',
  );

  const _ShortcutPilotProvider({
    required this.label,
    required this.sourceHint,
    required this.shortcutName,
  });

  final String label;
  final String sourceHint;
  final String shortcutName;
}

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
  final _scrollController = ScrollController();
  late final ShortcutImportCredentialService _service;

  List<ShortcutImportCredential> _credentials = const [];
  ShortcutImportCredential? _oneTimeCredential;
  bool _loading = true;
  bool _working = false;
  int _setupStep = 0;
  String? _error;
  _ShortcutPilotProvider _provider = _ShortcutPilotProvider.mtnMomo;

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
    _scrollController.dispose();
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
      title: 'Replace the connection key?',
      detail:
          'Your Shortcut will stop sending messages until you paste in the new key.',
      action: 'Replace key',
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
        _setupStep = 1;
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
        title: 'Could not replace connection key',
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
        if (_oneTimeCredential?.id == credential.id) {
          _oneTimeCredential = null;
          _setupStep = 1;
        }
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
      barrierDismissible: false,
      builder: (dialogContext) => AppModalDialog(
        maxWidth: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (destructive ? AppColors.danger : AppColors.primary)
                        .withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    destructive
                        ? Icons.link_off_rounded
                        : Icons.sync_lock_rounded,
                    size: 21,
                    color: destructive ? AppColors.danger : AppColors.primary,
                  ),
                ),
                const Spacer(),
                AppModalCloseButton(
                  onTap: () => Navigator.of(dialogContext).pop(false),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 21,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              detail,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: AppModalActionButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppModalActionButton(
                    label: action,
                    isPrimary: true,
                    primaryColor: destructive
                        ? AppColors.danger
                        : AppColors.primary,
                    primaryForegroundColor: AppColors.textPrimary,
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
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

  void _goToStep(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _setupStep = step);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  Widget _buildSetupStep() {
    switch (_setupStep) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDropdown<_ShortcutPilotProvider>(
              tooltip: 'Choose your payment provider',
              label: _provider.label,
              onSelected: (provider) => setState(() => _provider = provider),
              items: [
                for (final provider in _ShortcutPilotProvider.values)
                  AppDropdownItem(
                    value: provider,
                    label: provider.label,
                    selected: provider == _provider,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _ShortcutReleaseCard(
              version: widget.currentShortcutVersion,
              installUrl: widget.shortcutInstallUrl,
              onCopy: _copy,
            ),
            const SizedBox(height: 16),
            AppButton(
              label: widget.shortcutInstallUrl == null
                  ? 'Continue with manual setup'
                  : 'I added the Shortcut',
              icon: HugeIcons.strokeRoundedArrowRight01,
              onPressed: () => _goToStep(1),
            ),
          ],
        );
      case 1:
        if (_oneTimeCredential == null) {
          return _ConnectStep(
            controller: _deviceNameController,
            isWorking: _working,
            onCreate: () => unawaited(_create()),
          );
        }
        return _CredentialStep(
          credential: _oneTimeCredential!,
          endpoint: _service.importEndpoint,
          manualGuide: _ManualShortcutGuide(
            shortcutVersion: widget.currentShortcutVersion,
            provider: _provider,
            initiallyExpanded: widget.shortcutInstallUrl == null,
          ),
          onCopy: _copy,
          onDone: () => _goToStep(2),
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AutomationInstructions(provider: _provider),
            const SizedBox(height: 16),
            AppButton(
              label: 'I saved the automation',
              icon: HugeIcons.strokeRoundedArrowRight01,
              onPressed: () => _goToStep(3),
            ),
          ],
        );
      default:
        return _StepFrame(
          number: '4',
          title: 'Check your first message',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'When your next payment message arrives, return to Payment messages. '
                'Open it, check the amount and person, then confirm or dismiss it. '
                'Nothing is added to your records until you confirm.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Back to payment messages',
                icon: HugeIcons.strokeRoundedArrowRight01,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                _SetupTopBar(onBack: () => Navigator.of(context).pop()),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: AppColors.primary,
                          ),
                        )
                      : _error != null
                      ? _SetupError(
                          message: _error!,
                          onRetry: () => unawaited(_load()),
                        )
                      : ListView(
                          controller: _scrollController,
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
                            const SizedBox(height: 18),
                            Semantics(
                              label: 'Setup step ${_setupStep + 1} of 4',
                              child: Column(
                                children: [
                                  LinearProgressIndicator(
                                    value: (_setupStep + 1) / 4,
                                    color: AppColors.primary,
                                    backgroundColor: AppColors.surfaceElevated,
                                  ),
                                  const SizedBox(height: 10),
                                  Text('Step ${_setupStep + 1} of 4'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            ShortcutSetupIllustration(
                              stage: _setupStep,
                              provider: _provider.label,
                            ),
                            const SizedBox(height: 18),
                            AnimatedSwitcher(
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 240),
                              child: KeyedSubtree(
                                key: ValueKey(_setupStep),
                                child: _buildSetupStep(),
                              ),
                            ),
                            if (_setupStep > 0 && !_working)
                              TextButton(
                                onPressed: () => _goToStep(_setupStep - 1),
                                child: const Text('Previous step'),
                              ),
                            const SizedBox(height: 22),
                            if (_credentials.isNotEmpty)
                              ExpansionTile(
                                title: const Text(
                                  'Manage connected iPhones',
                                  style: TextStyle(fontSize: 14),
                                ),
                                children: [
                                  _CredentialList(
                                    credentials: _credentials,
                                    disabled: _working,
                                    onRotate: (item) => unawaited(_rotate(item)),
                                    onRevoke: (item) => unawaited(_revoke(item)),
                                  ),
                                ],
                              ),
                          ],
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

class _SetupTopBar extends StatelessWidget {
  const _SetupTopBar({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
    child: Row(
      children: [
        AppBackButton(onBack: onBack),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Connect your iPhone',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: AppColors.surfaceElevated,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.lock_outline_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}

class _SetupIntro extends StatelessWidget {
  const _SetupIntro();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.all(Radius.circular(999)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          child: Text(
            'You stay in control',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      SizedBox(height: 14),
      Text(
        'Let’s connect your payment messages',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
      ),
      SizedBox(height: 8),
      Text(
        'Follow one step at a time. You decide which messages become records.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
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
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
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
                '1. Add Budgetify Shortcut v$version',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                installUrl == null
                    ? 'No install link is available yet. Continue to build it manually in Apple Shortcuts; the next steps include the settings.'
                    : 'Copy the link, paste it into Safari, then tap Add Shortcut. Return here when done.',
                style: const TextStyle(
                  fontSize: 12,
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
    number: '2',
    title: 'Name your iPhone',
    child: Column(
      children: [
        AppInput(
          controller: controller,
          label: 'Device name',
          hintText: 'My iPhone',
          borderRadius: 28,
          enabled: !isWorking,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onCreate(),
        ),
        const SizedBox(height: 14),
        AppButton(
          label: 'Connect this iPhone',
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
    required this.manualGuide,
    required this.onCopy,
    required this.onDone,
  });

  final ShortcutImportCredential credential;
  final String endpoint;
  final Widget manualGuide;
  final Future<void> Function(String value, String label) onCopy;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => _StepFrame(
    number: '2',
    title: 'Add your connection details',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Keep this page open while you switch to Shortcuts. Copy the key and address into your Budgetify Shortcut. The key is shown only during this setup; keep it private.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 14),
        _CopyValue(
          label: 'Private connection key',
          value: credential.token!,
          obscure: true,
          onCopy: () => unawaited(onCopy(credential.token!, 'Connection key')),
        ),
        const SizedBox(height: 10),
        _CopyValue(
          label: 'Import address',
          value: endpoint,
          onCopy: () => unawaited(onCopy(endpoint, 'Import address')),
        ),
        const SizedBox(height: 14),
        manualGuide,
        const SizedBox(height: 14),
        AppButton(
          label: 'I pasted the connection details',
          icon: HugeIcons.strokeRoundedArrowRight01,
          onPressed: onDone,
        ),
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
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _CopyValue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hidden = widget.obscure && !_revealed;
    return AppInput(
      controller: _controller,
      label: widget.label,
      readOnly: true,
      obscureText: hidden,
      borderRadius: 24,
      suffixIcon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.obscure)
            IconButton(
              tooltip: hidden ? 'Show connection key' : 'Hide connection key',
              onPressed: () => setState(() => _revealed = !_revealed),
              icon: Icon(
                hidden
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ),
          IconButton(
            tooltip: 'Copy ${widget.label}',
            onPressed: widget.onCopy,
            icon: const Icon(
              Icons.copy_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AutomationInstructions extends StatelessWidget {
  const _AutomationInstructions({
    required this.provider,
  });

  final _ShortcutPilotProvider provider;

  @override
  Widget build(BuildContext context) => _StepFrame(
    number: '3',
    title: 'Choose which messages to send',
    child: Column(
      children: [
        Text(
          'For ${provider.label}',
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        const _Instruction(
          title: 'Open Apple Shortcuts',
          detail:
              'Find Automation and add a Message trigger. Depending on your iOS version, this is in the Automation tab or in the Shortcut editor.',
        ),
        _Instruction(
          title: 'Choose only your ${provider.label} sender',
          detail:
              'Use the sender shown on a genuine payment SMS in Messages. Do not select all senders, so personal messages stay out of Budgetify.',
        ),
        _Instruction(
          title: 'Run your Budgetify Shortcut',
          detail:
              'Choose ${provider.shortcutName} and pass the received Message as its input. Choose the option to run automatically without asking each time, if available.',
          isLast: true,
        ),
      ],
    ),
  );
}

class _ManualShortcutGuide extends StatelessWidget {
  const _ManualShortcutGuide({
    required this.shortcutVersion,
    required this.provider,
    required this.initiallyExpanded,
  });

  final int shortcutVersion;
  final _ShortcutPilotProvider provider;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    initiallyExpanded: initiallyExpanded,
    tilePadding: EdgeInsets.zero,
    title: const Text(
      'Building the Shortcut manually?',
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    ),
    subtitle: const Text(
      'Show the actions and connection settings',
      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
    ),
    children: [
      _Instruction(
        title: 'Create ${provider.shortcutName}',
        detail:
            'In Shortcuts, create a shortcut with this name. Add Generate UUID, Current Date, and Format Date set to ISO 8601. These supply the unique ID and date below.',
      ),
      const _Instruction(
        title: 'Add Get Contents of URL',
        detail:
            'Paste your import address. Choose POST, add the Authorization header with Bearer followed by a space and your private key, then add the JSON fields below. Use the received Message input for the sender and message text, not fixed example text.',
        isLast: true,
      ),
      const SizedBox(height: 12),
      _PayloadGuide(shortcutVersion: shortcutVersion, provider: provider),
    ],
  );
}

class _PayloadGuide extends StatelessWidget {
  const _PayloadGuide({required this.shortcutVersion, required this.provider});

  final int shortcutVersion;
  final _ShortcutPilotProvider provider;

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
        _PayloadLine(label: 'sourceHint', value: provider.sourceHint),
        const _PayloadLine(
          label: 'messageSender',
          value: 'Sender from Message input',
        ),
        const _PayloadLine(
          label: 'message',
          value: 'Content from Message input',
        ),
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
                  AppDropdown<String>(
                    tooltip: 'Manage iPhone connection',
                    icon: Icons.more_horiz_rounded,
                    enabled: !disabled && credential.isActive,
                    onSelected: (value) {
                      if (value == 'rotate') {
                        onRotate(credential);
                      } else {
                        onRevoke(credential);
                      }
                    },
                    items: const [
                      AppDropdownItem(
                        value: 'rotate',
                        label: 'Replace connection key',
                        icon: Icons.sync_lock_rounded,
                      ),
                      AppDropdownItem(
                        value: 'revoke',
                        label: 'Disconnect',
                        icon: Icons.link_off_rounded,
                      ),
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
      borderRadius: BorderRadius.circular(28),
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
