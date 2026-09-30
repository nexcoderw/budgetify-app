import '../../../core/config/app_env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../auth/data/models/auth_session.dart';
import '../../auth/data/routes/auth_api_routes.dart';
import '../../auth/data/services/auth_api_service.dart';
import '../../auth/data/services/auth_session_storage.dart';
import '../data/models/transaction_models.dart';
import '../data/routes/transactions_api_routes.dart';
import '../data/services/transactions_api_service.dart';

class TransactionService {
  TransactionService({
    required TransactionsApiService transactionsApiService,
    required AuthApiService authApiService,
    required AuthSessionStorage sessionStorage,
  }) : _transactionsApiService = transactionsApiService,
       _authApiService = authApiService,
       _sessionStorage = sessionStorage;

  factory TransactionService.createDefault() {
    final apiClient = ApiClient(baseUrlResolver: () => AppEnv.apiBaseUrl);

    return TransactionService(
      transactionsApiService: TransactionsApiService(
        apiClient: apiClient,
        routes: TransactionsApiRoutes.instance,
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

  final TransactionsApiService _transactionsApiService;

  final AuthApiService _authApiService;
  final AuthSessionStorage _sessionStorage;

  Future<TransactionListResult> list({
    int page = 1,
    int limit = 20,
    TransactionStatus? status,
    TransactionTransferType? transferType,
    TransactionRecipientType? recipientType,
    TransactionCategory? category,
    DateTime? from,
    DateTime? to,
    String? search,
  }) {
    return _authorized((accessToken) {
      return _transactionsApiService.list(
        accessToken: accessToken,
        page: page,
        limit: limit,
        status: status,
        transferType: transferType,
        recipientType: recipientType,
        category: category,
        from: from,
        to: to,
        search: search,
      );
    });
  }

  Future<TransactionDetail> getDetail({required String transactionId}) {
    return _authorized((accessToken) {
      return _transactionsApiService.getDetail(
        accessToken: accessToken,
        transactionId: transactionId,
      );
    });
  }

  Future<TransactionQuote> quote({
    required int amount,
    required TransactionTransferType transferType,
  }) {
    return _authorized((accessToken) {
      return _transactionsApiService.quote(
        accessToken: accessToken,
        amount: amount,
        transferType: transferType,
      );
    });
  }

  Future<PaymentTransaction> create({
    required int amount,
    required TransactionTransferType transferType,
    required TransactionRecipientType recipientType,
    required TransactionCategory category,
    required String receiverIdentifier,
    required String idempotencyKey,
  }) {
    return _authorized((accessToken) {
      return _transactionsApiService.create(
        accessToken: accessToken,
        amount: amount,
        transferType: transferType,
        recipientType: recipientType,
        category: category,
        receiverIdentifier: receiverIdentifier,
        idempotencyKey: idempotencyKey,
      );
    });
  }

  Future<PaymentTransaction> recordUssdOpened({
    required String transactionId,
    required String clientEventId,
  }) {
    return _authorized((accessToken) {
      return _transactionsApiService.recordUssdOpened(
        accessToken: accessToken,
        transactionId: transactionId,
        clientEventId: clientEventId,
      );
    });
  }

  Future<T> _authorized<T>(
    Future<T> Function(String accessToken) request,
  ) async {
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

  Future<PaymentTransaction> recordProviderSmsResult({
    required String transactionId,
    required String clientEventId,
    required int amount,
    required TransactionStatus status,
    required DateTime occurredAt,
    String? providerReference,
    String? receiverName,
    String? failureCode,
    String? failureReason,
  }) {
    return _authorized((accessToken) {
      return _transactionsApiService.recordProviderSmsResult(
        accessToken: accessToken,
        transactionId: transactionId,
        clientEventId: clientEventId,
        amount: amount,
        status: status,
        occurredAt: occurredAt,
        providerReference: providerReference,
        receiverName: receiverName,
        failureCode: failureCode,
        failureReason: failureReason,
      );
    });
  }
}
