import '../../../news/data/models/news_article_model.dart';
import '../../../news/domain/entities/news_article.dart';
import '../../domain/repositories/bookmarks_repository.dart';
import '../datasources/bookmarks_local_data_source.dart';

/// Implementation of [BookmarksRepository] backed by [BookmarksLocalDataSource].
///
/// Maps domain [NewsArticle] entities to persistent [NewsArticleModel] instances
/// and preserves clean architecture separation.
class BookmarksRepositoryImpl implements BookmarksRepository {
  final BookmarksLocalDataSource _localDataSource;

  BookmarksRepositoryImpl({
    required BookmarksLocalDataSource localDataSource,
  }) : _localDataSource = localDataSource;

  @override
  Future<List<NewsArticle>> getBookmarks() async {
    final models = await _localDataSource.getBookmarks();
    return models.map((model) => model.toEntity()).toList();
  }

  @override
  Future<void> saveBookmark(NewsArticle article) async {
    final model = NewsArticleModel.fromEntity(article);
    await _localDataSource.saveBookmark(model);
  }

  @override
  Future<void> removeBookmark(String articleUrl) async {
    await _localDataSource.removeBookmark(articleUrl);
  }

  @override
  Future<bool> isBookmarked(String articleUrl) async {
    return _localDataSource.isBookmarked(articleUrl);
  }

  @override
  Future<void> clearAllBookmarks() async {
    await _localDataSource.clearAllBookmarks();
  }
}
