import 'package:http_parser/http_parser.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/paginated_response.dart';
import '../../../../core/network/pagination_helpers.dart';
import '../models/todo_item.dart';
import '../models/todo_list_query.dart';
import '../models/todo_upload_image.dart';
import '../routes/todo_api_routes.dart';

class TodoApiService {
  TodoApiService({required ApiClient apiClient, required TodoApiRoutes routes})
    : _apiClient = apiClient,
      _routes = routes;

  final ApiClient _apiClient;
  final TodoApiRoutes _routes;

  Future<PaginatedResponse<TodoItem>> fetchTodosPage(
    String accessToken, {
    TodoListQuery query = const TodoListQuery(),
  }) async {
    final json = await _apiClient.getJson(
      _routes.list,
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
      queryParameters: query.toQueryParameters(),
    );

    return PaginatedResponse<TodoItem>.fromJson(json, TodoItem.fromJson);
  }

  Future<List<TodoItem>> fetchTodos(
    String accessToken, {
    TodoListQuery query = const TodoListQuery(),
  }) {
    return collectPaginatedItems<TodoItem>(
      ({required int page, required int limit}) => fetchTodosPage(
        accessToken,
        query: query.copyWith(page: page, limit: limit),
      ),
    );
  }

  Future<TodoItem> fetchTodo({
    required String accessToken,
    required String todoId,
  }) async {
    final json = await _apiClient.getJson(
      _routes.byId(todoId),
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
    );

    return TodoItem.fromJson(json);
  }

  Future<TodoItem> createTodo({
    required String accessToken,
    required String name,
    required double price,
    required TodoPriority priority,
    required List<TodoUploadImage> images,
  }) async {
    final json = await _apiClient.postMultipart(
      _routes.list,
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
      fields: <String, String>{
        'name': name,
        'price': _encodeAmount(price),
        'priority': priority.apiValue,
      },
      files: images.map(_toMultipartFile).toList(growable: false),
    );

    return TodoItem.fromJson(json);
  }

  Future<TodoItem> updateTodo({
    required String accessToken,
    required String todoId,
    required String name,
    required double price,
    required TodoPriority priority,
    String? primaryImageId,
    List<TodoUploadImage> images = const [],
  }) async {
    final fields = <String, String>{
      'name': name,
      'price': _encodeAmount(price),
      'priority': priority.apiValue,
    };

    if (primaryImageId != null) {
      fields['primaryImageId'] = primaryImageId;
    }

    final json = await _apiClient.patchMultipart(
      _routes.byId(todoId),
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
      fields: fields,
      files: images.map(_toMultipartFile).toList(growable: false),
    );

    return TodoItem.fromJson(json);
  }

  Future<void> deleteTodo({
    required String accessToken,
    required String todoId,
  }) {
    return _apiClient.delete(
      _routes.byId(todoId),
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
    );
  }

  ApiMultipartFile _toMultipartFile(TodoUploadImage image) {
    return ApiMultipartFile(
      fieldName: 'images',
      filename: image.filename,
      bytes: image.bytes,
      contentType: MediaType.parse(image.mimeType),
    );
  }

  String _encodeAmount(double amount) {
    final normalized = amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);

    return normalized;
  }
}
