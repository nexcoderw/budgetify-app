import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../data/models/transaction_models.dart';

bool get supportsIosManualTransactionConfirmation {
  return !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
}

enum ManualTransactionConfirmationChoice {
  successful,
  failed,
  notSure;

  TransactionStatus? get status {
    return switch (this) {
      ManualTransactionConfirmationChoice.successful =>
        TransactionStatus.completed,
      ManualTransactionConfirmationChoice.failed => TransactionStatus.failed,
      ManualTransactionConfirmationChoice.notSure => null,
    };
  }
}

Future<ManualTransactionConfirmationChoice?>
showManualTransactionConfirmationSheet(
  BuildContext context, {
  required PaymentTransaction transaction,
}) {
  return showModalBottomSheet<ManualTransactionConfirmationChoice>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (_) =>
        _ManualTransactionConfirmationSheet(transaction: transaction),
  );
}

class _ManualTransactionConfirmationSheet extends StatefulWidget {
  const _ManualTransactionConfirmationSheet({required this.transaction});

  final PaymentTransaction transaction;

  @override
  State<_ManualTransactionConfirmationSheet> createState() =>
      _ManualTransactionConfirmationSheetState();
}

class _ManualTransactionConfirmationSheetState
    extends State<_ManualTransactionConfirmationSheet> {
  ManualTransactionConfirmationChoice? _pendingChoice;

  @override
  Widget build(BuildContext context) {
    final choice = _pendingChoice;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 620),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: choice == null
          ? _buildChoiceView()
          : _buildConfirmationView(choice),
    );
  }

  Widget _buildChoiceView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SheetHandle(),
        const SizedBox(height: 18),
        const Text(
          'Confirm payment',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Did this payment complete in MTN MoMo?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        _TransactionSummary(transaction: widget.transaction),
        const SizedBox(height: 20),
        AppButton(
          label: 'Payment successful',
          icon: HugeIcons.strokeRoundedMoneySendSquare,
          size: AppButtonSize.md,
          onPressed: () {
            setState(() {
              _pendingChoice = ManualTransactionConfirmationChoice.successful;
            });
          },
        ),
        const SizedBox(height: 10),
        AppButton(
          label: 'Payment failed',
          icon: HugeIcons.strokeRoundedTransactionHistory,
          size: AppButtonSize.md,
          variant: AppButtonVariant.secondary,
          onPressed: () {
            setState(() {
              _pendingChoice = ManualTransactionConfirmationChoice.failed;
            });
          },
        ),
        const SizedBox(height: 10),
        AppButton(
          label: 'Not sure yet',
          icon: HugeIcons.strokeRoundedTransactionHistory,
          size: AppButtonSize.md,
          variant: AppButtonVariant.ghost,
          onPressed: () {
            Navigator.of(
              context,
            ).pop(ManualTransactionConfirmationChoice.notSure);
          },
        ),
        const SizedBox(height: 12),
        Text(
          'iPhone does not allow Budgetify to automatically read your MTN confirmation SMS. Only choose a final result when you are sure.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 9,
            height: 1.45,
            color: AppColors.textSecondary.withValues(alpha: 0.76),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmationView(ManualTransactionConfirmationChoice choice) {
    final isSuccessful =
        choice == ManualTransactionConfirmationChoice.successful;

    final title = isSuccessful
        ? 'Mark payment successful?'
        : 'Mark payment failed?';

    final description = isSuccessful
        ? 'Budgetify will record this transaction as completed based on your confirmation.'
        : 'Budgetify will record this transaction as failed based on your confirmation.';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SheetHandle(),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.45,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          description,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        _TransactionSummary(transaction: widget.transaction),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Text(
            'This is a manual confirmation. It will be recorded separately from MTN-verified transaction evidence.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 18),
        AppButton(
          label: isSuccessful ? 'Confirm successful' : 'Confirm failed',
          icon: isSuccessful
              ? HugeIcons.strokeRoundedMoneySendSquare
              : HugeIcons.strokeRoundedTransactionHistory,
          size: AppButtonSize.md,
          variant: isSuccessful
              ? AppButtonVariant.primary
              : AppButtonVariant.secondary,
          onPressed: () {
            Navigator.of(context).pop(choice);
          },
        ),
        const SizedBox(height: 10),
        AppButton(
          label: 'Go back',
          icon: HugeIcons.strokeRoundedArrowLeft01,
          size: AppButtonSize.md,
          variant: AppButtonVariant.ghost,
          onPressed: () {
            setState(() {
              _pendingChoice = null;
            });
          },
        ),
      ],
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _TransactionSummary extends StatelessWidget {
  const _TransactionSummary({required this.transaction});

  final PaymentTransaction transaction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Text(
            '${_formatAmount(transaction.amount)} RWF',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            transaction.recipientDisplayName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            transaction.receiverIdentifier,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            transaction.transferType.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              color: AppColors.textSecondary.withValues(alpha: 0.74),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatAmount(int amount) {
  final value = amount.toString();

  final buffer = StringBuffer();

  for (var index = 0; index < value.length; index++) {
    final remaining = value.length - index;

    buffer.write(value[index]);

    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }

  return buffer.toString();
}
