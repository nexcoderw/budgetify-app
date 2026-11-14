import 'dart:convert';

import '../../../../core/storage/secure_storage_service.dart';
import '../models/auth_session.dart';

class AuthSessionStorage {
  AuthSessionStorage({required SecureStorageService secureStorageService})
    : _secureStorageService = secureStorageService;

  static const _storageKey = 'ingengo.auth.session';
  static const _legacyStorageKey = 'budgetify.auth.session';

  final SecureStorageService _secureStorageService;

  Future<void> save(AuthSession session) {
    return _secureStorageService.write(
      key: _storageKey,
      value: jsonEncode(session.toJson()),
    );
  }

  Future<AuthSession?> read() async {
    final raw =
        await _secureStorageService.read(_storageKey) ??
        await _secureStorageService.read(_legacyStorageKey);

    if (raw == null || raw.isEmpty) {
      return null;
    }

    final json = jsonDecode(raw) as Map<String, dynamic>;

    return AuthSession.fromStorageJson(json);
  }

  Future<void> clear() async {
    await _secureStorageService.delete(_storageKey);
    await _secureStorageService.delete(_legacyStorageKey);
  }
}
