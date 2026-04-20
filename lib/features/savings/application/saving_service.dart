import '../../../core/config/app_env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paginated_response.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../auth/data/models/auth_session.dart';
import '../../auth/data/routes/auth_api_routes.dart';
import '../../auth/data/services/auth_api_service.dart';
import '../../auth/data/services/auth_session_storage.dart';
import '../data/models/saving_entry.dart';
import '../data/models/saving_list_query.dart';
import '../data/routes/savings_api_routes.dart';
import '../data/services/savings_api_service.dart';

class SavingService {
  SavingService({
    required SavingsApiService savingsApiService,
    required AuthApiService authApiService,
    required AuthSessionStorage sessionStorage,
  }) : _savingsApiService = savingsApiService,
       _authApiService = authApiService,
       _sessionStorage = sessionStorage;

  factory SavingService.createDefault() {
    final apiClient = ApiClient(baseUrlResolver: () => AppEnv.apiBaseUrl);

    return SavingService(
      savingsApiService: SavingsApiService(
        apiClient: apiClient,
        routes: SavingsApiRoutes.instance,
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

  final SavingsApiService _savingsApiService;
  final AuthApiService _authApiService;
  final AuthSessionStorage _sessionStorage;

  Future<List<SavingEntry>> listSavings({
    SavingListQuery query = const SavingListQuery(),
  }) async {
    final session = await _resolveActiveSession();
    return _savingsApiService.fetchSavings(session.accessToken, query: query);
  }

  Future<PaginatedResponse<SavingEntry>> listSavingsPage({
    SavingListQuery query = const SavingListQuery(),
  }) async {
    final session = await _resolveActiveSession();
    return _savingsApiService.fetchSavingsPage(
      session.accessToken,
      query: query,
    );
  }

  Future<SavingEntry> createSaving({
    required String label,
    required double amount,
    SavingCurrencyCode currency = SavingCurrencyCode.rwf,
    required DateTime date,
    String? note,
    bool stillHave = true,
  }) async {
    final session = await _resolveActiveSession();

    return _savingsApiService.createSaving(
      accessToken: session.accessToken,
      label: label,
      amount: amount,
      currency: currency,
      date: date,
      note: note,
      stillHave: stillHave,
    );
  }

  Future<SavingEntry> updateSaving({
    required String savingId,
    String? label,
    double? amount,
    SavingCurrencyCode? currency,
    DateTime? date,
    String? note,
    bool? stillHave,
  }) async {
    final session = await _resolveActiveSession();

    return _savingsApiService.updateSaving(
      accessToken: session.accessToken,
      savingId: savingId,
      label: label,
      amount: amount,
      currency: currency,
      date: date,
      note: note,
      stillHave: stillHave,
    );
  }

  Future<List<SavingTransactionEntry>> listSavingTransactions(
    String savingId,
  ) async {
    final session = await _resolveActiveSession();

    return _savingsApiService.fetchSavingTransactions(
      accessToken: session.accessToken,
      savingId: savingId,
    );
  }

  Future<SavingEntry> createSavingDeposit({
    required String savingId,
    required double amount,
    SavingCurrencyCode currency = SavingCurrencyCode.rwf,
    required DateTime date,
    String? note,
    required List<SavingDepositIncomeSource> incomeSources,
  }) async {
    final session = await _resolveActiveSession();

    return _savingsApiService.createSavingDeposit(
      accessToken: session.accessToken,
      savingId: savingId,
      amount: amount,
      currency: currency,
      date: date,
      note: note,
      incomeSources: incomeSources,
    );
  }

  Future<void> deleteSaving(String savingId) async {
    final session = await _resolveActiveSession();

    await _savingsApiService.deleteSaving(
      accessToken: session.accessToken,
      savingId: savingId,
    );
  }

  Future<AuthSession> _resolveActiveSession() async {
    final session = await _sessionStorage.read();

    if (session == null) {
      throw StateError('No active session is available for saving requests.');
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
