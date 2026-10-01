import '../../../../core/network/api_client.dart';
import '../models/auth_session.dart';
import '../models/email_initiate_response.dart';
import '../routes/auth_api_routes.dart';

/// Handles the two-step email OTP authentication flow:
///
/// Step 1 — submit the email and request an OTP.
///
/// Step 2 — submit the 4-digit OTP and receive the authenticated session.
class EmailOtpApiService {
  EmailOtpApiService({
    required ApiClient apiClient,
    required AuthApiRoutes routes,
  }) : _apiClient = apiClient,
       _routes = routes;

  final ApiClient _apiClient;

  final AuthApiRoutes _routes;

  Future<EmailInitiateResponse> initiateEmailAuth(String email) async {
    final json = await _apiClient.postJson(
      _routes.emailInitiate,
      body: <String, dynamic>{'email': email},
    );

    return EmailInitiateResponse.fromJson(json);
  }

  /// Submits the 4-digit OTP to complete sign-in or registration.
  Future<AuthSession> verifyEmailOtp(String email, String otp) async {
    final json = await _apiClient.postJson(
      _routes.emailVerify,
      body: <String, dynamic>{'email': email, 'otp': otp},
    );

    return AuthSession.fromJson(json);
  }
}
