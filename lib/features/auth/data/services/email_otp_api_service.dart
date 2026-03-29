import '../../../../core/network/api_client.dart';
import '../models/auth_session.dart';
import '../models/email_initiate_response.dart';
import '../routes/auth_api_routes.dart';

/// Handles the two-step email OTP authentication flow:
///   Step 1 — [initiateEmailAuth]: submit email → API sends OTP
///   Step 2 — [verifyEmailOtp]:    submit OTP   → API returns JWT tokens
class EmailOtpApiService {
  EmailOtpApiService({
    required ApiClient apiClient,
    required AuthApiRoutes routes,
  })  : _apiClient = apiClient,
        _routes = routes;

  final ApiClient _apiClient;
  final AuthApiRoutes _routes;

  /// Step 1: send email to receive an OTP.
  ///
  /// Returns [EmailInitiateResponse] whose [action] field indicates
  /// whether this is a "login" (existing user) or "register" (new user) flow,
  /// so the UI can show the appropriate message on the OTP screen.
  Future<EmailInitiateResponse> initiateEmailAuth(String email) async {
    final json = await _apiClient.postJson(
      _routes.emailInitiate,
      body: <String, dynamic>{'email': email},
    );

    return EmailInitiateResponse.fromJson(json);
  }

  /// Step 2: submit the 6-digit OTP to complete sign-in or registration.
  ///
  /// On success the API creates (or reuses) a session and returns JWT tokens.
  Future<AuthSession> verifyEmailOtp(String email, String otp) async {
    final json = await _apiClient.postJson(
      _routes.emailVerify,
      body: <String, dynamic>{'email': email, 'otp': otp},
    );

    return AuthSession.fromJson(json);
  }
}
