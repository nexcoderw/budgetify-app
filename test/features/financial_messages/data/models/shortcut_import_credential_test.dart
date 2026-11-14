import 'package:ingengo/features/financial_messages/data/models/shortcut_import_credential.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const token = 'bfi_test_one-time-secret';
  final json = <String, dynamic>{
    'id': '8d769f92-a7b4-4902-90b0-84165bc16411',
    'deviceName': 'Pilot iPhone',
    'tokenPrefix': 'bfi_test',
    'status': 'ACTIVE',
    'lastUsedAt': null,
    'expiresAt': '2027-10-30T12:00:00.000Z',
    'revokedAt': null,
    'createdAt': '2026-10-30T12:00:00.000Z',
    'token': token,
  };

  test('requires a token in one-time credential responses', () {
    final credential = ShortcutImportCredential.fromJson(
      json,
      requireToken: true,
    );

    expect(credential.token, token);
    expect(credential.isActive, isTrue);
  });

  test('creates metadata without retaining the one-time token', () {
    final credential = ShortcutImportCredential.fromJson(
      json,
      requireToken: true,
    );

    final metadata = credential.withoutToken();

    expect(metadata.id, credential.id);
    expect(metadata.token, isNull);
  });

  test('rejects a creation response without a one-time token', () {
    final missingToken = Map<String, dynamic>.from(json)..remove('token');

    expect(
      () => ShortcutImportCredential.fromJson(missingToken, requireToken: true),
      throwsFormatException,
    );
  });
}
