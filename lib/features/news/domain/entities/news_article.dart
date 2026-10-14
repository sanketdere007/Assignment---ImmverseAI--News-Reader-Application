import 'package:flutter/foundation.dart';
import 'news_source.dart';

/// Clean Architecture domain entity representing a news article.
///
/// Fully independent from network packages (Dio, JSON parsers, HTTP models).
@immutable
class NewsArticle {
  /// Publisher source information.
  final NewsSource? source;

  /// Author of the article, if identified.
  final String? author;

  /// Article headline or title. Guaranteed non-empty for UI safety.
  final String title;

  /// Brief snippet or summary of the article.
  final String? description;

  /// Direct web URL to the full article.
  final String url;

  /// URL to the featured cover image, if available.
  final String? urlToImage;

  /// Publication timestamp parsed into standard [DateTime].
  final DateTime? publishedAt;

  /// Truncated content body provided by the news feed.
  final String? content;

  const NewsArticle({
    this.source,
    this.author,
    required this.title,
    this.description,
    required this.url,
    this.urlToImage,
    this.publishedAt,
    this.content,
  });

  /// Convenient URI object for navigation or browser launching.
  Uri? get uri => Uri.tryParse(url);

  /// Safe helper getter for displaying the publisher name.
  String get sourceName =>
      (source?.name != null && source!.name.trim().isNotEmpty)
          ? source!.name
          : 'Unknown Source';

  /// Whether a valid web image URL is associated with this article.
  bool get hasValidImage =>
      urlToImage != null &&
      urlToImage!.trim().isNotEmpty &&
      (urlToImage!.startsWith('http://') || urlToImage!.startsWith('https://'));

  /// Copies this entity with optional replaced fields.
  NewsArticle copyWith({
    NewsSource? source,
    String? author,
    String? title,
    String? description,
    String? url,
    String? urlToImage,
    DateTime? publishedAt,
    String? content,
  }) {
    return NewsArticle(
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
      other is NewsArticle &&
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
      'NewsArticle(title: $title, source: $sourceName, publishedAt: $publishedAt)';
}
