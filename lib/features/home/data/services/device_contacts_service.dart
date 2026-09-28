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

    final status = await FlutterContacts.permissions.check(
      PermissionType.read,
    );

    return _mapPermission(status);
  }

  Future<DeviceContactsPermission> requestPermission() async {
    if (!isSupported) {
      return DeviceContactsPermission.unsupported;
    }

    final status = await FlutterContacts.permissions.request(
      PermissionType.read,
    );

    return _mapPermission(status);
  }

  Future<List<DeviceContact>> getContacts() async {
    if (!isSupported) {
      return const [];
    }

    final contacts = await FlutterContacts.getAll(
      properties: const {
        ContactProperty.name,
        ContactProperty.phone,
      },
    );
    final results = <DeviceContact>[];
    final seenNumbers = <String>{};

    for (final contact in contacts) {
      final displayName = contact.displayName?.trim();
      final resolvedName = displayName == null || displayName.isEmpty
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
            id: '${contact.id ?? 'contact-${results.length}'}-$index',
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

  DeviceContactsPermission _mapPermission(PermissionStatus status) {
    return switch (status) {
      PermissionStatus.granted || PermissionStatus.limited =>
        DeviceContactsPermission.granted,
      PermissionStatus.notDetermined =>
        DeviceContactsPermission.notDetermined,
      PermissionStatus.denied => DeviceContactsPermission.denied,
      PermissionStatus.permanentlyDenied =>
        DeviceContactsPermission.permanentlyDenied,
      PermissionStatus.restricted => DeviceContactsPermission.restricted,
    };
  }
}
