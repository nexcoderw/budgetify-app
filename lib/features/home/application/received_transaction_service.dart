import '../../../core/config/app_env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../auth/data/models/auth_session.dart';
import '../../auth/data/routes/auth_api_routes.dart';
import '../../auth/data/services/auth_api_service.dart';
import '../../auth/data/services/auth_session_storage.dart';
import '../data/models/received_transaction_models.dart';
import '../data/routes/received_transactions_api_routes.dart';
import '../data/services/received_transactions_api_service.dart';

class ReceivedTransactionService {
  ReceivedTransactionService({
    required ReceivedTransactionsApiService receivedTransactionsApiService,
    required AuthApiService authApiService,
    required AuthSessionStorage sessionStorage,
  }) : _receivedTransactionsApiService = receivedTransactionsApiService,
       _authApiService = authApiService,
       _sessionStorage = sessionStorage;

  factory ReceivedTransactionService.createDefault() {
    final apiClient = ApiClient(baseUrlResolver: () => AppEnv.apiBaseUrl);

    return ReceivedTransactionService(
      receivedTransactionsApiService: ReceivedTransactionsApiService(
        apiClient: apiClient,
        routes: ReceivedTransactionsApiRoutes.instance,
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

  final ReceivedTransactionsApiService _receivedTransactionsApiService;

  final AuthApiService _authApiService;

  final AuthSessionStorage _sessionStorage;

  Future<ReceivedTransactionListResult> list({
    int page = 1,
    int limit = 20,
    ReceivedTransactionStatus? status,
    ReceivedTransactionEvidenceSource? evidenceSource,
    ReceivedTransactionClassification? classification,
    DateTime? from,
    DateTime? to,
    String? search,
  }) {
    return _authorized((accessToken) {
      return _receivedTransactionsApiService.list(
        accessToken: accessToken,
        page: page,
        limit: limit,
        status: status,
        evidenceSource: evidenceSource,
        classification: classification,
        from: from,
        to: to,
        search: search,
      );
    });
  }

  Future<ReceivedTransaction> getDetail({
    required String receivedTransactionId,
  }) {
    return _authorized((accessToken) {
      return _receivedTransactionsApiService.getDetail(
        accessToken: accessToken,
        receivedTransactionId: receivedTransactionId,
      );
    });
  }

  Future<ReceivedTransaction> recordProviderSms({
    required String clientEventId,
    required int amount,
    required String providerReference,
    required DateTime occurredAt,
    String? senderIdentifier,
    String? senderName,
  }) {
    return _authorized((accessToken) {
      return _receivedTransactionsApiService.recordProviderSms(
        accessToken: accessToken,
        clientEventId: clientEventId,
        amount: amount,
        providerReference: providerReference,
        occurredAt: occurredAt,
        senderIdentifier: senderIdentifier,
        senderName: senderName,
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

  Future<ReceivedTransaction> recordManual({
    required String clientEventId,
    required int amount,
    required DateTime occurredAt,
    String? senderIdentifier,
    String? senderName,
    String? providerReference,
  }) {
    return _authorized((accessToken) {
      return _receivedTransactionsApiService.recordManual(
        accessToken: accessToken,
        clientEventId: clientEventId,
        amount: amount,
        occurredAt: occurredAt,
        senderIdentifier: senderIdentifier,
        senderName: senderName,
        providerReference: providerReference,
      );
    });
  }
}
