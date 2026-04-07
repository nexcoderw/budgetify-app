class CreatedBySummary {
  const CreatedBySummary({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.avatarUrl,
  });

  factory CreatedBySummary.fromJson(Map<String, dynamic> json) {
    return CreatedBySummary(
      id: json['id'] as String,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  final String id;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
}
