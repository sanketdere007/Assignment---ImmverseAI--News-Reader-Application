import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/app_error.dart';
import '../../domain/entities/news_article.dart';
import '../../domain/entities/paginated_news.dart';
import '../../domain/usecases/search_news.dart';
import 'news_providers.dart';
import 'search_news_state.dart';

/// Riverpod notifier managing state, debouncing, pagination, and refresh for News Search.
class SearchNewsNotifier extends Notifier<SearchNewsState> {
  late final SearchNews _searchNews;
  int _currentRequestId = 0;
  Timer? _debounceTimer;

  @override
  SearchNewsState build() {
    _searchNews = ref.watch(searchNewsUseCaseProvider);

    ref.onDispose(() {
      _debounceTimer?.cancel();
    });

    return const SearchNewsState();
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

  /// Live search input handler with ~500ms debounce.
  void onQueryChanged(String query) {
    _debounceTimer?.cancel();
    final cleanQuery = query.trim();

    if (cleanQuery.isEmpty) {
      clearSearch();
      return;
    }

    // If query hasn't changed and results are loaded/loading, skip debouncing
    if (cleanQuery == state.query &&
        (state.isLoaded || state.status == SearchStatus.loading)) {
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      search(cleanQuery);
    });
  }

  /// Submits a search keyword to the `/everything` endpoint.
  Future<void> search(String query) async {
    _debounceTimer?.cancel();
    final cleanQuery = query.trim();

    // Do not call API for empty or whitespace-only query
    if (cleanQuery.isEmpty) {
      clearSearch();
      return;
    }

    // Avoid duplicate requests for identical completed or loading queries
    if (cleanQuery == state.query &&
        (state.isLoaded || state.status == SearchStatus.loading)) {
      return;
    }

    final requestId = ++_currentRequestId;

    if (kDebugMode) {
      debugPrint(
        '[SearchNewsNotifier] search start: query="$cleanQuery", page=1',
      );
    }

    // Reset pagination to page 1 and clear previous query results
    state = state.copyWith(
      status: SearchStatus.loading,
      query: cleanQuery,
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

      // Verify this request is still the latest one before mutating state
      if (requestId != _currentRequestId) {
        return;
      }

      int? totalResults;
      if (searchResults is PaginatedNews) {
        totalResults = searchResults.totalResults;
      }

      if (kDebugMode) {
        debugPrint(
          '[SearchNewsNotifier] search response: count=${searchResults.length}, totalResults=$totalResults',
        );
      }

      if (searchResults.isEmpty) {
        state = state.copyWith(
          status: SearchStatus.empty,
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
            '[SearchNewsNotifier] search success: articles=${searchResults.length}, totalResults=$totalResults, hasMore=${!hasReachedMax}',
          );
        }

        state = state.copyWith(
          status: SearchStatus.loaded,
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
            '[SearchNewsNotifier] search error: code=${e.code}, message="${e.message}"',
          );
        }
        state = state.copyWith(
          status: SearchStatus.error,
          errorMessage: e.message,
        );
      }
    } catch (_) {
      if (requestId == _currentRequestId) {
        if (kDebugMode) {
          debugPrint(
            '[SearchNewsNotifier] search unexpected error for query="$cleanQuery"',
          );
        }
        state = state.copyWith(
          status: SearchStatus.error,
          errorMessage:
              'Unable to search articles right now. Please check your connection and try again.',
        );
      }
    }
  }

  /// Clears active query and results, resets pagination, and returns to initial prompt state.
  void clearSearch() {
    _debounceTimer?.cancel();
    _currentRequestId++;
    state = const SearchNewsState(status: SearchStatus.initial);
  }

  /// Fetches the next page for infinite scrolling, avoiding duplicate entries.
  Future<void> fetchNextPage() async {
    if (state.isLoadingMore ||
        state.isRefreshing ||
        state.status == SearchStatus.loading ||
        state.hasReachedMax ||
        state.query.isEmpty) {
      return;
    }

    final requestId = _currentRequestId;
    final nextPage = state.page + 1;

    if (kDebugMode) {
      debugPrint(
        '[SearchNewsNotifier] fetchNextPage requested: query="${state.query}", nextPage=$nextPage',
      );
    }

    state = state.copyWith(
      isLoadingMore: true,
      clearPaginationError: true,
    );

    try {
      final newArticles = await _searchNews(
        query: state.query,
        sortBy: ApiConstants.defaultSortBy,
        page: nextPage,
        pageSize: ApiConstants.defaultPageSize,
      );

      // Verify this request is still the latest one
      if (requestId != _currentRequestId) {
        return;
      }

      if (newArticles.isEmpty) {
        if (kDebugMode) {
          debugPrint(
            '[SearchNewsNotifier] fetchNextPage returned empty list for page $nextPage. Reached end of search cleanly.',
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

      // Prevent duplicate articles by checking URLs (with safe fallback)
      final existingKeys = state.articles.map(_getArticleKey).toSet();
      final uniqueNewArticles = newArticles
          .where((a) => !existingKeys.contains(_getArticleKey(a)))
          .toList();

      final combined = [...state.articles, ...uniqueNewArticles];

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
          '[SearchNewsNotifier] fetchNextPage success: page=$nextPage, returned=${newArticles.length}, added=${uniqueNewArticles.length}, totalArticles=${combined.length}, totalResults=$effectiveTotal, hasMore=${!hasReachedMax}',
        );
      }

      state = state.copyWith(
        status: SearchStatus.loaded,
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
          '[SearchNewsNotifier] fetchNextPage error: code=${e.code}, message="${e.message}"',
        );
      }

      if (e.code == 'maximumResultsReached' || e.code == 'HTTP_426') {
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
          '[SearchNewsNotifier] fetchNextPage unexpected error for page $nextPage',
        );
      }

      state = state.copyWith(
        isLoadingMore: false,
        paginationErrorMessage: 'Failed to load more articles. Tap to retry.',
      );
    }
  }

  /// Pull-to-refresh handler fetching page 1 for the current search query.
  Future<void> refresh() async {
    if (state.isRefreshing || state.isLoadingMore || state.query.isEmpty) {
      return;
    }

    final requestId = ++_currentRequestId;

    if (kDebugMode) {
      debugPrint(
        '[SearchNewsNotifier] refresh start: query="${state.query}"',
      );
    }

    state = state.copyWith(
      isRefreshing: true,
      clearPaginationError: true,
    );

    try {
      final refreshed = await _searchNews(
        query: state.query,
        sortBy: ApiConstants.defaultSortBy,
        page: 1,
        pageSize: ApiConstants.defaultPageSize,
      );

      if (requestId != _currentRequestId) {
        return;
      }

      int? totalResults;
      if (refreshed is PaginatedNews) {
        totalResults = refreshed.totalResults;
      }

      if (kDebugMode) {
        debugPrint(
          '[SearchNewsNotifier] refresh response: count=${refreshed.length}, totalResults=$totalResults',
        );
      }

      if (refreshed.isEmpty) {
        state = state.copyWith(
          status: SearchStatus.empty,
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
            '[SearchNewsNotifier] refresh success: articles=${refreshed.length}, totalResults=$totalResults, hasMore=${!hasReachedMax}',
          );
        }

        state = state.copyWith(
          status: SearchStatus.loaded,
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
            '[SearchNewsNotifier] refresh error: code=${e.code}, message="${e.message}"',
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
          debugPrint('[SearchNewsNotifier] refresh unexpected error');
        }
        state = state.copyWith(
          isRefreshing: false,
          errorMessage: state.articles.isEmpty
              ? 'Failed to refresh search results. Please try again.'
              : null,
        );
      }
    }
  }
}

/// Global Riverpod provider managing [SearchNewsNotifier] and [SearchNewsState].
final searchNewsNotifierProvider =
    NotifierProvider<SearchNewsNotifier, SearchNewsState>(
  SearchNewsNotifier.new,
);
