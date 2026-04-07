import '../../../../core/network/api_client.dart';
import '../../../auth/data/models/auth_user.dart';
import '../routes/users_api_routes.dart';

class UsersApiService {
  UsersApiService({
    required ApiClient apiClient,
    required UsersApiRoutes routes,
  }) : _apiClient = apiClient,
       _routes = routes;

  final ApiClient _apiClient;
  final UsersApiRoutes _routes;

  Future<AuthUser> updateCurrentUserNames({
    required String accessToken,
    required String firstName,
    required String lastName,
  }) async {
    final json = await _apiClient.patchJson(
      _routes.me,
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
      body: <String, dynamic>{'firstName': firstName, 'lastName': lastName},
    );

    return AuthUser.fromJson(json);
  }

  Future<AuthUser> requestCurrentUserDeletion({
    required String accessToken,
  }) async {
    final json = await _apiClient.postJson(
      _routes.deletionRequest,
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
    );

    return AuthUser.fromJson(json);
  }
}
