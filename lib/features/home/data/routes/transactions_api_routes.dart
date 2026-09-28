class TransactionsApiRoutes {
  const TransactionsApiRoutes._();

  static const instance =
      TransactionsApiRoutes._();

  static const String base =
      '/api/v1/transactions';

  String get quote => '$base/quote';

  String get create => base;
}