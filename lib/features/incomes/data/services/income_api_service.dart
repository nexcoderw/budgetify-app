import '../../../../core/network/api_client.dart';
import '../models/income.dart';
import '../routes/income_routes.dart';

class IncomeApiService {
  IncomeApiService(this.client);
  final ApiClient client;
  Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
  };

  Future<IncomePageResult> list(
    String token, {
    required int page,
    String? status,
    String? search,
  }) async {
    final json = await client.getJson(
      IncomeRoutes.list,
      headers: _headers(token),
      queryParameters: {
        'page': page,
        'limit': 20,
        'status': status,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return IncomePageResult.fromJson(json);
  }

  Future<void> create(String token, Map<String, dynamic> body) async {
    await client.postJson(
      IncomeRoutes.list,
      headers: _headers(token),
      body: body,
    );
  }

  Future<void> update(
    String token,
    String id,
    Map<String, dynamic> body,
  ) async {
    await client.patchJson(
      IncomeRoutes.detail(id),
      headers: _headers(token),
      body: body,
    );
  }

  Future<void> receive(String token, String id, DateTime date) async {
    await client.postJson(
      IncomeRoutes.receive(id),
      headers: _headers(token),
      body: {'date': date.toUtc().toIso8601String()},
    );
  }

  Future<Map<String, dynamic>> payments(String token, String id, int page) =>
      client.getJson(
        IncomeRoutes.payments(id),
        headers: _headers(token),
        queryParameters: {'page': page, 'limit': 20},
      );

  Future<void> link(String token, String id, String paymentId) async {
    await client.postJson(
      IncomeRoutes.link(id),
      headers: _headers(token),
      body: {'receivedTransactionId': paymentId},
    );
  }

  Future<void> archive(String token, String id) =>
      client.delete(IncomeRoutes.detail(id), headers: _headers(token));
}
