import 'dart:convert';

import 'package:http_parser/http_parser.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/paginated_response.dart';
import '../../../../core/network/pagination_helpers.dart';
import '../../../expenses/data/models/expense_entry.dart';
import '../models/todo_item.dart';
import '../models/todo_list_query.dart';
import '../models/todo_summary.dart';
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
      queryParameters: _buildQueryParameters(query),
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

  Future<TodoSummary> fetchTodoSummary(
    String accessToken, {
    TodoListQuery query = const TodoListQuery(),
  }) async {
    final json = await _apiClient.getJson(
      _routes.summary,
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
      queryParameters: _buildQueryParameters(query, includePagination: false),
    );

    return TodoSummary.fromJson(json);
  }

  Future<TodoUpcomingSummary> fetchTodoUpcoming(
    String accessToken, {
    TodoListQuery query = const TodoListQuery(),
    int days = 7,
  }) async {
    final json = await _apiClient.getJson(
      _routes.upcoming,
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
      queryParameters: _buildQueryParameters(
        query,
        includePagination: false,
        days: days,
      ),
    );

    return TodoUpcomingSummary.fromJson(json);
  }

  Future<TodoItem> createTodo({
    required String accessToken,
    required String name,
    required double price,
    required TodoPriority priority,
    required TodoStatus status,
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
        status: status,
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
    TodoStatus? status,
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
        status: status,
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

  Future<void> recordTodoExpense({
    required String accessToken,
    required String todoId,
    required String label,
    required double amount,
    ExpenseCurrency currency = ExpenseCurrency.rwf,
    required ExpenseCategory category,
    ExpensePaymentMethod paymentMethod = ExpensePaymentMethod.cash,
    ExpenseMobileMoneyChannel? mobileMoneyChannel,
    ExpenseMobileMoneyProvider? mobileMoneyProvider,
    ExpenseMobileMoneyNetwork? mobileMoneyNetwork,
    required DateTime date,
    String? occurrenceDate,
    String? note,
  }) async {
    await _apiClient.postJson(
      _routes.recordExpense(todoId),
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
      body: <String, dynamic>{
        'label': label,
        'amount': amount,
        'currency': currency.apiValue,
        'category': category.apiValue,
        'paymentMethod': paymentMethod.apiValue,
        if (mobileMoneyChannel != null)
          'mobileMoneyChannel': mobileMoneyChannel.apiValue,
        if (mobileMoneyProvider != null)
          'mobileMoneyProvider': mobileMoneyProvider.apiValue,
        if (mobileMoneyNetwork != null)
          'mobileMoneyNetwork': mobileMoneyNetwork.apiValue,
        'date': date.toUtc().toIso8601String(),
        ...?(occurrenceDate == null
            ? null
            : <String, dynamic>{'occurrenceDate': occurrenceDate}),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
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
    TodoStatus? status,
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
    if (status != null) fields['status'] = status.apiValue;
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

  Map<String, dynamic> _buildQueryParameters(
    TodoListQuery query, {
    bool includePagination = true,
    int? days,
  }) {
    final normalizedSearch = query.search?.trim();

    final parameters = <String, dynamic>{
      if (query.frequency != null) 'frequency': query.frequency!.apiValue,
      if (query.priority != null) 'priority': query.priority!.apiValue,
      if (query.status != null) 'status': query.status!.apiValue,
      if (normalizedSearch != null && normalizedSearch.length >= 3)
        'search': normalizedSearch,
      if (query.dateFrom?.isNotEmpty ?? false) 'dateFrom': query.dateFrom,
      if (query.dateTo?.isNotEmpty ?? false) 'dateTo': query.dateTo,
      if (includePagination && query.page != null) 'page': query.page,
      if (includePagination && query.limit != null) 'limit': query.limit,
    };

    if (days != null) {
      parameters['days'] = days;
    }

    return parameters;
  }
}
