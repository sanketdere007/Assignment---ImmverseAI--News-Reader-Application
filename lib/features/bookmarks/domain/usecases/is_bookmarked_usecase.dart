import '../repositories/bookmarks_repository.dart';

/// Use case to check if an article URL is bookmarked.
class IsBookmarkedUseCase {
  final BookmarksRepository _repository;

  const IsBookmarkedUseCase(this._repository);

  Future<bool> call(String articleUrl) => _repository.isBookmarked(articleUrl);
}
