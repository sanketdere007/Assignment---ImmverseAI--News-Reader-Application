import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicknews/features/bookmarks/domain/repositories/bookmarks_repository.dart';
import 'package:quicknews/features/bookmarks/presentation/providers/bookmarks_provider.dart';
import 'package:quicknews/features/news/domain/entities/news_article.dart';
import 'package:quicknews/features/news/domain/entities/news_source.dart';
import 'package:quicknews/features/news/presentation/screens/news_detail_screen.dart';

class DetailTestBookmarksRepository implements BookmarksRepository {
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

  const testArticle = NewsArticle(
    source: NewsSource(name: 'Tech Insider'),
    author: 'Sarah Connor',
    title: 'Future of Mobile Development',
    description: 'A deep dive into cross-platform application architectures.',
    content: 'Full article text discussing clean architecture and state management.',
    url: 'https://techinsider.com/future-mobile',
  );

  testWidgets('NewsDetailScreen displays empty fallback when article is null',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: NewsDetailScreen(article: null),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No Article Selected'), findsOneWidget);
    expect(find.text('Back to Headlines'), findsOneWidget);
  });

  testWidgets('NewsDetailScreen displays article content and toggles bookmark button',
      (WidgetTester tester) async {
    final mockRepo = DetailTestBookmarksRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookmarksRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: NewsDetailScreen(article: testArticle),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Tech Insider'), findsWidgets);
    expect(find.text('Future of Mobile Development'), findsOneWidget);
    expect(find.text('Sarah Connor'), findsOneWidget);
    expect(find.text('A deep dive into cross-platform application architectures.'), findsOneWidget);
    expect(find.text('Original Article Source'), findsOneWidget);

    // Initial bookmark button should be outline (not saved)
    final bookmarkBtn = find.byKey(const Key('detail_bookmark_button'));
    expect(bookmarkBtn, findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
    expect(find.byKey(const Key('saved_offline_banner')), findsNothing);

    // Tap bookmark button to save
    await tester.tap(bookmarkBtn);
    await tester.pumpAndSettle();

    // Verify filled bookmark icon, offline banner, and SnackBar
    expect(find.byIcon(Icons.bookmark_rounded), findsWidgets);
    expect(find.text('Article bookmarked'), findsOneWidget);
    expect(find.byKey(const Key('saved_offline_banner')), findsOneWidget);

    // Tap bookmark button again to remove
    await tester.tap(bookmarkBtn);
    await tester.pumpAndSettle();

    expect(find.text('Bookmark removed'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
  });
}
