import 'package:flutter/foundation.dart';
import '../../../news/domain/entities/news_article.dart';

/// Lifecycle statuses for offline news bookmarks.
enum BookmarksStatus {
  initial,
  loading,
  loaded,
  error,
}

/// Immutable state representation for the bookmarks feature.
@immutable
class BookmarksState {
  final BookmarksStatus status;
  final List<NewsArticle> bookmarks;
  final Set<String> bookmarkedUrls;
  final String? errorMessage;

  const BookmarksState({
    this.status = BookmarksStatus.initial,
    this.bookmarks = const [],
    this.bookmarkedUrls = const {},
    this.errorMessage,
  });

  bool get isLoading => status == BookmarksStatus.loading;
  bool get isLoaded => status == BookmarksStatus.loaded;
  bool get isEmpty => status == BookmarksStatus.loaded && bookmarks.isEmpty;

  /// Checks whether an article URL is currently in the active bookmarked set.
  bool isBookmarked(String url) {
    final clean = url.trim();
    if (clean.isEmpty) return false;
    return bookmarkedUrls.contains(clean);
  }

  BookmarksState copyWith({
    BookmarksStatus? status,
    List<NewsArticle>? bookmarks,
    Set<String>? bookmarkedUrls,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BookmarksState(
      status: status ?? this.status,
      bookmarks: bookmarks ?? this.bookmarks,
      bookmarkedUrls: bookmarkedUrls ?? this.bookmarkedUrls,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookmarksState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          listEquals(bookmarks, other.bookmarks) &&
          setEquals(bookmarkedUrls, other.bookmarkedUrls) &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(
        status,
        Object.hashAll(bookmarks),
        Object.hashAll(bookmarkedUrls),
        errorMessage,
      );

  @override
  String toString() =>
      'BookmarksState(status: $status, count: ${bookmarks.length}, error: $errorMessage)';
}
