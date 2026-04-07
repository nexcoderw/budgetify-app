import '../../../../core/network/api_client.dart';
import '../../../../core/network/paginated_response.dart';
import '../../../../core/network/pagination_helpers.dart';
import '../models/income_entry.dart';
import '../models/income_list_query.dart';
import '../routes/income_api_routes.dart';

class IncomeApiService {
  IncomeApiService({
    required ApiClient apiClient,
    required IncomeApiRoutes routes,
  }) : _apiClient = apiClient,
       _routes = routes;

  final ApiClient _apiClient;
  final IncomeApiRoutes _routes;

  Future<PaginatedResponse<IncomeEntry>> fetchIncomePage(
    String accessToken, {
    IncomeListQuery query = const IncomeListQuery(),
  }) async {
    final json = await _apiClient.getJson(
      _routes.list,
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
      queryParameters: query.toQueryParameters(),
    );

    return PaginatedResponse<IncomeEntry>.fromJson(json, IncomeEntry.fromJson);
  }

  Future<List<IncomeEntry>> fetchIncome(
    String accessToken, {
    IncomeListQuery query = const IncomeListQuery(),
  }) {
    return collectPaginatedItems<IncomeEntry>(
      ({required int page, required int limit}) => fetchIncomePage(
        accessToken,
        query: query.copyWith(page: page, limit: limit),
      ),
    );
  }

  Future<IncomeEntry> createIncome({
    required String accessToken,
    required String label,
    required double amount,
    required IncomeCategory category,
    required DateTime date,
    bool received = false,
  }) async {
    final json = await _apiClient.postJson(
      _routes.list,
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
      body: <String, dynamic>{
        'label': label,
        'amount': amount,
        'category': category.apiValue,
        'date': date.toUtc().toIso8601String(),
        'received': received,
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
    bool? received,
  }) async {
    final body = <String, dynamic>{
      'label': label,
      'amount': amount,
      'category': category.apiValue,
      'date': date.toUtc().toIso8601String(),
    };

    if (received != null) {
      body['received'] = received;
    }

    final json = await _apiClient.patchJson(
      _routes.byId(incomeId),
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
      body: body,
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
