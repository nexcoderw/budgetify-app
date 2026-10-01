import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_input.dart';

class RecordReceivedMoneyForm extends StatelessWidget {
  const RecordReceivedMoneyForm({
    super.key,
    required this.formKey,
    required this.amountController,
    required this.senderNameController,
    required this.senderIdentifierController,
    required this.providerReferenceController,
    required this.receivedDateController,
    required this.compact,
    required this.isSaving,
    required this.senderError,
    required this.amountValidator,
    required this.senderIdentifierValidator,
    required this.providerReferenceValidator,
    required this.onSenderChanged,
    required this.onChooseReceivedDate,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;

  final TextEditingController amountController;
  final TextEditingController senderNameController;
  final TextEditingController senderIdentifierController;
  final TextEditingController providerReferenceController;
  final TextEditingController receivedDateController;

  final bool compact;
  final bool isSaving;

  final String? senderError;

  final FormFieldValidator<String> amountValidator;
  final FormFieldValidator<String> senderIdentifierValidator;
  final FormFieldValidator<String> providerReferenceValidator;

  final VoidCallback onSenderChanged;
  final VoidCallback onChooseReceivedDate;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(compact ? 2 : 10, 0, compact ? 2 : 10, 12),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Record received money',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: compact ? 24 : 26,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.7,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add a payment you received manually.',
              style: TextStyle(
                fontSize: 12,
                height: 1.55,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 28),
            _AmountField(
              controller: amountController,
              validator: amountValidator,
            ),
            const SizedBox(height: 12),
            _SenderFields(
              nameController: senderNameController,
              identifierController: senderIdentifierController,
              senderError: senderError,
              identifierValidator: senderIdentifierValidator,
              onChanged: onSenderChanged,
            ),
            const SizedBox(height: 12),
            _ProviderReferenceField(
              controller: providerReferenceController,
              validator: providerReferenceValidator,
            ),
            const SizedBox(height: 12),
            _ReceivedDateField(
              controller: receivedDateController,
              isSaving: isSaving,
              onTap: onChooseReceivedDate,
            ),
            const SizedBox(height: 18),
            const _ManualEvidenceNotice(),
            const SizedBox(height: 26),
            AppButton(
              label: 'Save received money',
              icon: HugeIcons.strokeRoundedMoneyReceiveCircle,
              size: AppButtonSize.lg,
              isLoading: isSaving,
              onPressed: isSaving ? null : onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({required this.controller, required this.validator});

  final TextEditingController controller;

  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return AppInput(
      controller: controller,
      hintText: 'Amount received',
      leadingIcon: HugeIcons.strokeRoundedMoneyReceiveCircle,
      borderRadius: 28,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: validator,
      suffixIcon: const Padding(
        padding: EdgeInsets.only(right: 18),
        child: Center(
          widthFactor: 1,
          child: Text(
            'RWF',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SenderFields extends StatelessWidget {
  const _SenderFields({
    required this.nameController,
    required this.identifierController,
    required this.senderError,
    required this.identifierValidator,
    required this.onChanged,
  });

  final TextEditingController nameController;
  final TextEditingController identifierController;

  final String? senderError;

  final FormFieldValidator<String> identifierValidator;

  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppInput(
          controller: nameController,
          hintText: 'Sender name',
          borderRadius: 28,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          maxLength: 120,
          onChanged: (_) {
            onChanged();
          },
        ),
        const SizedBox(height: 12),
        AppInput(
          controller: identifierController,
          hintText: 'Sender phone number',
          borderRadius: 28,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s()-]')),
          ],
          maxLength: 35,
          validator: identifierValidator,
          onChanged: (_) {
            onChanged();
          },
        ),
        if (senderError != null) ...[
          const SizedBox(height: 7),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                senderError!,
                style: const TextStyle(fontSize: 11, color: AppColors.danger),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ProviderReferenceField extends StatelessWidget {
  const _ProviderReferenceField({
    required this.controller,
    required this.validator,
  });

  final TextEditingController controller;

  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return AppInput(
      controller: controller,
      hintText: 'Transaction reference (optional)',
      leadingIcon: HugeIcons.strokeRoundedTransactionHistory,
      borderRadius: 28,
      textInputAction: TextInputAction.next,
      maxLength: 128,
      validator: validator,
    );
  }
}

class _ReceivedDateField extends StatelessWidget {
  const _ReceivedDateField({
    required this.controller,
    required this.isSaving,
    required this.onTap,
  });

  final TextEditingController controller;

  final bool isSaving;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppInput(
      controller: controller,
      hintText: 'Received date',
      leadingIcon: HugeIcons.strokeRoundedTransactionHistory,
      borderRadius: 28,
      readOnly: true,
      onTap: isSaving ? null : onTap,
      suffixIcon: Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Center(
          widthFactor: 1,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ManualEvidenceNotice extends StatelessWidget {
  const _ManualEvidenceNotice();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedTransactionHistory,
            size: 15,
            strokeWidth: 1.7,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            'This entry is manually reported and is not '
            'an independent MTN confirmation.',
            style: TextStyle(
              fontSize: 10,
              height: 1.5,
              color: AppColors.textSecondary.withValues(alpha: 0.82),
            ),
          ),
        ),
      ],
    );
  }
}
