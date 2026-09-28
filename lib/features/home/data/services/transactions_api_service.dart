import '../../../../core/network/api_client.dart';
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

  Future<TransactionQuote> quote({
    required String accessToken,
    required int amount,
    required TransactionTransferType transferType,
  }) async {
    final json = await _apiClient.postJson(
      _routes.quote,
      headers: <String, String>{
        'Authorization': 'Bearer $accessToken',
      },
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
      headers: <String, String>{
        'Authorization': 'Bearer $accessToken',
      },
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
}