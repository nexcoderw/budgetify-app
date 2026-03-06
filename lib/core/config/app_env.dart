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

  static String get apiBaseUrl => _normalizeBaseUrl(_require('API_BASE_URL'));

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
    if (value.endsWith('/')) {
      return value.substring(0, value.length - 1);
    }

    return value;
  }
}
