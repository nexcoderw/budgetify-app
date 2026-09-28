class DeviceContact {
  const DeviceContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
  });

  final String id;
  final String name;
  final String phoneNumber;

  String get initials {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);

    if (words.isEmpty) {
      return '#';
    }

    if (words.length == 1) {
      return String.fromCharCode(words.first.runes.first).toUpperCase();
    }

    return String.fromCharCodes([
      words.first.runes.first,
      words.last.runes.first,
    ]).toUpperCase();
  }
}
