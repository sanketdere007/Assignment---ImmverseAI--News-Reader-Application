import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import 'app_error.dart';

/// Centralized error handling and conversion utility.
///
/// Converts low-level network, HTTP, serialization, and runtime exceptions
/// into typed, user-safe [AppError] domain objects. Redacts sensitive tokens
/// and API keys to protect user security.
abstract final class ErrorHandler {
  /// Regular expression to detect and redact potential 32-character hexadecimal
  /// or alphanumeric API keys in error strings.
  static final RegExp _apiKeyRegex = RegExp(r'[a-fA-F0-9]{32}');

  /// Maps a [DioException] into a domain-safe [AppError].
  static AppError fromDioException(DioException exception) {
    if (kDebugMode) {
      debugPrint('[ErrorHandler] Processing DioException: ${exception.type} - ${exception.message}');
    }

    switch (exception.type) {
      case DioExceptionType.cancel:
        return RequestCancelledError(
          'Request was cancelled.',
          'CANCELLED',
          exception.message,
        );

      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return TimeoutError(
          'Connection timed out. Please check your network and try again.',
          'TIMEOUT',
          exception.message,
        );

      case DioExceptionType.badCertificate:
        return ServerError(
          'Security certificate validation failed. Please check your network security.',
          exception.response?.statusCode,
          'BAD_CERTIFICATE',
          exception.message,
        );

      case DioExceptionType.connectionError:
        return NetworkError(
          'No internet connection or server unreachable. Please check your network.',
          'NO_INTERNET',
          exception.message,
        );

      case DioExceptionType.badResponse:
        return _handleBadResponse(exception.response);

      case DioExceptionType.unknown:
        final inner = exception.error;
        if (inner is SocketException || inner is HandshakeException) {
          return NetworkError(
            'Unable to connect to the news server. Please check your internet connection.',
            'SOCKET_ERROR',
            inner.toString(),
          );
        }
        if (inner is FormatException) {
          return DataParsingError(
            'Received malformed response from the news server.',
            'MALFORMED_JSON',
            inner.message,
          );
        }
        return UnknownError(
          'An unexpected network error occurred.',
          'UNKNOWN_DIO',
          exception.message,
        );
    }
  }

  /// Evaluates HTTP response status codes and server error payloads.
  static AppError _handleBadResponse(Response? response) {
    final statusCode = response?.statusCode;
    String? apiMessage;
    String? apiCode;

    // Safely extract error details if the server sent a JSON error payload
    final data = response?.data;
    if (data is Map<String, dynamic>) {
      if (data['message'] is String) {
        apiMessage = sanitize(data['message'] as String);
      }
      if (data['code'] is String) {
        apiCode = data['code'] as String;
      }
    }

    final normalizedCode = apiCode?.toLowerCase();
    if (normalizedCode == 'apikeyinvalid') {
      return UnauthorizedError(
        apiMessage ?? 'Your API key is invalid or incorrect. Please check your credentials.',
        'apiKeyInvalid',
        response?.data,
      );
    }
    if (normalizedCode == 'apikeymissing') {
      return UnauthorizedError(
        apiMessage ??
            'Your API key is missing. Please run the application with:\n'
            'flutter run --dart-define=NEWS_API_KEY=YOUR_API_KEY',
        'apiKeyMissing',
        response?.data,
      );
    }
    if (normalizedCode == 'apikeydisabled') {
      return UnauthorizedError(
        apiMessage ?? 'Your API key has been disabled. Please contact support or obtain a new key.',
        'apiKeyDisabled',
        response?.data,
      );
    }
    if (normalizedCode == 'apikeyexhausted') {
      return RateLimitError(
        apiMessage ?? 'Your API key has reached its request quota. Please upgrade or try again later.',
        'apiKeyExhausted',
        response?.data,
      );
    }
    if (normalizedCode == 'ratelimited' || statusCode == 429) {
      return RateLimitError(
        apiMessage ?? 'You have made too many requests recently. Please wait a moment and try again.',
        'rateLimited',
        response?.data,
      );
    }

    switch (statusCode) {
      case 401:
      case 403:
        return UnauthorizedError(
          apiMessage ?? 'Invalid API key or unauthorized access. Please verify your credentials.',
          apiCode ?? 'UNAUTHORIZED',
          response?.data,
        );

      case 400:
      case 404:
        return ServerError(
          apiMessage ?? 'The requested news resource was not found or the request was invalid.',
          statusCode,
          apiCode ?? 'BAD_REQUEST',
          response?.data,
        );

      case 500:
      case 502:
      case 503:
      case 504:
        return ServerError(
          'News service is currently unavailable. Please try again later.',
          statusCode,
          apiCode ?? 'SERVER_ERROR',
          response?.data,
        );

      default:
        return ServerError(
          apiMessage ?? 'Server returned an error (status: $statusCode).',
          statusCode,
          apiCode ?? 'HTTP_$statusCode',
          response?.data,
        );
    }
  }

  /// Maps any general [Object] or [Exception] into an [AppError].
  static AppError fromException(Object error, [StackTrace? stackTrace]) {
    if (error is AppError) {
      return error;
    }

    if (error is DioException) {
      return fromDioException(error);
    }

    if (error is SocketException) {
      return NetworkError(
        'No internet connection. Please verify your network.',
        'SOCKET_EXCEPTION',
        error.message,
      );
    }

    if (error is FormatException || error is TypeError) {
      return DataParsingError(
        'Failed to parse server data structure.',
        'PARSING_ERROR',
        error.toString(),
      );
    }

    return UnknownError(
      'An unexpected application error occurred.',
      'GENERIC_EXCEPTION',
      error.toString(),
    );
  }

  /// Sanitizes text strings to remove any embedded API keys or credentials.
  static String sanitize(String text) {
    var sanitized = text.replaceAll(_apiKeyRegex, '[REDACTED]');
    if (ApiConstants.cleanApiKey.isNotEmpty) {
      sanitized = sanitized.replaceAll(ApiConstants.cleanApiKey, '[REDACTED]');
    }
    return sanitized;
  }
}
