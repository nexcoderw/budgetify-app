class FinancialMessageImportRoutes {
  const FinancialMessageImportRoutes._();

  static const instance = FinancialMessageImportRoutes._();
  static const String base = '/api/v1/financial-message-imports';

  String get list => base;

  String get pilotSummary => '$base/pilot-summary';

  String detail(String id) => '$base/$id';

  String confirm(String id) => '$base/$id/confirm';

  String dismiss(String id) => '$base/$id/dismiss';
}
