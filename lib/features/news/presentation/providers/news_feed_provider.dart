import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/app_error.dart';
import '../../domain/entities/news_article.dart';
import '../../domain/entities/paginated_news.dart';
import '../../domain/usecases/get_top_headlines.dart';
import '../../domain/usecases/search_news.dart';
import 'news_feed_state.dart';
import 'news_providers.dart';

/// Riverpod notifier managing state, pagination, category switching, search, and refresh for the News Feed.
class NewsFeedNotifier extends Notifier<NewsFeedState> {
  late final GetTopHeadlines _getTopHeadlines;
  late final SearchNews _searchNews;
  int _currentRequestId = 0;

  @override
  NewsFeedState build() {
    _getTopHeadlines = ref.watch(getTopHeadlinesUseCaseProvider);
    _searchNews = ref.watch(searchNewsUseCaseProvider);

    // Trigger initial headline fetch asynchronously on first load
    Future.microtask(() => loadInitialHeadlines());

    return const NewsFeedState(status: NewsFeedStatus.initial);
  }

  /// Generates a unique key for deduplicating news articles.
  /// Uses article URL as primary unique identifier; falls back to available fields if URL is empty.
  String _getArticleKey(NewsArticle article) {
    final cleanUrl = article.url.trim();
    if (cleanUrl.isNotEmpty) {
      return 'url:$cleanUrl';
    }
    final cleanTitle = article.title.trim();
    final timestamp = article.publishedAt?.millisecondsSinceEpoch ?? 0;
    final source = article.source?.name.trim() ?? article.author?.trim() ?? '';
    return 'fallback:$cleanTitle|$timestamp|$source';
  }

  /// Loads the first page of news headlines for the specified category or currently selected category.
  Future<void> loadInitialHeadlines({String? category}) async {
    final targetCategory =
        (category ?? state.selectedCategory).trim().toLowerCase();
    final requestId = ++_currentRequestId;

    if (kDebugMode) {
      debugPrint(
        '[NewsFeedNotifier] loadInitialHeadlines start: category=$targetCategory, page=1',
      );
    }

    state = state.copyWith(
      selectedCategory: targetCategory,
      status: NewsFeedStatus.loading,
      articles: const [],
      page: 1,
      hasReachedMax: false,
      isLoadingMore: false,
      isRefreshing: false,
      clearSearchQuery: true,
      clearTotalResults: true,
      clearError: true,
      clearPaginationError: true,
    );

    try {
      final articles = await _getTopHeadlines(
        country: ApiConstants.defaultCountry,
        category: targetCategory,
        page: 1,
        pageSize: ApiConstants.defaultPageSize,
      );

      // Verify this request is still the latest one before mutating state
      if (requestId != _currentRequestId) {
        return;
      }

      int? totalResults;
      if (articles is PaginatedNews) {
        totalResults = articles.totalResults;
      }

      if (kDebugMode) {
        debugPrint(
          '[NewsFeedNotifier] loadInitialHeadlines response: count=${articles.length}, totalResults=$totalResults',
        );
      }

      if (articles.isEmpty) {
        state = state.copyWith(
          status: NewsFeedStatus.empty,
          articles: const [],
          page: 1,
          totalResults: totalResults ?? 0,
          hasReachedMax: true,
          clearError: true,
        );
      } else {
        // Use totalResults from API response to determine whether more pages exist.
        // Do not assume API always returns a full page.
        final bool hasReachedMax;
        if (totalResults != null) {
          hasReachedMax = articles.length >= totalResults ||
              (totalResults > 0 && 1 * ApiConstants.defaultPageSize >= totalResults);
        } else {
          hasReachedMax = articles.length < ApiConstants.defaultPageSize;
        }

        if (kDebugMode) {
          debugPrint(
            '[NewsFeedNotifier] loadInitialHeadlines success: articles=${articles.length}, totalResults=$totalResults, hasMore=${!hasReachedMax}',
          );
        }

        state = state.copyWith(
          status: NewsFeedStatus.loaded,
          articles: articles,
          page: 1,
          totalResults: totalResults,
          hasReachedMax: hasReachedMax,
          clearError: true,
        );
      }
    } on AppError catch (e) {
      if (requestId == _currentRequestId) {
        if (kDebugMode) {
          debugPrint(
            '[NewsFeedNotifier] loadInitialHeadlines error: code=${e.code}, message="${e.message}"',
          );
        }
        state = state.copyWith(
          status: NewsFeedStatus.error,
          errorMessage: e.message,
        );
      }
    } catch (_) {
      if (requestId == _currentRequestId) {
        if (kDebugMode) {
          debugPrint(
            '[NewsFeedNotifier] loadInitialHeadlines unexpected error for category=$targetCategory',
          );
        }
        state = state.copyWith(
          status: NewsFeedStatus.error,
          errorMessage:
              'Unable to load $targetCategory headlines. Please check your connection and try again.',
        );
      }
    }
  }

