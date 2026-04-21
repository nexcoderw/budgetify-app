import '../../../core/config/app_env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paginated_response.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../auth/data/models/auth_session.dart';
import '../../auth/data/routes/auth_api_routes.dart';
import '../../auth/data/services/auth_api_service.dart';
import '../../auth/data/services/auth_session_storage.dart';
import '../data/models/expense_entry.dart';
import '../data/models/expense_list_query.dart';
import '../data/routes/expenses_api_routes.dart';
import '../data/services/expenses_api_service.dart';

class ExpenseService {
  ExpenseService({
    required ExpensesApiService expensesApiService,
    required AuthApiService authApiService,
    required AuthSessionStorage sessionStorage,
  }) : _expensesApiService = expensesApiService,
       _authApiService = authApiService,
       _sessionStorage = sessionStorage;

  factory ExpenseService.createDefault() {
    final apiClient = ApiClient(baseUrlResolver: () => AppEnv.apiBaseUrl);

    return ExpenseService(
      expensesApiService: ExpensesApiService(
        apiClient: apiClient,
        routes: ExpensesApiRoutes.instance,
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

  final ExpensesApiService _expensesApiService;
  final AuthApiService _authApiService;
  final AuthSessionStorage _sessionStorage;

  Future<List<ExpenseCategoryOption>> listExpenseCategories() async {
    final session = await _resolveActiveSession();
    return _expensesApiService.fetchExpenseCategories(session.accessToken);
  }

  Future<List<ExpenseEntry>> listExpenses({
    ExpenseListQuery query = const ExpenseListQuery(),
  }) async {
    final session = await _resolveActiveSession();
    return _expensesApiService.fetchExpenses(session.accessToken, query: query);
  }

  Future<PaginatedResponse<ExpenseEntry>> listExpensesPage({
    ExpenseListQuery query = const ExpenseListQuery(),
  }) async {
    final session = await _resolveActiveSession();
    return _expensesApiService.fetchExpensesPage(
      session.accessToken,
      query: query,
    );
  }

  Future<ExpenseSummary> getExpenseSummary({
    ExpenseListQuery query = const ExpenseListQuery(),
  }) async {
    final session = await _resolveActiveSession();
    return _expensesApiService.fetchExpenseSummary(
      session.accessToken,
      query: query,
    );
  }

  Future<ExpenseAudit> getExpenseAudit({
    ExpenseListQuery query = const ExpenseListQuery(),
  }) async {
    final session = await _resolveActiveSession();
    return _expensesApiService.fetchExpenseAudit(
      session.accessToken,
      query: query,
    );
  }

  Future<MobileMoneyQuote> quoteMobileMoneyExpense({
    required double amount,
    ExpenseCurrency currency = ExpenseCurrency.rwf,
    required ExpenseMobileMoneyProvider mobileMoneyProvider,
    required ExpenseMobileMoneyChannel mobileMoneyChannel,
    ExpenseMobileMoneyNetwork? mobileMoneyNetwork,
  }) async {
    final session = await _resolveActiveSession();
    return _expensesApiService.quoteMobileMoneyExpense(
      accessToken: session.accessToken,
      amount: amount,
      currency: currency,
      mobileMoneyProvider: mobileMoneyProvider,
      mobileMoneyChannel: mobileMoneyChannel,
      mobileMoneyNetwork: mobileMoneyNetwork,
    );
  }

  Future<ExpenseEntry> createExpense({
    required String label,
    required double amount,
    ExpenseCurrency currency = ExpenseCurrency.rwf,
    required ExpenseCategory category,
    ExpensePaymentMethod paymentMethod = ExpensePaymentMethod.cash,
    ExpenseMobileMoneyChannel? mobileMoneyChannel,
    ExpenseMobileMoneyProvider? mobileMoneyProvider,
    ExpenseMobileMoneyNetwork? mobileMoneyNetwork,
    required DateTime date,
    String? note,
  }) async {
    final session = await _resolveActiveSession();

    return _expensesApiService.createExpense(
      accessToken: session.accessToken,
      label: label,
      amount: amount,
      currency: currency,
      category: category,
      paymentMethod: paymentMethod,
      mobileMoneyChannel: mobileMoneyChannel,
      mobileMoneyProvider: mobileMoneyProvider,
      mobileMoneyNetwork: mobileMoneyNetwork,
      date: date,
      note: note,
    );
  }

  Future<ExpenseEntry> updateExpense({
    required String expenseId,
    required String label,
    required double amount,
    ExpenseCurrency currency = ExpenseCurrency.rwf,
    required ExpenseCategory category,
    ExpensePaymentMethod paymentMethod = ExpensePaymentMethod.cash,
    ExpenseMobileMoneyChannel? mobileMoneyChannel,
    ExpenseMobileMoneyProvider? mobileMoneyProvider,
    ExpenseMobileMoneyNetwork? mobileMoneyNetwork,
    required DateTime date,
    String? note,
  }) async {
    final session = await _resolveActiveSession();

    return _expensesApiService.updateExpense(
      accessToken: session.accessToken,
      expenseId: expenseId,
      label: label,
      amount: amount,
      currency: currency,
      category: category,
      paymentMethod: paymentMethod,
      mobileMoneyChannel: mobileMoneyChannel,
      mobileMoneyProvider: mobileMoneyProvider,
      mobileMoneyNetwork: mobileMoneyNetwork,
      date: date,
      note: note,
    );
  }

  Future<void> deleteExpense(String expenseId) async {
    final session = await _resolveActiveSession();

    await _expensesApiService.deleteExpense(
      accessToken: session.accessToken,
      expenseId: expenseId,
    );
  }

  Future<AuthSession> _resolveActiveSession() async {
    final session = await _sessionStorage.read();

    if (session == null) {
      throw StateError('No active session is available for expense requests.');
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
