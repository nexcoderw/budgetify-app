class ExpensesApiRoutes {
  const ExpensesApiRoutes._();

  static const instance = ExpensesApiRoutes._();

  static const String _base = '/api/v1/expenses';

  String get list => _base;
  String get categories => '$_base/categories';
  String get summary => '$_base/summary';
  String get audit => '$_base/audit';
  String get mobileMoneyQuote => '$_base/mobile-money/quote';
  String byId(String expenseId) => '$_base/$expenseId';
}
