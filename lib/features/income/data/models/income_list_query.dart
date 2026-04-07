import 'income_entry.dart';

class IncomeListQuery {
  const IncomeListQuery({
    this.month,
    this.year,
    this.category,
    this.received,
    this.search,
    this.dateFrom,
    this.dateTo,
    this.page,
    this.limit,
  });

  final int? month;
  final int? year;
  final IncomeCategory? category;
  final bool? received;
  final String? search;
  final String? dateFrom;
  final String? dateTo;
  final int? page;
  final int? limit;

  IncomeListQuery copyWith({
    int? month,
    int? year,
    IncomeCategory? category,
    bool? received,
    String? search,
    String? dateFrom,
    String? dateTo,
    int? page,
    int? limit,
  }) {
    return IncomeListQuery(
      month: month ?? this.month,
      year: year ?? this.year,
      category: category ?? this.category,
      received: received ?? this.received,
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
      if (received != null) 'received': received,
      if (normalizedSearch != null && normalizedSearch.length >= 3)
        'search': normalizedSearch,
      if (dateFrom != null && dateFrom!.isNotEmpty) 'dateFrom': dateFrom,
      if (dateTo != null && dateTo!.isNotEmpty) 'dateTo': dateTo,
      if (page != null) 'page': page,
      if (limit != null) 'limit': limit,
    };
  }
}
