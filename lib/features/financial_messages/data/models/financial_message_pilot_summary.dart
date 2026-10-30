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

class FinancialMessageProviderMetric {
  const FinancialMessageProviderMetric({
    required this.providerCode,
    required this.label,
    required this.enabled,
    required this.total,
    required this.parsed,
    required this.needsReview,
    required this.confirmed,
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
    );
  }

  final String? providerCode;
  final String label;
  final bool enabled;
  final int total;
  final int parsed;
  final int needsReview;
  final int confirmed;
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
