import '../../../../core/network/api_client.dart';
import '../models/income_entry.dart';
import '../routes/income_api_routes.dart';

class IncomeApiService {
  IncomeApiService({
    required ApiClient apiClient,
    required IncomeApiRoutes routes,
  }) : _apiClient = apiClient,
       _routes = routes;

  final ApiClient _apiClient;
  final IncomeApiRoutes _routes;

  Future<List<IncomeEntry>> fetchIncome(String accessToken) async {
    final json = await _apiClient.getJsonList(
      _routes.list,
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
    );

    return json
        .cast<Map<String, dynamic>>()
        .map(IncomeEntry.fromJson)
        .toList(growable: false);
  }

  Future<IncomeEntry> createIncome({
    required String accessToken,
    required String label,
    required double amount,
    required IncomeCategory category,
    required DateTime date,
  }) async {
    final json = await _apiClient.postJson(
      _routes.list,
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
      body: <String, dynamic>{
        'label': label,
        'amount': amount,
        'category': category.apiValue,
        'date': date.toUtc().toIso8601String(),
      },
    );

    return IncomeEntry.fromJson(json);
  }

  Future<IncomeEntry> updateIncome({
    required String accessToken,
    required String incomeId,
    required String label,
    required double amount,
    required IncomeCategory category,
    required DateTime date,
  }) async {
    final json = await _apiClient.patchJson(
      _routes.byId(incomeId),
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
      body: <String, dynamic>{
        'label': label,
        'amount': amount,
        'category': category.apiValue,
        'date': date.toUtc().toIso8601String(),
      },
    );

    return IncomeEntry.fromJson(json);
  }

  Future<void> deleteIncome({
    required String accessToken,
    required String incomeId,
  }) {
    return _apiClient.delete(
      _routes.byId(incomeId),
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
    );
  }
}
