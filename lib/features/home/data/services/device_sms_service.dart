import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/provider_sms_message.dart';

class DeviceSmsService {
  const DeviceSmsService();

  static const MethodChannel _channel = MethodChannel('budgetify/sms');

  bool get isSupported {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  }

  Future<DeviceSmsPermission> checkPermission() async {
    if (!isSupported) {
      return DeviceSmsPermission.unsupported;
    }

    final result = await _channel.invokeMethod<String>('checkPermission');

    return DeviceSmsPermission.fromPlatformValue(result ?? 'denied');
  }

  Future<DeviceSmsPermission> requestPermission() async {
    if (!isSupported) {
      return DeviceSmsPermission.unsupported;
    }

    final result = await _channel.invokeMethod<String>('requestPermission');

    return DeviceSmsPermission.fromPlatformValue(result ?? 'denied');
  }

  Future<List<ProviderSmsMessage>> readRecentMomoMessages({
    required DateTime since,
    int limit = 100,
  }) async {
    if (!isSupported) {
      return const [];
    }

    final response = await _channel.invokeMethod<List<dynamic>>(
      'readRecentMomoMessages',
      <String, dynamic>{
        'sinceMillis': since.millisecondsSinceEpoch,
        'limit': limit,
      },
    );

    if (response == null) {
      return const [];
    }

    return response
        .map(
          (item) => ProviderSmsMessage.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }
}
