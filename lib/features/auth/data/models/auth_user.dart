class AuthUser {
  AuthUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.avatarUrl,
    required this.isEmailVerified,
    required this.status,
    required this.lastLoginAt,
    required this.accountDeletionRequestedAt,
    required this.accountDeletionScheduledFor,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      fullName: json['fullName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      isEmailVerified: json['isEmailVerified'] as bool,
      status: json['status'] as String,
      lastLoginAt: _parseDateTime(json['lastLoginAt']),
      accountDeletionRequestedAt: _parseDateTime(
        json['accountDeletionRequestedAt'],
      ),
      accountDeletionScheduledFor: _parseDateTime(
        json['accountDeletionScheduledFor'],
      ),
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
    );
  }

  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? fullName;
  final String? avatarUrl;
  final bool isEmailVerified;
  final String status;
  final DateTime? lastLoginAt;
  final DateTime? accountDeletionRequestedAt;
  final DateTime? accountDeletionScheduledFor;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'fullName': fullName,
      'avatarUrl': avatarUrl,
      'isEmailVerified': isEmailVerified,
      'status': status,
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'accountDeletionRequestedAt': accountDeletionRequestedAt
          ?.toIso8601String(),
      'accountDeletionScheduledFor': accountDeletionScheduledFor
          ?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value == null) {
      return null;
    }

    return DateTime.parse(value as String).toUtc();
  }
}
