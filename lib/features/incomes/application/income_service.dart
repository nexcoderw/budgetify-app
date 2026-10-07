import '../../../core/config/app_env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../auth/data/models/auth_session.dart';
import '../../auth/data/routes/auth_api_routes.dart';
import '../../auth/data/services/auth_api_service.dart';
import '../../auth/data/services/auth_session_storage.dart';
import '../data/models/income.dart';
import '../data/services/income_api_service.dart';

class IncomeService {
  IncomeService({
    required IncomeApiService api,
    required AuthApiService auth,
    required AuthSessionStorage storage,
  }) : _api = api,
       _auth = auth,
       _storage = storage;

  factory IncomeService.createDefault() {
    final client = ApiClient(baseUrlResolver: () => AppEnv.apiBaseUrl);
    return IncomeService(
      api: IncomeApiService(client),
      auth: AuthApiService(apiClient: client, routes: AuthApiRoutes.instance),
      storage: AuthSessionStorage(secureStorageService: SecureStorageService()),
    );
  }
  final IncomeApiService _api;
  final AuthApiService _auth;
  final AuthSessionStorage _storage;

  Future<IncomePageResult> list({
    int page = 1,
    String? status,
    String? search,
  }) => _authorized(
    (token) => _api.list(token, page: page, status: status, search: search),
  );
  Future<void> save(Map<String, dynamic> body, {String? id}) => _authorized(
    (token) =>
        id == null ? _api.create(token, body) : _api.update(token, id, body),
  );
  Future<void> receive(String id, DateTime date) =>
      _authorized((token) => _api.receive(token, id, date));
  Future<Map<String, dynamic>> payments(String id, int page) =>
      _authorized((token) => _api.payments(token, id, page));
  Future<void> link(String id, String paymentId) =>
      _authorized((token) => _api.link(token, id, paymentId));
  Future<void> archive(String id) =>
      _authorized((token) => _api.archive(token, id));

  Future<T> _authorized<T>(Future<T> Function(String token) request) async {
    var session = await _storage.read();
    if (session == null) {
      throw StateError('No authenticated session was found.');
    }
    if (session.needsRefresh) session = await _refresh(session);
    try {
      return await request(session.accessToken);
    } on ApiException catch (error) {
      if (error.statusCode != 401) rethrow;
      session = await _refresh(session);
      return request(session.accessToken);
    }
  }

  Future<AuthSession> _refresh(AuthSession session) async {
    final refreshed = await _auth.refreshSession(session.refreshToken);
    await _storage.save(refreshed);
    return refreshed;
  }
}
