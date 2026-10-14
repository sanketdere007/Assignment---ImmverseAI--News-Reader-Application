import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicknews/core/error/app_error.dart';
import 'package:quicknews/features/news/domain/entities/news_article.dart';
import 'package:quicknews/features/news/domain/entities/paginated_news.dart';
import 'package:quicknews/features/news/domain/entities/news_source.dart';
import 'package:quicknews/features/news/domain/repositories/news_repository.dart';
import 'package:quicknews/features/news/domain/usecases/get_top_headlines.dart';
import 'package:quicknews/features/news/domain/usecases/search_news.dart';
import 'package:quicknews/features/news/presentation/providers/news_feed_provider.dart';
import 'package:quicknews/features/news/presentation/providers/news_feed_state.dart';
import 'package:quicknews/features/news/presentation/providers/news_providers.dart';

class MockNewsRepository implements NewsRepository {
  List<NewsArticle> Function({
    String? category,
    String? country,
    String? sources,
    int page,
    int pageSize,
    String? query,
  })? onGetTopHeadlines;

  List<NewsArticle> Function({
    required String query,
    String? domains,
    String? sortBy,
    int page,
    int pageSize,
  })? onSearchNews;

  @override
  Future<List<NewsArticle>> getTopHeadlines({
    String? country,
    String? category,
    String? sources,
    String? query,
    int page = 1,
    int pageSize = 20,
  }) async {
    if (onGetTopHeadlines != null) {
      return onGetTopHeadlines!(
        country: country,
        category: category,
        sources: sources,
        query: query,
        page: page,
        pageSize: pageSize,
      );
    }
    return const [];
  }

  @override
  Future<List<NewsArticle>> searchNews({
    required String query,
    String? domains,
    String? sortBy,
    int page = 1,
    int pageSize = 20,
  }) async {
    if (onSearchNews != null) {
      return onSearchNews!(
        query: query,
        domains: domains,
        sortBy: sortBy,
        page: page,
        pageSize: pageSize,
      );
    }
    return const [];
  }
}

