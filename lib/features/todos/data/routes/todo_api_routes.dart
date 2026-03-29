class TodoApiRoutes {
  const TodoApiRoutes._();

  static const instance = TodoApiRoutes._();

  static const String _base = '/api/v1/todos';

  String get list => _base;

  String byId(String todoId) => '$_base/$todoId';
}
