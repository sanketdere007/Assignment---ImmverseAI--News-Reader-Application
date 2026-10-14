import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicknews/core/error/app_error.dart';
import 'package:quicknews/features/news/domain/entities/news_article.dart';
import 'package:quicknews/features/news/domain/entities/paginated_news.dart';
import 'package:quicknews/features/news/domain/entities/news_source.dart';
import 'package:quicknews/features/news/domain/repositories/news_repository.dart';
import 'package:quicknews/features/news/domain/usecases/search_news.dart';
import 'package:quicknews/features/news/presentation/providers/news_providers.dart';
import 'package:quicknews/features/news/presentation/providers/search_news_provider.dart';
import 'package:quicknews/features/news/presentation/providers/search_news_state.dart';

class MockNewsRepository implements NewsRepository {
  FutureOr<List<NewsArticle>> Function({
    required String query,
    String? domains,
    String? sortBy,
    int page,
    int pageSize,
  })?
  onSearchNews;

  @override
  Future<List<NewsArticle>> searchNews({
    required String query,
    String? domains,
    String? sortBy,
    int page = 1,
    int pageSize = 20,
  }) async {
    if (onSearchNews != null) {
      return await onSearchNews!(
        query: query,
        domains: domains,
        sortBy: sortBy,
        page: page,
        pageSize: pageSize,
      );
    }
    return const [];
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

void main() {
  late MockNewsRepository mockRepository;
  late ProviderContainer container;

  NewsArticle createArticle(String id, {String title = 'Title'}) {
    return NewsArticle(
      source: NewsSource(id: 'source-$id', name: 'Source $id'),
      title: '$title $id',
      url: 'https://news.example.com/$id',
      description: 'Description for article $id',
      publishedAt: DateTime(2026, 10, 14, 12, 0),
    );
  }

  setUp(() {
    mockRepository = MockNewsRepository();
    container = ProviderContainer(
      overrides: [
        newsRepositoryProvider.overrideWithValue(mockRepository),
        searchNewsUseCaseProvider.overrideWithValue(SearchNews(mockRepository)),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('SearchNewsNotifier State Management Tests', () {
    test(
      '1. Initial state has initial status, empty query, and empty articles',
      () {
        final state = container.read(searchNewsNotifierProvider);
        expect(state.status, SearchStatus.initial);
        expect(state.isInitial, isTrue);
        expect(state.query, isEmpty);
        expect(state.articles, isEmpty);
        expect(state.page, 1);
        expect(state.hasReachedMax, isFalse);
      },
    );

    test(
      '2. Successful search returns articles and sets loaded status',
      () async {
        String? executedQuery;
        int? executedPage;
        String? executedSortBy;
        final tArticles = [createArticle('1'), createArticle('2')];

        mockRepository.onSearchNews =
            ({required query, domains, page = 1, pageSize = 20, sortBy}) {
              executedQuery = query;
              executedPage = page;
              executedSortBy = sortBy;
              return tArticles;
            };

        final notifier = container.read(searchNewsNotifierProvider.notifier);
        await notifier.search('flutter framework');

        final state = container.read(searchNewsNotifierProvider);
        expect(state.status, SearchStatus.loaded);
        expect(state.isLoaded, isTrue);
        expect(state.query, 'flutter framework');
        expect(state.articles, tArticles);
        expect(state.page, 1);
        expect(state.hasReachedMax, isTrue); // < 20 articles
        expect(executedQuery, 'flutter framework');
        expect(executedPage, 1);
        expect(executedSortBy, 'publishedAt');
      },
    );

    test(
      '3. Empty or whitespace-only queries do not call API and reset state',
      () async {
        var apiCalled = false;
        mockRepository.onSearchNews =
            ({required query, domains, page = 1, pageSize = 20, sortBy}) {
              apiCalled = true;
              return [createArticle('1')];
            };

        final notifier = container.read(searchNewsNotifierProvider.notifier);

        // Search empty string
        await notifier.search('');
        expect(apiCalled, isFalse);
        expect(
          container.read(searchNewsNotifierProvider).status,
          SearchStatus.initial,
        );

        // Search whitespace
        await notifier.search('    ');
        expect(apiCalled, isFalse);
        expect(
          container.read(searchNewsNotifierProvider).status,
          SearchStatus.initial,
        );
      },
    );

    test('4. Empty API results transitions state to empty', () async {
      mockRepository.onSearchNews =
          ({required query, domains, page = 1, pageSize = 20, sortBy}) {
            return [];
          };

      final notifier = container.read(searchNewsNotifierProvider.notifier);
      await notifier.search('nonexistent_topic_xyz');

      final state = container.read(searchNewsNotifierProvider);
      expect(state.status, SearchStatus.empty);
      expect(state.isEmpty, isTrue);
      expect(state.articles, isEmpty);
      expect(state.hasReachedMax, isTrue);
    });

    test(
      '5. API errors set error status with server error message and retry works',
      () async {
        var callCount = 0;
        mockRepository.onSearchNews =
            ({required query, domains, page = 1, pageSize = 20, sortBy}) {
              callCount++;
              if (callCount == 1) {
                throw const NetworkError('Network connection failed');
              }
              return [createArticle('retry_success')];
            };

        final notifier = container.read(searchNewsNotifierProvider.notifier);
        await notifier.search('cryptocurrency');

        var state = container.read(searchNewsNotifierProvider);
        expect(state.status, SearchStatus.error);
        expect(state.hasError, isTrue);
        expect(state.errorMessage, 'Network connection failed');
        expect(state.articles, isEmpty);

        // Retry search
        await notifier.search('cryptocurrency');
        state = container.read(searchNewsNotifierProvider);
        expect(state.status, SearchStatus.loaded);
        expect(state.articles.length, 1);
        expect(state.articles.first.title, contains('retry_success'));
      },
    );

    test(
      '6. NewsAPI RateLimitError and UnauthorizedError are preserved in state',
      () async {
        mockRepository.onSearchNews =
            ({required query, domains, page = 1, pageSize = 20, sortBy}) {
              throw const RateLimitError(
                'API rate limit reached. Please wait.',
              );
            };

        final notifier = container.read(searchNewsNotifierProvider.notifier);
        await notifier.search('ai news');

        final state = container.read(searchNewsNotifierProvider);
        expect(state.status, SearchStatus.error);
        expect(state.errorMessage, 'API rate limit reached. Please wait.');
      },
    );

    test(
      '7. Changing query resets pagination to page 1 and clears previous results',
      () async {
        final initialArticles = List.generate(
          20,
          (i) => createArticle('ai_$i'),
        );
        final newArticles = [createArticle('space_1')];

        mockRepository.onSearchNews =
            ({required query, domains, page = 1, pageSize = 20, sortBy}) {
              if (query == 'artificial intelligence') return initialArticles;
              if (query == 'space') return newArticles;
              return [];
            };

        final notifier = container.read(searchNewsNotifierProvider.notifier);
        await notifier.search('artificial intelligence');

        var state = container.read(searchNewsNotifierProvider);
        expect(state.query, 'artificial intelligence');
        expect(state.articles.length, 20);

        // Change query to 'space'
        await notifier.search('space');

        state = container.read(searchNewsNotifierProvider);
        expect(state.query, 'space');
        expect(state.articles, newArticles);
        expect(state.page, 1);
        expect(state.hasReachedMax, isTrue);
      },
    );

    test(
      '8. Prevents slower response from old query from overwriting latest results',
      () async {
        final completer1 = Completer<List<NewsArticle>>();
        final completer2 = Completer<List<NewsArticle>>();

        mockRepository.onSearchNews =
            ({required query, domains, page = 1, pageSize = 20, sortBy}) {
              if (query == 'slow_query') {
                return completer1.future;
              } else if (query == 'fast_query') {
                return completer2.future;
              }
              return Future.value(<NewsArticle>[]);
            };

        final notifier = container.read(searchNewsNotifierProvider.notifier);

        // Trigger query 1 (slow)
        final future1 = notifier.search('slow_query');

        // Trigger query 2 (fast)
        final future2 = notifier.search('fast_query');

        // Query 2 completes first
        completer2.complete([createArticle('fast_result')]);
        await future2;

        var state = container.read(searchNewsNotifierProvider);
        expect(state.query, 'fast_query');
        expect(state.articles.first.title, contains('fast_result'));

        // Query 1 finishes later
        completer1.complete([createArticle('slow_result')]);
        await future1;

        // State should still be fast_query results, not overwritten by slow_query
        state = container.read(searchNewsNotifierProvider);
        expect(state.query, 'fast_query');
        expect(state.articles.first.title, contains('fast_result'));
      },
    );

    test(
      '9. Avoids duplicate request for identical query when already loaded',
      () async {
        var callCount = 0;
        mockRepository.onSearchNews =
            ({required query, domains, page = 1, pageSize = 20, sortBy}) {
              callCount++;
              return [createArticle('duplicate_check')];
            };

        final notifier = container.read(searchNewsNotifierProvider.notifier);
        await notifier.search('robotics');
        expect(callCount, 1);

        // Repeat identical query
        await notifier.search('robotics');
        expect(callCount, 1); // Not called again
      },
    );

    test(
      '10. Pagination increments page and appends unique articles',
      () async {
        final page1 = List.generate(20, (i) => createArticle('p1_$i'));
        final page2 = [createArticle('p2_1'), createArticle('p2_2')];

        mockRepository.onSearchNews =
            ({required query, domains, page = 1, pageSize = 20, sortBy}) {
              if (page == 1) return page1;
              if (page == 2) return page2;
              return [];
            };

        final notifier = container.read(searchNewsNotifierProvider.notifier);
        await notifier.search('science');

        var state = container.read(searchNewsNotifierProvider);
        expect(state.articles.length, 20);
        expect(state.page, 1);
        expect(state.hasReachedMax, isFalse);

        await notifier.fetchNextPage();

        state = container.read(searchNewsNotifierProvider);
        expect(state.articles.length, 22);
        expect(state.page, 2);
        expect(state.hasReachedMax, isTrue);
      },
    );

    test('11. Pagination deduplicates articles by URL and title', () async {
      final duplicateArticle = createArticle(
        'dup_id',
        title: 'Duplicate Article',
      );
      final page1 = [duplicateArticle, createArticle('unique_1')];
      // Simulate NewsAPI returning duplicateArticle again on page 2
      final page2 = [duplicateArticle, createArticle('unique_2')];

      mockRepository.onSearchNews =
          ({required query, domains, page = 1, pageSize = 20, sortBy}) {
            if (page == 1) return page1;
            if (page == 2) return page2;
            return [];
          };

      final notifier = container.read(searchNewsNotifierProvider.notifier);
      await notifier.search('dedup');

      await notifier.fetchNextPage();

      final state = container.read(searchNewsNotifierProvider);
      expect(state.articles.length, 3);
      expect(
        state.articles.where((a) => a.url == duplicateArticle.url).length,
        1,
      );
    });

    test('12. Prevents concurrent pagination calls', () async {
      var paginationCallCount = 0;
      mockRepository.onSearchNews =
          ({required query, domains, page = 1, pageSize = 20, sortBy}) {
            paginationCallCount++;
            if (page == 1)
              return List.generate(20, (i) => createArticle('item_$i'));
            return [createArticle('next')];
          };

      final notifier = container.read(searchNewsNotifierProvider.notifier);
      await notifier.search('concurrency');

      final future1 = notifier.fetchNextPage();
      final future2 = notifier.fetchNextPage();

      await Future.wait([future1, future2]);

      expect(
        paginationCallCount,
        2,
      ); // Initial search + exactly 1 pagination call
    });

    test(
      '13. Pagination error preserves loaded articles and sets pagination error message',
      () async {
        final initialArticles = List.generate(
          20,
          (i) => createArticle('init_$i'),
        );
        mockRepository.onSearchNews =
            ({required query, domains, page = 1, pageSize = 20, sortBy}) {
              if (page == 1) return initialArticles;
              throw const TimeoutError('Pagination timed out');
            };

        final notifier = container.read(searchNewsNotifierProvider.notifier);
        await notifier.search('timeout_test');

        await notifier.fetchNextPage();

        final state = container.read(searchNewsNotifierProvider);
        expect(state.articles.length, 20);
        expect(state.isLoadingMore, isFalse);
        expect(state.paginationErrorMessage, 'Pagination timed out');
      },
    );

    test(
      '14. Pull-to-refresh resets to page 1 and fetches latest search results',
      () async {
        final initialArticles = List.generate(
          20,
          (i) => createArticle('old_$i'),
        );
        final refreshedArticles = [createArticle('new_1')];

        mockRepository.onSearchNews =
            ({required query, domains, page = 1, pageSize = 20, sortBy}) {
              if (page == 1 && initialArticles.isNotEmpty) {
                return initialArticles;
              }
              return [];
            };

        final notifier = container.read(searchNewsNotifierProvider.notifier);
        await notifier.search('refresh_test');

        mockRepository.onSearchNews =
            ({required query, domains, page = 1, pageSize = 20, sortBy}) {
              return refreshedArticles;
            };

        await notifier.refresh();

        final state = container.read(searchNewsNotifierProvider);
        expect(state.articles, refreshedArticles);
        expect(state.page, 1);
        expect(state.isRefreshing, isFalse);
      },
    );

    test(
      '15. clearSearch resets state to initial and clears articles and query',
      () async {
        mockRepository.onSearchNews =
            ({required query, domains, page = 1, pageSize = 20, sortBy}) {
              return [createArticle('to_be_cleared')];
            };

        final notifier = container.read(searchNewsNotifierProvider.notifier);
        await notifier.search('to_clear');

        var state = container.read(searchNewsNotifierProvider);
        expect(state.isLoaded, isTrue);

        notifier.clearSearch();

        state = container.read(searchNewsNotifierProvider);
        expect(state.status, SearchStatus.initial);
        expect(state.isInitial, isTrue);
        expect(state.articles, isEmpty);
        expect(state.query, isEmpty);
      },
    );

    test(
      '16. Partial keywords like buis, techn, crick, polit pass unchanged to repository',
      () async {
        final queriedKeywords = <String>[];
        mockRepository.onSearchNews =
            ({required query, domains, page = 1, pageSize = 20, sortBy}) {
              queriedKeywords.add(query);
              return [createArticle('match_for_$query')];
            };

        final notifier = container.read(searchNewsNotifierProvider.notifier);

        for (final partial in ['buis', '  techn  ', 'crick', 'polit']) {
          await notifier.search(partial);
          final state = container.read(searchNewsNotifierProvider);
          expect(state.status, SearchStatus.loaded);
          expect(state.query, partial.trim());
          expect(
            state.articles.first.title,
            contains('match_for_${partial.trim()}'),
          );
        }

        expect(queriedKeywords, ['buis', 'techn', 'crick', 'polit']);
      },
    );

    test(
      '17. Partial keyword buis returning empty results enters empty state without fallback',
      () async {
        String? executedKeyword;
        mockRepository.onSearchNews =
            ({required query, domains, page = 1, pageSize = 20, sortBy}) {
              executedKeyword = query;
              return [];
            };

        final notifier = container.read(searchNewsNotifierProvider.notifier);
        await notifier.search('buis');

        final state = container.read(searchNewsNotifierProvider);
        expect(executedKeyword, 'buis');
        expect(state.status, SearchStatus.empty);
        expect(state.query, 'buis');
        expect(state.articles, isEmpty);
        expect(state.hasReachedMax, isTrue);
      },
    );

    test(
      '18. Smaller search response than pageSize with totalResults > count leaves hasMore=true and paginates page 2',
      () async {
        final page1 = List.generate(14, (i) => createArticle('search_p1_$i'));
        final page2 = List.generate(10, (i) => createArticle('search_p2_$i'));

        mockRepository.onSearchNews =
            ({required query, domains, page = 1, pageSize = 20, sortBy}) {
              if (page == 1) {
                return PaginatedNews(articles: page1, totalResults: 40);
              }
              if (page == 2) {
                return PaginatedNews(articles: page2, totalResults: 40);
              }
              return PaginatedNews(articles: [], totalResults: 40);
            };

        final notifier = container.read(searchNewsNotifierProvider.notifier);
        await notifier.search('quantum computing');

        var state = container.read(searchNewsNotifierProvider);
        expect(state.status, SearchStatus.loaded);
        expect(state.articles.length, 14);
        expect(state.totalResults, 40);
        expect(state.page, 1);
        expect(state.hasReachedMax, isFalse);
        expect(state.hasMore, isTrue);

        await notifier.fetchNextPage();

        state = container.read(searchNewsNotifierProvider);
        expect(state.articles.length, 24);
        expect(state.page, 2);
        expect(state.hasReachedMax, isTrue); // 2 * 20 = 40 >= 40
        expect(state.hasMore, isFalse);
      },
    );

    test(
      '19. API limit maximumResultsReached cleanly stops search pagination without error banner',
      () async {
        final initialArticles = List.generate(20, (i) => createArticle('search_$i'));

        mockRepository.onSearchNews =
            ({required query, domains, page = 1, pageSize = 20, sortBy}) {
              if (page == 1) {
                return PaginatedNews(articles: initialArticles, totalResults: 100);
              }
              throw const ServerError('Maximum results reached.', 426, 'maximumResultsReached');
            };

        final notifier = container.read(searchNewsNotifierProvider.notifier);
        await notifier.search('technology');

        await notifier.fetchNextPage();
        final state = container.read(searchNewsNotifierProvider);

        expect(state.articles.length, 20);
        expect(state.isLoadingMore, isFalse);
        expect(state.hasReachedMax, isTrue);
        expect(state.hasMore, isFalse);
        expect(state.paginationErrorMessage, isNull);
      },
    );

    test(
      '20. Failed search pagination retains current page and recovers on retry',
      () async {
        final initialArticles = List.generate(20, (i) => createArticle('init_$i'));
        final page2Articles = [createArticle('page2_item')];
        var page2Attempt = 0;

        mockRepository.onSearchNews =
            ({required query, domains, page = 1, pageSize = 20, sortBy}) {
              if (page == 1) {
                return PaginatedNews(articles: initialArticles, totalResults: 50);
              }
              if (page == 2) {
                page2Attempt++;
                if (page2Attempt == 1) {
                  throw const TimeoutError('Search pagination timeout');
                }
                return PaginatedNews(articles: page2Articles, totalResults: 50);
              }
              return [];
            };

        final notifier = container.read(searchNewsNotifierProvider.notifier);
        await notifier.search('astronomy');

        // First attempt fails
        await notifier.fetchNextPage();
        var state = container.read(searchNewsNotifierProvider);

        expect(state.articles.length, 20);
        expect(state.page, 1);
        expect(state.isLoadingMore, isFalse);
        expect(state.paginationErrorMessage, 'Search pagination timeout');

        // Retry succeeds
        await notifier.fetchNextPage();
        state = container.read(searchNewsNotifierProvider);

        expect(state.articles.length, 21);
        expect(state.page, 2);
        expect(state.isLoadingMore, isFalse);
        expect(state.paginationErrorMessage, isNull);
      },
    );
  });
}
