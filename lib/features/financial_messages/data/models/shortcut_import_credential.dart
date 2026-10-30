enum ShortcutImportCredentialStatus {
  active('ACTIVE', 'Active'),
  expired('EXPIRED', 'Expired'),
  revoked('REVOKED', 'Revoked');

  const ShortcutImportCredentialStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static ShortcutImportCredentialStatus fromApiValue(String value) {
    return values.firstWhere(
      (status) => status.apiValue == value,
      orElse: () => throw FormatException(
        'Unsupported Shortcut credential status: $value',
      ),
    );
  }
}

class ShortcutImportCredential {
  const ShortcutImportCredential({
    required this.id,
    required this.deviceName,
    required this.tokenPrefix,
    required this.status,
    required this.lastUsedAt,
    required this.expiresAt,
    required this.revokedAt,
    required this.createdAt,
    required this.token,
  });

  factory ShortcutImportCredential.fromJson(
    Map<String, dynamic> json, {
    bool requireToken = false,
  }) {
    final token = _optionalString(json, 'token');
    if (requireToken && token == null) {
      throw const FormatException(
        'The one-time Shortcut credential was not returned.',
      );
    }

    return ShortcutImportCredential(
      id: _requiredString(json, 'id'),
      deviceName: _requiredString(json, 'deviceName'),
      tokenPrefix: _requiredString(json, 'tokenPrefix'),
      status: ShortcutImportCredentialStatus.fromApiValue(
        _requiredString(json, 'status'),
      ),
      lastUsedAt: _optionalDate(json, 'lastUsedAt'),
      expiresAt: _requiredDate(json, 'expiresAt'),
      revokedAt: _optionalDate(json, 'revokedAt'),
      createdAt: _requiredDate(json, 'createdAt'),
      token: token,
    );
  }

  final String id;
  final String deviceName;
  final String tokenPrefix;
  final ShortcutImportCredentialStatus status;
  final DateTime? lastUsedAt;
  final DateTime expiresAt;
  final DateTime? revokedAt;
  final DateTime createdAt;
  final String? token;

  bool get isActive => status == ShortcutImportCredentialStatus.active;

  ShortcutImportCredential withoutToken() {
    return ShortcutImportCredential(
      id: id,
      deviceName: deviceName,
      tokenPrefix: tokenPrefix,
      status: status,
      lastUsedAt: lastUsedAt,
      expiresAt: expiresAt,
      revokedAt: revokedAt,
      createdAt: createdAt,
      token: null,
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing or invalid $key.');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid $key.');
  }
  return value;
}

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final value = DateTime.tryParse(_requiredString(json, key));
  if (value == null) {
    throw FormatException('Invalid $key.');
  }
  return value.toLocal();
}

DateTime? _optionalDate(Map<String, dynamic> json, String key) {
  final value = _optionalString(json, key);
  if (value == null) {
    return null;
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Invalid $key.');
  }
  return parsed.toLocal();
}
