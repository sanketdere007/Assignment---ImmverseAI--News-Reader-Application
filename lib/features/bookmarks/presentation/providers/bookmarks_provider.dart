import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../news/domain/entities/news_article.dart';
import '../../data/datasources/bookmarks_local_data_source.dart';
import '../../data/repositories/bookmarks_repository_impl.dart';
import '../../domain/repositories/bookmarks_repository.dart';
import '../../domain/usecases/clear_bookmarks_usecase.dart';
import '../../domain/usecases/get_bookmarks_usecase.dart';
import '../../domain/usecases/is_bookmarked_usecase.dart';
import '../../domain/usecases/remove_bookmark_usecase.dart';
import '../../domain/usecases/save_bookmark_usecase.dart';
import 'bookmarks_state.dart';

/// Provider for [BookmarksLocalDataSource].
final bookmarksLocalDataSourceProvider =
    Provider<BookmarksLocalDataSource>((ref) {
  return BookmarksLocalDataSourceImpl();
});

/// Provider for [BookmarksRepository].
final bookmarksRepositoryProvider = Provider<BookmarksRepository>((ref) {
  final localDataSource = ref.watch(bookmarksLocalDataSourceProvider);
  return BookmarksRepositoryImpl(localDataSource: localDataSource);
});

/// Provider for [GetBookmarksUseCase].
final getBookmarksUseCaseProvider = Provider<GetBookmarksUseCase>((ref) {
  final repository = ref.watch(bookmarksRepositoryProvider);
  return GetBookmarksUseCase(repository);
});

/// Provider for [SaveBookmarkUseCase].
final saveBookmarkUseCaseProvider = Provider<SaveBookmarkUseCase>((ref) {
  final repository = ref.watch(bookmarksRepositoryProvider);
  return SaveBookmarkUseCase(repository);
});

/// Provider for [RemoveBookmarkUseCase].
final removeBookmarkUseCaseProvider = Provider<RemoveBookmarkUseCase>((ref) {
  final repository = ref.watch(bookmarksRepositoryProvider);
  return RemoveBookmarkUseCase(repository);
});

/// Provider for [IsBookmarkedUseCase].
final isBookmarkedUseCaseProvider = Provider<IsBookmarkedUseCase>((ref) {
  final repository = ref.watch(bookmarksRepositoryProvider);
  return IsBookmarkedUseCase(repository);
});

/// Provider for [ClearBookmarksUseCase].
final clearBookmarksUseCaseProvider = Provider<ClearBookmarksUseCase>((ref) {
  final repository = ref.watch(bookmarksRepositoryProvider);
  return ClearBookmarksUseCase(repository);
});

/// Riverpod Notifier managing persistent bookmark state and offline operations.
class BookmarksNotifier extends Notifier<BookmarksState> {
  late final GetBookmarksUseCase _getBookmarks;
  late final SaveBookmarkUseCase _saveBookmark;
  late final RemoveBookmarkUseCase _removeBookmark;
  late final ClearBookmarksUseCase _clearBookmarks;

  @override
  BookmarksState build() {
    _getBookmarks = ref.watch(getBookmarksUseCaseProvider);
    _saveBookmark = ref.watch(saveBookmarkUseCaseProvider);
    _removeBookmark = ref.watch(removeBookmarkUseCaseProvider);
    _clearBookmarks = ref.watch(clearBookmarksUseCaseProvider);

    // Asynchronously load saved bookmarks upon initialization
    Future.microtask(() => loadBookmarks());

    return const BookmarksState(status: BookmarksStatus.initial);
  }

