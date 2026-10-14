import '../../../news/domain/entities/news_article.dart';
import '../repositories/bookmarks_repository.dart';

/// Use case to save an article to offline bookmarks.
class SaveBookmarkUseCase {
  final BookmarksRepository _repository;

  const SaveBookmarkUseCase(this._repository);

  Future<void> call(NewsArticle article) => _repository.saveBookmark(article);
}
