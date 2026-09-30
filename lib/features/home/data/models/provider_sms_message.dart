enum DeviceSmsPermission {
  granted,
  denied,
  unsupported;

  static DeviceSmsPermission fromPlatformValue(String value) {
    return switch (value) {
      'granted' => DeviceSmsPermission.granted,
      'denied' => DeviceSmsPermission.denied,
      _ => DeviceSmsPermission.unsupported,
    };
  }
}

class ProviderSmsMessage {
  const ProviderSmsMessage({
    required this.id,
    required this.address,
    required this.body,
    required this.receivedAt,
  });

  factory ProviderSmsMessage.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final address = json['address'];
    final body = json['body'];
    final receivedAtMillis = json['receivedAtMillis'];

    if (id is! String || body is! String || receivedAtMillis is! int) {
      throw const FormatException('Invalid SMS message payload.');
    }

    return ProviderSmsMessage(
      id: id,
      address: address is String ? address : '',
      body: body,
      receivedAt: DateTime.fromMillisecondsSinceEpoch(receivedAtMillis),
    );
  }

  final String id;
  final String address;

  /// Kept only in memory while parsing.
  /// Never submit this raw value to the API.
  final String body;

  final DateTime receivedAt;
}
