/// Response from POST /auth/email/initiate.
///
/// [action] tells the client which screen to show next:
///   - "login"    → existing account, sign-in OTP sent
///   - "register" → new address, onboarding OTP sent
class EmailInitiateResponse {
  const EmailInitiateResponse({
    required this.action,
    required this.maskedEmail,
    required this.message,
  });

  factory EmailInitiateResponse.fromJson(Map<String, dynamic> json) {
    return EmailInitiateResponse(
      action: json['action'] as String,
      maskedEmail: json['maskedEmail'] as String,
      message: json['message'] as String,
    );
  }

  final String action;
  final String maskedEmail;
  final String message;

  bool get isLogin => action == 'login';
  bool get isRegister => action == 'register';
}
