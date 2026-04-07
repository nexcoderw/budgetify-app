import 'paginated_response.dart';

typedef PaginatedPageFetcher<T> =
    Future<PaginatedResponse<T>> Function({
      required int page,
      required int limit,
    });

const int defaultBatchPageLimit = 100;

Future<List<T>> collectPaginatedItems<T>(
  PaginatedPageFetcher<T> fetchPage, {
  int batchLimit = defaultBatchPageLimit,
}) async {
  final items = <T>[];
  var page = 1;
  var hasNextPage = true;

  while (hasNextPage) {
    final response = await fetchPage(page: page, limit: batchLimit);
    items.addAll(response.items);
    hasNextPage = response.meta.hasNextPage;
    page += 1;
  }

  return items;
}
