import '../../../../core/network/api_client.dart';
import '../models/auth_session.dart';
import '../models/password_auth_models.dart';
import '../routes/auth_api_routes.dart';

class PasswordAuthApiService {
  PasswordAuthApiService({
    required ApiClient apiClient,
    required AuthApiRoutes routes,
  }) : _apiClient = apiClient,
       _routes = routes;

  final ApiClient _apiClient;
  final AuthApiRoutes _routes;

  Future<PasswordStatus> getStatus(String email) async {
    final json = await _apiClient.postJson(
      _routes.passwordStatus,
      body: <String, dynamic>{'email': email},
    );

    return PasswordStatus.fromJson(json);
  }

  Future<PasswordChallenge> requestChallenge(String email) async {
    final json = await _apiClient.postJson(
      _routes.passwordChallenge,
      body: <String, dynamic>{'email': email},
    );

    return PasswordChallenge.fromJson(json);
  }

  Future<PasswordSetupGrant> verifyChallenge(String email, String otp) async {
    final json = await _apiClient.postJson(
      _routes.passwordChallengeVerify,
      body: <String, dynamic>{'email': email, 'otp': otp},
    );

    return PasswordSetupGrant.fromJson(json);
  }

  Future<void> setPassword({
    required String grantToken,
    required String password,
    required String confirmPassword,
  }) async {
    await _apiClient.postJson(
      _routes.passwordSet,
      body: <String, dynamic>{
        'grantToken': grantToken,
        'password': password,
        'confirmPassword': confirmPassword,
      },
    );
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final json = await _apiClient.postJson(
      _routes.passwordLogin,
      body: <String, dynamic>{'email': email, 'password': password},
    );

    return AuthSession.fromJson(json);
  }
}
