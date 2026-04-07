import 'package:flutter/foundation.dart';

class PartnershipInviteLinkStore {
  PartnershipInviteLinkStore._();

  static final PartnershipInviteLinkStore instance =
      PartnershipInviteLinkStore._();

  final ValueNotifier<String?> pendingInviteToken = ValueNotifier<String?>(
    null,
  );

  void stageInviteToken(String token) {
    final normalized = token.trim();
    if (normalized.isEmpty) {
      return;
    }

    pendingInviteToken.value = normalized;
  }

  String? takePendingInviteToken() {
    final token = pendingInviteToken.value?.trim();
    pendingInviteToken.value = null;

    if (token == null || token.isEmpty) {
      return null;
    }

    return token;
  }
}
