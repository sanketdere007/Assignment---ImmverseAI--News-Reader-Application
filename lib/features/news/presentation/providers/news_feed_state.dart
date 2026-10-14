import 'package:flutter/foundation.dart';
import '../../domain/entities/news_article.dart';

/// Status states representing the lifecycle of the news feed.
enum NewsFeedStatus {
  /// Initial uninitialized state before first request starts.
  initial,

  /// Initial or category-switch loading.
  loading,

  /// Successfully loaded articles.
  loaded,

  /// Successfully queried but zero articles were found.
  empty,

  /// Initial or category fetch failed.
  error,
}

/// Immutable state container for the News Home Screen feed.
@immutable
class NewsFeedState {
  /// Overall status of the feed.
  final NewsFeedStatus status;

  /// Current accumulated list of news articles.
  final List<NewsArticle> articles;

  /// Currently selected category filter (e.g. 'general', 'business').
  final String selectedCategory;

  /// Active search query string when user is searching across `/everything`.
  final String? searchQuery;

  /// Current pagination page number (1-indexed).
  final int page;

  /// Total count of articles reported by the News API.
  final int? totalResults;

  /// Whether the end of the news feed has been reached.
  final bool hasReachedMax;

  /// Whether an incremental pagination request is running.
  final bool isLoadingMore;

  /// Whether a pull-to-refresh operation is actively executing.
  final bool isRefreshing;

  /// Error message for initial or full-feed load failures.
  final String? errorMessage;

  /// Error message for pagination append failures.
  final String? paginationErrorMessage;

  const NewsFeedState({
    this.status = NewsFeedStatus.initial,
    this.articles = const [],
    this.selectedCategory = 'general',
    this.searchQuery,
    this.page = 1,
    this.totalResults,
    this.hasReachedMax = false,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.errorMessage,
    this.paginationErrorMessage,
  });

  /// True when more results are available for pagination.
  bool get hasMore => !hasReachedMax;

  /// True when the feed is loading its initial set of articles.
  bool get isInitialLoading =>
      status == NewsFeedStatus.loading && articles.isEmpty;

  /// True when articles are loaded and ready to display.
  bool get isLoaded => status == NewsFeedStatus.loaded;

  /// True when the query completed with zero results.
  bool get isEmpty => status == NewsFeedStatus.empty;

  /// True when the initial or full load failed.
  bool get hasError => status == NewsFeedStatus.error;

  /// True when an active search query is currently filtering the feed.
  bool get isSearching =>
      searchQuery != null && searchQuery!.trim().isNotEmpty;

  NewsFeedState copyWith({
    NewsFeedStatus? status,
    List<NewsArticle>? articles,
    String? selectedCategory,
    String? searchQuery,
    int? page,
    int? totalResults,
    bool? hasReachedMax,
    bool? isLoadingMore,
    bool? isRefreshing,
    String? errorMessage,
    String? paginationErrorMessage,
    bool clearSearchQuery = false,
    bool clearTotalResults = false,
    bool clearError = false,
    bool clearPaginationError = false,
  }) {
    return NewsFeedState(
      status: status ?? this.status,
      articles: articles ?? this.articles,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: clearSearchQuery ? null : (searchQuery ?? this.searchQuery),
      page: page ?? this.page,
      totalResults:
          clearTotalResults ? null : (totalResults ?? this.totalResults),
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
      other is NewsFeedState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          listEquals(articles, other.articles) &&
          selectedCategory == other.selectedCategory &&
          searchQuery == other.searchQuery &&
          page == other.page &&
          totalResults == other.totalResults &&
          hasReachedMax == other.hasReachedMax &&
          isLoadingMore == other.isLoadingMore &&
          isRefreshing == other.isRefreshing &&
          errorMessage == other.errorMessage &&
          paginationErrorMessage == other.paginationErrorMessage;

  @override
  int get hashCode => Object.hash(
        status,
        Object.hashAll(articles),
        selectedCategory,
        searchQuery,
        page,
        totalResults,
        hasReachedMax,
        isLoadingMore,
        isRefreshing,
        errorMessage,
        paginationErrorMessage,
      );

  @override
  String toString() =>
      'NewsFeedState(status: $status, category: $selectedCategory, search: $searchQuery, page: $page, totalResults: $totalResults, articles: ${articles.length}, hasReachedMax: $hasReachedMax)';
}
