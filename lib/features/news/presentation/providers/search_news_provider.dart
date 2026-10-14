import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/app_error.dart';
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

    // Avoid duplicate requests for identical completed queries
    if (cleanQuery == state.query && state.isLoaded) {
      return;
    }

    final requestId = ++_currentRequestId;

    // Reset pagination to page 1 and clear previous query results
    state = state.copyWith(
      status: SearchStatus.loading,
      query: cleanQuery,
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

      // Verify this request is still the latest one before mutating state
      if (requestId != _currentRequestId) {
        return;
      }

      if (searchResults.isEmpty) {
        state = state.copyWith(
          status: SearchStatus.empty,
          articles: const [],
          page: 1,
          hasReachedMax: true,
          clearError: true,
        );
      } else {
        state = state.copyWith(
          status: SearchStatus.loaded,
          articles: searchResults,
          page: 1,
          hasReachedMax: searchResults.length < ApiConstants.defaultPageSize,
          clearError: true,
        );
      }
    } on AppError catch (e) {
      if (requestId == _currentRequestId) {
        state = state.copyWith(
          status: SearchStatus.error,
          errorMessage: e.message,
        );
      }
    } catch (_) {
      if (requestId == _currentRequestId) {
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

    final nextPage = state.page + 1;
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
          status: SearchStatus.loaded,
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

  /// Pull-to-refresh handler fetching page 1 for the current search query.
  Future<void> refresh() async {
    if (state.isRefreshing || state.query.isEmpty) {
      return;
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

      if (refreshed.isEmpty) {
        state = state.copyWith(
          status: SearchStatus.empty,
          articles: const [],
          page: 1,
          hasReachedMax: true,
          isRefreshing: false,
          clearError: true,
        );
      } else {
        state = state.copyWith(
          status: SearchStatus.loaded,
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
            ? 'Failed to refresh search results. Please try again.'
            : null,
      );
    }
  }
}

/// Global Riverpod provider managing [SearchNewsNotifier] and [SearchNewsState].
final searchNewsNotifierProvider =
    NotifierProvider<SearchNewsNotifier, SearchNewsState>(
  SearchNewsNotifier.new,
);