void main() {
  late MockNewsRepository mockRepository;
  late ProviderContainer container;

  NewsArticle createArticle(String id, {String title = 'Title', String category = 'general'}) {
    return NewsArticle(
      source: NewsSource(id: 'source-$id', name: 'Source $id'),
      title: '$title $id',
      url: 'https://news.example.com/$id',
      description: 'Description $id',
      publishedAt: DateTime(2026, 10, 14, 10, 0),
    );
  }

  setUp(() {
    mockRepository = MockNewsRepository();
    container = ProviderContainer(
      overrides: [
        newsRepositoryProvider.overrideWithValue(mockRepository),
        getTopHeadlinesUseCaseProvider.overrideWithValue(
          GetTopHeadlines(mockRepository),
        ),
        searchNewsUseCaseProvider.overrideWithValue(
          SearchNews(mockRepository),
        ),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('NewsFeedNotifier State Management', () {
    test('1. Successful initial loading sets articles and loaded status with country=us', () async {
      String? queriedCountry;
      final tArticles = [createArticle('1'), createArticle('2')];
      mockRepository.onGetTopHeadlines = ({category, country, sources, page = 1, pageSize = 20, query}) {
        queriedCountry = country;
        return tArticles;
      };

      final notifier = container.read(newsFeedNotifierProvider.notifier);
      await notifier.loadInitialHeadlines();

      final state = container.read(newsFeedNotifierProvider);
      expect(state.status, NewsFeedStatus.loaded);
      expect(state.articles, tArticles);
      expect(queriedCountry, 'us');
      expect(state.page, 1);
      expect(state.hasReachedMax, isTrue);
    });

    test('2. Empty API result transitions state to empty', () async {
      mockRepository.onGetTopHeadlines = ({category, country, sources, page = 1, pageSize = 20, query}) {
        return [];
      };

      final notifier = container.read(newsFeedNotifierProvider.notifier);
      await notifier.loadInitialHeadlines();

      final state = container.read(newsFeedNotifierProvider);
      expect(state.status, NewsFeedStatus.empty);
      expect(state.articles, isEmpty);
      expect(state.hasReachedMax, isTrue);
    });

    test('3. Initial API error sets error status and retry recovers', () async {
      var callCount = 0;
      mockRepository.onGetTopHeadlines = ({category, country, sources, page = 1, pageSize = 20, query}) {
        callCount++;
        if (callCount == 1) {
          throw const NetworkError('Network unreachable');
        }
        return [createArticle('1')];
      };

      final notifier = container.read(newsFeedNotifierProvider.notifier);
      await notifier.loadInitialHeadlines();

      var state = container.read(newsFeedNotifierProvider);
      expect(state.status, NewsFeedStatus.error);
      expect(state.errorMessage, 'Network unreachable');

      // Retry
      await notifier.loadInitialHeadlines();
      state = container.read(newsFeedNotifierProvider);
      expect(state.status, NewsFeedStatus.loaded);
      expect(state.articles.length, 1);
    });

    test('4. Loading the next page increments page number and appends results', () async {
      final page1 = List.generate(20, (i) => createArticle('p1_$i'));
      final page2 = [createArticle('p2_1'), createArticle('p2_2')];

      mockRepository.onGetTopHeadlines = ({category, country, sources, page = 1, pageSize = 20, query}) {
        if (page == 1) return page1;
        if (page == 2) return page2;
        return [];
      };

      final notifier = container.read(newsFeedNotifierProvider.notifier);
      await notifier.loadInitialHeadlines();

      var state = container.read(newsFeedNotifierProvider);
      expect(state.articles.length, 20);
      expect(state.page, 1);
      expect(state.hasReachedMax, isFalse);

      await notifier.fetchNextPage();
      state = container.read(newsFeedNotifierProvider);
      expect(state.articles.length, 22);
      expect(state.page, 2);
      expect(state.hasReachedMax, isTrue);
    });

    test('5. Appending results skips duplicate articles by URL and title', () async {
      final articleA = createArticle('duplicate_url', title: 'Unique Title 1');
      final articleB = createArticle('duplicate_url', title: 'Unique Title 2');
      final articleC = createArticle('unique_3', title: 'Unique Title 3');

      mockRepository.onGetTopHeadlines = ({category, country, sources, page = 1, pageSize = 20, query}) {
        if (page == 1) return List.generate(20, (i) => i == 0 ? articleA : createArticle('p1_$i'));
        return [articleB, articleC];
      };

      final notifier = container.read(newsFeedNotifierProvider.notifier);
      await notifier.loadInitialHeadlines();

      await notifier.fetchNextPage();
      final state = container.read(newsFeedNotifierProvider);

      expect(state.articles.where((a) => a.url == articleA.url).length, 1);
      expect(state.articles.any((a) => a.url == articleC.url), isTrue);
    });

    test('6. Prevents concurrent pagination calls while one is active', () async {
      var fetchCallCount = 0;
      mockRepository.onGetTopHeadlines = ({category, country, sources, page = 1, pageSize = 20, query}) {
        fetchCallCount++;
        if (page == 1) return List.generate(20, (i) => createArticle('item_$i'));
        return [createArticle('next')];
      };

      final notifier = container.read(newsFeedNotifierProvider.notifier);
      await notifier.loadInitialHeadlines();

      final future1 = notifier.fetchNextPage();
      final future2 = notifier.fetchNextPage();

      await Future.wait([future1, future2]);

      expect(fetchCallCount, 2);
    });

    test('7. Stops pagination when no more results exist', () async {
      mockRepository.onGetTopHeadlines = ({category, country, sources, page = 1, pageSize = 20, query}) {
        return [createArticle('only_one')];
      };

      final notifier = container.read(newsFeedNotifierProvider.notifier);
      await notifier.loadInitialHeadlines();

      final stateBefore = container.read(newsFeedNotifierProvider);
      expect(stateBefore.hasReachedMax, isTrue);

      await notifier.fetchNextPage();
      final stateAfter = container.read(newsFeedNotifierProvider);

      expect(stateAfter.page, 1);
    });

    test('8. Pull-to-refresh resets pagination and refreshes from page 1', () async {
      mockRepository.onGetTopHeadlines = ({category, country, sources, page = 1, pageSize = 20, query}) {
        return List.generate(20, (i) => createArticle('initial_$i'));
      };

      final notifier = container.read(newsFeedNotifierProvider.notifier);
      await notifier.loadInitialHeadlines();

      final refreshedArticle = createArticle('refreshed_1');
      mockRepository.onGetTopHeadlines = ({category, country, sources, page = 1, pageSize = 20, query}) {
        return [refreshedArticle];
      };

      await notifier.refresh();
      final state = container.read(newsFeedNotifierProvider);

      expect(state.status, NewsFeedStatus.loaded);
      expect(state.articles.length, 1);
      expect(state.articles.first.url, refreshedArticle.url);
      expect(state.page, 1);
      expect(state.isRefreshing, isFalse);
    });

    test('9. Category change resets page number, articles, and queries new category', () async {
      String? requestedCategory;
      mockRepository.onGetTopHeadlines = ({category, country, sources, page = 1, pageSize = 20, query}) {
        requestedCategory = category;
        return [createArticle('tech_1')];
      };

      final notifier = container.read(newsFeedNotifierProvider.notifier);
      await notifier.loadInitialHeadlines();

      await notifier.changeCategory('technology');
      final state = container.read(newsFeedNotifierProvider);

      expect(state.selectedCategory, 'technology');
      expect(requestedCategory, 'technology');
      expect(state.page, 1);

      requestedCategory = null;
      await notifier.changeCategory('technology');
      expect(requestedCategory, isNull);
    });

    test('10. Pagination error retains already loaded articles and sets pagination error', () async {
      final initialArticles = List.generate(20, (i) => createArticle('init_$i'));
      mockRepository.onGetTopHeadlines = ({category, country, sources, page = 1, pageSize = 20, query}) {
        if (page == 1) return initialArticles;
        throw const TimeoutError('Pagination timeout');
      };

      final notifier = container.read(newsFeedNotifierProvider.notifier);
      await notifier.loadInitialHeadlines();

      await notifier.fetchNextPage();
      final state = container.read(newsFeedNotifierProvider);

      expect(state.articles.length, 20);
      expect(state.status, NewsFeedStatus.loaded);
      expect(state.isLoadingMore, isFalse);
      expect(state.paginationErrorMessage, 'Pagination timeout');
    });

    test('11. Search submits query to /everything and clearing search restores top headlines', () async {
      String? queriedKeyword;
      mockRepository.onSearchNews = ({required query, domains, page = 1, pageSize = 20, sortBy}) {
        queriedKeyword = query;
        return [createArticle('search_res_1')];
      };

      mockRepository.onGetTopHeadlines = ({category, country, sources, page = 1, pageSize = 20, query}) {
        return [createArticle('headline_1')];
      };

      final notifier = container.read(newsFeedNotifierProvider.notifier);
      await notifier.loadInitialHeadlines();

      // Submit search query
      await notifier.search('quantum computing');

      var state = container.read(newsFeedNotifierProvider);
      expect(state.isSearching, isTrue);
      expect(state.searchQuery, 'quantum computing');
      expect(queriedKeyword, 'quantum computing');
      expect(state.articles.length, 1);
      expect(state.articles.first.title.contains('search_res_1'), isTrue);

      // Clear search
      await notifier.clearSearch();
      state = container.read(newsFeedNotifierProvider);
      expect(state.isSearching, isFalse);
      expect(state.searchQuery, isNull);
      expect(state.articles.first.title.contains('headline_1'), isTrue);
    });

    test('12. Category switching sequence: General -> Business -> Technology', () async {
      final requestedCategories = <String?>[];
      mockRepository.onGetTopHeadlines = ({category, country, sources, page = 1, pageSize = 20, query}) {
        requestedCategories.add(category);
        return [createArticle('article_for_$category')];
      };

      final notifier = container.read(newsFeedNotifierProvider.notifier);
      await notifier.loadInitialHeadlines();

      var state = container.read(newsFeedNotifierProvider);
      expect(state.selectedCategory, 'general');
      expect(state.articles.first.title, contains('general'));

      // Switch to Business
      await notifier.changeCategory('business');
      state = container.read(newsFeedNotifierProvider);
      expect(state.selectedCategory, 'business');
      expect(state.articles.first.title, contains('business'));
      expect(state.page, 1);

      // Switch to Technology
      await notifier.changeCategory('technology');
      state = container.read(newsFeedNotifierProvider);
      expect(state.selectedCategory, 'technology');
      expect(state.articles.first.title, contains('technology'));
      expect(state.page, 1);

      expect(requestedCategories, ['general', 'business', 'technology']);
    });

    test('13. Pagination and pull-to-refresh query the active selected category', () async {
      final categoryCalls = <Map<String, dynamic>>[];
      mockRepository.onGetTopHeadlines = ({category, country, sources, page = 1, pageSize = 20, query}) {
        categoryCalls.add({'category': category, 'page': page});
        if (page == 1) {
          return List.generate(20, (i) => createArticle('cat_${category}_$i'));
        }
        return [createArticle('cat_${category}_page2')];
      };

      final notifier = container.read(newsFeedNotifierProvider.notifier);
      await notifier.changeCategory('science');

      var state = container.read(newsFeedNotifierProvider);
      expect(state.selectedCategory, 'science');
      expect(state.page, 1);

      // Pagination
      await notifier.fetchNextPage();
      state = container.read(newsFeedNotifierProvider);
      expect(state.selectedCategory, 'science');
      expect(state.page, 2);
      expect(categoryCalls.last, {'category': 'science', 'page': 2});

      // Pull-to-refresh
      await notifier.refresh();
      state = container.read(newsFeedNotifierProvider);
      expect(state.selectedCategory, 'science');
      expect(state.page, 1);
      expect(categoryCalls.last, {'category': 'science', 'page': 1});
    });

    test('14. Category returning zero articles enters empty state without falling back to General', () async {
      mockRepository.onGetTopHeadlines = ({category, country, sources, page = 1, pageSize = 20, query}) {
        if (category == 'entertainment') return [];
        return [createArticle('general_item')];
      };

      final notifier = container.read(newsFeedNotifierProvider.notifier);
      await notifier.changeCategory('entertainment');

      final state = container.read(newsFeedNotifierProvider);
      expect(state.selectedCategory, 'entertainment');
      expect(state.status, NewsFeedStatus.empty);
      expect(state.articles, isEmpty);
      expect(state.hasReachedMax, isTrue);
    });

    test('15. Category error sets error status and preserves selected category for retry', () async {
      var callCount = 0;
      mockRepository.onGetTopHeadlines = ({category, country, sources, page = 1, pageSize = 20, query}) {
        callCount++;
        if (callCount == 1) {
          throw const NetworkError('Sports feed unavailable');
        }
        return [createArticle('sports_item')];
      };

      final notifier = container.read(newsFeedNotifierProvider.notifier);
      await notifier.changeCategory('sports');

      var state = container.read(newsFeedNotifierProvider);
      expect(state.selectedCategory, 'sports');
      expect(state.status, NewsFeedStatus.error);
      expect(state.errorMessage, 'Sports feed unavailable');

      // Retry loads current selected category (sports)
      await notifier.loadInitialHeadlines();
      state = container.read(newsFeedNotifierProvider);
      expect(state.selectedCategory, 'sports');
      expect(state.status, NewsFeedStatus.loaded);
      expect(state.articles.first.title, contains('sports_item'));
    });

    test('16. Partial keywords like buis query /everything unchanged and empty results enters empty state without fallback to General', () async {
      String? executedKeyword;
      mockRepository.onSearchNews = ({required query, domains, page = 1, pageSize = 20, sortBy}) {
        executedKeyword = query;
        return [];
      };

      mockRepository.onGetTopHeadlines = ({category, country, sources, page = 1, pageSize = 20, query}) {
        return [createArticle('general_headline')];
      };

      final notifier = container.read(newsFeedNotifierProvider.notifier);
      await notifier.loadInitialHeadlines();

      // Search partial keyword 'buis'
      await notifier.search('buis');

      final state = container.read(newsFeedNotifierProvider);
      expect(executedKeyword, 'buis');
      expect(state.isSearching, isTrue);
      expect(state.searchQuery, 'buis');
      expect(state.status, NewsFeedStatus.empty);
      expect(state.articles, isEmpty);
      expect(state.hasReachedMax, isTrue);
    });

    test('17. Smaller response than pageSize with totalResults > count leaves hasMore=true and paginates page 2', () async {
      final page1Articles = List.generate(12, (i) => createArticle('item_p1_$i'));
      final page2Articles = List.generate(10, (i) => createArticle('item_p2_$i'));

      mockRepository.onGetTopHeadlines = ({category, country, sources, page = 1, pageSize = 20, query}) {
        if (page == 1) {
          return PaginatedNews(articles: page1Articles, totalResults: 35);
        }
        if (page == 2) {
          return PaginatedNews(articles: page2Articles, totalResults: 35);
        }
        return PaginatedNews(articles: [], totalResults: 35);
      };

      final notifier = container.read(newsFeedNotifierProvider.notifier);
      await notifier.loadInitialHeadlines();

      var state = container.read(newsFeedNotifierProvider);
      expect(state.status, NewsFeedStatus.loaded);
      expect(state.articles.length, 12);
      expect(state.totalResults, 35);
      expect(state.page, 1);
      // Key fix: 12 articles loaded < 35 totalResults -> hasReachedMax is false, hasMore is true!
      expect(state.hasReachedMax, isFalse);
      expect(state.hasMore, isTrue);

      // Scroll to trigger page 2
      await notifier.fetchNextPage();

      state = container.read(newsFeedNotifierProvider);
      expect(state.status, NewsFeedStatus.loaded);
      expect(state.articles.length, 22);
      expect(state.page, 2);
      expect(state.hasReachedMax, isTrue); // 2 * 20 = 40 >= 35, all results covered
      expect(state.hasMore, isFalse);
    });

    test('18. Fallback deduplication handles articles without URL using title, timestamp, and source', () async {
      final articleNoUrl1 = NewsArticle(
        title: 'Breaking Headline Without URL',
        url: '',
        publishedAt: DateTime(2026, 10, 14, 12, 0),
        source: const NewsSource(id: 'source-1', name: 'Source 1'),
      );
      final duplicateNoUrl = NewsArticle(
        title: 'Breaking Headline Without URL',
        url: '',
        publishedAt: DateTime(2026, 10, 14, 12, 0),
        source: const NewsSource(id: 'source-1', name: 'Source 1'),
      );
      final uniqueNoUrl = NewsArticle(
        title: 'Different Headline Without URL',
        url: '',
        publishedAt: DateTime(2026, 10, 14, 13, 0),
        source: const NewsSource(id: 'source-2', name: 'Source 2'),
      );

      mockRepository.onGetTopHeadlines = ({category, country, sources, page = 1, pageSize = 20, query}) {
        if (page == 1) {
          return PaginatedNews(articles: [articleNoUrl1], totalResults: 10);
        }
        return PaginatedNews(articles: [duplicateNoUrl, uniqueNoUrl], totalResults: 10);
      };

      final notifier = container.read(newsFeedNotifierProvider.notifier);
      await notifier.loadInitialHeadlines();

      await notifier.fetchNextPage();
      final state = container.read(newsFeedNotifierProvider);

      expect(state.articles.length, 2); // articleNoUrl1 and uniqueNoUrl kept, duplicateNoUrl filtered
      expect(state.articles.any((a) => a.title == 'Different Headline Without URL'), isTrue);
    });

    test('19. API limit maximumResultsReached cleanly stops pagination without error banner', () async {
      final initialArticles = List.generate(20, (i) => createArticle('art_$i'));

      mockRepository.onGetTopHeadlines = ({category, country, sources, page = 1, pageSize = 20, query}) {
        if (page == 1) {
          return PaginatedNews(articles: initialArticles, totalResults: 100);
        }
        throw const ServerError('Maximum results reached.', 426, 'maximumResultsReached');
      };

      final notifier = container.read(newsFeedNotifierProvider.notifier);
      await notifier.loadInitialHeadlines();

      await notifier.fetchNextPage();
      final state = container.read(newsFeedNotifierProvider);

      expect(state.articles.length, 20);
      expect(state.isLoadingMore, isFalse);
      expect(state.hasReachedMax, isTrue);
      expect(state.hasMore, isFalse);
      expect(state.paginationErrorMessage, isNull);
    });

    test('20. Failed pagination request retains current page and can be retried successfully', () async {
      final initialArticles = List.generate(20, (i) => createArticle('init_$i'));
      final page2Articles = [createArticle('page2_item')];
      var page2Attempt = 0;

      mockRepository.onGetTopHeadlines = ({category, country, sources, page = 1, pageSize = 20, query}) {
        if (page == 1) {
          return PaginatedNews(articles: initialArticles, totalResults: 50);
        }
        if (page == 2) {
          page2Attempt++;
          if (page2Attempt == 1) {
            throw const NetworkError('Network dropped during pagination');
          }
          return PaginatedNews(articles: page2Articles, totalResults: 50);
        }
        return [];
      };

      final notifier = container.read(newsFeedNotifierProvider.notifier);
      await notifier.loadInitialHeadlines();

      // First attempt fails
      await notifier.fetchNextPage();
      var state = container.read(newsFeedNotifierProvider);

      expect(state.articles.length, 20);
      expect(state.page, 1); // Page NOT incremented on failure
      expect(state.isLoadingMore, isFalse);
      expect(state.paginationErrorMessage, 'Network dropped during pagination');

      // Retry attempt succeeds
      await notifier.fetchNextPage();
      state = container.read(newsFeedNotifierProvider);

      expect(state.articles.length, 21);
      expect(state.page, 2); // Page incremented on success
      expect(state.isLoadingMore, isFalse);
      expect(state.paginationErrorMessage, isNull);
    });
  });
}
