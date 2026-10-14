import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicknews/features/news/domain/entities/news_article.dart';
import 'package:quicknews/features/news/domain/entities/news_source.dart';
import 'package:quicknews/features/news/domain/repositories/news_repository.dart';
import 'package:quicknews/features/news/domain/usecases/search_news.dart';
import 'package:quicknews/features/news/presentation/providers/news_providers.dart';
import 'package:quicknews/features/news/presentation/providers/search_news_provider.dart';
import 'package:quicknews/features/news/presentation/providers/search_news_state.dart';
import 'package:quicknews/features/news/presentation/screens/search_screen.dart';
import 'package:quicknews/features/news/presentation/widgets/news_article_card.dart';
import 'package:quicknews/features/news/presentation/widgets/news_empty_view.dart';
import 'package:quicknews/features/news/presentation/widgets/news_error_view.dart';
import 'package:quicknews/features/news/presentation/widgets/news_loading_view.dart';
import 'package:quicknews/features/news/presentation/widgets/search_prompt_view.dart';

class MockNewsRepository implements NewsRepository {
  List<NewsArticle> articlesToReturn = const [];
  String? lastQueried;

  @override
  Future<List<NewsArticle>> searchNews({
    required String query,
    String? domains,
    String? sortBy,
    int page = 1,
    int pageSize = 20,
  }) async {
    lastQueried = query;
    return articlesToReturn;
  }

  @override
  Future<List<NewsArticle>> getTopHeadlines({
    String? country,
    String? category,
    String? sources,
    String? query,
    int page = 1,
    int pageSize = 20,
  }) async {
    return const [];
  }
}

class _PresetSearchNewsNotifier extends SearchNewsNotifier {
  final SearchNewsState _preset;

  _PresetSearchNewsNotifier(this._preset);

  @override
  SearchNewsState build() {
    return _preset;
  }
}

