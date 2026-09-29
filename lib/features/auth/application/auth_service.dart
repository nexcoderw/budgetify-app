import 'auth_service_contract.dart';
import '../data/models/auth_session.dart';
import '../data/models/auth_user.dart';
import '../data/models/email_initiate_response.dart';
import '../data/models/password_auth_models.dart';
import '../data/routes/auth_api_routes.dart';
import '../data/services/auth_api_service.dart';
import '../data/services/auth_session_storage.dart';
import '../data/services/email_otp_api_service.dart';
import '../data/services/google_identity_service.dart';
import '../data/services/password_auth_api_service.dart';
import '../../users/data/routes/users_api_routes.dart';
import '../../users/data/services/users_api_service.dart';
import '../../../core/config/app_env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/secure_storage_service.dart';

class AuthService implements AuthServiceContract {
  AuthService({
    required AuthApiService authApiService,
    required EmailOtpApiService emailOtpApiService,
    required PasswordAuthApiService passwordAuthApiService,
    required UsersApiService usersApiService,
    required AuthSessionStorage sessionStorage,
    required GoogleIdentityService googleIdentityService,
  }) : _authApiService = authApiService,
       _emailOtpApiService = emailOtpApiService,
       _passwordAuthApiService = passwordAuthApiService,
       _usersApiService = usersApiService,
       _sessionStorage = sessionStorage,
       _googleIdentityService = googleIdentityService;

  factory AuthService.createDefault() {
    final apiClient = ApiClient(baseUrlResolver: () => AppEnv.apiBaseUrl);
    final authRoutes = AuthApiRoutes.instance;
    final usersRoutes = UsersApiRoutes.instance;

    return AuthService(
      authApiService: AuthApiService(apiClient: apiClient, routes: authRoutes),
      emailOtpApiService: EmailOtpApiService(
        apiClient: apiClient,
        routes: authRoutes,
      ),
      passwordAuthApiService: PasswordAuthApiService(
        apiClient: apiClient,
        routes: authRoutes,
      ),
      usersApiService: UsersApiService(
        apiClient: apiClient,
        routes: usersRoutes,
      ),
      sessionStorage: AuthSessionStorage(
        secureStorageService: SecureStorageService(),
      ),
      googleIdentityService: GoogleIdentityService(),
    );
  }

  final AuthApiService _authApiService;
  final EmailOtpApiService _emailOtpApiService;
  final PasswordAuthApiService _passwordAuthApiService;
  final UsersApiService _usersApiService;
  final AuthSessionStorage _sessionStorage;
  final GoogleIdentityService _googleIdentityService;

  @override
  Future<void> ensureInitialized() =>
      _googleIdentityService.ensureInitialized();

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

  // ── Password authentication ───────────────────────────────────────────────

  @override
  Future<PasswordStatus> getPasswordStatus(String email) {
    return _passwordAuthApiService.getStatus(email);
  }

  @override
  Future<PasswordChallenge> requestPasswordChallenge(String email) {
    return _passwordAuthApiService.requestChallenge(email);
  }

  @override
  Future<PasswordSetupGrant> verifyPasswordChallenge(String email, String otp) {
    return _passwordAuthApiService.verifyChallenge(email, otp);
  }

  @override
  Future<void> setPassword({
    required String grantToken,
    required String password,
    required String confirmPassword,
  }) {
    return _passwordAuthApiService.setPassword(
      grantToken: grantToken,
      password: password,
      confirmPassword: confirmPassword,
    );
  }

  @override
  Future<AuthSession> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final session = await _passwordAuthApiService.login(
      email: email,
      password: password,
    );
    await _sessionStorage.save(session);

    return session;
  }

  @override
  Future<AuthUser> updateCurrentUserNames({
    required String firstName,
    required String lastName,
  }) async {
    final session = await _sessionStorage.read();

    if (session == null) {
      throw StateError('No stored session was found for this profile update.');
    }

    final activeSession = await _resolveActiveSession(session);
    final updatedUser = await _usersApiService.updateCurrentUserNames(
      accessToken: activeSession.accessToken,
      firstName: firstName,
      lastName: lastName,
    );

    await _sessionStorage.save(
      AuthSession(
        accessToken: activeSession.accessToken,
        refreshToken: activeSession.refreshToken,
        expiresIn: activeSession.expiresIn,
        tokenType: activeSession.tokenType,
        user: updatedUser,
        issuedAt: activeSession.issuedAt,
      ),
    );

    return updatedUser;
  }

  @override
  Future<AuthUser> requestCurrentUserDeletion() async {
    final session = await _sessionStorage.read();

    if (session == null) {
      throw StateError(
        'No stored session was found for this account deletion request.',
      );
    }

    final activeSession = await _resolveActiveSession(session);
    final updatedUser = await _usersApiService.requestCurrentUserDeletion(
      accessToken: activeSession.accessToken,
    );

    await _sessionStorage.save(
      AuthSession(
        accessToken: activeSession.accessToken,
        refreshToken: activeSession.refreshToken,
        expiresIn: activeSession.expiresIn,
        tokenType: activeSession.tokenType,
        user: updatedUser,
        issuedAt: activeSession.issuedAt,
      ),
    );

    return updatedUser;
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

      return _usersApiService.fetchCurrentUser(
        accessToken: activeSession.accessToken,
      );
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
