class LoansApiRoutes {
  const LoansApiRoutes._();

  static const instance = LoansApiRoutes._();

  static const String _base = '/api/v1/loans';

  String get list => _base;

  String byId(String loanId) => '$_base/$loanId';

  String sendToExpense(String loanId) => '$_base/$loanId/send-to-expense';
}
