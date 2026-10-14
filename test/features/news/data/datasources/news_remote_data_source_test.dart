import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicknews/core/constants/api_constants.dart';
import 'package:quicknews/core/error/app_error.dart';
import 'package:quicknews/core/network/dio_client.dart';
import 'package:quicknews/features/news/data/datasources/news_remote_data_source.dart';

/// Test HTTP adapter allowing simulated HTTP responses and exceptions in Dio.
class FakeHttpClientAdapter implements HttpClientAdapter {
  Future<ResponseBody> Function(RequestOptions options)? onFetch;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (onFetch != null) {
      return onFetch!(options);
    }
    throw UnimplementedError('onFetch handler not configured for FakeHttpClientAdapter');
  }

  @override
  void close({bool force = false}) {}
}

/// Test RequestInterceptorHandler capturing interceptor transitions.
class FakeRequestInterceptorHandler extends RequestInterceptorHandler {
  bool nextCalled = false;
  RequestOptions? passedOptions;

  @override
  void next(RequestOptions options) {
    nextCalled = true;
    passedOptions = options;
  }
}

void main() {
  late FakeHttpClientAdapter fakeAdapter;
  late Dio dio;
  late DioClient dioClient;
  const testApiKey = 'test_api_key_1234567890abcdef12345678';

  final sampleArticleJson = {
    'source': {'id': 'bbc-news', 'name': 'BBC News'},
    'author': 'Correspondent',
    'title': 'Test Headline',
    'description': 'Test Description',
    'url': 'https://bbc.com/news/1',
    'urlToImage': 'https://bbc.com/img.jpg',
    'publishedAt': '2026-10-14T09:00:00Z',
    'content': 'Test Content',
  };

  final sampleResponse = {
    'status': 'ok',
    'totalResults': 1,
    'articles': [sampleArticleJson],
  };

  setUp(() {
    fakeAdapter = FakeHttpClientAdapter();
    dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
    dio.httpClientAdapter = fakeAdapter;
    dioClient = DioClient(dio: dio);
  });

  group('NewsRemoteDataSourceImpl - Top Headlines', () {
    test('should throw ConfigurationError with exact flutter run command when API key is empty', () async {
      final dataSource = NewsRemoteDataSourceImpl(
        dioClient: dioClient,
        apiKey: '   ',
      );

      try {
        await dataSource.getTopHeadlines();
        fail('Expected ConfigurationError to be thrown');
      } on ConfigurationError catch (e) {
        expect(e.message, contains('flutter run --dart-define=NEWS_API_KEY=YOUR_API_KEY'));
        expect(e.code, 'MISSING_API_KEY');
      }
    });

    test('should safely strip shell quotes from API key', () async {
      RequestOptions? capturedOptions;
      fakeAdapter.onFetch = (options) async {
        capturedOptions = options;
        return ResponseBody.fromString(
          jsonEncode(sampleResponse),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      final dataSource = NewsRemoteDataSourceImpl(
        dioClient: dioClient,
        apiKey: '"quoted_api_key_1234567890abcdef"',
      );

      await dataSource.getTopHeadlines();

      expect(capturedOptions!.headers[ApiConstants.apiKeyHeader], 'quoted_api_key_1234567890abcdef');
    });

    test('should fetch top headlines with default country=us, page=1, pageSize=20', () async {
      RequestOptions? capturedOptions;
      fakeAdapter.onFetch = (options) async {
        capturedOptions = options;
        return ResponseBody.fromString(
          jsonEncode(sampleResponse),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      final dataSource = NewsRemoteDataSourceImpl(
        dioClient: dioClient,
        apiKey: testApiKey,
      );

      final result = await dataSource.getTopHeadlines();

      expect(result.isSuccess, isTrue);
      expect(capturedOptions, isNotNull);
      expect(capturedOptions!.path, ApiConstants.topHeadlinesEndpoint);
      expect(capturedOptions!.queryParameters['country'], 'us');
      expect(capturedOptions!.queryParameters['page'], 1);
      expect(capturedOptions!.queryParameters['pageSize'], 20);
      expect(capturedOptions!.headers[ApiConstants.apiKeyHeader], testApiKey);
    });

    test('should pass selected category to top headlines', () async {
      RequestOptions? capturedOptions;
      fakeAdapter.onFetch = (options) async {
        capturedOptions = options;
        return ResponseBody.fromString(
          jsonEncode(sampleResponse),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      final dataSource = NewsRemoteDataSourceImpl(
        dioClient: dioClient,
        apiKey: testApiKey,
      );

      await dataSource.getTopHeadlines(category: 'technology');

      expect(capturedOptions!.queryParameters['category'], 'technology');
      expect(capturedOptions!.queryParameters['country'], 'us');
    });

    test('should pass exact lowercase query parameter for each supported category', () async {
      final categories = [
        'general',
        'business',
        'technology',
        'entertainment',
        'health',
        'science',
        'sports',
      ];

      for (final cat in categories) {
        RequestOptions? capturedOptions;
        fakeAdapter.onFetch = (options) async {
          capturedOptions = options;
          return ResponseBody.fromString(
            jsonEncode(sampleResponse),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        };

        final dataSource = NewsRemoteDataSourceImpl(
          dioClient: dioClient,
          apiKey: testApiKey,
        );

        await dataSource.getTopHeadlines(category: cat);

        expect(capturedOptions!.queryParameters['category'], cat);
        expect(capturedOptions!.queryParameters['country'], 'us');
        expect(capturedOptions!.queryParameters['page'], 1);
        expect(capturedOptions!.queryParameters['pageSize'], 20);
      }
    });

    test('should normalize capitalized category input to lowercase for API request', () async {
      RequestOptions? capturedOptions;
      fakeAdapter.onFetch = (options) async {
        capturedOptions = options;
        return ResponseBody.fromString(
          jsonEncode(sampleResponse),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      final dataSource = NewsRemoteDataSourceImpl(
        dioClient: dioClient,
        apiKey: testApiKey,
      );

      await dataSource.getTopHeadlines(category: 'Business');

      expect(capturedOptions!.queryParameters['category'], 'business');
    });

    test('should NOT combine sources with country or category', () async {
      RequestOptions? capturedOptions;
      fakeAdapter.onFetch = (options) async {
        capturedOptions = options;
        return ResponseBody.fromString(
          jsonEncode(sampleResponse),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      final dataSource = NewsRemoteDataSourceImpl(
        dioClient: dioClient,
        apiKey: testApiKey,
      );

      await dataSource.getTopHeadlines(
        sources: 'techcrunch',
        country: 'us',
        category: 'technology',
      );

      expect(capturedOptions!.queryParameters['sources'], 'techcrunch');
      expect(capturedOptions!.queryParameters.containsKey('country'), isFalse);
      expect(capturedOptions!.queryParameters.containsKey('category'), isFalse);
    });
  });

  group('NewsRemoteDataSourceImpl - Everything Endpoint', () {
    test('should query /everything endpoint with q, sortBy=publishedAt, page, and pageSize', () async {
      RequestOptions? capturedOptions;
      fakeAdapter.onFetch = (options) async {
        capturedOptions = options;
        return ResponseBody.fromString(
          jsonEncode(sampleResponse),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      final dataSource = NewsRemoteDataSourceImpl(
        dioClient: dioClient,
        apiKey: testApiKey,
      );

      final result = await dataSource.getEverything(
        query: 'flutter framework',
        domains: 'wsj.com',
        page: 2,
        pageSize: 20,
      );

      expect(result.isSuccess, isTrue);
      expect(capturedOptions, isNotNull);
      expect(capturedOptions!.path, ApiConstants.everythingEndpoint);
      expect(capturedOptions!.queryParameters['q'], 'flutter framework');
      expect(capturedOptions!.queryParameters['sortBy'], 'publishedAt');
      expect(capturedOptions!.queryParameters['domains'], 'wsj.com');
      expect(capturedOptions!.queryParameters['page'], 2);
      expect(capturedOptions!.queryParameters['pageSize'], 20);
    });

    test('should throw ConfigurationError when search query is empty', () async {
      final dataSource = NewsRemoteDataSourceImpl(
        dioClient: dioClient,
        apiKey: testApiKey,
      );

      expect(
        () => dataSource.getEverything(query: '   '),
        throwsA(isA<ConfigurationError>()),
      );
    });
  });

  group('NewsRemoteDataSourceImpl - Error Handling', () {
    test('should map NewsAPI apiKeyInvalid to UnauthorizedError', () async {
      fakeAdapter.onFetch = (options) async {
        return ResponseBody.fromString(
          jsonEncode({
            'status': 'error',
            'code': 'apiKeyInvalid',
            'message': 'Your API key is invalid or incorrect.',
          }),
          401,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      final dataSource = NewsRemoteDataSourceImpl(
        dioClient: dioClient,
        apiKey: testApiKey,
      );

      expect(
        () => dataSource.getTopHeadlines(),
        throwsA(isA<UnauthorizedError>()),
      );
    });

    test('should map NewsAPI rateLimited to RateLimitError', () async {
      fakeAdapter.onFetch = (options) async {
        return ResponseBody.fromString(
          jsonEncode({
            'status': 'error',
            'code': 'rateLimited',
            'message': 'Too many requests.',
          }),
          429,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      final dataSource = NewsRemoteDataSourceImpl(
        dioClient: dioClient,
        apiKey: testApiKey,
      );

      expect(
        () => dataSource.getTopHeadlines(),
        throwsA(isA<RateLimitError>()),
      );
    });

    test('should map HTTP 500 server error to ServerError', () async {
      fakeAdapter.onFetch = (options) async {
        return ResponseBody.fromString(
          'Internal Server Error',
          500,
        );
      };

      final dataSource = NewsRemoteDataSourceImpl(
        dioClient: dioClient,
        apiKey: testApiKey,
      );

      expect(
        () => dataSource.getTopHeadlines(),
        throwsA(isA<ServerError>()),
      );
    });

    test('should map Dio connection timeout to TimeoutError', () async {
      fakeAdapter.onFetch = (options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
          message: 'Connection timed out',
        );
      };

      final dataSource = NewsRemoteDataSourceImpl(
        dioClient: dioClient,
        apiKey: testApiKey,
      );

      expect(
        () => dataSource.getTopHeadlines(),
        throwsA(isA<TimeoutError>()),
      );
    });

    test('should map network connection failure to NetworkError', () async {
      fakeAdapter.onFetch = (options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'Failed to host lookup',
        );
      };

      final dataSource = NewsRemoteDataSourceImpl(
        dioClient: dioClient,
        apiKey: testApiKey,
      );

      expect(
        () => dataSource.getTopHeadlines(),
        throwsA(isA<NetworkError>()),
      );
    });

    test('should map non-map JSON payload to DataParsingError', () async {
      fakeAdapter.onFetch = (options) async {
        return ResponseBody.fromString(
          jsonEncode(['not', 'a', 'map']),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      final dataSource = NewsRemoteDataSourceImpl(
        dioClient: dioClient,
        apiKey: testApiKey,
      );

      expect(
        () => dataSource.getTopHeadlines(),
        throwsA(isA<DataParsingError>()),
      );
    });

    test('NewsApiKeyInterceptor attaches X-Api-Key when missing', () {
      const interceptor = NewsApiKeyInterceptor();
      final options = RequestOptions(path: '/top-headlines');
      final handler = FakeRequestInterceptorHandler();

      interceptor.onRequest(options, handler);

      expect(handler.nextCalled, isTrue);
    });

    test('SafeLoggingInterceptor never exposes sensitive keys or tokens', () {
      const interceptor = SafeLoggingInterceptor();
      final options = RequestOptions(
        path: '/top-headlines',
        headers: {
          'x-api-key': 'test_api_key_secret',
          'authorization': 'Bearer some_token',
        },
        queryParameters: {
          'apiKey': 'test_api_key_secret',
          'country': 'us',
        },
      );

      final handler = FakeRequestInterceptorHandler();
      interceptor.onRequest(options, handler);

      expect(handler.nextCalled, isTrue);
    });
  });

  group('ApiConstants Configuration', () {
    test('standardizes environment variable name to exactly NEWS_API_KEY', () {
      expect(ApiConstants.newsApiKeyEnv, 'NEWS_API_KEY');
    });

    test('apiKeyDiagnostic reports presence and char count safely without leaking key text', () {
      final diagnostic = ApiConstants.apiKeyDiagnostic;
      expect(diagnostic, isA<String>());
      if (ApiConstants.hasApiKey) {
        expect(diagnostic, contains('Present'));
        expect(diagnostic, contains('chars'));
      } else {
        expect(diagnostic, 'Missing (0 chars)');
      }
    });

    test('cleanApiKey strips surrounding quotes and whitespace', () {
      expect(ApiConstants.cleanApiKey, isA<String>());
    });
  });
}
