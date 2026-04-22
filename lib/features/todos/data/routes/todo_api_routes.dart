class TodoApiRoutes {
  const TodoApiRoutes._();

  static const instance = TodoApiRoutes._();

  static const String _base = '/api/v1/todos';

  String get list => _base;
  String get summary => '$_base/summary';
  String get upcoming => '$_base/upcoming';

  String byId(String todoId) => '$_base/$todoId';
  String recordExpense(String todoId) => '$_base/$todoId/record-expense';
}
