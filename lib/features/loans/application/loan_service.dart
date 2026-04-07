import '../../../core/config/app_env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paginated_response.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../auth/data/models/auth_session.dart';
import '../../auth/data/routes/auth_api_routes.dart';
import '../../auth/data/services/auth_api_service.dart';
import '../../auth/data/services/auth_session_storage.dart';
import '../data/models/loan_entry.dart';
import '../data/models/loan_list_query.dart';
import '../data/routes/loans_api_routes.dart';
import '../data/services/loans_api_service.dart';

class LoanService {
  LoanService({
    required LoansApiService loansApiService,
    required AuthApiService authApiService,
    required AuthSessionStorage sessionStorage,
  }) : _loansApiService = loansApiService,
       _authApiService = authApiService,
       _sessionStorage = sessionStorage;

  factory LoanService.createDefault() {
    final apiClient = ApiClient(baseUrlResolver: () => AppEnv.apiBaseUrl);

    return LoanService(
      loansApiService: LoansApiService(
        apiClient: apiClient,
        routes: LoansApiRoutes.instance,
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

  final LoansApiService _loansApiService;
  final AuthApiService _authApiService;
  final AuthSessionStorage _sessionStorage;

  Future<List<LoanEntry>> listLoans({
    LoanListQuery query = const LoanListQuery(),
  }) async {
    final session = await _resolveActiveSession();
    return _loansApiService.fetchLoans(session.accessToken, query: query);
  }

  Future<PaginatedResponse<LoanEntry>> listLoansPage({
    LoanListQuery query = const LoanListQuery(),
  }) async {
    final session = await _resolveActiveSession();
    return _loansApiService.fetchLoansPage(session.accessToken, query: query);
  }

  Future<LoanEntry> createLoan({
    required String label,
    required double amount,
    required DateTime date,
    bool paid = false,
    String? note,
  }) async {
    final session = await _resolveActiveSession();
    return _loansApiService.createLoan(
      accessToken: session.accessToken,
      label: label,
      amount: amount,
      date: date,
      paid: paid,
      note: note,
    );
  }

  Future<LoanEntry> updateLoan({
    required String loanId,
    String? label,
    double? amount,
    DateTime? date,
    bool? paid,
    String? note,
  }) async {
    final session = await _resolveActiveSession();
    return _loansApiService.updateLoan(
      accessToken: session.accessToken,
      loanId: loanId,
      label: label,
      amount: amount,
      date: date,
      paid: paid,
      note: note,
    );
  }

  Future<LoanSettlementResponse> sendLoanToExpense({
    required String loanId,
    required DateTime date,
    String? note,
  }) async {
    final session = await _resolveActiveSession();
    return _loansApiService.sendLoanToExpense(
      accessToken: session.accessToken,
      loanId: loanId,
      date: date,
      note: note,
    );
  }

  Future<void> deleteLoan(String loanId) async {
    final session = await _resolveActiveSession();
    await _loansApiService.deleteLoan(
      accessToken: session.accessToken,
      loanId: loanId,
    );
  }

  Future<AuthSession> _resolveActiveSession() async {
    final session = await _sessionStorage.read();

    if (session == null) {
      throw StateError('No active session is available for loan requests.');
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
