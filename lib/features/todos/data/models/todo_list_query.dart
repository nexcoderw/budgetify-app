import 'todo_item.dart';

class TodoListQuery {
  const TodoListQuery({
    this.frequency,
    this.priority,
    this.done,
    this.search,
    this.dateFrom,
    this.dateTo,
    this.page,
    this.limit,
  });

  final TodoFrequency? frequency;
  final TodoPriority? priority;
  final bool? done;
  final String? search;
  final String? dateFrom;
  final String? dateTo;
  final int? page;
  final int? limit;

  TodoListQuery copyWith({
    TodoFrequency? frequency,
    TodoPriority? priority,
    bool? done,
    String? search,
    String? dateFrom,
    String? dateTo,
    int? page,
    int? limit,
  }) {
    return TodoListQuery(
      frequency: frequency ?? this.frequency,
      priority: priority ?? this.priority,
      done: done ?? this.done,
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
      if (frequency != null) 'frequency': frequency!.apiValue,
      if (priority != null) 'priority': priority!.apiValue,
      if (done != null) 'done': done,
      if (normalizedSearch != null && normalizedSearch.length >= 3)
        'search': normalizedSearch,
      if (dateFrom != null && dateFrom!.isNotEmpty) 'dateFrom': dateFrom,
      if (dateTo != null && dateTo!.isNotEmpty) 'dateTo': dateTo,
      if (page != null) 'page': page,
      if (limit != null) 'limit': limit,
    };
  }
}
