import '../../../../core/network/api_client.dart';
import '../models/shortcut_import_credential.dart';
import '../routes/shortcut_import_credential_routes.dart';

class ShortcutImportCredentialApiService {
  const ShortcutImportCredentialApiService({
    required ApiClient apiClient,
    required ShortcutImportCredentialRoutes routes,
  }) : _apiClient = apiClient,
       _routes = routes;

  final ApiClient _apiClient;
  final ShortcutImportCredentialRoutes _routes;

  Map<String, String> _headers(String token) {
    return <String, String>{'Authorization': 'Bearer $token'};
  }

  Future<List<ShortcutImportCredential>> list(String accessToken) async {
    final json = await _apiClient.getJsonList(
      ShortcutImportCredentialRoutes.base,
      headers: _headers(accessToken),
    );
    return json
        .map(
          (item) => ShortcutImportCredential.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<ShortcutImportCredential> create({
    required String accessToken,
    required String deviceName,
  }) async {
    final json = await _apiClient.postJson(
      ShortcutImportCredentialRoutes.base,
      headers: _headers(accessToken),
      body: <String, dynamic>{'deviceName': deviceName.trim()},
    );
    return ShortcutImportCredential.fromJson(json, requireToken: true);
  }

  Future<ShortcutImportCredential> rotate({
    required String accessToken,
    required String id,
  }) async {
    final json = await _apiClient.postJson(
      _routes.rotate(id),
      headers: _headers(accessToken),
    );
    return ShortcutImportCredential.fromJson(json, requireToken: true);
  }

  Future<void> revoke({required String accessToken, required String id}) {
    return _apiClient.delete(
      _routes.revoke(id),
      headers: _headers(accessToken),
    );
  }
}
