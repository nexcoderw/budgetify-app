import '../../../../core/network/api_client.dart';
import '../models/partnership_models.dart';
import '../routes/partnerships_api_routes.dart';

class PartnershipsApiService {
  PartnershipsApiService({
    required ApiClient apiClient,
    required PartnershipsApiRoutes routes,
  }) : _apiClient = apiClient,
       _routes = routes;

  final ApiClient _apiClient;
  final PartnershipsApiRoutes _routes;

  Future<Partnership?> fetchMyPartnership(String accessToken) async {
    final json = await _apiClient.getNullableJson(
      _routes.mine,
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
    );

    if (json == null) {
      return null;
    }

    return Partnership.fromJson(json);
  }

  Future<Partnership> invitePartner({
    required String accessToken,
    required String email,
  }) async {
    final json = await _apiClient.postJson(
      _routes.invite,
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
      body: <String, dynamic>{'email': email},
    );

    return Partnership.fromJson(json);
  }

  Future<void> cancelPendingInvite({required String accessToken}) {
    return _apiClient.delete(
      _routes.invite,
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
    );
  }

  Future<void> removePartnership({required String accessToken}) {
    return _apiClient.delete(
      _routes.mine,
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
    );
  }

  Future<InviteInfo> fetchInviteInfo(String inviteToken) async {
    final json = await _apiClient.getJson(
      _routes.inviteInfo,
      queryParameters: <String, dynamic>{'token': inviteToken},
    );

    return InviteInfo.fromJson(json);
  }

  Future<Partnership> acceptInvite({
    required String accessToken,
    required String inviteToken,
  }) async {
    final json = await _apiClient.postJson(
      _routes.accept,
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
      body: <String, dynamic>{'token': inviteToken},
    );

    return Partnership.fromJson(json);
  }
}
