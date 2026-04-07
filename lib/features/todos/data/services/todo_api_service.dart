import 'dart:convert';

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
    required bool done,
    required TodoFrequency frequency,
    required String startDate,
    String? endDate,
    List<int> frequencyDays = const <int>[],
    List<String> occurrenceDates = const <String>[],
    required List<TodoUploadImage> images,
  }) async {
    final json = await _apiClient.postMultipart(
      _routes.list,
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
      fields: _buildTodoFields(
        name: name,
        price: price,
        priority: priority,
        done: done,
        frequency: frequency,
        startDate: startDate,
        endDate: endDate,
        frequencyDays: frequencyDays,
        occurrenceDates: occurrenceDates,
      ),
      files: images.map(_toMultipartFile).toList(growable: false),
    );

    return TodoItem.fromJson(json);
  }

  Future<TodoItem> updateTodo({
    required String accessToken,
    required String todoId,
    String? name,
    double? price,
    TodoPriority? priority,
    bool? done,
    TodoFrequency? frequency,
    String? startDate,
    String? endDate,
    List<int>? frequencyDays,
    List<String>? occurrenceDates,
    double? deductAmount,
    String? recordedOccurrenceDate,
    String? primaryImageId,
    List<TodoUploadImage> images = const [],
  }) async {
    final json = await _apiClient.patchMultipart(
      _routes.byId(todoId),
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
      fields: _buildTodoFields(
        name: name,
        price: price,
        priority: priority,
        done: done,
        frequency: frequency,
        startDate: startDate,
        endDate: endDate,
        frequencyDays: frequencyDays,
        occurrenceDates: occurrenceDates,
        deductAmount: deductAmount,
        recordedOccurrenceDate: recordedOccurrenceDate,
        primaryImageId: primaryImageId,
      ),
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

  Map<String, String> _buildTodoFields({
    String? name,
    double? price,
    TodoPriority? priority,
    bool? done,
    TodoFrequency? frequency,
    String? startDate,
    String? endDate,
    List<int>? frequencyDays,
    List<String>? occurrenceDates,
    double? deductAmount,
    String? recordedOccurrenceDate,
    String? primaryImageId,
  }) {
    final fields = <String, String>{};

    if (name != null) fields['name'] = name;
    if (price != null) fields['price'] = _encodeAmount(price);
    if (priority != null) fields['priority'] = priority.apiValue;
    if (done != null) fields['done'] = done.toString();
    if (frequency != null) fields['frequency'] = frequency.apiValue;
    if (startDate != null) fields['startDate'] = startDate;
    if (endDate != null) fields['endDate'] = endDate;
    if (frequencyDays != null) {
      fields['frequencyDays'] = jsonEncode(frequencyDays);
    }
    if (occurrenceDates != null) {
      fields['occurrenceDates'] = jsonEncode(occurrenceDates);
    }
    if (deductAmount != null) {
      fields['deductAmount'] = _encodeAmount(deductAmount);
    }
    if (recordedOccurrenceDate != null) {
      fields['recordedOccurrenceDate'] = recordedOccurrenceDate;
    }
    if (primaryImageId != null) {
      fields['primaryImageId'] = primaryImageId;
    }

    return fields;
  }
}
