import 'package:dio/dio.dart';

abstract class AppException implements Exception {
  const AppException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() => 'AppException: $message (statusCode: $statusCode)';
}

class ServerException extends AppException {
  const ServerException([
    super.message = 'A server error occurred.',
    super.statusCode,
  ]);
}

class NetworkException extends AppException {
  const NetworkException([super.message = 'No Internet connection.']);
}

class CacheException extends AppException {
  const CacheException([super.message = 'A local storage error occurred.']);
}

class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'Unauthorized access.']);
}

class RequestCancelledException extends AppException {
  const RequestCancelledException([
    super.message = 'Network request was cancelled.',
  ]);
}

/// Extension mapping [DioException] to domain-friendly [AppException].
extension DioExceptionMapper on DioException {
  AppException toAppException() {
    switch (type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.transformTimeout:
        return const NetworkException(
          'Network connection timeout. Please check your internet.',
        );
      case DioExceptionType.badResponse:
        final code = response?.statusCode;
        if (code == 401 || code == 403) {
          return UnauthorizedException(
            'Unauthorized (status code: $code). Please check API key.',
          );
        }
        return ServerException(
          response?.statusMessage ?? 'Server error occurred ($code).',
          code,
        );
      case DioExceptionType.cancel:
        return const RequestCancelledException();
      case DioExceptionType.badCertificate:
        return const NetworkException('SSL certificate validation failed.');
      case DioExceptionType.unknown:
        return NetworkException(
          message ?? 'An unexpected network error occurred.',
        );
    }
  }
}
