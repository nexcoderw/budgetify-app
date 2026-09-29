import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

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

  static DeviceContactsPermission _lastKnownPermission =
      DeviceContactsPermission.notDetermined;

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

    return _lastKnownPermission;
  }

  Future<DeviceContactsPermission> requestPermission() async {
    if (!isSupported) {
      return DeviceContactsPermission.unsupported;
    }

    final isGranted = await FlutterContacts.requestPermission(
      readonly: true,
    );

    _lastKnownPermission = isGranted
        ? DeviceContactsPermission.granted
        : DeviceContactsPermission.denied;

    return _lastKnownPermission;
  }

  Future<List<DeviceContact>> getContacts() async {
    if (!isSupported) {
      return const [];
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
      final resolvedName = displayName.isEmpty
          ? 'Unknown contact'
          : displayName;
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
