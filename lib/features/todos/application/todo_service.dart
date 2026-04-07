import '../../../core/config/app_env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../auth/data/models/auth_session.dart';
import '../../auth/data/routes/auth_api_routes.dart';
import '../../auth/data/services/auth_api_service.dart';
import '../../auth/data/services/auth_session_storage.dart';
import '../data/models/todo_item.dart';
import '../data/models/todo_list_query.dart';
import '../data/models/todo_upload_image.dart';
import '../data/routes/todo_api_routes.dart';
import '../data/services/todo_api_service.dart';
import '../../../core/network/paginated_response.dart';

class TodoService {
  TodoService({
    required TodoApiService todoApiService,
    required AuthApiService authApiService,
    required AuthSessionStorage sessionStorage,
  }) : _todoApiService = todoApiService,
       _authApiService = authApiService,
       _sessionStorage = sessionStorage;

  factory TodoService.createDefault() {
    final apiClient = ApiClient(baseUrlResolver: () => AppEnv.apiBaseUrl);

    return TodoService(
      todoApiService: TodoApiService(
        apiClient: apiClient,
        routes: TodoApiRoutes.instance,
      ),
      authApiService: AuthApiService(
        apiClient: apiClient,
        routes: AuthApiRoutes.instance,
      ),
      sessionStorage: AuthSessionStorage(
        secureStorageService: SecureStorageService(),
      ),
    );
  }

  final TodoApiService _todoApiService;
  final AuthApiService _authApiService;
  final AuthSessionStorage _sessionStorage;

  Future<List<TodoItem>> listTodos({
    TodoListQuery query = const TodoListQuery(),
  }) async {
    final session = await _resolveActiveSession();

    return _todoApiService.fetchTodos(session.accessToken, query: query);
  }

  Future<PaginatedResponse<TodoItem>> listTodosPage({
    TodoListQuery query = const TodoListQuery(),
  }) async {
    final session = await _resolveActiveSession();

    return _todoApiService.fetchTodosPage(session.accessToken, query: query);
  }

  Future<TodoItem> getTodo(String todoId) async {
    final session = await _resolveActiveSession();

    return _todoApiService.fetchTodo(
      accessToken: session.accessToken,
      todoId: todoId,
    );
  }

  Future<TodoItem> createTodo({
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
    final session = await _resolveActiveSession();

    return _todoApiService.createTodo(
      accessToken: session.accessToken,
      name: name,
      price: price,
      priority: priority,
      done: done,
      frequency: frequency,
      startDate: startDate,
      endDate: endDate,
      frequencyDays: frequencyDays,
      occurrenceDates: occurrenceDates,
      images: images,
    );
  }

  Future<TodoItem> updateTodo({
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
    final session = await _resolveActiveSession();

    return _todoApiService.updateTodo(
      accessToken: session.accessToken,
      todoId: todoId,
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
      images: images,
    );
  }

  Future<void> deleteTodo(String todoId) async {
    final session = await _resolveActiveSession();

    await _todoApiService.deleteTodo(
      accessToken: session.accessToken,
      todoId: todoId,
    );
  }

  Future<AuthSession> _resolveActiveSession() async {
    final session = await _sessionStorage.read();

    if (session == null) {
      throw StateError('No active session is available for todo requests.');
    }

    if (!session.needsRefresh) {
      return session;
    }

    final refreshedSession = await _authApiService.refreshSession(
      session.refreshToken,
    );
    await _sessionStorage.save(refreshedSession);

    return refreshedSession;
  }
}
