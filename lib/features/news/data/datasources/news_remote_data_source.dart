import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/app_error.dart';
import '../../../../core/error/error_handler.dart';
import '../../../../core/network/dio_client.dart';
import '../models/news_response_model.dart';

/// Contract defining remote news API calls.
abstract class NewsRemoteDataSource {
  /// Fetches top headlines from NewsAPI.
  ///
  /// [country] defaults to [ApiConstants.defaultCountry] ('us').
  /// [page] 1-indexed pagination page.
  /// [pageSize] items per page.
  /// [category] optional category filter.
  /// [sources] optional source identifiers (e.g. 'techcrunch'). Cannot be combined with country/category.
  /// [query] optional search term.
  ///
  /// Throws [AppError] on missing configuration, network issues, or API errors.
  Future<NewsResponseModel> getTopHeadlines({
    String? country,
    String? category,
    String? sources,
    String? query,
    int page = 1,
    int pageSize = ApiConstants.defaultPageSize,
  });

  /// Searches articles across the `/everything` endpoint.
  ///
  /// [query] search term (must not be empty).
  /// [domains] optional source-domain filter (e.g. 'wsj.com').
  /// [sortBy] sorting mode, defaults to [ApiConstants.defaultSortBy] ('publishedAt').
  /// [page] pagination page.
  /// [pageSize] items per page.
  Future<NewsResponseModel> getEverything({
    required String query,
    String? domains,
    String? sortBy,
    int page = 1,
    int pageSize = ApiConstants.defaultPageSize,
  });
}

/// Implementation of [NewsRemoteDataSource] using [DioClient].
class NewsRemoteDataSourceImpl implements NewsRemoteDataSource {
  final DioClient _dioClient;
  final String _apiKey;

  NewsRemoteDataSourceImpl({
    required DioClient dioClient,
    String? apiKey,
  })  : _dioClient = dioClient,
        _apiKey = apiKey ?? ApiConstants.cleanApiKey;

  @override
  Future<NewsResponseModel> getTopHeadlines({
    String? country,
    String? category,
    String? sources,
    String? query,
    int page = 1,
    int pageSize = ApiConstants.defaultPageSize,
  }) async {
    final cleanKey = _validateApiKey();

    // 1. Prepare query parameters
    final queryParameters = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
    };

    // NewsAPI constraint: Do NOT mix 'sources' with 'country' or 'category'
    if (sources != null && sources.trim().isNotEmpty) {
      queryParameters['sources'] = sources.trim();
    } else {
      final effectiveCountry = country ?? ApiConstants.defaultCountry;
      if (effectiveCountry.isNotEmpty) {
        queryParameters['country'] = effectiveCountry;
      }
      if (category != null && category.trim().isNotEmpty) {
        queryParameters['category'] = category.trim().toLowerCase();
      }
    }

    if (query != null && query.trim().isNotEmpty) {
      queryParameters['q'] = query.trim();
    }

    if (kDebugMode) {
      debugPrint(
        '[NewsRemoteDataSource] GET /top-headlines: '
        'country=${queryParameters["country"]}, '
        'category=${queryParameters["category"] ?? "none"}, '
        'page=${queryParameters["page"]}',
      );
    }

    // 2. Execute GET request to /top-headlines
    return _performGetRequest(
      path: ApiConstants.topHeadlinesEndpoint,
      queryParameters: queryParameters,
      apiKey: cleanKey,
    );
  }

  @override
  Future<NewsResponseModel> getEverything({
    required String query,
    String? domains,
    String? sortBy,
    int page = 1,
    int pageSize = ApiConstants.defaultPageSize,
  }) async {
    final cleanKey = _validateApiKey();
    final cleanQuery = query.trim();

    // NewsAPI constraint: Do not send an empty query to Everything endpoint
    if (cleanQuery.isEmpty) {
      throw const ConfigurationError(
        'Search query cannot be empty when searching articles.',
        'EMPTY_QUERY',
      );
    }

    final queryParameters = <String, dynamic>{
      'q': cleanQuery,
      'page': page,
      'pageSize': pageSize,
      'sortBy': sortBy ?? ApiConstants.defaultSortBy,
    };

    if (domains != null && domains.trim().isNotEmpty) {
      queryParameters['domains'] = domains.trim();
    }

    if (kDebugMode) {
      debugPrint(
        '[NewsRemoteDataSource] GET /everything: '
        'q="$cleanQuery", page=$page, pageSize=$pageSize, '
        'sortBy=${queryParameters["sortBy"]}',
      );
    }

    // Execute GET request to /everything
    return _performGetRequest(
      path: ApiConstants.everythingEndpoint,
      queryParameters: queryParameters,
      apiKey: cleanKey,
    );
  }

  String _validateApiKey() {
    var cleanKey = _apiKey.trim();
    if ((cleanKey.startsWith('"') && cleanKey.endsWith('"')) ||
        (cleanKey.startsWith("'") && cleanKey.endsWith("'"))) {
      cleanKey = cleanKey.substring(1, cleanKey.length - 1).trim();
    }

    if (kDebugMode) {
      final status = cleanKey.isNotEmpty
          ? 'Present (${cleanKey.length} chars)'
          : 'Missing (0 chars)';
      debugPrint('[NewsRemoteDataSource] API key validation: $status');
    }

    if (cleanKey.isEmpty) {
      throw const ConfigurationError(
        'News API key is missing. Please run the application with:\n'
        'flutter run --dart-define=NEWS_API_KEY=YOUR_API_KEY',
        'MISSING_API_KEY',
      );
    }
    return cleanKey;
  }

  Future<NewsResponseModel> _performGetRequest({
    required String path,
    required Map<String, dynamic> queryParameters,
    required String apiKey,
  }) async {
    try {
      final response = await _dioClient.get(
        path,
        queryParameters: queryParameters,
        options: Options(
          headers: <String, dynamic>{
            ApiConstants.apiKeyHeader: apiKey,
          },
        ),
      );

      if (kDebugMode) {
        debugPrint(
          '[NewsRemoteDataSource] Response HTTP ${response.statusCode} for $path',
        );
      }

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const DataParsingError(
          'Unexpected server response: Expected a JSON object.',
          'INVALID_ROOT_TYPE',
        );
      }

      final model = NewsResponseModel.fromJson(data);

      // Verify if News API returned a functional error in payload
      if (!model.isSuccess) {
        final errorCode = model.code?.toLowerCase();
        final message = model.message ?? 'News API reported an error.';

        if (errorCode == 'apikeyinvalid' ||
            errorCode == 'apikeymissing' ||
            errorCode == 'apikeydisabled') {
          throw UnauthorizedError(message, model.code, data);
        } else if (errorCode == 'ratelimited' || errorCode == 'apikeyexhausted') {
          throw RateLimitError(message, model.code, data);
        } else {
          throw ServerError(message, response.statusCode, model.code, data);
        }
      }

      return model;
    } on DioException catch (e) {
      throw ErrorHandler.fromDioException(e);
    } on AppError {
      rethrow;
    } catch (e, stack) {
      throw ErrorHandler.fromException(e, stack);
    }
  }
}
