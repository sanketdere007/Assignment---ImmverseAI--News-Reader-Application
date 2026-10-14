import '../../../news/domain/entities/news_article.dart';

/// Clean Architecture domain repository contract for news bookmarks.
abstract class BookmarksRepository {
  /// Retrieves all persisted offline bookmarks.
  Future<List<NewsArticle>> getBookmarks();

  /// Persists an article locally for offline reading.
  Future<void> saveBookmark(NewsArticle article);

  /// Removes an article from offline bookmarks by its unique URL.
  Future<void> removeBookmark(String articleUrl);

  /// Checks if an article URL is currently saved as a bookmark.
  Future<bool> isBookmarked(String articleUrl);

  /// Clears all bookmarks from persistent storage.
  Future<void> clearAllBookmarks();
}
