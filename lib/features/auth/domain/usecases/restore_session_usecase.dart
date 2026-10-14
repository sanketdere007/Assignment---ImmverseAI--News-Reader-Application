import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

/// Use case for restoring a persisted session on application startup.
class RestoreSessionUseCase {
  final AuthRepository _repository;

  const RestoreSessionUseCase(this._repository);

  Future<UserEntity?> call() {
    return _repository.restoreSession();
  }
}
