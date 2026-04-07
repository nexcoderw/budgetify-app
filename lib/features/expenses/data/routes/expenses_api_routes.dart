class ExpensesApiRoutes {
  const ExpensesApiRoutes._();

  static const instance = ExpensesApiRoutes._();

  static const String _base = '/api/v1/expenses';

  String get list => _base;
  String get categories => '$_base/categories';
  String byId(String expenseId) => '$_base/$expenseId';
}
