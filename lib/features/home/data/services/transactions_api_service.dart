import '../../../../core/network/api_client.dart';
import '../models/transaction_analytics_models.dart';
import '../models/transaction_models.dart';
import '../routes/transactions_api_routes.dart';

class TransactionsApiService {
  TransactionsApiService({
    required ApiClient apiClient,
    required TransactionsApiRoutes routes,
  }) : _apiClient = apiClient,
       _routes = routes;

  final ApiClient _apiClient;
  final TransactionsApiRoutes _routes;

  Map<String, String> _authorizedHeaders(String accessToken) {
    return <String, String>{'Authorization': 'Bearer $accessToken'};
  }

  Future<TransactionListResult> list({
    required String accessToken,
    int page = 1,
    int limit = 20,
    TransactionStatus? status,
    TransactionTransferType? transferType,
    TransactionRecipientType? recipientType,
    TransactionCategory? category,
    DateTime? from,
    DateTime? to,
    String? search,
  }) async {
    final json = await _apiClient.getJson(
      _routes.list,
      headers: _authorizedHeaders(accessToken),
      queryParameters: <String, dynamic>{
        'page': page,
        'limit': limit,
        'status': status?.apiValue,
        'transferType': transferType?.apiValue,
        'recipientType': recipientType?.apiValue,
        'category': category?.apiValue,
        'from': from,
        'to': to,
        'search': search?.trim().isEmpty ?? true ? null : search!.trim(),
      },
    );

    return TransactionListResult.fromJson(json);
  }

  Future<TransactionAnalytics> analytics({
    required String accessToken,
    required DateTime from,
    required DateTime to,
  }) async {
    if (from.isAfter(to)) {
      throw ArgumentError(
        'Analytics start date must not occur after its end date.',
      );
    }

    final json = await _apiClient.getJson(
      _routes.analytics,
      headers: _authorizedHeaders(accessToken),
      queryParameters: <String, dynamic>{
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
      },
    );

    return TransactionAnalytics.fromJson(json);
  }

  Future<TransactionDetail> getDetail({
    required String accessToken,
    required String transactionId,
  }) async {
    final json = await _apiClient.getJson(
      _routes.detail(transactionId),
      headers: _authorizedHeaders(accessToken),
    );

    return TransactionDetail.fromJson(json);
  }

  Future<TransactionQuote> quote({
    required String accessToken,
    required int amount,
    required TransactionTransferType transferType,
  }) async {
    final json = await _apiClient.postJson(
      _routes.quote,
      headers: _authorizedHeaders(accessToken),
      body: <String, dynamic>{
        'amount': amount,
        'transferType': transferType.apiValue,
      },
    );

    return TransactionQuote.fromJson(json);
  }

  Future<PaymentTransaction> create({
    required String accessToken,
    required int amount,
    required TransactionTransferType transferType,
    required TransactionRecipientType recipientType,
    required TransactionCategory category,
    required String receiverIdentifier,
    required String idempotencyKey,
  }) async {
    final json = await _apiClient.postJson(
      _routes.create,
      headers: _authorizedHeaders(accessToken),
      body: <String, dynamic>{
        'amount': amount,
        'transferType': transferType.apiValue,
        'recipientType': recipientType.apiValue,
        'category': category.apiValue,
        'receiverIdentifier': receiverIdentifier,
        'idempotencyKey': idempotencyKey,
      },
    );

    return PaymentTransaction.fromJson(json);
  }

  Future<PaymentTransaction> recordUssdOpened({
    required String accessToken,
    required String transactionId,
    required String clientEventId,
  }) async {
    final json = await _apiClient.postJson(
      _routes.ussdOpened(transactionId),
      headers: _authorizedHeaders(accessToken),
      body: <String, dynamic>{'clientEventId': clientEventId},
    );

    return PaymentTransaction.fromJson(json);
  }

  Future<PaymentTransaction> recordProviderSmsResult({
    required String accessToken,
    required String transactionId,
    required String clientEventId,
    required int amount,
    required TransactionStatus status,
    required DateTime occurredAt,
    String? providerReference,
    String? receiverName,
    String? failureCode,
    String? failureReason,
  }) async {
    if (status != TransactionStatus.completed &&
        status != TransactionStatus.failed &&
        status != TransactionStatus.cancelled) {
      throw ArgumentError.value(
        status,
        'status',
        'Provider SMS result must be completed, failed, or cancelled.',
      );
    }

    final json = await _apiClient.postJson(
      _routes.providerSmsResult(transactionId),
      headers: _authorizedHeaders(accessToken),
      body: <String, dynamic>{
        'clientEventId': clientEventId,
        'amount': amount,
        'status': status.apiValue,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        'providerReference': ?providerReference,
        'receiverName': ?receiverName,
        'failureCode': ?failureCode,
        'failureReason': ?failureReason,
      },
    );

    return PaymentTransaction.fromJson(json);
  }

  Future<PaymentTransaction> recordManualResult({
    required String accessToken,
    required String transactionId,
    required String clientEventId,
    required TransactionStatus status,
  }) async {
    if (status != TransactionStatus.completed &&
        status != TransactionStatus.failed) {
      throw ArgumentError.value(
        status,
        'status',
        'Manual result must be completed or failed.',
      );
    }

    final json = await _apiClient.postJson(
      _routes.manualResult(transactionId),
      headers: _authorizedHeaders(accessToken),
      body: <String, dynamic>{
        'clientEventId': clientEventId,
        'status': status.apiValue,
      },
    );

    return PaymentTransaction.fromJson(json);
  }
}
