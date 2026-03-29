import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class AppEnv {
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) {
      return;
    }

    try {
      await dotenv.load(fileName: '.env');
    } finally {
      _loaded = true;
    }
  }

  static String get apiBaseUrl {
    if (kIsWeb) {
      return _normalizeBaseUrl(_require('API_BASE_URL_WEB'));
    }

    final nativeOverride =
        optional('API_BASE_URL_NATIVE') ?? optional('API_BASE_URL_MOBILE');
    final configuredBaseUrl = nativeOverride ?? _require('API_BASE_URL');

    return _normalizeBaseUrl(
      _rewriteLoopbackHostForAndroidEmulator(configuredBaseUrl),
    );
  }

  static String get googleServerClientId => _require('GOOGLE_SERVER_CLIENT_ID');

  static String? optional(String key) {
    final value = dotenv.env[key]?.trim();

    if (value == null || value.isEmpty) {
      return null;
    }

    return value;
  }

  static String _require(String key) {
    final value = optional(key) ?? String.fromEnvironment(key).trim();

    if (value.isEmpty) {
      throw StateError('Missing required environment variable: $key');
    }

    return value;
  }

  static String _normalizeBaseUrl(String value) {
    var normalized = value;

    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    if (normalized.endsWith('/api/v1')) {
      normalized = normalized.substring(
        0,
        normalized.length - '/api/v1'.length,
      );
    }

    return normalized;
  }

  static String _rewriteLoopbackHostForAndroidEmulator(String value) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return value;
    }

    final uri = Uri.tryParse(value);

    if (uri == null) {
      return value;
    }

    final host = uri.host.toLowerCase();

    if (host != '127.0.0.1' && host != 'localhost') {
      return value;
    }

    return uri.replace(host: '10.0.2.2').toString();
  }
}
