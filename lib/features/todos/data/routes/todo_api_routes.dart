class TodoApiRoutes {
  const TodoApiRoutes._();

  static const instance = TodoApiRoutes._();

  String get list => '/todos';

  String byId(String todoId) => '/todos/$todoId';
}
