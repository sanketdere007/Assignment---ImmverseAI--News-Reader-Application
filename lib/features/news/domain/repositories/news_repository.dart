import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/app_error.dart';
import '../entities/news_article.dart';

/// Contract defining news retrieval operations.
///
/// Implementations must map remote models into domain entities and
/// convert all raw exceptions into typed [AppError] instances.
abstract class NewsRepository {
  /// Fetches top headlines based on filtering parameters.
  ///
  /// [country] defaults to [ApiConstants.defaultCountry] ('us').
  /// [page] pagination page number (1-indexed).
  /// [pageSize] number of results per page (defaults to [ApiConstants.defaultPageSize] = 20).
  /// [category] optional category filter (e.g. 'business', 'technology').
  /// [sources] optional publisher identifiers (e.g. 'techcrunch').
  /// [query] optional search keyword filter.
  ///
  /// Returns a list of [NewsArticle] domain entities.
  /// Throws [AppError] on network, authentication, or parsing failures.
  Future<List<NewsArticle>> getTopHeadlines({
    String? country,
    String? category,
    String? sources,
    String? query,
    int page = 1,
    int pageSize = ApiConstants.defaultPageSize,
  });

  /// Searches articles across the `/everything` endpoint.
  ///
  /// [query] search keyword (required and non-empty).
  /// [domains] optional source-domain filter (e.g. 'wsj.com').
  /// [sortBy] sorting mode, defaults to [ApiConstants.defaultSortBy] ('publishedAt').
  /// [page] pagination page.
  /// [pageSize] items per page.
  Future<List<NewsArticle>> searchNews({
    required String query,
    String? domains,
    String? sortBy,
    int page = 1,
    int pageSize = ApiConstants.defaultPageSize,
  });
}
