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
    final seenNumbers = <String>{};

    for (final contact in contacts) {
      final displayName = contact.displayName.trim();
      final resolvedName = displayName.isEmpty
          ? 'Unknown contact'
          : displayName;

      for (var index = 0; index < contact.phones.length; index++) {
        final phoneNumber = contact.phones[index].number.trim();
        final normalizedNumber = phoneNumber.replaceAll(RegExp(r'\D'), '');

        if (phoneNumber.isEmpty ||
            normalizedNumber.isEmpty ||
            !seenNumbers.add(normalizedNumber)) {
          continue;
        }

        results.add(
          DeviceContact(
            id: '${contact.id.isEmpty ? 'contact-${results.length}' : contact.id}-$index',
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
