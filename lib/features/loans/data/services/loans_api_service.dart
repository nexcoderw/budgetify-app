import '../../../../core/network/api_client.dart';
import '../../../../core/network/paginated_response.dart';
import '../../../../core/network/pagination_helpers.dart';
import '../models/loan_entry.dart';
import '../models/loan_list_query.dart';
import '../routes/loans_api_routes.dart';

class LoansApiService {
  LoansApiService({
    required ApiClient apiClient,
    required LoansApiRoutes routes,
  }) : _apiClient = apiClient,
       _routes = routes;

  final ApiClient _apiClient;
  final LoansApiRoutes _routes;

  Future<PaginatedResponse<LoanEntry>> fetchLoansPage(
    String accessToken, {
    LoanListQuery query = const LoanListQuery(),
  }) async {
    final json = await _apiClient.getJson(
      _routes.list,
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
      queryParameters: query.toQueryParameters(),
    );

    return PaginatedResponse<LoanEntry>.fromJson(json, LoanEntry.fromJson);
  }

  Future<List<LoanEntry>> fetchLoans(
    String accessToken, {
    LoanListQuery query = const LoanListQuery(),
  }) {
    return collectPaginatedItems<LoanEntry>(
      ({required int page, required int limit}) => fetchLoansPage(
        accessToken,
        query: query.copyWith(page: page, limit: limit),
      ),
    );
  }

  Future<LoanEntry> createLoan({
    required String accessToken,
    required String label,
    required double amount,
    required DateTime date,
    bool paid = false,
    String? note,
  }) async {
    final json = await _apiClient.postJson(
      _routes.list,
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
      body: <String, dynamic>{
        'label': label,
        'amount': amount,
        'date': date.toUtc().toIso8601String(),
        'paid': paid,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );

    return LoanEntry.fromJson(json);
  }

  Future<LoanEntry> updateLoan({
    required String accessToken,
    required String loanId,
    String? label,
    double? amount,
    DateTime? date,
    bool? paid,
    String? note,
  }) async {
    final body = <String, dynamic>{};

    if (label != null) {
      body['label'] = label;
    }
    if (amount != null) {
      body['amount'] = amount;
    }
    if (date != null) {
      body['date'] = date.toUtc().toIso8601String();
    }
    if (paid != null) {
      body['paid'] = paid;
    }
    if (note != null) {
      body['note'] = note.trim().isEmpty ? null : note.trim();
    }

    final json = await _apiClient.patchJson(
      _routes.byId(loanId),
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
      body: body,
    );

    return LoanEntry.fromJson(json);
  }

  Future<LoanSettlementResponse> sendLoanToExpense({
    required String accessToken,
    required String loanId,
    required DateTime date,
    String? note,
  }) async {
    final json = await _apiClient.postJson(
      _routes.sendToExpense(loanId),
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
      body: <String, dynamic>{
        'date': date.toUtc().toIso8601String(),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );

    return LoanSettlementResponse.fromJson(json);
  }

  Future<void> deleteLoan({
    required String accessToken,
    required String loanId,
  }) {
    return _apiClient.delete(
      _routes.byId(loanId),
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
    );
  }
}
