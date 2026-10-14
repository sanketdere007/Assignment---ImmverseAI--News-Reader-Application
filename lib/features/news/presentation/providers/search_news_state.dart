import 'package:flutter/foundation.dart';
import '../../domain/entities/news_article.dart';

/// Status states representing the lifecycle of the search operation.
enum SearchStatus {
  /// Initial uninitialized state before any search query is submitted.
  initial,

  /// Initial or re-query loading state.
  loading,

  /// Successfully retrieved search results.
  loaded,

  /// Query succeeded but zero articles were matched.
  empty,

  /// Search request failed due to network, auth, or API errors.
  error,
}

/// Immutable state container for the Search News feature.
@immutable
class SearchNewsState {
  /// Overall status of the search operation.
  final SearchStatus status;

  /// Accumulated list of news articles matching the search criteria.
  final List<NewsArticle> articles;

  /// The active search keyword query.
  final String query;

  /// Current pagination page number (1-indexed).
  final int page;

  /// Whether all pages of matching articles have been retrieved.
  final bool hasReachedMax;

  /// Whether an incremental pagination request is running in the background.
  final bool isLoadingMore;

  /// Whether a pull-to-refresh operation is actively executing.
  final bool isRefreshing;

  /// Error message for initial search failure.
  final String? errorMessage;

  /// Error message for pagination append failures.
  final String? paginationErrorMessage;

  const SearchNewsState({
    this.status = SearchStatus.initial,
    this.articles = const [],
    this.query = '',
    this.page = 1,
    this.hasReachedMax = false,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.errorMessage,
    this.paginationErrorMessage,
  });

  /// True when no search has been initiated yet.
  bool get isInitial => status == SearchStatus.initial;

  /// True when search is loading its initial set of articles.
  bool get isInitialLoading =>
      status == SearchStatus.loading && articles.isEmpty;

  /// True when matching articles are loaded and ready to display.
  bool get isLoaded => status == SearchStatus.loaded;

  /// True when the search query completed with zero matching articles.
  bool get isEmpty => status == SearchStatus.empty;

  /// True when the search request failed.
  bool get hasError => status == SearchStatus.error;

  SearchNewsState copyWith({
    SearchStatus? status,
    List<NewsArticle>? articles,
    String? query,
    int? page,
    bool? hasReachedMax,
    bool? isLoadingMore,
    bool? isRefreshing,
    String? errorMessage,
    String? paginationErrorMessage,
    bool clearError = false,
    bool clearPaginationError = false,
  }) {
    return SearchNewsState(
      status: status ?? this.status,
      articles: articles ?? this.articles,
      query: query ?? this.query,
      page: page ?? this.page,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      paginationErrorMessage: clearPaginationError
          ? null
          : (paginationErrorMessage ?? this.paginationErrorMessage),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchNewsState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          listEquals(articles, other.articles) &&
          query == other.query &&
          page == other.page &&
          hasReachedMax == other.hasReachedMax &&
          isLoadingMore == other.isLoadingMore &&
          isRefreshing == other.isRefreshing &&
          errorMessage == other.errorMessage &&
          paginationErrorMessage == other.paginationErrorMessage;

  @override
  int get hashCode => Object.hash(
        status,
        Object.hashAll(articles),
        query,
        page,
        hasReachedMax,
        isLoadingMore,
        isRefreshing,
        errorMessage,
        paginationErrorMessage,
      );

  @override
  String toString() =>
      'SearchNewsState(status: $status, query: "$query", page: $page, articles: ${articles.length}, hasReachedMax: $hasReachedMax)';
}
