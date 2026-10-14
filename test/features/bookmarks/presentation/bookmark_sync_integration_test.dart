import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicknews/features/bookmarks/domain/repositories/bookmarks_repository.dart';
import 'package:quicknews/features/bookmarks/presentation/providers/bookmarks_provider.dart';
import 'package:quicknews/features/bookmarks/presentation/screens/bookmarks_screen.dart';
import 'package:quicknews/features/news/domain/entities/news_article.dart';
import 'package:quicknews/features/news/domain/entities/news_source.dart';
import 'package:quicknews/features/news/presentation/screens/news_detail_screen.dart';
import 'package:quicknews/features/news/presentation/widgets/news_article_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SyncMemoryBookmarksRepository implements BookmarksRepository {
  final Map<String, NewsArticle> _store = {};

  @override
  Future<List<NewsArticle>> getBookmarks() async {
    return _store.values.toList();
  }

  @override
  Future<void> saveBookmark(NewsArticle article) async {
    _store[article.url] = article;
  }

  @override
  Future<void> removeBookmark(String articleUrl) async {
    _store.remove(articleUrl);
  }

  @override
  Future<bool> isBookmarked(String articleUrl) async {
    return _store.containsKey(articleUrl);
  }

  @override
  Future<void> clearAllBookmarks() async {
    _store.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const sharedArticle = NewsArticle(
    source: NewsSource(name: 'Reuters'),
    author: 'Global Desk',
    title: 'Global Tech Breakthrough',
    description: 'Technological leap announced worldwide.',
    url: 'https://reuters.com/tech-breakthrough-1',
  );

  testWidgets(
      'Bookmark state is synchronized across Home card, NewsDetail, and Bookmarks screen',
      (WidgetTester tester) async {
    final sharedRepo = SyncMemoryBookmarksRepository();

    final container = ProviderContainer(
      overrides: [
        bookmarksRepositoryProvider.overrideWithValue(sharedRepo),
      ],
    );

    // 1. Pump HomeScreen with an article card
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: NewsArticleCard(article: sharedArticle),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial state is unbookmarked
    expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_rounded), findsNothing);

    // 2. Bookmark from Home card
    final cardBtn = find.byKey(Key('bookmark_action_${sharedArticle.url}'));
    await tester.tap(cardBtn);
    await tester.pumpAndSettle();

    // Verify Home card is now filled
    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
    expect(find.text('Article bookmarked'), findsOneWidget);

    // 3. Pump NewsDetailScreen for the same article in the same scope
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: NewsDetailScreen(article: sharedArticle),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify detail screen reflects the bookmarked state immediately
    expect(find.byKey(const Key('detail_bookmark_button')), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
    expect(find.byKey(const Key('saved_offline_banner')), findsOneWidget);

    // 4. Pump BookmarksScreen
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: BookmarksScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify BookmarksScreen displays the saved article
    expect(find.text('Saved Articles (1)'), findsOneWidget);
    expect(find.text('Global Tech Breakthrough'), findsOneWidget);

    // 5. Remove bookmark from BookmarksScreen
    final bookmarkRemoveBtn =
        find.byKey(Key('bookmark_action_${sharedArticle.url}'));
    await tester.tap(bookmarkRemoveBtn);
    await tester.pumpAndSettle();

    // BookmarksScreen transitions to empty state
    expect(find.text('Bookmark removed'), findsOneWidget);
    expect(find.text('No bookmarks yet'), findsOneWidget);

    // 6. Return to Home card
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: NewsArticleCard(article: sharedArticle),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Home card is now unbookmarked (outline icon)
    expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_rounded), findsNothing);
  });
}
