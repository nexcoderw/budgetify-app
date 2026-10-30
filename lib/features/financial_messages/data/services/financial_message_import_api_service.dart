import '../../../../core/network/api_client.dart';
import '../../../home/data/models/received_transaction_models.dart';
import '../../../incomes/data/models/income.dart';
import '../models/financial_message_import.dart';
import '../routes/financial_message_import_routes.dart';

class FinancialMessageImportApiService {
  const FinancialMessageImportApiService({
    required ApiClient apiClient,
    required FinancialMessageImportRoutes routes,
  }) : _apiClient = apiClient,
       _routes = routes;

  final ApiClient _apiClient;
  final FinancialMessageImportRoutes _routes;

  Map<String, String> _headers(String accessToken) {
    return <String, String>{'Authorization': 'Bearer $accessToken'};
  }

  Future<FinancialMessageImportPage> list({
    required String accessToken,
    required FinancialMessageImportStatus status,
    int page = 1,
    int limit = 20,
  }) async {
    final json = await _apiClient.getJson(
      _routes.list,
      headers: _headers(accessToken),
      queryParameters: <String, dynamic>{
        'status': status.apiValue,
        'page': page,
        'limit': limit,
      },
    );
    return FinancialMessageImportPage.fromJson(json);
  }

  Future<FinancialMessageImport> detail({
    required String accessToken,
    required String id,
  }) async {
    final json = await _apiClient.getJson(
      _routes.detail(id),
      headers: _headers(accessToken),
    );
    return FinancialMessageImport.fromJson(json);
  }

  Future<FinancialMessageImport> update({
    required String accessToken,
    required String id,
    required int amount,
    required DateTime occurredAt,
    String? senderName,
    String? senderIdentifier,
    String? providerReference,
  }) async {
    final json = await _apiClient.patchJson(
      _routes.detail(id),
      headers: _headers(accessToken),
      body: <String, dynamic>{
        'amount': amount,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        if (senderName?.trim().isNotEmpty ?? false)
          'senderName': senderName!.trim(),
        if (senderIdentifier?.trim().isNotEmpty ?? false)
          'senderIdentifier': senderIdentifier!.replaceAll(
            RegExp(r'\s+'),
            '',
          ),
        if (providerReference?.trim().isNotEmpty ?? false)
          'providerReference': providerReference!.trim(),
      },
    );
    return FinancialMessageImport.fromJson(json);
  }

  Future<void> confirm({
    required String accessToken,
    required String id,
    required ReceivedTransactionClassification classification,
    required bool createIncome,
    String? note,
    IncomeCategory? incomeCategory,
    String? incomeLabel,
  }) async {
    await _apiClient.postJson(
      _routes.confirm(id),
      headers: _headers(accessToken),
      body: <String, dynamic>{
        'classification': classification.apiValue,
        'createIncome': createIncome,
        if (note?.trim().isNotEmpty ?? false) 'note': note!.trim(),
        if (incomeCategory != null)
          'incomeCategory': incomeCategory.apiValue,
        if (incomeLabel?.trim().isNotEmpty ?? false)
          'incomeLabel': incomeLabel!.trim(),
      },
    );
  }

  Future<void> dismiss({
    required String accessToken,
    required String id,
  }) async {
    await _apiClient.postJson(
      _routes.dismiss(id),
      headers: _headers(accessToken),
    );
  }
}
