import '../../../data/models/device_contact.dart';
import '../../../data/models/transaction_models.dart';

class RecipientSelection {
  const RecipientSelection({
    required this.identifier,
    required this.recipientType,
    required this.title,
    required this.subtitle,
    this.contactId,
  });

  factory RecipientSelection.fromContact(DeviceContact contact) {
    return RecipientSelection(
      identifier: contact.phoneNumber,
      recipientType: TransactionRecipientType.phone,
      title: contact.name,
      subtitle: contact.phoneNumber,
      contactId: contact.id,
    );
  }

  final String identifier;
  final TransactionRecipientType recipientType;
  final String title;
  final String subtitle;
  final String? contactId;

  String get key => '${recipientType.apiValue}:$identifier';
}

List<DeviceContact> filterRecipientContacts({
  required List<DeviceContact> contacts,
  required String query,
}) {
  final normalizedQuery = query.trim().toLowerCase();

  if (normalizedQuery.isEmpty) {
    return contacts;
  }

  final queryDigits = normalizedQuery.replaceAll(RegExp(r'\D'), '');
  final comparableQuery = comparableRecipientPhone(normalizedQuery);

  return contacts
      .where((contact) {
        final name = contact.name.toLowerCase();
        final phone = contact.phoneNumber.replaceAll(RegExp(r'\D'), '');
        final comparablePhone = comparableRecipientPhone(contact.phoneNumber);

        return name.contains(normalizedQuery) ||
            (queryDigits.isNotEmpty &&
                (phone.contains(queryDigits) ||
                    comparablePhone.contains(comparableQuery)));
      })
      .toList(growable: false);
}

RecipientSelection? resolveTypedRecipient({
  required String query,
  required List<DeviceContact> contacts,
}) {
  final value = query.trim();

  if (value.isEmpty || !RegExp(r'^[+\d\s()-]+$').hasMatch(value)) {
    return null;
  }

  final recipientType = inferTransactionRecipientType(value);

  if (!isValidTransactionRecipient(value, recipientType)) {
    return null;
  }

  if (recipientType == TransactionRecipientType.phone &&
      contacts.any(
        (contact) =>
            comparableRecipientPhone(contact.phoneNumber) ==
            comparableRecipientPhone(value),
      )) {
    return null;
  }

  final digits = value.replaceAll(RegExp(r'\D'), '');

  final transferType = inferTransactionTransferType(
    recipientIdentifier: digits,
    recipientType: recipientType,
  );

  final subtitle = switch (recipientType) {
    TransactionRecipientType.phone => '${transferType.label} phone number',
    TransactionRecipientType.bankAccount => 'eKash bank account',
    TransactionRecipientType.momoCode => 'MoMo Pay merchant code',
  };

  return RecipientSelection(
    identifier: digits,
    recipientType: recipientType,
    title: digits,
    subtitle: subtitle,
  );
}

String comparableRecipientPhone(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');

  if (digits.startsWith('250')) {
    return digits.substring(3);
  }

  if (digits.startsWith('0')) {
    return digits.substring(1);
  }

  return digits;
}
