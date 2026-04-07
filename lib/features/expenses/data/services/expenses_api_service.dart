import '../../../../core/network/api_client.dart';
import '../../../../core/network/paginated_response.dart';
import '../../../../core/network/pagination_helpers.dart';
import '../models/expense_entry.dart';
import '../models/expense_list_query.dart';
import '../routes/expenses_api_routes.dart';

class ExpensesApiService {
  ExpensesApiService({
    required ApiClient apiClient,
    required ExpensesApiRoutes routes,
  }) : _apiClient = apiClient,
       _routes = routes;

  final ApiClient _apiClient;
  final ExpensesApiRoutes _routes;

  Future<List<ExpenseCategoryOption>> fetchExpenseCategories(
    String accessToken,
  ) async {
    final json = await _apiClient.getJsonList(
      _routes.categories,
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
    );

    return json
        .cast<Map<String, dynamic>>()
        .map(ExpenseCategoryOption.fromJson)
        .toList(growable: false);
  }

  Future<PaginatedResponse<ExpenseEntry>> fetchExpensesPage(
    String accessToken, {
    ExpenseListQuery query = const ExpenseListQuery(),
  }) async {
    final json = await _apiClient.getJson(
      _routes.list,
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
      queryParameters: query.toQueryParameters(),
    );

    return PaginatedResponse<ExpenseEntry>.fromJson(json, ExpenseEntry.fromJson);
  }

  Future<List<ExpenseEntry>> fetchExpenses(
    String accessToken, {
    ExpenseListQuery query = const ExpenseListQuery(),
  }) {
    return collectPaginatedItems<ExpenseEntry>(
      ({required int page, required int limit}) => fetchExpensesPage(
        accessToken,
        query: query.copyWith(page: page, limit: limit),
      ),
    );
  }

  Future<ExpenseEntry> createExpense({
    required String accessToken,
    required String label,
    required double amount,
    required ExpenseCategory category,
    required DateTime date,
    String? note,
  }) async {
    final json = await _apiClient.postJson(
      _routes.list,
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
      body: <String, dynamic>{
        'label': label,
        'amount': amount,
        'category': category.apiValue,
        'date': date.toUtc().toIso8601String(),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );

    return ExpenseEntry.fromJson(json);
  }

  Future<ExpenseEntry> updateExpense({
    required String accessToken,
    required String expenseId,
    required String label,
    required double amount,
    required ExpenseCategory category,
    required DateTime date,
    String? note,
  }) async {
    final json = await _apiClient.patchJson(
      _routes.byId(expenseId),
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
      body: <String, dynamic>{
        'label': label,
        'amount': amount,
        'category': category.apiValue,
        'date': date.toUtc().toIso8601String(),
        'note': note?.trim().isEmpty ?? true ? null : note!.trim(),
      },
    );

    return ExpenseEntry.fromJson(json);
  }

  Future<void> deleteExpense({
    required String accessToken,
    required String expenseId,
  }) {
    return _apiClient.delete(
      _routes.byId(expenseId),
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
    );
  }
}
