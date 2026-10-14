import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';

/// Riverpod provider for dependency injection of [DioClient].
final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient();
});

/// Reusable HTTP networking client powered by Dio.
class DioClient {
  DioClient({Dio? dio}) : _dio = dio ?? _createDio();

  final Dio _dio;

  Dio get dio => _dio;

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        sendTimeout: ApiConstants.sendTimeout,
        headers: const <String, dynamic>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        responseType: ResponseType.json,
      ),
    );

    // Attach News API authentication interceptor
    dio.interceptors.add(const NewsApiKeyInterceptor());

    // Attach safe logging interceptor in debug mode only
    if (kDebugMode) {
      debugPrint(
        '[DioClient] Initialized Dio (API key status: ${ApiConstants.apiKeyDiagnostic})',
      );
      dio.interceptors.add(const SafeLoggingInterceptor());
    }

    return dio;
  }

  /// Convenience GET request wrapper.
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// Convenience POST request wrapper.
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// Convenience PUT request wrapper.
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// Convenience DELETE request wrapper.
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }
}

/// Automatically injects X-Api-Key request header when targeting NewsAPI.
class NewsApiKeyInterceptor extends Interceptor {
  const NewsApiKeyInterceptor();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final key = ApiConstants.cleanApiKey;
    if (key.isNotEmpty) {
      final existingKey = options.headers.keys.firstWhere(
        (k) => k.toLowerCase() == ApiConstants.apiKeyHeader.toLowerCase(),
        orElse: () => '',
      );

      if (existingKey.isEmpty) {
        options.headers[ApiConstants.apiKeyHeader] = key;
      } else {
        final val = options.headers[existingKey];
        if (val == null || (val is String && val.trim().isEmpty)) {
          options.headers[existingKey] = key;
        }
      }

      if (kDebugMode) {
        debugPrint(
          '[NewsApiKeyInterceptor] Request ${options.path}: attached X-Api-Key (${key.length} chars)',
        );
      }
    } else {
      if (kDebugMode) {
        debugPrint(
          '[NewsApiKeyInterceptor] Request ${options.path}: API key missing (0 chars)',
        );
      }
    }
    handler.next(options);
  }
}

/// Reusable interceptor for safe logging in debug mode.
/// Redacts sensitive keys, query parameters, authorization tokens, and API keys.
class SafeLoggingInterceptor extends Interceptor {
  const SafeLoggingInterceptor();

  static final RegExp _apiKeyRegex = RegExp(r'[a-fA-F0-9]{32}');

  static const Set<String> _sensitiveHeaderKeys = {
    'authorization',
    'x-api-key',
    'apikey',
    'cookie',
    'set-cookie',
  };

  static const Set<String> _sensitivePayloadKeys = {
    'password',
    'token',
    'secret',
    'apikey',
    'api_key',
    'key',
    'auth_token',
    'access_token',
    'refresh_token',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('[HTTP Request] ${options.method} ${_sanitizeUri(options.uri)}');
      final sanitizedHeaders = _sanitizeHeaders(options.headers);
      debugPrint('[HTTP Headers] $sanitizedHeaders');
      if (options.data != null) {
        debugPrint('[HTTP Body] ${_sanitizePayload(options.data)}');
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint(
        '[HTTP Response] Status ${response.statusCode} for ${_sanitizeUri(response.requestOptions.uri)}',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      final message = _sanitizeString(err.message ?? '');
      debugPrint(
        '[HTTP Error] ${err.type} for ${_sanitizeUri(err.requestOptions.uri)}: $message',
      );
    }
    handler.next(err);
  }

  static String _sanitizeString(String text) {
    var sanitized = text.replaceAll(_apiKeyRegex, '[REDACTED]');
    if (ApiConstants.cleanApiKey.isNotEmpty) {
      sanitized = sanitized.replaceAll(ApiConstants.cleanApiKey, '[REDACTED]');
    }
    return sanitized;
  }

  static String _sanitizeUri(Uri uri) {
    if (!uri.hasQuery) return _sanitizeString(uri.toString());

    final sanitizedParams = Map<String, dynamic>.from(uri.queryParameters);
    for (final key in sanitizedParams.keys.toList()) {
      if (_sensitivePayloadKeys.contains(key.toLowerCase()) ||
          key.toLowerCase().contains('key')) {
        sanitizedParams[key] = '[REDACTED]';
      }
    }
    final sanitizedUri = uri.replace(queryParameters: sanitizedParams);
    return _sanitizeString(sanitizedUri.toString());
  }

  Map<String, dynamic> _sanitizeHeaders(Map<String, dynamic> headers) {
    return headers.map((key, value) {
      if (_sensitiveHeaderKeys.contains(key.toLowerCase())) {
        return MapEntry(key, '[REDACTED]');
      }
      return MapEntry(key, value);
    });
  }

  dynamic _sanitizePayload(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data.map((key, value) {
        if (_sensitivePayloadKeys.contains(key.toLowerCase())) {
          return MapEntry(key, '[REDACTED]');
        }
        if (value is Map<String, dynamic>) {
          return MapEntry(key, _sanitizePayload(value));
        }
        return MapEntry(key, value);
      });
    }
    return data;
  }
}
