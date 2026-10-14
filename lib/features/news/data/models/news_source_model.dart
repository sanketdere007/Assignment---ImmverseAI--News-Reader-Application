import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/news_source.dart';

part 'news_source_model.g.dart';

/// Data model representing the source object in News API responses.
@JsonSerializable()
@immutable
class NewsSourceModel {
  final String? id;
  final String? name;

  const NewsSourceModel({
    this.id,
    this.name,
  });

  /// Creates a [NewsSourceModel] from a JSON map safely.
  factory NewsSourceModel.fromJson(Map<String, dynamic> json) =>
      _$NewsSourceModelFromJson(json);

  /// Converts this model into a JSON map.
  Map<String, dynamic> toJson() => _$NewsSourceModelToJson(this);

  /// Converts this data model to the domain [NewsSource] entity.
  NewsSource toEntity() {
    return NewsSource(
      id: id,
      name: (name != null && name!.trim().isNotEmpty)
          ? name!.trim()
          : 'Unknown Source',
    );
  }

  /// Creates a model from a domain [NewsSource] entity.
  factory NewsSourceModel.fromEntity(NewsSource entity) {
    return NewsSourceModel(
      id: entity.id,
      name: entity.name,
    );
  }

  NewsSourceModel copyWith({
    String? id,
    String? name,
  }) {
    return NewsSourceModel(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NewsSourceModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'NewsSourceModel(id: $id, name: $name)';
}
