class TransactionsApiRoutes {
  const TransactionsApiRoutes._();

  static const instance = TransactionsApiRoutes._();

  static const String base = '/api/v1/transactions';

  String get list => base;

  String get analytics => '$base/analytics';

  String get history => '$base/history';

  String get quote => '$base/quote';

  String get create => base;

  String detail(String transactionId) {
    return '$base/$transactionId';
  }

  String ussdOpened(String transactionId) {
    return '$base/$transactionId/ussd-opened';
  }

  String providerSmsResult(String transactionId) {
    return '$base/$transactionId/provider-sms-result';
  }

  String manualResult(String transactionId) {
    return '$base/$transactionId/manual-result';
  }
}
