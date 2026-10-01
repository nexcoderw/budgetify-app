import 'package:flutter_test/flutter_test.dart';

import 'package:budgetify/features/home/data/models/device_contact.dart';
import 'package:budgetify/features/home/data/models/transaction_models.dart';
import 'package:budgetify/features/home/presentation/widgets/recipient/recipient_selection.dart';

void main() {
  group('comparableRecipientPhone', () {
    test('normalizes local and international Rwanda phone numbers', () {
      expect(comparableRecipientPhone('0791 032 369'), '791032369');
      expect(comparableRecipientPhone('+250 791 032 369'), '791032369');
      expect(comparableRecipientPhone('791032369'), '791032369');
    });
  });

  group('filterRecipientContacts', () {
    const contacts = [
      DeviceContact(
        id: '1',
        name: 'Alice Example',
        phoneNumber: '0781234567',
      ),
      DeviceContact(
        id: '2',
        name: 'Daniel Example',
        phoneNumber: '+250791032369',
      ),
    ];

    test('filters contacts by name', () {
      final result = filterRecipientContacts(
        contacts: contacts,
        query: 'alice',
      );

      expect(result, hasLength(1));
      expect(result.single.id, '1');
    });

    test('matches equivalent Rwanda phone formats', () {
      final result = filterRecipientContacts(
        contacts: contacts,
        query: '0791032369',
      );

      expect(result, hasLength(1));
      expect(result.single.id, '2');
    });

    test('returns all contacts for empty query', () {
      final result = filterRecipientContacts(
        contacts: contacts,
        query: '',
      );

      expect(result, contacts);
    });
  });

  group('resolveTypedRecipient', () {
    test('recognizes MTN phone number', () {
      final recipient = resolveTypedRecipient(
        query: '0791032369',
        contacts: const [],
      );

      expect(recipient, isNotNull);
      expect(
        recipient!.recipientType,
        TransactionRecipientType.phone,
      );
      expect(recipient.identifier, '0791032369');
      expect(recipient.subtitle, 'MTN MoMo phone number');
    });

    test('does not duplicate a phone already available as a contact', () {
      final recipient = resolveTypedRecipient(
        query: '0791032369',
        contacts: const [
          DeviceContact(
            id: '1',
            name: 'Daniel',
            phoneNumber: '+250791032369',
          ),
        ],
      );

      expect(recipient, isNull);
    });

    test('recognizes MoMo merchant code', () {
      final recipient = resolveTypedRecipient(
        query: '12345',
        contacts: const [],
      );

      expect(recipient, isNotNull);
      expect(
        recipient!.recipientType,
        TransactionRecipientType.momoCode,
      );
      expect(recipient.subtitle, 'MoMo Pay merchant code');
    });

    test('rejects alphabetic typed recipients', () {
      final recipient = resolveTypedRecipient(
        query: 'Daniel',
        contacts: const [],
      );

      expect(recipient, isNull);
    });
  });
}