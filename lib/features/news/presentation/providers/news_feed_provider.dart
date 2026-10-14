import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/app_error.dart';
import '../../domain/entities/news_article.dart';
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

  /// Loads the first page of news headlines for the specified category or currently selected category.
  Future<void> loadInitialHeadlines({String? category}) async {
    final targetCategory =
        (category ?? state.selectedCategory).trim().toLowerCase();
    final requestId = ++_currentRequestId;

    state = state.copyWith(
      selectedCategory: targetCategory,
      status: NewsFeedStatus.loading,
      articles: const [],
      page: 1,
      hasReachedMax: false,
      isLoadingMore: false,
      isRefreshing: false,
      clearSearchQuery: true,
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

      if (articles.isEmpty) {
        state = state.copyWith(
          status: NewsFeedStatus.empty,
          articles: const [],
          page: 1,
          hasReachedMax: true,
          clearError: true,
        );
      } else {
        state = state.copyWith(
          status: NewsFeedStatus.loaded,
          articles: articles,
          page: 1,
          hasReachedMax: articles.length < ApiConstants.defaultPageSize,
          clearError: true,
        );
      }
    } on AppError catch (e) {
      if (requestId == _currentRequestId) {
        state = state.copyWith(
          status: NewsFeedStatus.error,
          errorMessage: e.message,
        );
      }
    } catch (_) {
      if (requestId == _currentRequestId) {
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

    // Avoid duplicate requests for identical completed queries
    if (cleanQuery == state.searchQuery && state.isLoaded) {
      return;
    }

    final requestId = ++_currentRequestId;

    state = state.copyWith(
      status: NewsFeedStatus.loading,
      searchQuery: cleanQuery,
      articles: const [],
      page: 1,
      hasReachedMax: false,
      isLoadingMore: false,
      isRefreshing: false,
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

      if (searchResults.isEmpty) {
        state = state.copyWith(
          status: NewsFeedStatus.empty,
          articles: const [],
          page: 1,
          hasReachedMax: true,
          clearError: true,
        );
      } else {
        state = state.copyWith(
          status: NewsFeedStatus.loaded,
          articles: searchResults,
          page: 1,
          hasReachedMax: searchResults.length < ApiConstants.defaultPageSize,
          clearError: true,
        );
      }
    } on AppError catch (e) {
      if (requestId == _currentRequestId) {
        state = state.copyWith(
          status: NewsFeedStatus.error,
          errorMessage: e.message,
        );
      }
    } catch (_) {
      if (requestId == _currentRequestId) {
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

    final nextPage = state.page + 1;
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

      if (newArticles.isEmpty) {
        state = state.copyWith(
          isLoadingMore: false,
          hasReachedMax: true,
        );
      } else {
        // Prevent duplicate articles by checking stable URLs and titles
        final existingUrls = state.articles
            .map((a) => a.url)
            .where((u) => u.isNotEmpty)
            .toSet();
        final existingTitles = state.articles.map((a) => a.title).toSet();

        final uniqueNewArticles = newArticles.where((a) {
          if (a.url.isNotEmpty && existingUrls.contains(a.url)) return false;
          if (existingTitles.contains(a.title)) return false;
          return true;
        }).toList();

        final combined = [...state.articles, ...uniqueNewArticles];
        state = state.copyWith(
          status: NewsFeedStatus.loaded,
          articles: combined,
          page: nextPage,
          isLoadingMore: false,
          hasReachedMax: newArticles.length < ApiConstants.defaultPageSize,
          clearPaginationError: true,
        );
      }
    } on AppError catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        paginationErrorMessage: e.message,
      );
    } catch (_) {
      state = state.copyWith(
        isLoadingMore: false,
        paginationErrorMessage: 'Failed to load more articles. Tap to retry.',
      );
    }
  }

  /// Pull-to-refresh handler fetching page 1 while preserving active category or search query.
  Future<void> refresh() async {
    if (state.isRefreshing) {
      return;
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

      if (refreshed.isEmpty) {
        state = state.copyWith(
          status: NewsFeedStatus.empty,
          articles: const [],
          page: 1,
          hasReachedMax: true,
          isRefreshing: false,
          clearError: true,
        );
      } else {
        state = state.copyWith(
          status: NewsFeedStatus.loaded,
          articles: refreshed,
          page: 1,
          hasReachedMax: refreshed.length < ApiConstants.defaultPageSize,
          isRefreshing: false,
          clearError: true,
        );
      }
    } on AppError catch (e) {
      state = state.copyWith(
        isRefreshing: false,
        errorMessage: state.articles.isEmpty ? e.message : null,
      );
    } catch (_) {
      state = state.copyWith(
        isRefreshing: false,
        errorMessage: state.articles.isEmpty
            ? 'Failed to refresh feed. Please try again.'
            : null,
      );
    }
  }
}

/// Global provider for [NewsFeedNotifier] and [NewsFeedState].
final newsFeedNotifierProvider =
    NotifierProvider<NewsFeedNotifier, NewsFeedState>(
  NewsFeedNotifier.new,
);
