import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../../../../core/error/app_error.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../news/data/models/news_article_model.dart';

/// Contract for local bookmark persistence operations.
abstract class BookmarksLocalDataSource {
  /// Loads all locally bookmarked news articles.
  Future<List<NewsArticleModel>> getBookmarks();

  /// Persists a news article bookmark to local storage.
  /// Prevents duplicates by using the article URL as the unique key.
  Future<void> saveBookmark(NewsArticleModel article);

  /// Removes an article bookmark by its unique URL.
  Future<void> removeBookmark(String articleUrl);

  /// Checks whether an article is currently bookmarked by its URL.
  Future<bool> isBookmarked(String articleUrl);

  /// Clears all saved bookmarks from local storage.
  Future<void> clearAllBookmarks();
}

/// Hive-backed implementation of [BookmarksLocalDataSource].
///
/// Features:
/// - Persistent offline storage using Hive box [StorageService.bookmarksBox]
/// - JSON serialization for schema evolution and robustness
/// - Safe handling of null, missing, or malformed fields
/// - Duplicate prevention via URL normalization
/// - Injection support for testing
class BookmarksLocalDataSourceImpl implements BookmarksLocalDataSource {
  final Box<dynamic>? _injectedBox;

  BookmarksLocalDataSourceImpl({Box<dynamic>? box}) : _injectedBox = box;

  Future<Box<dynamic>> _getBox() async {
    if (_injectedBox != null) {
      return _injectedBox!;
    }
    try {
      return await StorageService.openBox<dynamic>(StorageService.bookmarksBox);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          '[BookmarksLocalDataSource] Error opening Hive box: $e\n$stackTrace',
        );
      }
      throw CacheError('Failed to access bookmark storage: $e');
    }
  }

  /// Generates a normalized storage key for an article.
  String _normalizeKey(String? url, String? title) {
    if (url != null && url.trim().isNotEmpty) {
      return url.trim();
    }
    if (title != null && title.trim().isNotEmpty) {
      return title.trim();
    }
    return '';
  }

  @override
  Future<List<NewsArticleModel>> getBookmarks() async {
    try {
      final box = await _getBox();
      final articles = <NewsArticleModel>[];
      final seenKeys = <String>{};

      for (final value in box.values) {
        try {
          NewsArticleModel? model;
          if (value is String) {
            final decoded = jsonDecode(value);
            if (decoded is Map<String, dynamic>) {
              model = NewsArticleModel.fromJson(decoded);
            } else if (decoded is Map) {
              model = NewsArticleModel.fromJson(
                Map<String, dynamic>.from(decoded),
              );
            }
          } else if (value is Map<String, dynamic>) {
            model = NewsArticleModel.fromJson(value);
          } else if (value is Map) {
            model = NewsArticleModel.fromJson(
              Map<String, dynamic>.from(value),
            );
          }

          if (model != null) {
            final key = _normalizeKey(model.url, model.title);
            if (key.isNotEmpty && !seenKeys.contains(key)) {
              seenKeys.add(key);
              articles.add(model);
            } else if (key.isEmpty) {
              articles.add(model);
            }
          }
        } catch (itemError) {
          if (kDebugMode) {
            debugPrint(
              '[BookmarksLocalDataSource] Skipped corrupted entry: $itemError',
            );
          }
        }
      }

      return articles;
    } on AppError {
      rethrow;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          '[BookmarksLocalDataSource] Error getting bookmarks: $e\n$stackTrace',
        );
      }
      throw CacheError('Failed to load bookmarks from storage: $e');
    }
  }

  @override
  Future<void> saveBookmark(NewsArticleModel article) async {
    try {
      final key = _normalizeKey(article.url, article.title);
      if (key.isEmpty) {
        throw const CacheError('Article must have a valid URL or title to be bookmarked.');
      }

      final box = await _getBox();
      final payload = jsonEncode(article.toJson());
      await box.put(key, payload);
    } on AppError {
      rethrow;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          '[BookmarksLocalDataSource] Error saving bookmark: $e\n$stackTrace',
        );
      }
      throw CacheError('Failed to save bookmark: $e');
    }
  }

  @override
  Future<void> removeBookmark(String articleUrl) async {
    try {
      final key = articleUrl.trim();
      if (key.isEmpty) return;

      final box = await _getBox();
      if (box.containsKey(key)) {
        await box.delete(key);
        return;
      }

      // Fallback search across values if key format differed
      dynamic targetKey;
      for (final currentKey in box.keys) {
        final val = box.get(currentKey);
        if (val is String && val.contains(key)) {
          targetKey = currentKey;
          break;
        }
      }

      if (targetKey != null) {
        await box.delete(targetKey);
      }
    } on AppError {
      rethrow;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          '[BookmarksLocalDataSource] Error removing bookmark: $e\n$stackTrace',
        );
      }
      throw CacheError('Failed to remove bookmark: $e');
    }
  }

  @override
  Future<bool> isBookmarked(String articleUrl) async {
    try {
      final key = articleUrl.trim();
      if (key.isEmpty) return false;

      final box = await _getBox();
      if (box.containsKey(key)) {
        return true;
      }

      for (final currentKey in box.keys) {
        final val = box.get(currentKey);
        if (val is String && val.contains(key)) {
          return true;
        }
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> clearAllBookmarks() async {
    try {
      final box = await _getBox();
      await box.clear();
    } on AppError {
      rethrow;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          '[BookmarksLocalDataSource] Error clearing bookmarks: $e\n$stackTrace',
        );
      }
      throw CacheError('Failed to clear bookmarks: $e');
    }
  }
}
