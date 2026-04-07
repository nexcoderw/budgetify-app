class PaginationMetaResponse {
  const PaginationMetaResponse({
    required this.page,
    required this.limit,
    required this.totalItems,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPreviousPage,
  });

  factory PaginationMetaResponse.fromJson(Map<String, dynamic> json) {
    return PaginationMetaResponse(
      page: (json['page'] as num).toInt(),
      limit: (json['limit'] as num).toInt(),
      totalItems: (json['totalItems'] as num).toInt(),
      totalPages: (json['totalPages'] as num).toInt(),
      hasNextPage: json['hasNextPage'] as bool,
      hasPreviousPage: json['hasPreviousPage'] as bool,
    );
  }

  final int page;
  final int limit;
  final int totalItems;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPreviousPage;
}

class PaginatedResponse<T> {
  const PaginatedResponse({required this.items, required this.meta});

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json) itemFromJson,
  ) {
    final rawItems = (json['items'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();

    return PaginatedResponse<T>(
      items: rawItems.map(itemFromJson).toList(growable: false),
      meta: PaginationMetaResponse.fromJson(
        json['meta'] as Map<String, dynamic>,
      ),
    );
  }

  final List<T> items;
  final PaginationMetaResponse meta;
}
