import '../../../../core/network/api_client.dart';
import '../models/received_transaction_models.dart';
import '../routes/received_transactions_api_routes.dart';

class ReceivedTransactionsApiService {
  ReceivedTransactionsApiService({
    required ApiClient apiClient,
    required ReceivedTransactionsApiRoutes routes,
  }) : _apiClient = apiClient,
       _routes = routes;

  final ApiClient _apiClient;

  final ReceivedTransactionsApiRoutes _routes;

  Map<String, String> _authorizedHeaders(String accessToken) {
    return <String, String>{'Authorization': 'Bearer $accessToken'};
  }

  Future<ReceivedTransactionListResult> list({
    required String accessToken,
    int page = 1,
    int limit = 20,
    ReceivedTransactionStatus? status,
    ReceivedTransactionEvidenceSource? evidenceSource,
    ReceivedTransactionClassification? classification,
    DateTime? from,
    DateTime? to,
    String? search,
  }) async {
    final normalizedSearch = search?.trim();

    final json = await _apiClient.getJson(
      _routes.list,
      headers: _authorizedHeaders(accessToken),
      queryParameters: <String, dynamic>{
        'page': page,
        'limit': limit,
        'status': status?.apiValue,
        'evidenceSource': evidenceSource?.apiValue,
        'classification': classification?.apiValue,
        'from': from?.toUtc().toIso8601String(),
        'to': to?.toUtc().toIso8601String(),
        'search': normalizedSearch == null || normalizedSearch.isEmpty
            ? null
            : normalizedSearch,
      },
    );

    return ReceivedTransactionListResult.fromJson(json);
  }

  Future<ReceivedTransaction> getDetail({
    required String accessToken,
    required String receivedTransactionId,
  }) async {
    final json = await _apiClient.getJson(
      _routes.detail(receivedTransactionId),
      headers: _authorizedHeaders(accessToken),
    );

    return ReceivedTransaction.fromJson(json);
  }

  Future<ReceivedTransaction> recordProviderSms({
    required String accessToken,
    required String clientEventId,
    required int amount,
    required String providerReference,
    required DateTime occurredAt,
    String? senderIdentifier,
    String? senderName,
  }) async {
    final normalizedIdentifier = senderIdentifier?.trim();

    final normalizedName = senderName?.trim();

    if ((normalizedIdentifier == null || normalizedIdentifier.isEmpty) &&
        (normalizedName == null || normalizedName.isEmpty)) {
      throw ArgumentError(
        'Received SMS evidence requires a sender name or identifier.',
      );
    }

    final json = await _apiClient.postJson(
      _routes.providerSms,
      headers: _authorizedHeaders(accessToken),
      body: <String, dynamic>{
        'clientEventId': clientEventId,
        'amount': amount,
        'providerReference': providerReference,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        if (normalizedIdentifier != null && normalizedIdentifier.isNotEmpty)
          'senderIdentifier': normalizedIdentifier,
        if (normalizedName != null && normalizedName.isNotEmpty)
          'senderName': normalizedName,
      },
    );

    return ReceivedTransaction.fromJson(json);
  }
}
