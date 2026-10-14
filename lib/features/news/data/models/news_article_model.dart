import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/news_article.dart';
import 'news_source_model.dart';

part 'news_article_model.g.dart';

/// Data model representing a news article payload from News API.
@JsonSerializable(explicitToJson: true)
@immutable
class NewsArticleModel {
  final NewsSourceModel? source;
  final String? author;
  final String? title;
  final String? description;
  final String? url;
  final String? urlToImage;
  final DateTime? publishedAt;
  final String? content;

  const NewsArticleModel({
    this.source,
    this.author,
    this.title,
    this.description,
    this.url,
    this.urlToImage,
    this.publishedAt,
    this.content,
  });

  /// Factory constructor to parse JSON into [NewsArticleModel].
  factory NewsArticleModel.fromJson(Map<String, dynamic> json) =>
      _$NewsArticleModelFromJson(json);

  /// Converts this model into a JSON map.
  Map<String, dynamic> toJson() => _$NewsArticleModelToJson(this);

  /// Maps this data model to the independent domain entity [NewsArticle].
  NewsArticle toEntity() {
    final cleanTitle = (title != null && title!.trim().isNotEmpty)
        ? title!.trim()
        : 'Untitled Article';
    final cleanUrl = (url != null && url!.trim().isNotEmpty)
        ? url!.trim()
        : '';

    return NewsArticle(
      source: source?.toEntity(),
      author: author?.trim(),
      title: cleanTitle,
      description: description?.trim(),
      url: cleanUrl,
      urlToImage: (urlToImage != null && urlToImage!.trim().isNotEmpty)
          ? urlToImage!.trim()
          : null,
      publishedAt: publishedAt,
      content: content?.trim(),
    );
  }

  /// Creates a data model from an existing domain entity.
  factory NewsArticleModel.fromEntity(NewsArticle entity) {
    return NewsArticleModel(
      source: entity.source != null
          ? NewsSourceModel.fromEntity(entity.source!)
          : null,
      author: entity.author,
      title: entity.title,
      description: entity.description,
      url: entity.url,
      urlToImage: entity.urlToImage,
      publishedAt: entity.publishedAt,
      content: entity.content,
    );
  }

  NewsArticleModel copyWith({
    NewsSourceModel? source,
    String? author,
    String? title,
    String? description,
    String? url,
    String? urlToImage,
    DateTime? publishedAt,
    String? content,
  }) {
    return NewsArticleModel(
      source: source ?? this.source,
      author: author ?? this.author,
      title: title ?? this.title,
      description: description ?? this.description,
      url: url ?? this.url,
      urlToImage: urlToImage ?? this.urlToImage,
      publishedAt: publishedAt ?? this.publishedAt,
      content: content ?? this.content,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NewsArticleModel &&
          runtimeType == other.runtimeType &&
          source == other.source &&
          author == other.author &&
          title == other.title &&
          description == other.description &&
          url == other.url &&
          urlToImage == other.urlToImage &&
          publishedAt == other.publishedAt &&
          content == other.content;

  @override
  int get hashCode => Object.hash(
        source,
        author,
        title,
        description,
        url,
        urlToImage,
        publishedAt,
        content,
      );

  @override
  String toString() =>
      'NewsArticleModel(title: $title, author: $author, url: $url)';
}
