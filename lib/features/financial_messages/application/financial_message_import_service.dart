import '../../../core/config/app_env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../auth/data/models/auth_session.dart';
import '../../auth/data/routes/auth_api_routes.dart';
import '../../auth/data/services/auth_api_service.dart';
import '../../auth/data/services/auth_session_storage.dart';
import '../../home/data/models/received_transaction_models.dart';
import '../../incomes/data/models/income.dart';
import '../data/models/financial_message_import.dart';
import '../data/models/financial_message_pilot_summary.dart';
import '../data/routes/financial_message_import_routes.dart';
import '../data/services/financial_message_import_api_service.dart';

class FinancialMessageImportService {
  FinancialMessageImportService({
    required FinancialMessageImportApiService apiService,
    required AuthApiService authApiService,
    required AuthSessionStorage sessionStorage,
  }) : _apiService = apiService,
       _authApiService = authApiService,
       _sessionStorage = sessionStorage;

  factory FinancialMessageImportService.createDefault() {
    final apiClient = ApiClient(baseUrlResolver: () => AppEnv.apiBaseUrl);
    return FinancialMessageImportService(
      apiService: FinancialMessageImportApiService(
        apiClient: apiClient,
        routes: FinancialMessageImportRoutes.instance,
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

  final FinancialMessageImportApiService _apiService;
  final AuthApiService _authApiService;
  final AuthSessionStorage _sessionStorage;

  Future<FinancialMessageImportPage> list({
    required FinancialMessageImportStatus status,
    int page = 1,
    int limit = 20,
  }) => _authorized(
    (token) => _apiService.list(
      accessToken: token,
      status: status,
      page: page,
      limit: limit,
    ),
  );

  Future<FinancialMessagePilotSummary> pilotSummary({int days = 30}) =>
      _authorized(
        (token) => _apiService.pilotSummary(accessToken: token, days: days),
      );

  Future<FinancialMessageImport> detail(String id) =>
      _authorized((token) => _apiService.detail(accessToken: token, id: id));

  Future<FinancialMessageImport> update({
    required String id,
    required int amount,
    required DateTime occurredAt,
    String? senderName,
    String? senderIdentifier,
    String? providerReference,
  }) => _authorized(
    (token) => _apiService.update(
      accessToken: token,
      id: id,
      amount: amount,
      occurredAt: occurredAt,
      senderName: senderName,
      senderIdentifier: senderIdentifier,
      providerReference: providerReference,
    ),
  );

  Future<void> confirm({
    required String id,
    required ReceivedTransactionClassification classification,
    required bool createIncome,
    String? note,
    IncomeCategory? incomeCategory,
    String? incomeLabel,
  }) => _authorized(
    (token) => _apiService.confirm(
      accessToken: token,
      id: id,
      classification: classification,
      createIncome: createIncome,
      note: note,
      incomeCategory: incomeCategory,
      incomeLabel: incomeLabel,
    ),
  );

  Future<void> dismiss(String id) =>
      _authorized((token) => _apiService.dismiss(accessToken: token, id: id));

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
