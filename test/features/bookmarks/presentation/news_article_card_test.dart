import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicknews/features/bookmarks/domain/repositories/bookmarks_repository.dart';
import 'package:quicknews/features/bookmarks/presentation/providers/bookmarks_provider.dart';
import 'package:quicknews/features/news/domain/entities/news_article.dart';
import 'package:quicknews/features/news/domain/entities/news_source.dart';
import 'package:quicknews/features/news/presentation/widgets/news_article_card.dart';

class CardTestBookmarksRepository implements BookmarksRepository {
  final List<NewsArticle> items = [];

  @override
  Future<List<NewsArticle>> getBookmarks() async => List.from(items);

  @override
  Future<void> saveBookmark(NewsArticle article) async {
    items.removeWhere((a) => a.url == article.url);
    items.add(article);
  }

  @override
  Future<void> removeBookmark(String articleUrl) async {
    items.removeWhere((a) => a.url == articleUrl);
  }

  @override
  Future<bool> isBookmarked(String articleUrl) async {
    return items.any((a) => a.url == articleUrl);
  }

  @override
  Future<void> clearAllBookmarks() async {
    items.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sampleArticle = NewsArticle(
    source: NewsSource(name: 'BBC'),
    author: 'Editor',
    title: 'Breaking World News',
    description: 'Summary of world events.',
    url: 'https://bbc.com/world/1',
  );

  testWidgets('NewsArticleCard renders outlined bookmark icon by default and filled when bookmarked',
      (WidgetTester tester) async {
    final mockRepo = CardTestBookmarksRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookmarksRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: NewsArticleCard(article: sampleArticle),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final bookmarkBtn = find.byKey(Key('bookmark_action_${sampleArticle.url}'));
    expect(bookmarkBtn, findsOneWidget);

    // Initial state: outline icon
    expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_rounded), findsNothing);

    // Tap bookmark action
    await tester.tap(bookmarkBtn);
    await tester.pumpAndSettle();

    // After tap: filled icon and SnackBar
    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border_rounded), findsNothing);
    expect(find.text('Article bookmarked'), findsOneWidget);

    // Tap again to remove
    await tester.tap(bookmarkBtn);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_rounded), findsNothing);
    expect(find.text('Bookmark removed'), findsOneWidget);
  });
}
