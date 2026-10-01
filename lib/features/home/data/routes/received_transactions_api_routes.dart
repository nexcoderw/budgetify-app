class ReceivedTransactionsApiRoutes {
  const ReceivedTransactionsApiRoutes._();

  static const instance = ReceivedTransactionsApiRoutes._();

  static const String base = '/api/v1/received-transactions';

  String get list => base;

  String get providerSms => '$base/provider-sms';

  String get manual => '$base/manual';

  String detail(String receivedTransactionId) {
    return '$base/$receivedTransactionId';
  }

  String classification(String receivedTransactionId) {
    return '$base/$receivedTransactionId/classification';
  }
}
