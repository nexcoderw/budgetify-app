import '../../../core/config/app_env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../auth/data/models/auth_session.dart';
import '../../auth/data/routes/auth_api_routes.dart';
import '../../auth/data/services/auth_api_service.dart';
import '../../auth/data/services/auth_session_storage.dart';
import '../data/models/partnership_models.dart';
import '../data/routes/partnerships_api_routes.dart';
import '../data/services/partnerships_api_service.dart';

class PartnershipService {
  PartnershipService({
    required PartnershipsApiService partnershipsApiService,
    required AuthApiService authApiService,
    required AuthSessionStorage sessionStorage,
  }) : _partnershipsApiService = partnershipsApiService,
       _authApiService = authApiService,
       _sessionStorage = sessionStorage;

  factory PartnershipService.createDefault() {
    final apiClient = ApiClient(baseUrlResolver: () => AppEnv.apiBaseUrl);

    return PartnershipService(
      partnershipsApiService: PartnershipsApiService(
        apiClient: apiClient,
        routes: PartnershipsApiRoutes.instance,
      ),
      authApiService: AuthApiService(
        apiClient: apiClient,
        routes: AuthApiRoutes.instance,
      ),
      sessionStorage: AuthSessionStorage(
        secureStorageService: SecureStorageService(),
      ),
    );
  }

  final PartnershipsApiService _partnershipsApiService;
  final AuthApiService _authApiService;
  final AuthSessionStorage _sessionStorage;

  Future<Partnership?> getMyPartnership() async {
    final session = await _resolveActiveSession();
    return _partnershipsApiService.fetchMyPartnership(session.accessToken);
  }

  Future<Partnership> invitePartner({required String email}) async {
    final session = await _resolveActiveSession();
    return _partnershipsApiService.invitePartner(
      accessToken: session.accessToken,
      email: email,
    );
  }

  Future<void> cancelPendingInvite() async {
    final session = await _resolveActiveSession();
    await _partnershipsApiService.cancelPendingInvite(
      accessToken: session.accessToken,
    );
  }

  Future<void> removePartnership() async {
    final session = await _resolveActiveSession();
    await _partnershipsApiService.removePartnership(
      accessToken: session.accessToken,
    );
  }

  Future<InviteInfo> getInviteInfo(String inviteToken) {
    return _partnershipsApiService.fetchInviteInfo(inviteToken);
  }

  Future<Partnership> acceptInvite({required String inviteToken}) async {
    final session = await _resolveActiveSession();
    return _partnershipsApiService.acceptInvite(
      accessToken: session.accessToken,
      inviteToken: inviteToken,
    );
  }

  Future<AuthSession> _resolveActiveSession() async {
    final session = await _sessionStorage.read();

    if (session == null) {
      throw StateError(
        'No active session is available for partnership requests.',
      );
    }

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
