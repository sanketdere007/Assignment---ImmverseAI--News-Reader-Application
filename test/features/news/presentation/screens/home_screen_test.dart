import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicknews/features/news/domain/entities/news_article.dart';
import 'package:quicknews/features/news/domain/entities/news_source.dart';
import 'package:quicknews/features/news/domain/repositories/news_repository.dart';
import 'package:quicknews/features/news/domain/usecases/get_top_headlines.dart';
import 'package:quicknews/features/news/domain/usecases/search_news.dart';
import 'package:quicknews/features/news/presentation/providers/news_feed_provider.dart';
import 'package:quicknews/features/news/presentation/providers/news_feed_state.dart';
import 'package:quicknews/features/news/presentation/providers/news_providers.dart';
import 'package:quicknews/features/news/presentation/screens/home_screen.dart';
import 'package:quicknews/features/news/presentation/widgets/category_selector.dart';
import 'package:quicknews/features/news/presentation/widgets/news_article_card.dart';
import 'package:quicknews/features/news/presentation/widgets/news_empty_view.dart';
import 'package:quicknews/features/news/presentation/widgets/news_error_view.dart';
import 'package:quicknews/features/news/presentation/widgets/news_loading_view.dart';
import 'package:quicknews/features/news/presentation/widgets/search_prompt_view.dart';

class MockNewsRepository implements NewsRepository {
  List<NewsArticle> articlesToReturn = const [];

  @override
  Future<List<NewsArticle>> getTopHeadlines({
    String? country,
    String? category,
    String? sources,
    String? query,
    int page = 1,
    int pageSize = 20,
  }) async {
    return articlesToReturn;
  }

  @override
  Future<List<NewsArticle>> searchNews({
    required String query,
    String? domains,
    String? sortBy,
    int page = 1,
    int pageSize = 20,
  }) async {
    return articlesToReturn;
  }
}

