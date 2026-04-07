import 'expense_entry.dart';

class ExpenseListQuery {
  const ExpenseListQuery({
    this.month,
    this.year,
    this.category,
    this.search,
    this.dateFrom,
    this.dateTo,
    this.page,
    this.limit,
  });

  final int? month;
  final int? year;
  final ExpenseCategory? category;
  final String? search;
  final String? dateFrom;
  final String? dateTo;
  final int? page;
  final int? limit;

  ExpenseListQuery copyWith({
    int? month,
    int? year,
    ExpenseCategory? category,
    String? search,
    String? dateFrom,
    String? dateTo,
    int? page,
    int? limit,
  }) {
    return ExpenseListQuery(
      month: month ?? this.month,
      year: year ?? this.year,
      category: category ?? this.category,
      search: search ?? this.search,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      page: page ?? this.page,
      limit: limit ?? this.limit,
    );
  }

  Map<String, dynamic> toQueryParameters() {
    final normalizedSearch = search?.trim();

    return <String, dynamic>{
      if (month != null) 'month': month,
      if (year != null) 'year': year,
      if (category != null) 'category': category!.apiValue,
      if (normalizedSearch != null && normalizedSearch.length >= 3)
        'search': normalizedSearch,
      if (dateFrom != null && dateFrom!.isNotEmpty) 'dateFrom': dateFrom,
      if (dateTo != null && dateTo!.isNotEmpty) 'dateTo': dateTo,
      if (page != null) 'page': page,
      if (limit != null) 'limit': limit,
    };
  }
}
