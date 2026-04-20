import '../../../../core/network/api_client.dart';
import '../../../../core/network/paginated_response.dart';
import '../../../../core/network/pagination_helpers.dart';
import '../models/saving_entry.dart';
import '../models/saving_list_query.dart';
import '../routes/savings_api_routes.dart';

class SavingsApiService {
  SavingsApiService({
    required ApiClient apiClient,
    required SavingsApiRoutes routes,
  }) : _apiClient = apiClient,
       _routes = routes;

  final ApiClient _apiClient;
  final SavingsApiRoutes _routes;

  Future<PaginatedResponse<SavingEntry>> fetchSavingsPage(
    String accessToken, {
    SavingListQuery query = const SavingListQuery(),
  }) async {
    final json = await _apiClient.getJson(
      _routes.list,
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
      queryParameters: query.toQueryParameters(),
    );

    return PaginatedResponse<SavingEntry>.fromJson(json, SavingEntry.fromJson);
  }

  Future<List<SavingEntry>> fetchSavings(
    String accessToken, {
    SavingListQuery query = const SavingListQuery(),
  }) {
    return collectPaginatedItems<SavingEntry>(
      ({required int page, required int limit}) => fetchSavingsPage(
        accessToken,
        query: query.copyWith(page: page, limit: limit),
      ),
    );
  }

  Future<SavingEntry> createSaving({
    required String accessToken,
    required String label,
    required double amount,
    SavingCurrencyCode currency = SavingCurrencyCode.rwf,
    required DateTime date,
    String? note,
    bool stillHave = true,
  }) async {
    final json = await _apiClient.postJson(
      _routes.list,
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
      body: <String, dynamic>{
        'label': label,
        'amount': amount,
        'currency': currency.apiValue,
        'date': date.toUtc().toIso8601String(),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        'stillHave': stillHave,
      },
    );

    return SavingEntry.fromJson(json);
  }

  Future<SavingEntry> updateSaving({
    required String accessToken,
    required String savingId,
    String? label,
    double? amount,
    SavingCurrencyCode? currency,
    DateTime? date,
    String? note,
    bool? stillHave,
  }) async {
    final body = <String, dynamic>{};

    if (label != null) {
      body['label'] = label;
    }

    if (amount != null) {
      body['amount'] = amount;
    }

    if (currency != null) {
      body['currency'] = currency.apiValue;
    }

    if (date != null) {
      body['date'] = date.toUtc().toIso8601String();
    }

    if (note != null) {
      body['note'] = note.trim().isEmpty ? null : note.trim();
    }

    if (stillHave != null) {
      body['stillHave'] = stillHave;
    }

    final json = await _apiClient.patchJson(
      _routes.byId(savingId),
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
      body: body,
    );

    return SavingEntry.fromJson(json);
  }

  Future<List<SavingTransactionEntry>> fetchSavingTransactions({
    required String accessToken,
    required String savingId,
  }) async {
    final json = await _apiClient.getJsonList(
      _routes.transactions(savingId),
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
    );

    return json
        .map(
          (item) =>
              SavingTransactionEntry.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  Future<SavingEntry> createSavingDeposit({
    required String accessToken,
    required String savingId,
    required double amount,
    SavingCurrencyCode currency = SavingCurrencyCode.rwf,
    required DateTime date,
    String? note,
    required List<SavingDepositIncomeSource> incomeSources,
  }) async {
    final json = await _apiClient.postJson(
      _routes.deposits(savingId),
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
      body: <String, dynamic>{
        'amount': amount,
        'currency': currency.apiValue,
        'date': date.toUtc().toIso8601String(),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        'incomeSources': incomeSources
            .map((source) => source.toJson())
            .toList(growable: false),
      },
    );

    return SavingEntry.fromJson(json);
  }

  Future<SavingEntry> createSavingWithdrawal({
    required String accessToken,
    required String savingId,
    required double amount,
    SavingCurrencyCode currency = SavingCurrencyCode.rwf,
    required DateTime date,
    String? note,
  }) async {
    final json = await _apiClient.postJson(
      _routes.withdrawals(savingId),
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
      body: <String, dynamic>{
        'amount': amount,
        'currency': currency.apiValue,
        'date': date.toUtc().toIso8601String(),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );

    return SavingEntry.fromJson(json);
  }

  Future<void> deleteSaving({
    required String accessToken,
    required String savingId,
  }) {
    return _apiClient.delete(
      _routes.byId(savingId),
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
    );
  }
}

class SavingDepositIncomeSource {
  const SavingDepositIncomeSource({
    required this.incomeId,
    required this.amount,
    this.currency = SavingCurrencyCode.rwf,
  });

  final String incomeId;
  final double amount;
  final SavingCurrencyCode currency;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'incomeId': incomeId,
      'amount': amount,
      'currency': currency.apiValue,
    };
  }
}
