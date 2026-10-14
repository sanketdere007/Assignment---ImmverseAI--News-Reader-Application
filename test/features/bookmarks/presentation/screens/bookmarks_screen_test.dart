import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicknews/features/bookmarks/domain/repositories/bookmarks_repository.dart';
import 'package:quicknews/features/bookmarks/presentation/providers/bookmarks_provider.dart';
import 'package:quicknews/features/bookmarks/presentation/screens/bookmarks_screen.dart';
import 'package:quicknews/features/news/domain/entities/news_article.dart';
import 'package:quicknews/features/news/domain/entities/news_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockBookmarksRepository implements BookmarksRepository {
  final List<NewsArticle> articles;

  MockBookmarksRepository({List<NewsArticle>? initial})
      : articles = initial ?? [];

  @override
  Future<List<NewsArticle>> getBookmarks() async => List.from(articles);

  @override
  Future<void> saveBookmark(NewsArticle article) async {
    articles.removeWhere((a) => a.url == article.url);
    articles.add(article);
  }

  @override
  Future<void> removeBookmark(String articleUrl) async {
    articles.removeWhere((a) => a.url == articleUrl);
  }

  @override
  Future<bool> isBookmarked(String articleUrl) async {
    return articles.any((a) => a.url == articleUrl);
  }

  @override
  Future<void> clearAllBookmarks() async {
    articles.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const sampleArticle = NewsArticle(
    source: NewsSource(name: 'The Verge'),
    author: 'Tech Writer',
    title: 'Offline News in Flutter',
    description: 'Learn how to build offline capabilities with Hive',
    url: 'https://theverge.com/flutter-offline',
  );

  testWidgets('BookmarksScreen renders empty state when no bookmarks are saved',
      (WidgetTester tester) async {
    final mockRepo = MockBookmarksRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookmarksRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: BookmarksScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Bookmarks'), findsOneWidget);
    expect(find.text('No bookmarks yet'), findsOneWidget);
    expect(find.text('Explore Headlines'), findsOneWidget);
    expect(find.byKey(const Key('explore_news_button')), findsOneWidget);
  });

  testWidgets('BookmarksScreen displays list of bookmarked articles and offline badge',
      (WidgetTester tester) async {
    final mockRepo = MockBookmarksRepository(initial: [sampleArticle]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookmarksRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: BookmarksScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Bookmarks'), findsOneWidget);
    expect(find.text('Saved Articles (1)'), findsOneWidget);
    expect(find.text('Available Offline'), findsOneWidget);
    expect(find.text('Offline News in Flutter'), findsOneWidget);
    expect(find.text('The Verge'), findsOneWidget);
  });

  testWidgets('BookmarksScreen tapping bookmark action removes the article and shows empty state',
      (WidgetTester tester) async {
    final mockRepo = MockBookmarksRepository(initial: [sampleArticle]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookmarksRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: BookmarksScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Offline News in Flutter'), findsOneWidget);

    // Tap bookmark action button to remove it
    final bookmarkButton = find.byKey(Key('bookmark_action_${sampleArticle.url}'));
    expect(bookmarkButton, findsOneWidget);
    await tester.tap(bookmarkButton);
    await tester.pumpAndSettle();

    // Verify SnackBar feedback and transition to empty view
    expect(find.text('Bookmark removed'), findsOneWidget);
    expect(find.text('No bookmarks yet'), findsOneWidget);
  });
}
