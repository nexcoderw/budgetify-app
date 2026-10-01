const maximumManualReceivedAmount = 10_000_000;

String? validateReceivedAmount(String? value) {
  final amount = int.tryParse(value?.trim() ?? '');

  if (amount == null || amount <= 0) {
    return 'Enter a valid amount.';
  }

  if (amount > maximumManualReceivedAmount) {
    return 'Amount cannot exceed 10,000,000 RWF.';
  }

  return null;
}

String? validateReceivedSenderIdentifier(String? value) {
  final raw = value?.trim() ?? '';

  if (raw.isEmpty) {
    return null;
  }

  final compact = raw.replaceAll(RegExp(r'[\s()-]'), '');

  if (!RegExp(r'^\+?\d{3,34}$').hasMatch(compact)) {
    return 'Enter a valid sender number.';
  }

  return null;
}

String? validateReceivedProviderReference(String? value) {
  final reference = value?.trim() ?? '';

  if (reference.isEmpty) {
    return null;
  }

  if (reference.length < 3) {
    return 'Reference is too short.';
  }

  if (!RegExp(r'^[A-Za-z0-9._:/-]+$').hasMatch(reference)) {
    return 'Reference contains unsupported characters.';
  }

  return null;
}
