class PasswordStatus {
  const PasswordStatus({required this.hasPassword});

  factory PasswordStatus.fromJson(Map<String, dynamic> json) {
    return PasswordStatus(hasPassword: json['hasPassword'] == true);
  }

  final bool hasPassword;
}

class PasswordChallenge {
  const PasswordChallenge({required this.maskedEmail, required this.message});

  factory PasswordChallenge.fromJson(Map<String, dynamic> json) {
    return PasswordChallenge(
      maskedEmail: json['maskedEmail'] as String,
      message: json['message'] as String,
    );
  }

  final String maskedEmail;
  final String message;
}

class PasswordSetupGrant {
  const PasswordSetupGrant({required this.token, required this.expiresIn});

  factory PasswordSetupGrant.fromJson(Map<String, dynamic> json) {
    return PasswordSetupGrant(
      token: json['grantToken'] as String,
      expiresIn: json['expiresIn'] as int,
    );
  }

  final String token;
  final int expiresIn;
}
