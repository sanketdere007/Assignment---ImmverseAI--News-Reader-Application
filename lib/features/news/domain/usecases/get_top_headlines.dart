import '../../../../core/constants/api_constants.dart';
import '../entities/news_article.dart';
import '../repositories/news_repository.dart';

/// Use case that retrieves top headlines from the [NewsRepository].
class GetTopHeadlines {
  final NewsRepository _repository;

  const GetTopHeadlines(this._repository);

  /// Executes the top headlines retrieval request.
  Future<List<NewsArticle>> call({
    String? country,
    String? category,
    String? sources,
    String? query,
    int page = 1,
    int pageSize = ApiConstants.defaultPageSize,
  }) {
    return _repository.getTopHeadlines(
      country: country,
      category: category,
      sources: sources,
      query: query,
      page: page,
      pageSize: pageSize,
    );
  }
}