  /// Switches active news category, resets search, and reloads headlines for the selected category.
  Future<void> changeCategory(String category) async {
    final normalized = category.trim().toLowerCase();
    if (normalized == state.selectedCategory && !state.isSearching) {
      return;
    }

    await loadInitialHeadlines(category: normalized);
  }

  /// Submits a search keyword to the `/everything` endpoint.
  Future<void> search(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      await clearSearch();
      return;
    }

    // Avoid duplicate requests for identical completed or in-progress queries
    if (cleanQuery == state.searchQuery &&
        (state.isLoaded || state.status == NewsFeedStatus.loading)) {
      return;
    }

    final requestId = ++_currentRequestId;

    if (kDebugMode) {
      debugPrint(
        '[NewsFeedNotifier] search start: query="$cleanQuery", page=1',
      );
    }

    state = state.copyWith(
      status: NewsFeedStatus.loading,
      searchQuery: cleanQuery,
      articles: const [],
      page: 1,
      hasReachedMax: false,
      isLoadingMore: false,
      isRefreshing: false,
      clearTotalResults: true,
      clearError: true,
      clearPaginationError: true,
    );

    try {
      final searchResults = await _searchNews(
        query: cleanQuery,
        sortBy: ApiConstants.defaultSortBy,
        page: 1,
        pageSize: ApiConstants.defaultPageSize,
      );

      if (requestId != _currentRequestId) {
        return;
      }

      int? totalResults;
      if (searchResults is PaginatedNews) {
        totalResults = searchResults.totalResults;
      }

      if (kDebugMode) {
        debugPrint(
          '[NewsFeedNotifier] search response: count=${searchResults.length}, totalResults=$totalResults',
        );
      }

      if (searchResults.isEmpty) {
        state = state.copyWith(
          status: NewsFeedStatus.empty,
          articles: const [],
          page: 1,
          totalResults: totalResults ?? 0,
          hasReachedMax: true,
          clearError: true,
        );
      } else {
        final bool hasReachedMax;
        if (totalResults != null) {
          hasReachedMax = searchResults.length >= totalResults ||
              (totalResults > 0 && 1 * ApiConstants.defaultPageSize >= totalResults);
        } else {
          hasReachedMax = searchResults.length < ApiConstants.defaultPageSize;
        }

        if (kDebugMode) {
          debugPrint(
            '[NewsFeedNotifier] search success: articles=${searchResults.length}, totalResults=$totalResults, hasMore=${!hasReachedMax}',
          );
        }

        state = state.copyWith(
          status: NewsFeedStatus.loaded,
          articles: searchResults,
          page: 1,
          totalResults: totalResults,
          hasReachedMax: hasReachedMax,
          clearError: true,
        );
      }
    } on AppError catch (e) {
      if (requestId == _currentRequestId) {
        if (kDebugMode) {
          debugPrint(
            '[NewsFeedNotifier] search error: code=${e.code}, message="${e.message}"',
          );
        }
        state = state.copyWith(
          status: NewsFeedStatus.error,
          errorMessage: e.message,
        );
      }
    } catch (_) {
      if (requestId == _currentRequestId) {
        if (kDebugMode) {
          debugPrint(
            '[NewsFeedNotifier] search unexpected error for query="$cleanQuery"',
          );
        }
        state = state.copyWith(
          status: NewsFeedStatus.error,
          errorMessage:
              'Unable to search articles right now. Please check your connection and try again.',
        );
      }
    }
  }

  /// Clears active search and returns to currently selected category top headlines.
  Future<void> clearSearch() async {
    if (!state.isSearching && state.searchQuery == null) {
      return;
    }

    await loadInitialHeadlines(category: state.selectedCategory);
  }

  /// Fetches next page for infinite scrolling, avoiding duplicate entries.
  Future<void> fetchNextPage() async {
    if (state.isLoadingMore ||
        state.isRefreshing ||
        state.status == NewsFeedStatus.loading ||
        state.hasReachedMax) {
      return;
    }

    final requestId = _currentRequestId;
    final nextPage = state.page + 1;

    if (kDebugMode) {
      debugPrint(
        '[NewsFeedNotifier] fetchNextPage requested: nextPage=$nextPage, isSearching=${state.isSearching}, query=${state.searchQuery}, category=${state.selectedCategory}',
      );
    }

    state = state.copyWith(
      isLoadingMore: true,
      clearPaginationError: true,
    );

    try {
      final List<NewsArticle> newArticles;
      if (state.isSearching) {
        newArticles = await _searchNews(
          query: state.searchQuery!,
          sortBy: ApiConstants.defaultSortBy,
          page: nextPage,
          pageSize: ApiConstants.defaultPageSize,
        );
      } else {
        newArticles = await _getTopHeadlines(
          country: ApiConstants.defaultCountry,
          category: state.selectedCategory,
          page: nextPage,
          pageSize: ApiConstants.defaultPageSize,
        );
      }

      // If category or search changed during the async call, discard stale response
      if (requestId != _currentRequestId) {
        return;
      }

      if (newArticles.isEmpty) {
        if (kDebugMode) {
          debugPrint(
            '[NewsFeedNotifier] fetchNextPage returned empty list for page $nextPage. Reached end of feed cleanly.',
          );
        }
        state = state.copyWith(
          isLoadingMore: false,
          hasReachedMax: true,
          clearPaginationError: true,
        );
        return;
      }

      int? totalResults;
      if (newArticles is PaginatedNews) {
        totalResults = newArticles.totalResults;
      }
      final effectiveTotal = totalResults ?? state.totalResults;

      // Prevent duplicate articles using URL as unique identifier (with safe fallback)
      final existingKeys = state.articles.map(_getArticleKey).toSet();
      final uniqueNewArticles = newArticles
          .where((a) => !existingKeys.contains(_getArticleKey(a)))
          .toList();

      final combined = [...state.articles, ...uniqueNewArticles];

      // Determine hasReachedMax using totalResults and response size
      final bool hasReachedMax;
      if (effectiveTotal != null) {
        hasReachedMax = combined.length >= effectiveTotal ||
            (effectiveTotal > 0 && nextPage * ApiConstants.defaultPageSize >= effectiveTotal) ||
            uniqueNewArticles.isEmpty;
      } else {
        hasReachedMax = newArticles.length < ApiConstants.defaultPageSize;
      }

      if (kDebugMode) {
        debugPrint(
          '[NewsFeedNotifier] fetchNextPage success: page=$nextPage, returned=${newArticles.length}, added=${uniqueNewArticles.length}, totalArticles=${combined.length}, totalResults=$effectiveTotal, hasMore=${!hasReachedMax}',
        );
      }

      state = state.copyWith(
        status: NewsFeedStatus.loaded,
        articles: combined,
        page: nextPage,
        totalResults: effectiveTotal,
        isLoadingMore: false,
        hasReachedMax: hasReachedMax,
        clearPaginationError: true,
      );
    } on AppError catch (e) {
      if (requestId != _currentRequestId) return;

      if (kDebugMode) {
        debugPrint(
          '[NewsFeedNotifier] fetchNextPage error: code=${e.code}, message="${e.message}"',
        );
      }

      if (e.code == 'maximumResultsReached' || e.code == 'HTTP_426') {
        // Plan limit reached; stop pagination cleanly without noisy error banner
        state = state.copyWith(
          isLoadingMore: false,
          hasReachedMax: true,
          clearPaginationError: true,
        );
      } else {
        state = state.copyWith(
          isLoadingMore: false,
          paginationErrorMessage: e.message,
        );
      }
    } catch (_) {
      if (requestId != _currentRequestId) return;

      if (kDebugMode) {
        debugPrint(
          '[NewsFeedNotifier] fetchNextPage unexpected error for page $nextPage',
        );
      }

      state = state.copyWith(
        isLoadingMore: false,
        paginationErrorMessage: 'Failed to load more articles. Tap to retry.',
      );
    }
  }

  /// Pull-to-refresh handler fetching page 1 while preserving active category or search query.
  Future<void> refresh() async {
    if (state.isRefreshing || state.isLoadingMore) {
      return;
    }

    final requestId = ++_currentRequestId;

    if (kDebugMode) {
      debugPrint(
        '[NewsFeedNotifier] refresh start: isSearching=${state.isSearching}, query=${state.searchQuery}, category=${state.selectedCategory}',
      );
    }

    state = state.copyWith(
      isRefreshing: true,
      clearPaginationError: true,
    );

    try {
      final List<NewsArticle> refreshed;
      if (state.isSearching) {
        refreshed = await _searchNews(
          query: state.searchQuery!,
          sortBy: ApiConstants.defaultSortBy,
          page: 1,
          pageSize: ApiConstants.defaultPageSize,
        );
      } else {
        refreshed = await _getTopHeadlines(
          country: ApiConstants.defaultCountry,
          category: state.selectedCategory,
          page: 1,
          pageSize: ApiConstants.defaultPageSize,
        );
      }

      if (requestId != _currentRequestId) {
        return;
      }

      int? totalResults;
      if (refreshed is PaginatedNews) {
        totalResults = refreshed.totalResults;
      }

      if (kDebugMode) {
        debugPrint(
          '[NewsFeedNotifier] refresh response: count=${refreshed.length}, totalResults=$totalResults',
        );
      }

      if (refreshed.isEmpty) {
        state = state.copyWith(
          status: NewsFeedStatus.empty,
          articles: const [],
          page: 1,
          totalResults: totalResults ?? 0,
          hasReachedMax: true,
          isRefreshing: false,
          clearError: true,
        );
      } else {
        final bool hasReachedMax;
        if (totalResults != null) {
          hasReachedMax = refreshed.length >= totalResults ||
              (totalResults > 0 && 1 * ApiConstants.defaultPageSize >= totalResults);
        } else {
          hasReachedMax = refreshed.length < ApiConstants.defaultPageSize;
        }

        if (kDebugMode) {
          debugPrint(
            '[NewsFeedNotifier] refresh success: articles=${refreshed.length}, totalResults=$totalResults, hasMore=${!hasReachedMax}',
          );
        }

        state = state.copyWith(
          status: NewsFeedStatus.loaded,
          articles: refreshed,
          page: 1,
          totalResults: totalResults,
          hasReachedMax: hasReachedMax,
          isRefreshing: false,
          clearError: true,
        );
      }
    } on AppError catch (e) {
      if (requestId == _currentRequestId) {
        if (kDebugMode) {
          debugPrint(
            '[NewsFeedNotifier] refresh error: code=${e.code}, message="${e.message}"',
          );
        }
        state = state.copyWith(
          isRefreshing: false,
          errorMessage: state.articles.isEmpty ? e.message : null,
        );
      }
    } catch (_) {
      if (requestId == _currentRequestId) {
        if (kDebugMode) {
          debugPrint('[NewsFeedNotifier] refresh unexpected error');
        }
        state = state.copyWith(
          isRefreshing: false,
          errorMessage: state.articles.isEmpty
              ? 'Failed to refresh feed. Please try again.'
              : null,
        );
      }
    }
  }
}

/// Global provider for [NewsFeedNotifier] and [NewsFeedState].
final newsFeedNotifierProvider =
    NotifierProvider<NewsFeedNotifier, NewsFeedState>(
  NewsFeedNotifier.new,
);
