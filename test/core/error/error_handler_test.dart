import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicknews/core/error/app_error.dart';
import 'package:quicknews/core/error/error_handler.dart';

void main() {
  group('ErrorHandler and AppError', () {
    final tRequestOptions = RequestOptions(path: '/test');

    test('should map DioExceptionType.cancel to RequestCancelledError', () {
      final dioException = DioException(
        requestOptions: tRequestOptions,
        type: DioExceptionType.cancel,
      );
      final error = ErrorHandler.fromDioException(dioException);

      expect(error, isA<RequestCancelledError>());
    });

    test('should map Dio timeouts to TimeoutError', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.transformTimeout,
      ]) {
        final dioException = DioException(
          requestOptions: tRequestOptions,
          type: type,
        );
        final error = ErrorHandler.fromDioException(dioException);

        expect(error, isA<TimeoutError>());
      }
    });

    test('should map NewsAPI apiKeyInvalid, apiKeyMissing, and apiKeyDisabled to UnauthorizedError', () {
      for (final code in ['apiKeyInvalid', 'apiKeyMissing', 'apiKeyDisabled']) {
        final dioException = DioException(
          requestOptions: tRequestOptions,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: tRequestOptions,
            statusCode: 401,
            data: {'message': 'Key error occurred', 'code': code},
          ),
        );
        final error = ErrorHandler.fromDioException(dioException);

        expect(error, isA<UnauthorizedError>());
        expect(error.code, code);
      }
    });

    test('should include flutter run command in fallback message for apiKeyMissing', () {
      final dioException = DioException(
        requestOptions: tRequestOptions,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: tRequestOptions,
          statusCode: 401,
          data: {'code': 'apiKeyMissing'},
        ),
      );
      final error = ErrorHandler.fromDioException(dioException);

      expect(error, isA<UnauthorizedError>());
      expect(error.message, contains('flutter run --dart-define=NEWS_API_KEY=YOUR_API_KEY'));
    });

    test('should map NewsAPI rateLimited and apiKeyExhausted to RateLimitError', () {
      for (final code in ['rateLimited', 'apiKeyExhausted']) {
        final dioException = DioException(
          requestOptions: tRequestOptions,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: tRequestOptions,
            statusCode: 429,
            data: {'message': 'Quota exceeded', 'code': code},
          ),
        );
        final error = ErrorHandler.fromDioException(dioException);

        expect(error, isA<RateLimitError>());
        expect(error.code, code);
      }
    });

    test('should map HTTP 500 to ServerError', () {
      final dioException = DioException(
        requestOptions: tRequestOptions,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: tRequestOptions,
          statusCode: 500,
        ),
      );
      final error = ErrorHandler.fromDioException(dioException);

      expect(error, isA<ServerError>());
      expect((error as ServerError).statusCode, 500);
    });

    test('should map Dio connection error to NetworkError', () {
      final dioException = DioException(
        requestOptions: tRequestOptions,
        type: DioExceptionType.connectionError,
      );
      final error = ErrorHandler.fromDioException(dioException);

      expect(error, isA<NetworkError>());
    });

    test('should map unknown DioException with inner SocketException to NetworkError', () {
      final dioException = DioException(
        requestOptions: tRequestOptions,
        type: DioExceptionType.unknown,
        error: const SocketException('Connection refused'),
      );
      final error = ErrorHandler.fromDioException(dioException);

      expect(error, isA<NetworkError>());
    });

    test('should map FormatException and TypeError to DataParsingError', () {
      expect(
        ErrorHandler.fromException(const FormatException('Bad format')),
        isA<DataParsingError>(),
      );
      expect(
        ErrorHandler.fromException(TypeError()),
        isA<DataParsingError>(),
      );
    });

    test('should sanitize API key patterns from error strings', () {
      const sensitiveMessage =
          'Request failed with key a1b2c3d4e5f678901234567890abcdef in header';
      final sanitized = ErrorHandler.sanitize(sensitiveMessage);

      expect(sanitized.contains('a1b2c3d4e5f678901234567890abcdef'), isFalse);
      expect(sanitized, contains('[REDACTED]'));
    });
  });
}
