class IncomeApiRoutes {
  const IncomeApiRoutes._();

  static const instance = IncomeApiRoutes._();

  static const String base = '/api/v1/income';

  String get list => base;
  String get summary => '$base/summary';

  String byId(String incomeId) => '$base/$incomeId';
}