  /// Loads all saved bookmarks from local storage into state.
  Future<void> loadBookmarks() async {
    state = state.copyWith(
      status: BookmarksStatus.loading,
      clearError: true,
    );

    try {
      final list = await _getBookmarks();
      // Present in reverse chronological order (newest saved on top)
      final sorted = list.reversed.toList();
      final urls = sorted
          .map((article) => article.url.trim())
          .where((url) => url.isNotEmpty)
          .toSet();

      state = state.copyWith(
        status: BookmarksStatus.loaded,
        bookmarks: sorted,
        bookmarkedUrls: urls,
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(
        status: BookmarksStatus.error,
        errorMessage: 'Unable to load bookmarks from offline storage. Tap to retry.',
      );
    }
  }

  /// Toggles the bookmarked state of an article.
  /// Returns `true` if operation was successful, `false` otherwise.
  Future<bool> toggleBookmark(NewsArticle article) async {
    final cleanUrl = article.url.trim();
    if (state.isBookmarked(cleanUrl)) {
      return removeBookmark(cleanUrl);
    } else {
      return saveBookmark(article);
    }
  }

  /// Saves an article locally, updating state optimistically.
  Future<bool> saveBookmark(NewsArticle article) async {
    final cleanUrl = article.url.trim();
    if (cleanUrl.isEmpty && article.title.trim().isEmpty) {
      return false;
    }

    final previousState = state;

    // Prevent duplicate entries by filtering out existing matching URL
    final updatedList = [
      article,
      ...state.bookmarks.where((item) => item.url.trim() != cleanUrl),
    ];
    final updatedUrls = <String>{...state.bookmarkedUrls};
    if (cleanUrl.isNotEmpty) {
      updatedUrls.add(cleanUrl);
    }

    state = state.copyWith(
      status: BookmarksStatus.loaded,
      bookmarks: updatedList,
      bookmarkedUrls: updatedUrls,
      clearError: true,
    );

    try {
      await _saveBookmark(article);
      return true;
    } catch (_) {
      // Revert optimistic update on storage error
      state = previousState.copyWith(
        errorMessage: 'Failed to save bookmark. Please try again.',
      );
      return false;
    }
  }

  /// Removes an article from bookmarks, updating state optimistically.
  Future<bool> removeBookmark(String articleUrl) async {
    final cleanUrl = articleUrl.trim();
    if (cleanUrl.isEmpty) {
      return false;
    }

    final previousState = state;

    final updatedList = state.bookmarks
        .where((item) => item.url.trim() != cleanUrl)
        .toList();
    final updatedUrls = state.bookmarkedUrls
        .where((url) => url != cleanUrl)
        .toSet();

    state = state.copyWith(
      status: BookmarksStatus.loaded,
      bookmarks: updatedList,
      bookmarkedUrls: updatedUrls,
      clearError: true,
    );

    try {
      await _removeBookmark(cleanUrl);
      return true;
    } catch (_) {
      // Revert optimistic update on storage error
      state = previousState.copyWith(
        errorMessage: 'Failed to remove bookmark. Please try again.',
      );
      return false;
    }
  }

  /// Clears all bookmarks from local storage.
  Future<bool> clearAllBookmarks() async {
    final previousState = state;

    state = state.copyWith(
      status: BookmarksStatus.loaded,
      bookmarks: const [],
      bookmarkedUrls: const {},
      clearError: true,
    );

    try {
      await _clearBookmarks();
      return true;
    } catch (_) {
      state = previousState.copyWith(
        errorMessage: 'Failed to clear bookmarks. Please try again.',
      );
      return false;
    }
  }

  /// Convenience UI interaction: toggles bookmark and displays a styled SnackBar.
  Future<void> toggleBookmarkWithFeedback(
    BuildContext context,
    NewsArticle article,
  ) async {
    final wasBookmarked = state.isBookmarked(article.url);
    final success = await toggleBookmark(article);

    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    if (success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            wasBookmarked ? 'Bookmark removed' : 'Article bookmarked',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          action: wasBookmarked
              ? SnackBarAction(
                  label: 'Undo',
                  onPressed: () => saveBookmark(article),
                )
              : null,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            state.errorMessage ?? 'Bookmark action failed. Please try again.',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

/// Global provider for [BookmarksNotifier] and [BookmarksState].
final bookmarksNotifierProvider =
    NotifierProvider<BookmarksNotifier, BookmarksState>(
  BookmarksNotifier.new,
);

/// Efficient targeted provider to observe whether a specific article URL is bookmarked.
/// Avoids rebuilding unrelated widgets when other bookmarks change.
final isArticleBookmarkedProvider =
    Provider.family<bool, String>((ref, articleUrl) {
  return ref.watch(
    bookmarksNotifierProvider.select<bool>(
      (state) => state.isBookmarked(articleUrl),
    ),
  );
});

/// Provider exposing total count of bookmarked articles.
final bookmarksCountProvider = Provider<int>((ref) {
  return ref.watch(
    bookmarksNotifierProvider.select<int>((state) => state.bookmarks.length),
  );
});
