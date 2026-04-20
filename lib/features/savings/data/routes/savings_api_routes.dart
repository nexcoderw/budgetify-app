class SavingsApiRoutes {
  const SavingsApiRoutes._();

  static const instance = SavingsApiRoutes._();

  static const String _base = '/api/v1/savings';

  String get list => _base;

  String byId(String savingId) => '$_base/$savingId';

  String deposits(String savingId) => '$_base/$savingId/deposits';

  String transactions(String savingId) => '$_base/$savingId/transactions';
}