void main() {
  late MockNewsRepository mockRepository;

  final tArticle = NewsArticle(
    source: const NewsSource(id: 'bbc', name: 'BBC News'),
    title: 'Historic Discovery in Modern AI Systems',
    description: 'Researchers unveiled an efficient new architecture.',
    url: 'https://bbc.com/news/1',
    publishedAt: DateTime(2026, 10, 14, 11, 0),
  );

  setUp(() {
    mockRepository = MockNewsRepository();
  });

  Widget createWidgetUnderTest({
    NewsFeedState? initialState,
  }) {
    return ProviderScope(
      overrides: [
        newsRepositoryProvider.overrideWithValue(mockRepository),
        getTopHeadlinesUseCaseProvider.overrideWithValue(
          GetTopHeadlines(mockRepository),
        ),
        searchNewsUseCaseProvider.overrideWithValue(
          SearchNews(mockRepository),
        ),
        if (initialState != null)
          newsFeedNotifierProvider.overrideWith(() => _PresetNewsFeedNotifier(initialState)),
      ],
      child: const MaterialApp(
        home: HomeScreen(),
      ),
    );
  }

  group('HomeScreen Widget Tests', () {
    testWidgets('displays App Bar with News Reader title and action icons', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        initialState: NewsFeedState(
          status: NewsFeedStatus.loaded,
          articles: [tArticle],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('News Reader'), findsOneWidget);
      expect(find.byKey(const Key('home_search_button')), findsOneWidget);
      expect(find.byKey(const Key('home_bookmarks_button')), findsOneWidget);
      expect(find.byKey(const Key('home_settings_button')), findsOneWidget);
    });

    testWidgets('renders horizontal CategorySelector with supported categories', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        initialState: NewsFeedState(
          status: NewsFeedStatus.loaded,
          articles: [tArticle],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(CategorySelector), findsOneWidget);
      expect(find.text('General'), findsOneWidget);
      expect(find.text('Business'), findsOneWidget);
      expect(find.text('Technology'), findsOneWidget);
    });

    testWidgets('displays NewsLoadingView skeleton when initial loading', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        initialState: const NewsFeedState(
          status: NewsFeedStatus.loading,
          articles: [],
        ),
      ));
      await tester.pump();

      expect(find.byType(NewsLoadingView), findsOneWidget);
    });

    testWidgets('displays NewsArticleCard when articles are loaded', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        initialState: NewsFeedState(
          status: NewsFeedStatus.loaded,
          articles: [tArticle],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(NewsArticleCard), findsOneWidget);
      expect(find.text('Historic Discovery in Modern AI Systems'), findsOneWidget);
      expect(find.text('BBC News'), findsOneWidget);
    });

    testWidgets('displays NewsEmptyView when zero articles found', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        initialState: const NewsFeedState(
          status: NewsFeedStatus.empty,
          articles: [],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(NewsEmptyView), findsOneWidget);
      expect(find.text('No Articles Found'), findsOneWidget);
    });

    testWidgets('displays NewsErrorView on initial load error', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        initialState: const NewsFeedState(
          status: NewsFeedStatus.error,
          articles: [],
          errorMessage: 'No internet connection',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(NewsErrorView), findsOneWidget);
      expect(find.text('No internet connection'), findsOneWidget);
    });

    testWidgets('tapping search button activates search bar and allows input', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        initialState: NewsFeedState(
          status: NewsFeedStatus.loaded,
          articles: [tArticle],
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('home_search_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home_search_text_field')), findsOneWidget);
      expect(find.byKey(const Key('close_search_button')), findsOneWidget);
      expect(find.byType(SearchPromptView), findsOneWidget);

      // Closing search returns to headlines and CategorySelector
      await tester.tap(find.byKey(const Key('close_search_button')));
      await tester.pumpAndSettle();

      expect(find.byType(CategorySelector), findsOneWidget);
      expect(find.byType(NewsArticleCard), findsOneWidget);
    });

    testWidgets('displays active search banner when isSearching is true', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        initialState: NewsFeedState(
          status: NewsFeedStatus.loaded,
          articles: [tArticle],
          searchQuery: 'flutter',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('active_search_banner')), findsOneWidget);
      expect(find.text('Results for "flutter"'), findsOneWidget);
      expect(find.byKey(const Key('search_banner_clear_button')), findsOneWidget);
    });

    testWidgets('tapping Business category chip updates category selection', (tester) async {
      mockRepository.articlesToReturn = [tArticle];

      await tester.pumpWidget(ProviderScope(
        overrides: [
          newsRepositoryProvider.overrideWithValue(mockRepository),
          getTopHeadlinesUseCaseProvider.overrideWithValue(
            GetTopHeadlines(mockRepository),
          ),
          searchNewsUseCaseProvider.overrideWithValue(
            SearchNews(mockRepository),
          ),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      final businessChip = find.byKey(const Key('category_chip_business'));
      expect(businessChip, findsOneWidget);

      await tester.tap(businessChip);
      await tester.pumpAndSettle();

      final filterChip = tester.widget<FilterChip>(businessChip);
      expect(filterChip.selected, isTrue);
    });

    testWidgets('partial keyword search buis queries Everything endpoint and displays results', (tester) async {
      mockRepository.articlesToReturn = [tArticle];

      await tester.pumpWidget(ProviderScope(
        overrides: [
          newsRepositoryProvider.overrideWithValue(mockRepository),
          getTopHeadlinesUseCaseProvider.overrideWithValue(
            GetTopHeadlines(mockRepository),
          ),
          searchNewsUseCaseProvider.overrideWithValue(
            SearchNews(mockRepository),
          ),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      // Tap search button to activate search
      await tester.tap(find.byKey(const Key('home_search_button')));
      await tester.pumpAndSettle();

      final searchField = find.byKey(const Key('home_search_text_field'));
      await tester.enterText(searchField, 'buis');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('active_search_banner')), findsOneWidget);
      expect(find.text('Results for "buis"'), findsOneWidget);
      expect(find.byType(NewsArticleCard), findsOneWidget);
    });
  });
}

class _PresetNewsFeedNotifier extends NewsFeedNotifier {
  final NewsFeedState _preset;

  _PresetNewsFeedNotifier(this._preset);

  @override
  NewsFeedState build() {
    return _preset;
  }
}
