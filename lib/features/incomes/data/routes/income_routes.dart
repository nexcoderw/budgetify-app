abstract final class IncomeRoutes {
  static const list = '/api/v1/incomes';
  static String detail(String id) => '$list/$id';
  static String receive(String id) => '${detail(id)}/receive';
  static String payments(String id) => '${detail(id)}/payments';
  static String link(String id) => '${detail(id)}/link';
}
