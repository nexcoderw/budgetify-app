import '../../../../core/models/created_by_summary.dart';

enum TodoPriority {
  topPriority,
  priority,
  notPriority;

  String get apiValue => switch (this) {
    TodoPriority.topPriority => 'TOP_PRIORITY',
    TodoPriority.priority => 'PRIORITY',
    TodoPriority.notPriority => 'NOT_PRIORITY',
  };

  String get label => switch (this) {
    TodoPriority.topPriority => 'Top Priority',
    TodoPriority.priority => 'Priority',
    TodoPriority.notPriority => 'Not Priority',
  };

  static TodoPriority fromApiValue(String value) => switch (value) {
    'TOP_PRIORITY' => TodoPriority.topPriority,
    'PRIORITY' => TodoPriority.priority,
    'NOT_PRIORITY' => TodoPriority.notPriority,
    _ => throw FormatException('Unsupported todo priority value: $value'),
  };
}

enum TodoFrequency {
  once,
  weekly,
  monthly,
  yearly;

  String get apiValue => switch (this) {
    TodoFrequency.once => 'ONCE',
    TodoFrequency.weekly => 'WEEKLY',
    TodoFrequency.monthly => 'MONTHLY',
    TodoFrequency.yearly => 'YEARLY',
  };

  String get label => switch (this) {
    TodoFrequency.once => 'Once',
    TodoFrequency.weekly => 'Weekly',
    TodoFrequency.monthly => 'Monthly',
    TodoFrequency.yearly => 'Yearly',
  };

  static TodoFrequency fromApiValue(String? value) => switch (value) {
    'WEEKLY' => TodoFrequency.weekly,
    'MONTHLY' => TodoFrequency.monthly,
    'YEARLY' => TodoFrequency.yearly,
    _ => TodoFrequency.once,
  };
}

class TodoImageItem {
  const TodoImageItem({
    required this.id,
    required this.imageUrl,
    required this.publicId,
    required this.width,
    required this.height,
    required this.bytes,
    required this.format,
    required this.isPrimary,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TodoImageItem.fromJson(Map<String, dynamic> json) {
    return TodoImageItem(
      id: json['id'] as String,
      imageUrl: json['imageUrl'] as String,
      publicId: json['publicId'] as String,
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
      bytes: (json['bytes'] as num).toInt(),
      format: json['format'] as String,
      isPrimary: json['isPrimary'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
    );
  }

  final String id;
  final String imageUrl;
  final String publicId;
  final int width;
  final int height;
  final int bytes;
  final String format;
  final bool isPrimary;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class TodoItem {
  const TodoItem({
    required this.id,
    required this.name,
    required this.price,
    required this.priority,
    required this.done,
    required this.frequency,
    required this.startDate,
    required this.endDate,
    required this.frequencyDays,
    required this.occurrenceDates,
    required this.recordedOccurrenceDates,
    required this.remainingAmount,
    required this.coverImageUrl,
    required this.imageCount,
    required this.images,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    final images = (json['images'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(TodoImageItem.fromJson)
        .toList(growable: false);

    return TodoItem(
      id: json['id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      priority: TodoPriority.fromApiValue(json['priority'] as String),
      done: json['done'] as bool? ?? false,
      frequency: TodoFrequency.fromApiValue(json['frequency'] as String?),
      startDate: _parseOptionalDateOnly(json['startDate']),
      endDate: _parseOptionalDateOnly(json['endDate']),
      frequencyDays:
          (json['frequencyDays'] as List<dynamic>? ?? const <dynamic>[])
              .map((value) => (value as num).toInt())
              .toList(growable: false),
      occurrenceDates:
          (json['occurrenceDates'] as List<dynamic>? ?? const <dynamic>[])
              .map((value) => value as String)
              .toList(growable: false),
      recordedOccurrenceDates:
          (json['recordedOccurrenceDates'] as List<dynamic>? ??
                  const <dynamic>[])
              .map((value) => value as String)
              .toList(growable: false),
      remainingAmount: (json['remainingAmount'] as num?)?.toDouble(),
      coverImageUrl: json['coverImageUrl'] as String?,
      imageCount: (json['imageCount'] as num).toInt(),
      images: images,
      createdBy: (json['createdBy'] as Map<String, dynamic>?) != null
          ? CreatedBySummary.fromJson(json['createdBy'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
    );
  }

  final String id;
  final String name;
  final double price;
  final TodoPriority priority;
  final bool done;
  final TodoFrequency frequency;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<int> frequencyDays;
  final List<String> occurrenceDates;
  final List<String> recordedOccurrenceDates;
  final double? remainingAmount;
  final String? coverImageUrl;
  final int imageCount;
  final List<TodoImageItem> images;
  final CreatedBySummary? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  TodoImageItem? get primaryImage {
    for (final image in images) {
      if (image.isPrimary) {
        return image;
      }
    }

    return images.isEmpty ? null : images.first;
  }

  static DateTime? _parseOptionalDateOnly(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }

    return DateTime.tryParse(value);
  }
}
