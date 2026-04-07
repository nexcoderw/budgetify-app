class SavingListQuery {
  const SavingListQuery({
    this.month,
    this.year,
    this.search,
    this.dateFrom,
    this.dateTo,
    this.page,
    this.limit,
  });

  final int? month;
  final int? year;
  final String? search;
  final String? dateFrom;
  final String? dateTo;
  final int? page;
  final int? limit;

  SavingListQuery copyWith({
    int? month,
    int? year,
    String? search,
    String? dateFrom,
    String? dateTo,
    int? page,
    int? limit,
  }) {
    return SavingListQuery(
      month: month ?? this.month,
      year: year ?? this.year,
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
      if (normalizedSearch != null && normalizedSearch.length >= 3)
        'search': normalizedSearch,
      if (dateFrom != null && dateFrom!.isNotEmpty) 'dateFrom': dateFrom,
      if (dateTo != null && dateTo!.isNotEmpty) 'dateTo': dateTo,
      if (page != null) 'page': page,
      if (limit != null) 'limit': limit,
    };
  }
}
