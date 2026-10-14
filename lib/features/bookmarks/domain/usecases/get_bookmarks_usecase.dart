import '../../../news/domain/entities/news_article.dart';
import '../repositories/bookmarks_repository.dart';

/// Use case to load all saved bookmarks.
class GetBookmarksUseCase {
  final BookmarksRepository _repository;

  const GetBookmarksUseCase(this._repository);

  Future<List<NewsArticle>> call() => _repository.getBookmarks();
}
