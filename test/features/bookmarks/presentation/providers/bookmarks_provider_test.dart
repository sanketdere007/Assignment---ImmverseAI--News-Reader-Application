import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicknews/features/bookmarks/domain/repositories/bookmarks_repository.dart';
import 'package:quicknews/features/bookmarks/presentation/providers/bookmarks_provider.dart';
import 'package:quicknews/features/bookmarks/presentation/providers/bookmarks_state.dart';
import 'package:quicknews/features/news/domain/entities/news_article.dart';
import 'package:quicknews/features/news/domain/entities/news_source.dart';

class FakeBookmarksRepository implements BookmarksRepository {
  final List<NewsArticle> _items = [];
  bool shouldThrowOnSave = false;
  bool shouldThrowOnRemove = false;

  @override
  Future<List<NewsArticle>> getBookmarks() async {
    return List.unmodifiable(_items);
  }

  @override
  Future<void> saveBookmark(NewsArticle article) async {
    if (shouldThrowOnSave) {
      throw Exception('Database write failed');
    }
    _items.removeWhere((item) => item.url == article.url);
    _items.add(article);
  }

  @override
  Future<void> removeBookmark(String articleUrl) async {
    if (shouldThrowOnRemove) {
      throw Exception('Database delete failed');
    }
    _items.removeWhere((item) => item.url == articleUrl);
  }

  @override
  Future<bool> isBookmarked(String articleUrl) async {
    return _items.any((item) => item.url == articleUrl);
  }

  @override
  Future<void> clearAllBookmarks() async {
    _items.clear();
  }
}

void main() {
  late FakeBookmarksRepository repository;
  late ProviderContainer container;

  const testArticle1 = NewsArticle(
    source: NewsSource(name: 'BBC News'),
    author: 'Reporter 1',
    title: 'Headline One',
    description: 'Description 1',
    url: 'https://news.com/article1',
  );

  const testArticle2 = NewsArticle(
    source: NewsSource(name: 'CNN'),
    author: 'Reporter 2',
    title: 'Headline Two',
    description: 'Description 2',
    url: 'https://news.com/article2',
  );

  setUp(() {
    repository = FakeBookmarksRepository();
    container = ProviderContainer(
      overrides: [
        bookmarksRepositoryProvider.overrideWithValue(repository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('BookmarksNotifier', () {
    test('initial state loads bookmarks from repository asynchronously', () async {
      await repository.saveBookmark(testArticle1);

      // Read notifier
      final notifier = container.read(bookmarksNotifierProvider.notifier);
      await notifier.loadBookmarks();

      final state = container.read(bookmarksNotifierProvider);
      expect(state.status, BookmarksStatus.loaded);
      expect(state.bookmarks.length, 1);
      expect(state.isBookmarked('https://news.com/article1'), isTrue);
      expect(state.isBookmarked('https://news.com/article2'), isFalse);
    });

    test('saveBookmark adds article to state immediately and updates bookmarkedUrls', () async {
      final notifier = container.read(bookmarksNotifierProvider.notifier);

      final success = await notifier.saveBookmark(testArticle1);
      expect(success, isTrue);

      final state = container.read(bookmarksNotifierProvider);
      expect(state.bookmarks.length, 1);
      expect(state.bookmarks.first.title, 'Headline One');
      expect(state.bookmarkedUrls.contains(testArticle1.url), isTrue);

      // Verify targeted family provider
      final isBookmarked = container.read(
        isArticleBookmarkedProvider(testArticle1.url),
      );
      expect(isBookmarked, isTrue);
    });

    test('saveBookmark prevents duplicate entries for the same article URL', () async {
      final notifier = container.read(bookmarksNotifierProvider.notifier);

      await notifier.saveBookmark(testArticle1);
      await notifier.saveBookmark(testArticle2);

      // Attempt saving testArticle1 again with slightly modified content
      final modifiedArticle1 = testArticle1.copyWith(title: 'Headline One Updated');
      await notifier.saveBookmark(modifiedArticle1);

      final state = container.read(bookmarksNotifierProvider);
      expect(state.bookmarks.length, 2);
      expect(state.bookmarks.first.title, 'Headline One Updated');
      expect(state.bookmarkedUrls.length, 2);
    });

    test('removeBookmark removes article and updates set', () async {
      final notifier = container.read(bookmarksNotifierProvider.notifier);

      await notifier.saveBookmark(testArticle1);
      await notifier.saveBookmark(testArticle2);
      expect(container.read(bookmarksNotifierProvider).bookmarks.length, 2);

      final success = await notifier.removeBookmark(testArticle1.url);
      expect(success, isTrue);

      final state = container.read(bookmarksNotifierProvider);
      expect(state.bookmarks.length, 1);
      expect(state.bookmarks.first.url, testArticle2.url);
      expect(state.isBookmarked(testArticle1.url), isFalse);
      expect(state.isBookmarked(testArticle2.url), isTrue);
    });

    test('toggleBookmark adds unbookmarked article and removes bookmarked article', () async {
      final notifier = container.read(bookmarksNotifierProvider.notifier);

      // 1. Toggle when not bookmarked -> saves
      await notifier.toggleBookmark(testArticle1);
      expect(container.read(bookmarksNotifierProvider).isBookmarked(testArticle1.url), isTrue);

      // 2. Toggle when bookmarked -> removes
      await notifier.toggleBookmark(testArticle1);
      expect(container.read(bookmarksNotifierProvider).isBookmarked(testArticle1.url), isFalse);
      expect(container.read(bookmarksNotifierProvider).bookmarks.isEmpty, isTrue);
    });

    test('reverts optimistic update and sets errorMessage when save fails', () async {
      final notifier = container.read(bookmarksNotifierProvider.notifier);
      repository.shouldThrowOnSave = true;

      final success = await notifier.saveBookmark(testArticle1);
      expect(success, isFalse);

      final state = container.read(bookmarksNotifierProvider);
      expect(state.bookmarks.isEmpty, isTrue);
      expect(state.isBookmarked(testArticle1.url), isFalse);
      expect(state.errorMessage, isNotNull);
    });

    test('clearAllBookmarks removes all articles', () async {
      final notifier = container.read(bookmarksNotifierProvider.notifier);
      await notifier.saveBookmark(testArticle1);
      await notifier.saveBookmark(testArticle2);

      final success = await notifier.clearAllBookmarks();
      expect(success, isTrue);

      final state = container.read(bookmarksNotifierProvider);
      expect(state.bookmarks.isEmpty, isTrue);
      expect(state.bookmarkedUrls.isEmpty, isTrue);
    });
  });
}
