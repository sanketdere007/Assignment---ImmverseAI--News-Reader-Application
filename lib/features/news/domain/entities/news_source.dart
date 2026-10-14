import 'package:flutter/foundation.dart';

/// Domain entity representing the news publisher or source.
@immutable
class NewsSource {
  /// Unique source identifier (e.g. 'bbc-news', 'the-hindu'), or null if not indexed.
  final String? id;

  /// Human-readable source name (e.g. 'BBC News', 'The Hindu').
  final String name;

  const NewsSource({
    this.id,
    required this.name,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NewsSource &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'NewsSource(id: $id, name: $name)';
}
