import '../../../core/config/app_env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../auth/data/models/auth_session.dart';
import '../../auth/data/routes/auth_api_routes.dart';
import '../../auth/data/services/auth_api_service.dart';
import '../../auth/data/services/auth_session_storage.dart';
import '../data/models/shortcut_import_credential.dart';
import '../data/routes/shortcut_import_credential_routes.dart';
import '../data/services/shortcut_import_credential_api_service.dart';

class ShortcutImportCredentialService {
  ShortcutImportCredentialService({
    required ShortcutImportCredentialApiService apiService,
    required AuthApiService authApiService,
    required AuthSessionStorage sessionStorage,
  }) : _apiService = apiService,
       _authApiService = authApiService,
       _sessionStorage = sessionStorage;

  factory ShortcutImportCredentialService.createDefault() {
    final apiClient = ApiClient(baseUrlResolver: () => AppEnv.apiBaseUrl);
    return ShortcutImportCredentialService(
      apiService: ShortcutImportCredentialApiService(
        apiClient: apiClient,
        routes: ShortcutImportCredentialRoutes.instance,
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

  final ShortcutImportCredentialApiService _apiService;
  final AuthApiService _authApiService;
  final AuthSessionStorage _sessionStorage;

  String get importEndpoint {
    return '${AppEnv.apiBaseUrl}${ShortcutImportCredentialRoutes.importMessage}';
  }

  Future<List<ShortcutImportCredential>> list() {
    return _authorized(_apiService.list);
  }

  Future<ShortcutImportCredential> create(String deviceName) {
    return _authorized(
      (token) => _apiService.create(accessToken: token, deviceName: deviceName),
    );
  }

  Future<ShortcutImportCredential> rotate(String id) {
    return _authorized(
      (token) => _apiService.rotate(accessToken: token, id: id),
    );
  }

  Future<void> revoke(String id) {
    return _authorized(
      (token) => _apiService.revoke(accessToken: token, id: id),
    );
  }

  Future<T> _authorized<T>(Future<T> Function(String token) request) async {
    var session = await _sessionStorage.read();
    if (session == null) {
      throw StateError('No authenticated session was found.');
    }
    if (session.needsRefresh) {
      session = await _refresh(session);
    }
    try {
      return await request(session.accessToken);
    } on ApiException catch (error) {
      if (error.statusCode != 401) {
        rethrow;
      }
      session = await _refresh(session);
      return request(session.accessToken);
    }
  }

  Future<AuthSession> _refresh(AuthSession session) async {
    final refreshed = await _authApiService.refreshSession(
      session.refreshToken,
    );
    await _sessionStorage.save(refreshed);
    return refreshed;
  }
}
