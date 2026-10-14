import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'news_article.dart';

/// Clean Architecture domain entity representing a paginated news article result.
///
/// Implements [ListBase<NewsArticle>] for transparent compatibility with methods
/// expecting [List<NewsArticle>] while providing [totalResults] pagination metadata.
@immutable
class PaginatedNews extends ListBase<NewsArticle> {
  final List<NewsArticle> articles;
  final int totalResults;

  PaginatedNews({
    required this.articles,
    this.totalResults = 0,
  });

  @override
  int get length => articles.length;

  @override
  set length(int newLength) {
    throw UnsupportedError('PaginatedNews article list is immutable.');
  }

  @override
  NewsArticle operator [](int index) => articles[index];

  @override
  void operator []=(int index, NewsArticle value) {
    throw UnsupportedError('PaginatedNews article list is immutable.');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaginatedNews &&
          runtimeType == other.runtimeType &&
          totalResults == other.totalResults &&
          listEquals(articles, other.articles);

  @override
  int get hashCode => Object.hash(totalResults, Object.hashAll(articles));

  @override
  String toString() =>
      'PaginatedNews(totalResults: $totalResults, count: ${articles.length})';
}
