import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicknews/core/error/app_error.dart';
import 'package:quicknews/core/network/network_info.dart';
import 'package:quicknews/features/news/data/datasources/news_remote_data_source.dart';
import 'package:quicknews/features/news/data/models/news_article_model.dart';
import 'package:quicknews/features/news/data/models/news_response_model.dart';
import 'package:quicknews/features/news/data/models/news_source_model.dart';
import 'package:quicknews/features/news/data/repositories/news_repository_impl.dart';
import 'package:quicknews/features/news/domain/entities/news_article.dart';

class FakeNewsRemoteDataSource implements NewsRemoteDataSource {
  Future<NewsResponseModel> Function({
    String? country,
    String? category,
    String? sources,
    String? query,
    int page,
    int pageSize,
  })? onGetTopHeadlines;

  Future<NewsResponseModel> Function({
    required String query,
    String? domains,
    String? sortBy,
    int page,
    int pageSize,
  })? onGetEverything;

  @override
  Future<NewsResponseModel> getTopHeadlines({
    String? country,
    String? category,
    String? sources,
    String? query,
    int page = 1,
    int pageSize = 20,
  }) {
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
    throw UnimplementedError();
  }

  @override
  Future<NewsResponseModel> getEverything({
    required String query,
    String? domains,
    String? sortBy,
    int page = 1,
    int pageSize = 20,
  }) {
    if (onGetEverything != null) {
      return onGetEverything!(
        query: query,
        domains: domains,
        sortBy: sortBy,
        page: page,
        pageSize: pageSize,
      );
    }
    throw UnimplementedError();
  }
}

class FakeNetworkInfo implements NetworkInfo {
  bool isConnectedValue = true;

  @override
  Future<bool> get isConnected async => isConnectedValue;
}

void main() {
  late FakeNewsRemoteDataSource fakeRemoteDataSource;
  late FakeNetworkInfo fakeNetworkInfo;
  late NewsRepositoryImpl repository;

  final tArticleModel = NewsArticleModel(
    source: const NewsSourceModel(id: 'the-verge', name: 'The Verge'),
    author: 'Tech Reporter',
    title: 'New Gadget Launched',
    description: 'A revolutionary gadget arrived.',
    url: 'https://theverge.com/gadget-1',
    urlToImage: 'https://theverge.com/image.jpg',
    publishedAt: DateTime.parse('2026-10-14T10:00:00Z'),
    content: 'Detailed gadget specs here.',
  );

  setUp(() {
    fakeRemoteDataSource = FakeNewsRemoteDataSource();
    fakeNetworkInfo = FakeNetworkInfo();
    repository = NewsRepositoryImpl(
      remoteDataSource: fakeRemoteDataSource,
      networkInfo: fakeNetworkInfo,
    );
  });

  group('NewsRepositoryImpl - Top Headlines', () {
    test('should map remote models to domain entities on success', () async {
      fakeRemoteDataSource.onGetTopHeadlines = ({
        category,
        country,
        sources,
        page = 1,
        pageSize = 20,
        query,
      }) async {
        return NewsResponseModel(
          status: 'ok',
          totalResults: 1,
          articles: [tArticleModel],
        );
      };

      final articles = await repository.getTopHeadlines(
        country: 'us',
        category: 'technology',
      );

      expect(articles, isA<List<NewsArticle>>());
      expect(articles.length, 1);
      expect(articles.first.title, 'New Gadget Launched');
      expect(articles.first.sourceName, 'The Verge');
      expect(articles.first.url, 'https://theverge.com/gadget-1');
    });

    test('should return empty list on empty article results', () async {
      fakeRemoteDataSource.onGetTopHeadlines = ({
        category,
        country,
        sources,
        page = 1,
        pageSize = 20,
        query,
      }) async {
        return const NewsResponseModel(
          status: 'ok',
          totalResults: 0,
          articles: [],
        );
      };

      final articles = await repository.getTopHeadlines();

      expect(articles, isEmpty);
    });

    test('should throw NetworkError when NetworkInfo reports disconnected', () async {
      fakeNetworkInfo.isConnectedValue = false;

      expect(
        () => repository.getTopHeadlines(),
        throwsA(isA<NetworkError>()),
      );
    });

    test('should rethrow TimeoutError received from remote data source', () async {
      fakeRemoteDataSource.onGetTopHeadlines = ({
        category,
        country,
        sources,
        page = 1,
        pageSize = 20,
        query,
      }) async {
        throw const TimeoutError('Connection timeout');
      };

      expect(
        () => repository.getTopHeadlines(),
        throwsA(isA<TimeoutError>()),
      );
    });

    test('should rethrow UnauthorizedError on invalid credentials', () async {
      fakeRemoteDataSource.onGetTopHeadlines = ({
        category,
        country,
        sources,
        page = 1,
        pageSize = 20,
        query,
      }) async {
        throw const UnauthorizedError('Invalid API key');
      };

      expect(
        () => repository.getTopHeadlines(),
        throwsA(isA<UnauthorizedError>()),
      );
    });

    test('should rethrow ConfigurationError when API key is missing', () async {
      fakeRemoteDataSource.onGetTopHeadlines = ({
        category,
        country,
        sources,
        page = 1,
        pageSize = 20,
        query,
      }) async {
        throw const ConfigurationError('Missing key');
      };

      expect(
        () => repository.getTopHeadlines(),
        throwsA(isA<ConfigurationError>()),
      );
    });

    test('should map unexpected DioException escaping data source into AppError', () async {
      fakeRemoteDataSource.onGetTopHeadlines = ({
        category,
        country,
        sources,
        page = 1,
        pageSize = 20,
        query,
      }) async {
        throw DioException(
          requestOptions: RequestOptions(path: '/top-headlines'),
          type: DioExceptionType.connectionError,
        );
      };

      expect(
        () => repository.getTopHeadlines(),
        throwsA(isA<NetworkError>()),
      );
    });
  });

  group('NewsRepositoryImpl - Search News (/everything)', () {
    test('should query remote getEverything and map to domain entities', () async {
      fakeRemoteDataSource.onGetEverything = ({
        required query,
        domains,
        page = 1,
        pageSize = 20,
        sortBy,
      }) async {
        return NewsResponseModel(
          status: 'ok',
          totalResults: 1,
          articles: [tArticleModel],
        );
      };

      final articles = await repository.searchNews(
        query: 'artificial intelligence',
        domains: 'wsj.com',
      );

      expect(articles.length, 1);
      expect(articles.first.title, 'New Gadget Launched');
    });

    test('should throw NetworkError when offline during search', () async {
      fakeNetworkInfo.isConnectedValue = false;

      expect(
        () => repository.searchNews(query: 'test'),
        throwsA(isA<NetworkError>()),
      );
    });

    test('should pass partial keywords like buis, techn, crick, polit to remote data source unchanged', () async {
      final receivedQueries = <String>[];
      fakeRemoteDataSource.onGetEverything = ({
        required query,
        domains,
        page = 1,
        pageSize = 20,
        sortBy,
      }) async {
        receivedQueries.add(query);
        return NewsResponseModel(
          status: 'ok',
          totalResults: 1,
          articles: [tArticleModel],
        );
      };

      for (final keyword in ['buis', 'techn', 'crick', 'polit']) {
        final results = await repository.searchNews(query: keyword);
        expect(results.length, 1);
      }

      expect(receivedQueries, ['buis', 'techn', 'crick', 'polit']);
    });
  });
}
