import '../../../../core/constants/api_constants.dart';
import '../entities/news_article.dart';
import '../repositories/news_repository.dart';

/// Use case to search news articles using the NewsAPI /everything endpoint.
class SearchNews {
  final NewsRepository _repository;

  const SearchNews(this._repository);

  /// Executes news search against `/everything`.
  Future<List<NewsArticle>> call({
    required String query,
    String? domains,
    String? sortBy,
    int page = 1,
    int pageSize = ApiConstants.defaultPageSize,
  }) {
    return _repository.searchNews(
      query: query,
      domains: domains,
      sortBy: sortBy,
      page: page,
      pageSize: pageSize,
    );
  }
}
