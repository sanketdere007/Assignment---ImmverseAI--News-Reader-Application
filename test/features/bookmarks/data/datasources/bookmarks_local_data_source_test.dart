import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:quicknews/core/error/app_error.dart';
import 'package:quicknews/features/bookmarks/data/datasources/bookmarks_local_data_source.dart';
import 'package:quicknews/features/news/data/models/news_article_model.dart';
import 'package:quicknews/features/news/data/models/news_source_model.dart';

class FakeBox<T> implements Box<T> {
  final Map<dynamic, T> _storage = {};

  @override
  Iterable<T> get values => _storage.values;

  @override
  Iterable<dynamic> get keys => _storage.keys;

  @override
  bool containsKey(dynamic key) => _storage.containsKey(key);

  @override
  T? get(dynamic key, {T? defaultValue}) => _storage[key] ?? defaultValue;

  @override
  Future<void> put(dynamic key, T value) async {
    _storage[key] = value;
  }

  @override
  Future<void> delete(dynamic key) async {
    _storage.remove(key);
  }

  @override
  Future<int> clear() async {
    final count = _storage.length;
    _storage.clear();
    return count;
  }

  @override
  bool get isEmpty => _storage.isEmpty;

  @override
  bool get isNotEmpty => _storage.isNotEmpty;

  @override
  int get length => _storage.length;

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeBox<dynamic> fakeBox;
  late BookmarksLocalDataSourceImpl dataSource;

  final sampleArticle = NewsArticleModel(
    source: const NewsSourceModel(id: 'bbc-news', name: 'BBC News'),
    author: 'John Doe',
    title: 'Flutter 3.30 Released',
    description: 'Major enhancements in Flutter',
    url: 'https://example.com/flutter-update',
    urlToImage: 'https://example.com/image.jpg',
    publishedAt: DateTime.utc(2026, 10, 14, 12, 0, 0),
    content: 'Full article text content goes here.',
  );

  setUp(() {
    fakeBox = FakeBox<dynamic>();
    dataSource = BookmarksLocalDataSourceImpl(box: fakeBox);
  });

  group('BookmarksLocalDataSourceImpl', () {
    test('saveBookmark saves JSON string and prevents duplicates with same URL', () async {
      await dataSource.saveBookmark(sampleArticle);

      expect(fakeBox.length, 1);
      expect(fakeBox.containsKey(sampleArticle.url), isTrue);

      // Verify stored JSON has all fields
      final raw = fakeBox.get(sampleArticle.url) as String;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect(decoded['title'], 'Flutter 3.30 Released');
      expect(decoded['author'], 'John Doe');
      expect(decoded['url'], 'https://example.com/flutter-update');
      expect(decoded['source']['name'], 'BBC News');

      // Save duplicate with same URL but updated title
      final updatedArticle = sampleArticle.copyWith(
        title: 'Flutter 3.30 Released (Updated)',
      );
      await dataSource.saveBookmark(updatedArticle);

      // Must remain 1 entry, updated in-place
      expect(fakeBox.length, 1);
      final rawUpdated = fakeBox.get(sampleArticle.url) as String;
      final decodedUpdated = jsonDecode(rawUpdated) as Map<String, dynamic>;
      expect(decodedUpdated['title'], 'Flutter 3.30 Released (Updated)');
    });

    test('getBookmarks loads saved articles and maps them back safely', () async {
      await dataSource.saveBookmark(sampleArticle);

      final secondArticle = NewsArticleModel(
        source: const NewsSourceModel(name: 'TechCrunch'),
        title: 'AI Revolution',
        url: 'https://example.com/ai-rev',
        publishedAt: DateTime.utc(2026, 10, 13),
      );
      await dataSource.saveBookmark(secondArticle);

      final bookmarks = await dataSource.getBookmarks();
      expect(bookmarks.length, 2);
      expect(bookmarks.any((a) => a.url == sampleArticle.url), isTrue);
      expect(bookmarks.any((a) => a.url == secondArticle.url), isTrue);
    });

    test('getBookmarks safely ignores corrupted box entries', () async {
      await dataSource.saveBookmark(sampleArticle);

      // Inject corrupted non-JSON strings or non-article payloads
      await fakeBox.put('corrupted_key_1', 'not valid json string {{{{');
      await fakeBox.put('corrupted_key_2', 12345);

      final bookmarks = await dataSource.getBookmarks();
      // Should successfully return the 1 valid article without throwing
      expect(bookmarks.length, 1);
      expect(bookmarks.first.title, 'Flutter 3.30 Released');
    });

    test('isBookmarked accurately reflects storage status', () async {
      expect(await dataSource.isBookmarked(sampleArticle.url!), isFalse);

      await dataSource.saveBookmark(sampleArticle);
      expect(await dataSource.isBookmarked(sampleArticle.url!), isTrue);

      await dataSource.removeBookmark(sampleArticle.url!);
      expect(await dataSource.isBookmarked(sampleArticle.url!), isFalse);
    });

    test('removeBookmark removes entry by URL', () async {
      await dataSource.saveBookmark(sampleArticle);
      expect(fakeBox.containsKey(sampleArticle.url), isTrue);

      await dataSource.removeBookmark(sampleArticle.url!);
      expect(fakeBox.containsKey(sampleArticle.url), isFalse);
      expect(fakeBox.length, 0);
    });

    test('clearAllBookmarks empties the box', () async {
      await dataSource.saveBookmark(sampleArticle);
      await dataSource.saveBookmark(
        sampleArticle.copyWith(url: 'https://example.com/second'),
      );
      expect(fakeBox.length, 2);

      await dataSource.clearAllBookmarks();
      expect(fakeBox.length, 0);
      final list = await dataSource.getBookmarks();
      expect(list.isEmpty, isTrue);
    });

    test('saveBookmark throws CacheError if URL and title are both empty', () async {
      const invalidArticle = NewsArticleModel(title: '', url: '');
      expect(
        () => dataSource.saveBookmark(invalidArticle),
        throwsA(isA<CacheError>()),
      );
    });
  });
}
