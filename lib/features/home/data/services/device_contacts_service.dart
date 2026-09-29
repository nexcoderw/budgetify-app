import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter/services.dart';

import '../models/device_contact.dart';

enum DeviceContactsPermission {
  notDetermined,
  granted,
  denied,
  permanentlyDenied,
  restricted,
  unsupported,
}

class DeviceContactsService {
  const DeviceContactsService();

  static const _iosContactsChannel = MethodChannel('budgetify/contacts');

  bool get isSupported {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<DeviceContactsPermission> checkPermission() async {
    if (!isSupported) {
      return DeviceContactsPermission.unsupported;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final status = await _iosContactsChannel.invokeMethod<String>(
        'authorizationStatus',
      );

      return switch (status) {
        'granted' => DeviceContactsPermission.granted,
        'restricted' => DeviceContactsPermission.restricted,
        'denied' => DeviceContactsPermission.denied,
        _ => DeviceContactsPermission.notDetermined,
      };
    }

    return requestPermission();
  }

  Future<DeviceContactsPermission> requestPermission() async {
    if (!isSupported) {
      return DeviceContactsPermission.unsupported;
    }

    final isGranted = defaultTargetPlatform == TargetPlatform.iOS
        ? await _iosContactsChannel.invokeMethod<bool>('requestPermission') ??
              false
        : await FlutterContacts.requestPermission(readonly: true);

    return isGranted
        ? DeviceContactsPermission.granted
        : DeviceContactsPermission.denied;
  }

  Future<List<DeviceContact>> getContacts() async {
    if (!isSupported) {
      return const [];
    }

    final permission = await requestPermission();

    if (permission != DeviceContactsPermission.granted) {
      throw StateError('Contact access has not been granted.');
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final contacts = await _iosContactsChannel.invokeListMethod<dynamic>(
        'getContacts',
      );

      return (contacts ?? const [])
          .map((rawContact) {
            final contact = Map<Object?, Object?>.from(rawContact as Map);

            return DeviceContact(
              id: contact['id']?.toString() ?? '',
              name: contact['name']?.toString() ?? 'Unknown contact',
              phoneNumber: contact['phoneNumber']?.toString() ?? '',
            );
          })
          .where((contact) {
            return contact.id.isNotEmpty && contact.phoneNumber.isNotEmpty;
          })
          .toList(growable: false);
    }

    final contacts = await FlutterContacts.getContacts(
      withProperties: true,
      withThumbnail: false,
      withPhoto: false,
    );
    final results = <DeviceContact>[];
    final seenContactNumbers = <String>{};

    for (var contactIndex = 0; contactIndex < contacts.length; contactIndex++) {
      final contact = contacts[contactIndex];
      final displayName = contact.displayName.trim();
      final structuredName = [
        contact.name.first,
        contact.name.middle,
        contact.name.last,
      ].map((part) => part.trim()).where((part) => part.isNotEmpty).join(' ');
      final nickname = contact.name.nickname.trim();
      final resolvedName = displayName.isNotEmpty
          ? displayName
          : structuredName.isNotEmpty
          ? structuredName
          : nickname.isNotEmpty
          ? nickname
          : 'Unknown contact';
      final contactIdentity = contact.id.isEmpty
          ? 'contact-$contactIndex'
          : contact.id;

      for (var index = 0; index < contact.phones.length; index++) {
        final phoneNumber = contact.phones[index].number.trim();
        final normalizedNumber = phoneNumber.replaceAll(RegExp(r'\D'), '');
        final contactNumberKey = '$contactIdentity:$normalizedNumber';

        if (phoneNumber.isEmpty ||
            normalizedNumber.isEmpty ||
            !seenContactNumbers.add(contactNumberKey)) {
          continue;
        }

        results.add(
          DeviceContact(
            id: '$contactIdentity-$index',
            name: resolvedName,
            phoneNumber: phoneNumber,
          ),
        );
      }
    }

    results.sort(
      (left, right) => left.name.toLowerCase().compareTo(
        right.name.toLowerCase(),
      ),
    );

    return results;
  }
}
