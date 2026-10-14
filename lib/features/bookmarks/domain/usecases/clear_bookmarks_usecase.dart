import '../repositories/bookmarks_repository.dart';

/// Use case to clear all saved bookmarks.
class ClearBookmarksUseCase {
  final BookmarksRepository _repository;

  const ClearBookmarksUseCase(this._repository);

  Future<void> call() => _repository.clearAllBookmarks();
}
