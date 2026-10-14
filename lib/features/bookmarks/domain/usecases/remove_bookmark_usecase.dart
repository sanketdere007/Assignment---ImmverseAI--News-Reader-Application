import '../repositories/bookmarks_repository.dart';

/// Use case to remove an article from offline bookmarks by its URL.
class RemoveBookmarkUseCase {
  final BookmarksRepository _repository;

  const RemoveBookmarkUseCase(this._repository);

  Future<void> call(String articleUrl) => _repository.removeBookmark(articleUrl);
}