void main() {
  late MockNewsRepository mockRepository;

  final tArticle = NewsArticle(
    source: const NewsSource(id: 'tech-today', name: 'Tech Today'),
    title: 'Breakthrough in Quantum Computing Algorithms',
    description: 'Researchers discovered an exponentially faster method.',
    url: 'https://news.example.com/quantum',
    publishedAt: DateTime(2026, 10, 14, 10, 30),
  );

  setUp(() {
    mockRepository = MockNewsRepository();
  });

  Widget createWidgetUnderTest({
    SearchNewsState? initialState,
  }) {
    return ProviderScope(
      overrides: [
        newsRepositoryProvider.overrideWithValue(mockRepository),
        searchNewsUseCaseProvider.overrideWithValue(
          SearchNews(mockRepository),
        ),
        if (initialState != null)
          searchNewsNotifierProvider.overrideWith(
            () => _PresetSearchNewsNotifier(initialState),
          ),
      ],
      child: const MaterialApp(
        home: SearchScreen(),
      ),
    );
  }

  group('SearchScreen Widget Tests', () {
    testWidgets('1. Displays AppBar with search text field, back button, and initial prompt', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        initialState: const SearchNewsState(
          status: SearchStatus.initial,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('search_back_button')), findsOneWidget);
      expect(find.byKey(const Key('search_text_field')), findsOneWidget);
      expect(find.byType(SearchPromptView), findsOneWidget);
      expect(find.text('Search QuickNews'), findsOneWidget);
      expect(find.text('Try searching for'), findsOneWidget);
    });

    testWidgets('2. Displays NewsLoadingView when searching', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        initialState: const SearchNewsState(
          status: SearchStatus.loading,
          query: 'artificial intelligence',
          articles: [],
        ),
      ));
      await tester.pump();

      expect(find.byType(NewsLoadingView), findsOneWidget);
    });

    testWidgets('3. Displays NewsArticleCard when search returns articles', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        initialState: SearchNewsState(
          status: SearchStatus.loaded,
          query: 'quantum',
          articles: [tArticle],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(NewsArticleCard), findsOneWidget);
      expect(find.text('Breakthrough in Quantum Computing Algorithms'), findsOneWidget);
      expect(find.text('Tech Today'), findsOneWidget);
    });

    testWidgets('4. Displays NewsEmptyView when no articles match query', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        initialState: const SearchNewsState(
          status: SearchStatus.empty,
          query: 'nonexistenttopic',
          articles: [],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(NewsEmptyView), findsOneWidget);
      expect(find.textContaining('nonexistenttopic'), findsOneWidget);
      expect(find.byKey(const Key('empty_refresh_button')), findsOneWidget);
    });

    testWidgets('5. Displays NewsErrorView with retry action on failure', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        initialState: const SearchNewsState(
          status: SearchStatus.error,
          query: 'ai',
          errorMessage: 'Unable to reach News API',
          articles: [],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(NewsErrorView), findsOneWidget);
      expect(find.text('Unable to reach News API'), findsOneWidget);
      expect(find.byKey(const Key('news_error_retry_button')), findsOneWidget);
    });

    testWidgets('6. Tapping clear button clears text field and query state', (tester) async {
      mockRepository.articlesToReturn = [tArticle];

      await tester.pumpWidget(ProviderScope(
        overrides: [
          newsRepositoryProvider.overrideWithValue(mockRepository),
          searchNewsUseCaseProvider.overrideWithValue(
            SearchNews(mockRepository),
          ),
        ],
        child: const MaterialApp(
          home: SearchScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      final textFieldFinder = find.byKey(const Key('search_text_field'));
      await tester.enterText(textFieldFinder, 'flutter');
      await tester.pumpAndSettle();

      final clearButtonFinder = find.byKey(const Key('search_clear_button'));
      expect(clearButtonFinder, findsOneWidget);

      await tester.tap(clearButtonFinder);
      await tester.pumpAndSettle();

      expect(find.byType(SearchPromptView), findsOneWidget);
    });

    testWidgets('7. Submitting search queries repository and displays results', (tester) async {
      mockRepository.articlesToReturn = [tArticle];

      await tester.pumpWidget(ProviderScope(
        overrides: [
          newsRepositoryProvider.overrideWithValue(mockRepository),
          searchNewsUseCaseProvider.overrideWithValue(
            SearchNews(mockRepository),
          ),
        ],
        child: const MaterialApp(
          home: SearchScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      final textFieldFinder = find.byKey(const Key('search_text_field'));
      await tester.enterText(textFieldFinder, 'quantum');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(mockRepository.lastQueried, 'quantum');
      expect(find.byType(NewsArticleCard), findsOneWidget);
    });

    testWidgets('8. Partial keyword buis triggers search and displays matching results or empty state', (tester) async {
      mockRepository.articlesToReturn = [
        NewsArticle(
          source: const NewsSource(id: 'reuters', name: 'Reuters'),
          title: 'Global buis markets adjust to trade trends',
          description: 'A study on global trade.',
          url: 'https://reuters.com/buis-1',
          publishedAt: DateTime(2026, 10, 14, 11, 0),
        ),
      ];

      await tester.pumpWidget(ProviderScope(
        overrides: [
          newsRepositoryProvider.overrideWithValue(mockRepository),
          searchNewsUseCaseProvider.overrideWithValue(
            SearchNews(mockRepository),
          ),
        ],
        child: const MaterialApp(
          home: SearchScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      final textFieldFinder = find.byKey(const Key('search_text_field'));
      await tester.enterText(textFieldFinder, 'buis');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(mockRepository.lastQueried, 'buis');
      expect(find.text('Global buis markets adjust to trade trends'), findsOneWidget);

      // Empty state for unmatched partial keyword
      mockRepository.articlesToReturn = [];
      await tester.enterText(textFieldFinder, 'buis_nonexistent');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(mockRepository.lastQueried, 'buis_nonexistent');
      expect(find.byType(NewsEmptyView), findsOneWidget);
      expect(find.textContaining('buis_nonexistent'), findsOneWidget);
    });
  });
}
