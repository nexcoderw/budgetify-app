import 'auth_user.dart';

class AuthSession {
  AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.tokenType,
    required this.user,
    required this.issuedAt,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresIn: json['expiresIn'] as int,
      tokenType: json['tokenType'] as String,
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      issuedAt: DateTime.now().toUtc(),
    );
  }

  factory AuthSession.fromStorageJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresIn: json['expiresIn'] as int,
      tokenType: json['tokenType'] as String,
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      issuedAt: DateTime.parse(json['issuedAt'] as String).toUtc(),
    );
  }

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final String tokenType;
  final AuthUser user;
  final DateTime issuedAt;

  bool get needsRefresh {
    final refreshThreshold = issuedAt.add(Duration(seconds: expiresIn - 30));

    return DateTime.now().toUtc().isAfter(refreshThreshold);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresIn': expiresIn,
      'tokenType': tokenType,
      'user': user.toJson(),
      'issuedAt': issuedAt.toIso8601String(),
    };
  }
}
