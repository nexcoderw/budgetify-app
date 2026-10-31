enum FinancialMessagePilotHealth {
  healthy('HEALTHY'),
  needsAttention('NEEDS_ATTENTION'),
  insufficientData('INSUFFICIENT_DATA');

  const FinancialMessagePilotHealth(this.apiValue);
  final String apiValue;

  static FinancialMessagePilotHealth fromApiValue(String value) {
    return values.firstWhere(
      (item) => item.apiValue == value,
      orElse: () => throw FormatException('Unsupported pilot health: $value'),
    );
  }
}

enum FinancialMessageProviderReadiness {
  monitoring('MONITORING'),
  readyToEnable('READY_TO_ENABLE'),
  needsAttention('NEEDS_ATTENTION'),
  insufficientData('INSUFFICIENT_DATA');

  const FinancialMessageProviderReadiness(this.apiValue);
  final String apiValue;

  static FinancialMessageProviderReadiness fromApiValue(String value) {
    return values.firstWhere(
      (item) => item.apiValue == value,
      orElse: () =>
          throw FormatException('Unsupported provider readiness: $value'),
    );
  }
}

class FinancialMessageProviderMetric {
  const FinancialMessageProviderMetric({
    required this.providerCode,
    required this.label,
    required this.enabled,
    required this.total,
    required this.parsed,
    required this.needsReview,
    required this.confirmed,
    required this.parseRatePercent,
    required this.readiness,
  });

  factory FinancialMessageProviderMetric.fromJson(Map<String, dynamic> json) {
    return FinancialMessageProviderMetric(
      providerCode: _optionalString(json, 'providerCode'),
      label: _requiredString(json, 'label'),
      enabled: _requiredBool(json, 'enabled'),
      total: _requiredInt(json, 'total'),
      parsed: _requiredInt(json, 'parsed'),
      needsReview: _requiredInt(json, 'needsReview'),
      confirmed: _requiredInt(json, 'confirmed'),
      parseRatePercent: _requiredInt(json, 'parseRatePercent'),
      readiness: FinancialMessageProviderReadiness.fromApiValue(
        _requiredString(json, 'readiness'),
      ),
    );
  }

  final String? providerCode;
  final String label;
  final bool enabled;
  final int total;
  final int parsed;
  final int needsReview;
  final int confirmed;
  final int parseRatePercent;
  final FinancialMessageProviderReadiness readiness;
}

class FinancialMessagePilotSummary {
  const FinancialMessagePilotSummary({
    required this.mode,
    required this.windowDays,
    required this.total,
    required this.pending,
    required this.confirmed,
    required this.dismissed,
    required this.needsReview,
    required this.possibleDuplicates,
    required this.health,
    required this.lastImportAt,
    required this.providers,
    required this.isTruncated,
    required this.currentShortcutVersion,
    required this.minimumShortcutVersion,
    required this.shortcutInstallUrl,
    required this.legacyShortcutImports,
    required this.outdatedShortcutImports,
  });

  factory FinancialMessagePilotSummary.fromJson(Map<String, dynamic> json) {
    final rawProviders = json['providers'];
    if (rawProviders is! List) {
      throw const FormatException('Invalid provider metrics.');
    }

    return FinancialMessagePilotSummary(
      mode: _requiredString(json, 'mode'),
      windowDays: _requiredInt(json, 'windowDays'),
      total: _requiredInt(json, 'total'),
      pending: _requiredInt(json, 'pending'),
      confirmed: _requiredInt(json, 'confirmed'),
      dismissed: _requiredInt(json, 'dismissed'),
      needsReview: _requiredInt(json, 'needsReview'),
      possibleDuplicates: _requiredInt(json, 'possibleDuplicates'),
      health: FinancialMessagePilotHealth.fromApiValue(
        _requiredString(json, 'health'),
      ),
      lastImportAt: _optionalDate(json, 'lastImportAt'),
      providers: rawProviders
          .map(
            (item) => FinancialMessageProviderMetric.fromJson(
              _requiredMap(item, 'provider metric'),
            ),
          )
          .toList(growable: false),
      isTruncated: _requiredBool(json, 'isTruncated'),
      currentShortcutVersion: _requiredInt(json, 'currentShortcutVersion'),
      minimumShortcutVersion: _requiredInt(json, 'minimumShortcutVersion'),
      shortcutInstallUrl: _optionalString(json, 'shortcutInstallUrl'),
      legacyShortcutImports: _requiredInt(json, 'legacyShortcutImports'),
      outdatedShortcutImports: _requiredInt(json, 'outdatedShortcutImports'),
    );
  }

  final String mode;
  final int windowDays;
  final int total;
  final int pending;
  final int confirmed;
  final int dismissed;
  final int needsReview;
  final int possibleDuplicates;
  final FinancialMessagePilotHealth health;
  final DateTime? lastImportAt;
  final List<FinancialMessageProviderMetric> providers;
  final bool isTruncated;
  final int currentShortcutVersion;
  final int minimumShortcutVersion;
  final String? shortcutInstallUrl;
  final int legacyShortcutImports;
  final int outdatedShortcutImports;

  bool get hasOutdatedShortcuts =>
      legacyShortcutImports > 0 || outdatedShortcutImports > 0;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid $key.');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('Invalid $key.');
  }
  return value;
}

Map<String, dynamic> _requiredMap(Object? value, String label) {
  if (value is! Map) {
    throw FormatException('Invalid $label.');
  }
  return Map<String, dynamic>.from(value);
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('Invalid $key.');
  }
  return value;
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw FormatException('Invalid $key.');
  }
  return value;
}

DateTime? _optionalDate(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('Invalid $key.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Invalid $key.');
  }
  return parsed.toLocal();
}
