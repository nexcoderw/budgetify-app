import 'package:flutter/foundation.dart';

import '../../../core/storage/secure_storage_service.dart';

class PartnershipInviteLinkStore {
  PartnershipInviteLinkStore._({SecureStorageService? secureStorageService})
    : _secureStorageService = secureStorageService ?? SecureStorageService();

  static final PartnershipInviteLinkStore instance =
      PartnershipInviteLinkStore._();
  static const _storageKey = 'budgetify.partnership.pendingInviteToken';

  final SecureStorageService _secureStorageService;
  Future<void>? _hydrateFuture;
  bool _isHydrated = false;

  final ValueNotifier<String?> pendingInviteToken = ValueNotifier<String?>(
    null,
  );

  Future<void> hydrate() {
    if (_isHydrated) {
      return Future<void>.value();
    }

    final existingFuture = _hydrateFuture;
    if (existingFuture != null) {
      return existingFuture;
    }

    final future = _hydrateFromStorage();
    _hydrateFuture = future;

    return future;
  }

  Future<void> _hydrateFromStorage() async {
    try {
      final storedToken = await _secureStorageService.read(_storageKey);
      final normalized = storedToken?.trim();

      if (pendingInviteToken.value == null &&
          normalized != null &&
          normalized.isNotEmpty) {
        pendingInviteToken.value = normalized;
      }
    } finally {
      _isHydrated = true;
      _hydrateFuture = null;
    }
  }

  Future<void> stageInviteToken(String token) async {
    final normalized = token.trim();
    if (normalized.isEmpty) {
      return;
    }

    pendingInviteToken.value = normalized;
    await _secureStorageService.write(key: _storageKey, value: normalized);
  }

  Future<String?> takePendingInviteToken() async {
    await hydrate();

    final token = pendingInviteToken.value?.trim();
    pendingInviteToken.value = null;
    await _secureStorageService.delete(_storageKey);

    if (token == null || token.isEmpty) {
      return null;
    }

    return token;
  }
}
