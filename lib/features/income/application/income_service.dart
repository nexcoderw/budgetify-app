import '../../../core/config/app_env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../auth/data/models/auth_session.dart';
import '../../auth/data/routes/auth_api_routes.dart';
import '../../auth/data/services/auth_api_service.dart';
import '../../auth/data/services/auth_session_storage.dart';
import '../data/models/income_entry.dart';
import '../data/models/income_list_query.dart';
import '../data/routes/income_api_routes.dart';
import '../data/services/income_api_service.dart';
import '../../../core/network/paginated_response.dart';

class IncomeService {
  IncomeService({
    required IncomeApiService incomeApiService,
    required AuthApiService authApiService,
    required AuthSessionStorage sessionStorage,
  }) : _incomeApiService = incomeApiService,
       _authApiService = authApiService,
       _sessionStorage = sessionStorage;

  factory IncomeService.createDefault() {
    final apiClient = ApiClient(baseUrlResolver: () => AppEnv.apiBaseUrl);

    return IncomeService(
      incomeApiService: IncomeApiService(
        apiClient: apiClient,
        routes: IncomeApiRoutes.instance,
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

  final IncomeApiService _incomeApiService;
  final AuthApiService _authApiService;
  final AuthSessionStorage _sessionStorage;

  Future<List<IncomeEntry>> listIncome({
    IncomeListQuery query = const IncomeListQuery(),
  }) async {
    final session = await _resolveActiveSession();

    return _incomeApiService.fetchIncome(session.accessToken, query: query);
  }

  Future<PaginatedResponse<IncomeEntry>> listIncomePage({
    IncomeListQuery query = const IncomeListQuery(),
  }) async {
    final session = await _resolveActiveSession();

    return _incomeApiService.fetchIncomePage(session.accessToken, query: query);
  }

  Future<IncomeEntry> createIncome({
    required String label,
    required double amount,
    CurrencyCode currency = CurrencyCode.rwf,
    required IncomeCategory category,
    required DateTime date,
    bool received = false,
  }) async {
    final session = await _resolveActiveSession();

    return _incomeApiService.createIncome(
      accessToken: session.accessToken,
      label: label,
      amount: amount,
      currency: currency,
      category: category,
      date: date,
      received: received,
    );
  }

  Future<IncomeEntry> updateIncome({
    required String incomeId,
    required String label,
    required double amount,
    CurrencyCode currency = CurrencyCode.rwf,
    required IncomeCategory category,
    required DateTime date,
    bool? received,
  }) async {
    final session = await _resolveActiveSession();

    return _incomeApiService.updateIncome(
      accessToken: session.accessToken,
      incomeId: incomeId,
      label: label,
      amount: amount,
      currency: currency,
      category: category,
      date: date,
      received: received,
    );
  }

  Future<void> deleteIncome(String incomeId) async {
    final session = await _resolveActiveSession();

    await _incomeApiService.deleteIncome(
      accessToken: session.accessToken,
      incomeId: incomeId,
    );
  }

  Future<AuthSession> _resolveActiveSession() async {
    final session = await _sessionStorage.read();

    if (session == null) {
      throw StateError('No active session is available for income requests.');
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
