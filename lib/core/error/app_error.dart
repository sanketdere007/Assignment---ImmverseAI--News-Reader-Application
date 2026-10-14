import 'package:flutter/foundation.dart';

/// Base class for all application and domain errors in QuickNews.
///
/// Implements [Exception] so that errors can be thrown and caught in Dart's standard
/// exception handling pipeline. Preserves technical details safely for debugging
/// while presenting user-safe messages in [message].
@immutable
abstract class AppError implements Exception {
  final String message;
  final String? code;
  final dynamic technicalDetails;

  const AppError(
    this.message, {
    this.code,
    this.technicalDetails,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppError &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          code == other.code;

  @override
  int get hashCode => Object.hash(message, code);

  @override
  String toString() => message;
}

/// 1. Network failure or lack of internet connectivity.
class NetworkError extends AppError {
  const NetworkError([
    super.message = 'No internet connection. Please check your network and try again.',
    String? code,
    dynamic technicalDetails,
  ]) : super(code: code, technicalDetails: technicalDetails);
}

/// 2. Connection, send, or receive timeout.
class TimeoutError extends AppError {
  const TimeoutError([
    super.message = 'Connection timed out. Please check your connection and try again.',
    String? code,
    dynamic technicalDetails,
  ]) : super(code: code, technicalDetails: technicalDetails);
}

/// 3. HTTP 401/403 or invalid / unauthorized API credentials.
class UnauthorizedError extends AppError {
  const UnauthorizedError([
    super.message = 'Unauthorized or invalid API key. Please check your configuration.',
    String? code,
    dynamic technicalDetails,
  ]) : super(code: code, technicalDetails: technicalDetails);
}

/// 4. HTTP 429 API rate limit exceeded.
class RateLimitError extends AppError {
  const RateLimitError([
    super.message = 'API rate limit reached. Please wait a moment and try again.',
    String? code,
    dynamic technicalDetails,
  ]) : super(code: code, technicalDetails: technicalDetails);
}

/// 5. Server-side failures (HTTP 5xx or unhandled status codes).
class ServerError extends AppError {
  final int? statusCode;

  const ServerError([
    super.message = 'Failed to communicate with the server. Please try again later.',
    this.statusCode,
    String? code,
    dynamic technicalDetails,
  ]) : super(code: code, technicalDetails: technicalDetails);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerError &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          code == other.code &&
          statusCode == other.statusCode;

  @override
  int get hashCode => Object.hash(message, code, statusCode);
}

/// 6. Invalid JSON, malformed payload, or unexpected response structure.
class DataParsingError extends AppError {
  const DataParsingError([
    super.message = 'Failed to parse response from server. Unexpected data format.',
    String? code,
    dynamic technicalDetails,
  ]) : super(code: code, technicalDetails: technicalDetails);
}

/// 7. Empty article results returned for the requested criteria.
class EmptyResultsError extends AppError {
  const EmptyResultsError([
    super.message = 'No articles found matching your criteria.',
    String? code,
    dynamic technicalDetails,
  ]) : super(code: code, technicalDetails: technicalDetails);
}

/// 8. Missing compile-time or runtime API key configuration.
class ConfigurationError extends AppError {
  const ConfigurationError([
    super.message =
        'News API key is missing. Please run the application with:\n'
        'flutter run --dart-define=NEWS_API_KEY=YOUR_API_KEY',
    String? code,
    dynamic technicalDetails,
  ]) : super(code: code, technicalDetails: technicalDetails);
}

/// Local cache read or write failure.
class CacheError extends AppError {
  const CacheError([
    super.message = 'Failed to load cached data.',
    String? code,
    dynamic technicalDetails,
  ]) : super(code: code, technicalDetails: technicalDetails);
}

/// Cancelled HTTP or asynchronous request.
class RequestCancelledError extends AppError {
  const RequestCancelledError([
    super.message = 'The request was cancelled.',
    String? code,
    dynamic technicalDetails,
  ]) : super(code: code, technicalDetails: technicalDetails);
}

/// Unclassified or unexpected application error.
class UnknownError extends AppError {
  const UnknownError([
    super.message = 'An unexpected error occurred. Please try again.',
    String? code,
    dynamic technicalDetails,
  ]) : super(code: code, technicalDetails: technicalDetails);
}

