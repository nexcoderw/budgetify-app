import 'auth_service_contract.dart';
import '../data/models/auth_session.dart';
import '../data/models/auth_user.dart';
import '../data/models/email_initiate_response.dart';
import '../data/routes/auth_api_routes.dart';
import '../data/services/auth_api_service.dart';
import '../data/services/auth_session_storage.dart';
import '../data/services/email_otp_api_service.dart';
import '../data/services/google_identity_service.dart';
import '../../../core/config/app_env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/secure_storage_service.dart';

class AuthService implements AuthServiceContract {
  AuthService({
    required AuthApiService authApiService,
    required EmailOtpApiService emailOtpApiService,
    required AuthSessionStorage sessionStorage,
    required GoogleIdentityService googleIdentityService,
  })  : _authApiService = authApiService,
        _emailOtpApiService = emailOtpApiService,
        _sessionStorage = sessionStorage,
        _googleIdentityService = googleIdentityService;

  factory AuthService.createDefault() {
    final apiClient = ApiClient(baseUrlResolver: () => AppEnv.apiBaseUrl);
    final routes = AuthApiRoutes.instance;

    return AuthService(
      authApiService: AuthApiService(
        apiClient: apiClient,
        routes: routes,
      ),
      emailOtpApiService: EmailOtpApiService(
        apiClient: apiClient,
        routes: routes,
      ),
      sessionStorage: AuthSessionStorage(
        secureStorageService: SecureStorageService(),
      ),
      googleIdentityService: GoogleIdentityService(),
    );
  }

  final AuthApiService _authApiService;
  final EmailOtpApiService _emailOtpApiService;
  final AuthSessionStorage _sessionStorage;
  final GoogleIdentityService _googleIdentityService;

  @override
  Future<void> ensureInitialized() => _googleIdentityService.ensureInitialized();

  // ── Google OAuth ────────────────────────────────────────────────────────────

  @override
  Future<AuthSession> signInWithGoogle() async {
    final idToken = await _googleIdentityService.getIdToken();
    final session = await _authApiService.authenticateWithGoogle(idToken);

    await _sessionStorage.save(session);

    return session;
  }

  @override
  Future<AuthSession> signInWithGoogleIdToken(String idToken) async {
    final session = await _authApiService.authenticateWithGoogle(idToken);
    await _sessionStorage.save(session);
    return session;
  }

  // ── Email OTP ───────────────────────────────────────────────────────────────

  @override
  Future<EmailInitiateResponse> initiateEmailAuth(String email) {
    return _emailOtpApiService.initiateEmailAuth(email);
  }

  @override
  Future<AuthSession> verifyEmailOtp(String email, String otp) async {
    final session = await _emailOtpApiService.verifyEmailOtp(email, otp);
    await _sessionStorage.save(session);
    return session;
  }

  // ── Session management ──────────────────────────────────────────────────────

  @override
  Future<AuthUser?> restoreAuthenticatedUser() async {
    final session = await _sessionStorage.read();

    if (session == null) {
      return null;
    }

    try {
      final activeSession = await _resolveActiveSession(session);

      return _authApiService.fetchCurrentUser(activeSession.accessToken);
    } on ApiException {
      await clearSession();
      rethrow;
    } catch (_) {
      await clearSession();
      rethrow;
    }
  }

  @override
  Future<AuthSession> refreshSession() async {
    final session = await _sessionStorage.read();

    if (session == null) {
      throw StateError('No stored session was found to refresh.');
    }

    final refreshedSession = await _authApiService.refreshSession(
      session.refreshToken,
    );
    await _sessionStorage.save(refreshedSession);

    return refreshedSession;
  }

  @override
  Future<void> logout() async {
    final session = await _sessionStorage.read();

    try {
      if (session != null) {
        await _authApiService.logout(session.refreshToken);
      }
    } finally {
      await clearSession();
      await _googleIdentityService.signOut();
    }
  }

  @override
  Future<void> clearSession() => _sessionStorage.clear();

  Future<AuthSession> _resolveActiveSession(AuthSession session) async {
    if (!session.needsRefresh) {
      return session;
    }

    final refreshedSession = await _authApiService.refreshSession(
      session.refreshToken,
    );
    await _sessionStorage.save(refreshedSession);

    return refreshedSession;
  }
}
