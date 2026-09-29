import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_input.dart';

class PersonalDetailsTab extends StatelessWidget {
  const PersonalDetailsTab({
    super.key,
    required this.formKey,
    required this.firstNameController,
    required this.lastNameController,
    required this.enabled,
    required this.canSave,
    required this.isSaving,
    required this.onSave,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final bool enabled;
  final bool canSave;
  final bool isSaving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Personal details',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Update the name displayed on your Budgetify account.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            AppInput(
              controller: firstNameController,
              enabled: enabled,
              label: 'First name',
              hintText: 'Enter your first name',
              leadingIcon: HugeIcons.strokeRoundedUser02,
              textCapitalization: TextCapitalization.words,
              keyboardType: TextInputType.name,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.givenName],
              maxLength: 60,
              borderRadius: 28,
              validator: (value) => _validateName(value, 'First name'),
            ),
            const SizedBox(height: 20),
            AppInput(
              controller: lastNameController,
              enabled: enabled,
              label: 'Last name',
              hintText: 'Enter your last name',
              leadingIcon: HugeIcons.strokeRoundedUserSquare,
              textCapitalization: TextCapitalization.words,
              keyboardType: TextInputType.name,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.familyName],
              maxLength: 60,
              borderRadius: 28,
              validator: (value) => _validateName(value, 'Last name'),
              onSubmitted: (_) {
                if (canSave) {
                  onSave();
                }
              },
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: 240,
                child: AppButton(
                  label: 'Save changes',
                  icon: HugeIcons.strokeRoundedFloppyDisk,
                  size: AppButtonSize.md,
                  isLoading: isSaving,
                  onPressed: canSave ? onSave : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String? _validateName(String? value, String label) {
    final normalized = value?.trim() ?? '';

    if (normalized.isEmpty) {
      return '$label is required.';
    }

    if (normalized.length > 60) {
      return '$label must not exceed 60 characters.';
    }

    return null;
  }
}
